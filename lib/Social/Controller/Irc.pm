package Social::Controller::Irc;
use Moose;

extends "Tatsumaki::Handler";

use Encode ();

sub get {
    my ($self) = @_;

    $self->render('irc.html', {
        channels => $self->application->irc_channels,
        nick     => $self->application->irc_nick,
    });
}

sub post {
    my ($self) = @_;

    my $v = $self->request->params;

    $self->application->irc_send('privmsg', $v->{channel}, Encode::encode_utf8($v->{text}));

    my $html = Social::Helpers->format_message($v->{text});

    my $mq = Tatsumaki::MessageQueue->instance("irc");
    $mq->publish({
        type    => "privmsg",
        html    => $html,
        ident   => $v->{ident},
        channel => $v->{channel},
        avatar  => $v->{avatar},
        name    => $v->{name},
        address => $self->request->address,
        time    => scalar localtime(time),
    });

    $self->write({ success => 1 });
}


1;
