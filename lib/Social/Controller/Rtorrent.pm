package Social::Controller::Rtorrent;
use common::sense;
use parent "Tatsumaki::Handler";
use Social::Helpers;

sub post {
    my ($self) = @_;
    my $v = $self->request->params;

    if ($v->{cmd} eq "load_start") {
        if ($v->{text} =~ m[^(?:http://www.mininova.org/tor/)?(\d+)]i) {
            $self->application->rtorrent_client->update_status(
                $v->{cmd},
                "http://www.mininova.org/get/$1"
            );
        }
    } else {
        $self->application->rtorrent_client->update_status($v->{cmd},$v->{id});
    }
    $self->write({ success => 1 });
}

1;
