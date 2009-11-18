package Social::Controller::Irc;
use strict;
use warnings;

use parent "Tatsumaki::Handler";

use Social::Helpers;
use Encode ();

sub post {
    my ($self) = @_;

    my $v = $self->request->params;
    $self->application->irc_send('privmsg', $v->{channel}, Encode::encode_utf8($v->{text}));

    my $html = Social::Helpers->format_message($v->{text});
    Social::Helpers->mq_publish({
        type    => "privmsg",
        html    => $html,
        channel => $v->{channel},
        name    => $v->{ident},
        address => $self->request->address,
        time    => scalar localtime(time),
    });

    $self->write({ success => 1 });
}

1;
