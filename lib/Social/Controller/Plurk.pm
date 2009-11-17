package Social::Controller::Plurk;
use strict;
use warnings;

use parent "Tatsumaki::Handler";

use Social::Helpers;

sub post {
    my ($self) = @_;
    my $v = $self->request->params;
    $self->application->plurk_client->add_plurk($v->{text});
    $self->write({ success => 1 });
}

1;
