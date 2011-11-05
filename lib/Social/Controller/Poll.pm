package Social::Controller::Poll;
use parent qw(Tatsumaki::Handler);

__PACKAGE__->asynchronous(1);

use Tatsumaki::MessageQueue;
use AnyEvent::IRC::Util qw(encode_ctcp);
use Encode qw(encode_utf8);
use Social::Helpers;


sub get {
    my ($self) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");
    $session = rand(1) if $session eq 'dummy'; # for benchmarking stuff

    my $mq = Tatsumaki::MessageQueue->instance("social");
    $mq->poll_once($session, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my($self, @events) = @_;
    $self->write(\@events);
    $self->finish;
}

1;
