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
            my($con, $channel, $packet) = @_;
            if ($packet->{command} eq 'NOTICE' || $packet->{command} eq 'PRIVMSG') {
                # NOTICE for bouncer backlog
                my $msg = $packet->{params}[1];
                (my $who = $packet->{prefix}) =~ s/\!.*//;
                my $mq = Tatsumaki::MessageQueue->instance("irc");
                $mq->publish({
                    type => "message",
                    address => "chat.freenode.net",
                    time => scalar localtime,
                    channel => $channel,
                    name => $who,
                    ident => "$who\@gmail.com", # let's just assume everyone's gmail :)
                    html => Social::Helpers->format_message( Encode::decode_utf8($msg) )
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
            my ($con, $nick, $channel) = @_;
            print "$nick joined $channel\n";
        }
    );

    return $self;
}

1;
