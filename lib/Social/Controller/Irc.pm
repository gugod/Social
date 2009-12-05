package Social::Controller::Irc;
use strict;
use warnings;

use parent "Tatsumaki::Handler";

use AnyEvent::IRC::Util qw(encode_ctcp);
use Encode qw(encode_utf8);
use Social::Helpers;

sub post {
    my ($self) = @_;
    my %params = %{$self->request->params};

    my $text = $params{text};
    my $irc_event = "privmsg";

    if ($text =~ s{^/me }{}) {
        my $ctcp_data = encode_ctcp(["ACTION", Encode::encode_utf8($text)]);
        $self->application->irc_send($irc_event, $params{channel}, $ctcp_data);

        $irc_event = "ctcp_action";
    }
    else {
        $self->application->irc_send($irc_event, $params{channel}, encode_utf8($text));
    }

    my $html = format_message($text);
    mq_publish({
        type    => "irc_${irc_event}",
        html    => $html,
        channel => $params{channel},
        name    => $params{name},
        address => $self->request->address,
        time    => scalar localtime(time),
    });

    $self->write({ success => 1 });
}

1;
