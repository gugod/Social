package Social::Controller::Irc;
use strict;
use warnings;

use parent "Tatsumaki::Handler";

use Social::Helpers;
use Encode ();

sub get {
    my ($self) = @_;

    $self->render('irc.html', {
        channels => $self->application->irc_channels,
        nick     => $self->application->irc_nick,
    });
}

use YAML;

sub post {
    my ($self) = @_;

    my $v = $self->request->params;
    $self->application->irc_send('privmsg', $v->{channel}, Encode::encode_utf8($v->{text}));

    my $html = Social::Helpers->format_message($v->{text});
    Social::Helpers->mq_publish({
        type    => "privmsg",
        html    => $html,
        ident   => $v->{ident},
        channel => $v->{channel},
        name    => $v->{name},
        address => $self->request->address,
        time    => scalar localtime(time),
    });

    $self->write({ success => 1 });
}

1;
