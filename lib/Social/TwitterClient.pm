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
    lazy_build => 1
);

sub app {
    my ($class, @args) = @_;
    my $self = $class->new(@args);
    $self->twitty->start;
    $self->twitty->receive_statuses_friends;
    return $self;
}

sub _build_twitty {
    my ($self) = @_;

    my $twitty = AnyEvent::Twitter->new(
        username => $self->config->{username},
        password => $self->config->{password},
    );

    my $publish = sub {
        my ($twitty, @statuses) = @_;
        for (@statuses) {
            my ($pp_status, $raw_status) = @$_;
            Social::Helpers->mq_publish({
                type => "twitter",
                nick => $pp_status->{screen_name},
                text => $pp_status->{text},
            });
        }
    };

    $twitty->reg_cb(
        statuses_friends  => $publish,
        statuses_mentions => $publish,
    );

    $twitty->receive_statuses_friends;
    $twitty->receive_statuses_mentions;

    return $twitty;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
