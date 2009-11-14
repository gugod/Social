package Social::IRCClient;
use strict;
use warnings;
use base 'AnyEvent::IRC::Client';
use Tatsumaki::MessageQueue;
use Social::Helpers;

sub new {
    my ($class) = @_;
    my $self = AnyEvent::IRC::Client->new;
    bless $self, $class;

    $self->reg_cb(
        publicmsg  => sub {
            my ($con, $channel, $packet) = @_;

            if ($packet->{command} eq 'NOTICE' || $packet->{command} eq 'PRIVMSG') {
                # NOTICE for bouncer backlog
                my $msg = $packet->{params}[1];
                (my $who = $packet->{prefix}) =~ s/\!.*//;

                Social::Helpers->mq_publish({
                    type    => "privmsg",
                    channel => $self->heap->{network} . " " . $channel,
                    name    => $who,
                    html    => Social::Helpers->format_message( Encode::decode_utf8($msg) )
                });
            }
        },

        registered => sub {
            my ($con) = @_;
            my $channels = $con->heap->{config}{channels};

            for my $x (@$channels) {
                my ($channel, $password) =
                    (ref($x) eq 'ARRAY') ? @$x
                        : !ref($x) ? $x
                            : die("Don't understand the value $x");

                $channel =~ s/^(?![&#!+])/#/;

                $con->send_srv('JOIN', $channel, $password);
            }
        },

        join => sub {
            my ($con, $nick, $channel, $is_myself) = @_;
            Social::Helpers->mq_publish({
                type      => 'join',
                channel => $self->heap->{network} . " " . $channel,
                name      => $nick,
                is_myself => $is_myself
            });
        },

        part => sub {
            my ($con, $nick, $channel, $is_myself) = @_;
            Social::Helpers->mq_publish({
                type      => 'part',
                channel => $self->heap->{network} . " " . $channel,
                name      => $nick,
                is_myself => $is_myself
            });
        },

        ## A verf generic handler
        # read => sub {
        #     my ($con, $msg) = @_;
        #     my $cmd = lc($msg->{command});
        #     print Dump($msg);
        # }
    );

    return $self;
}

1;
