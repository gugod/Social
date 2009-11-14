package Social::Controller::Dashboard;
use strict;
use parent qw(Tatsumaki::Handler);

sub get {
    my ($self) = @_;

    $self->render('app.html', {
        channels => $self->application->irc_channels,
        nick     => $self->application->irc_nick,
    });
}

1;
