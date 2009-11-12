package Social::Application;
use 5.010;
use Moose;

extends "Tatsumaki::Application";

has config      => (is => "rw", isa => "HashRef");
has irc_clients => (is => "rw", isa => "HashRef");

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
