package Social::Application;
use 5.010;
use Moose;

extends "Tatsumaki::Application";

use Social::Helpers;
use Social::Controller::Dashboard;
use Social::Controller::Poll;
use Social::Controller::MultipartPoll;
use Social::Controller::Irc;
use Social::Controller::Twitter;

use Social::IRCClient;
use Social::TwitterClient;
use Social::PlurkClient;

has config => (
    is  => "rw",
    isa => "HashRef"
);

has irc_clients => (
    is         => "ro",
    isa        => "HashRef",
    required   => 1,
    lazy_build => 1
);

has twitter_client => (
    is         => "ro",
    isa        => "Social::TwitterClient",
    lazy_build => 1
);

has plurk_client => (
    is         => "ro",
    isa        => "Social::PlurkClient",
    lazy_build => 1
);

sub app {
    my($class, %args) = @_;
    my $self = $class->new([
        "/mpoll"     => "Social::Controller::MultipartPoll",
        "/poll"      => "Social::Controller::Poll",
        "/irc"       => "Social::Controller::Irc",
        "/twitter"   => "Social::Controller::Twitter",
        "/"          => "Social::Controller::Dashboard",
    ]);
    $self->config($args{config});

    $Tatsumaki::MessageQueue::BacklogLength = $args{config}->{MessageQueueBacklogLength} || 300;

    $self->irc_clients;
    $self->twitter_client if $args{config}->{twitter};
    $self->plurk_client if $args{config}->{plurk};
    return $self;
}

sub _build_plurk_client {
    my $self = shift;
    my $x = $self->config->{plurk};

    return undef unless defined $x;
    return Social::PlurkClient->app(config => $x);
}

sub _build_twitter_client {
    my $self = shift;
    my $x = $self->config->{twitter};

    return undef unless defined $x;
    return Social::TwitterClient->app(config => $x);
}

sub _build_irc_clients {
    my $self = shift;

    my $CONFIG = $self->config->{irc};
    return undef unless defined($CONFIG);

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
    return $self->config->{irc}{nick};
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
