package Social::PlurkClient;
use Moose;
use AnyEvent::Plurk 0.01;
use Social::Helpers;

has config => (
    is => "rw",
    isa => "HashRef",
    required => 1
);

has plurky => (
    is => "rw",
    isa => "AnyEvent::Plurk",
    required => 1,
    lazy_build => 1
);

sub app {
    my ($class, @args) = @_;
    my $self = $class->new(@args);
    $self->plurky->start;
    return $self;
}

sub _build_plurky {
    my ($self) = @_;

    my $p = AnyEvent::Plurk->new(
        username => $self->config->{username},
        password => $self->config->{password},
    );

    $p->reg_cb(
        latest_owner_plurks => sub {
            my ($p, $plurks) = @_;
            my $meta = $p->{_plurk}->meta;
            for my $pu (@$plurks) {
                my $user = $meta->{friends}{$pu->{owner_id}} || $meta->{fans}{$pu->{owner_id}};

                Social::Helpers->mq_publish({
                    %$pu,
                    type => "plurk",
                    html => Social::Helpers->format_message($pu->{content_raw}),
                    user => $user
                });
            }
        }
    );

    return $p;
}

1;
