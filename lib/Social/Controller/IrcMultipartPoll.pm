package Social::Controller::IrcMultipartPoll;
use strict;
use warnings;

use parent qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my($self) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance("irc");
    $mq->poll($session, sub {
        my @events = @_;
        for my $event (@events) {
            $self->stream_write($event);
        }
    });
}

1;
