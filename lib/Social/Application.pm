package Social::Application;
use 5.010;
use Moose;

extends "Tatsumaki::Application";

use Social::IRCClient;
use Social::Helpers;
use Social::Controller::Welcome;
use Social::Controller::Irc;
use Social::Controller::IrcPoll;
use Social::Controller::IrcMultipartPoll;

has config      => (is => "rw", isa => "HashRef");

has irc_clients => (is => "rw", isa => "HashRef", lazy_build => 1);

sub app {
    my($class, %args) = @_;
    my $self = $class->new([
        "/irc/mpoll" => "Social::Controller::IrcMultipartPoll",
        "/irc/poll"  => "Social::Controller::IrcPoll",
        "/irc"       => "Social::Controller::Irc",
        "/"          => "Social::Controller::Welcome",
    ]);
    $self->config($args{config});
    $self;
}

sub _build_irc_clients {
    my $self = shift;
    my $CONFIG = $self->config;

    my %IRC_CLIENT;
    while (my ($network, $config) = each %{$CONFIG->{networks}}) {
        my $x = Social::IRCClient->new;
        $x->heap->{config}  = $config;
        $x->heap->{network} = $network;

        $x->connect(
            $config->{host},
            $config->{port} || 6667,
            {
                nick     => $CONFIG->{nick},
                password => $config->{password}
            }
        );

        $IRC_CLIENT{$network} = $x;
    }
    return \%IRC_CLIENT;
}

sub irc_nick {
    my $self = shift;
    return $self->config->{nick};
}

sub irc_send {
    my $self = shift;
    my ($cmd, $target, @params) = @_;

    my ($network, $channel) = split(" ", $target, 2);

    my $client = $self->irc_clients->{$network}
        or die "Unknown network: $network\n";

    $client->send_srv($cmd, $channel, @params);
}

sub irc_channels {
    my $self = shift;
    my @channels;
    my $clients = $self->irc_clients;

    for my $network (keys %$clients) {
        push @channels, (map { "$network $_" } keys %{$clients->{$network}->channel_list});
    }
    return \@channels;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
