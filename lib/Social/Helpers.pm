package Social::Helpers;
use common::sense;
use HTML::Entities;

use Sub::Exporter -setup => {
    exports => ['mq_publish', 'format_message'],
    groups => {
        default => ['mq_publish', 'format_message']
    }
};

sub mq_publish {
    my ($e) = @_;
    my $mq = Tatsumaki::MessageQueue->instance("social");
    $mq->publish({
        time => scalar localtime,
        %$e
    });
}

sub format_message {
    my($text) = @_;
    $text =~ s{ (https?://\S+) | ([&<>"']+) }
              { $1 ? do { my $url = HTML::Entities::encode($1); qq(<a target="_blank" href="$url">$url</a>) } :
                $2 ? HTML::Entities::encode($2) : '' }egx;
    $text;
}

1;
