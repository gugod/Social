package Social::Helpers;
use strict;
use HTML::Entities;
sub mq_publish {
    my ($self, $e) = @_;
    my $mq = Tatsumaki::MessageQueue->instance("social");
    $mq->publish({
        time => scalar localtime,
        %$e
    });
}

sub format_message {
    my($self, $text) = @_;
    $text =~ s{ (https?://\S+) | ([&<>"']+) }
              { $1 ? do { my $url = HTML::Entities::encode($1); qq(<a target="_blank" href="$url">$url</a>) } :
                $2 ? HTML::Entities::encode($2) : '' }egx;
    $text;
}

1;
