package Social::TwitterClient;
use Moose;
use AnyEvent::Twitter;
use Social::Helpers;
has config => (
    is => "rw",
    isa => "HashRef"
);

has twitty => (
    is => "rw",
    isa => "AnyEvent::Twitter",
    required => 1,
    lazy_build => 1
);

sub app {
    my ($class, @args) = @_;
    my $self = $class->new(@args);
    $self->twitty->start;
    return $self;
}

sub _build_twitty {
    my ($self) = @_;

    my $twitty = AnyEvent::Twitter->new(
        username => $self->config->{username},
        password => $self->config->{password},
    );

    my $build_publisher = sub {
        my $type = shift;
        return sub {
            my ($twitty, @statuses) = @_;
            for (reverse @statuses) {
                my (undef, $status) = @$_;
                $status->{type} = $type;
                $status->{html} = format_message($status->{text});
                mq_publish($status);
            }
        }
    };

    $twitty->reg_cb(
        statuses_friends  => $build_publisher->("twitter_statuses_friends"),
        statuses_mentions => $build_publisher->("twitter_statuses_mentions"),
    );

    $twitty->receive_statuses_mentions;
    $twitty->receive_statuses_friends;
    return $twitty;
}

sub update_status {
    my ($self, $status) = @_;
    $self->twitty->update_status($status, sub {});
}

1;
