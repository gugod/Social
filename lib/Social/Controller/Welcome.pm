package Social::Controller::Welcome;
use strict;
use parent qw(Tatsumaki::Handler);

sub get {
    my ($self) = @_;
    $self->render('welcome.html');
}

1;
