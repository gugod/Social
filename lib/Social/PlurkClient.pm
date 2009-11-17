package Social::PlurkClient;
use Any::Moose;
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
        unread_plurks => sub {
            my ($p, $plurks) = @_;

            for my $pu (reverse @$plurks) {
                Social::Helpers->mq_publish({
                    %$pu,
                    type => "plurk",
                    html => Social::Helpers->format_message($pu->{content_raw})
                });
            }
        }
    );
    return $p;
}

sub add_plurk {
    my $self = shift;
    my $content = shift;
    $self->plurky->add_plurk($content);
}


1;
