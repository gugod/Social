package Social::Controller::Twitter;
use strict;
use warnings;

use parent "Tatsumaki::Handler";

use Social::Helpers;
use Encode ();

sub post {
    my ($self) = @_;
    my $v = $self->request->params;
    $self->application->twitter_client->update_status($v->{text});
    $self->write({ success => 1 });
}

1;
