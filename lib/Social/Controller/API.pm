package Social::Controller::API;
use parent qw(Tatsumaki::Handler);
use warnings;
use strict;
use AnyEvent::IRC::Util qw(encode_ctcp);
use Encode qw(encode_utf8);
use Social::Helpers;

# __PACKAGE__->asynchronous(1);
use Tatsumaki::MessageQueue;
use JSON::XS;

sub get {
    my ($self) = @_;
    # my %params = %{$self->request->params};
    my $payload = $self->request->parameters->{payload}; # json
    return $self->write({ error => 'payload is required.' }) unless $payload;

    my $data = decode_json( $payload );

    return $self->write({ error => 'can not decode json' }) unless $data;
    
    my $channel = $data->{channel};
    my $message = $data->{message};
    my $network = $data->{network};
    return $self->write({ error => 'network is required' }) unless $network;
    return $self->write({ error => 'channel is required' }) unless $channel;
    return $self->write({ error => 'message is required' }) unless $message;

    my $irc_event = "privmsg";
    $self->application->irc_send( $irc_event, $network . ' ' . $channel , encode_utf8($message));
    $self->write({ success => 1 });
}

1;
