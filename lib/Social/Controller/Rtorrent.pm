package Social::Controller::Rtorrent;
use strict;
use warnings;

use parent "Tatsumaki::Handler";

use Social::Helpers;
use Encode ();

sub post {
    my ($self) = @_;
    my $v = $self->request->params;
    if($v->{cmd} =~ /^load_start$/) {
        $self->application->rtorrent_client->update_status($v->{cmd},"http://www.mininova.org/get/".$v->{text});
    } else {
        $self->application->rtorrent_client->update_status($v->{cmd},$v->{id});
    }
    $self->write({ success => 1 });
}

1;
