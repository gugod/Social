package Social::RtorrentClient;
use Any::Moose;
use AnyEvent::Rtorrent;
use Social::Helpers;
has config => (
    is => "rw",
    isa => "HashRef"
);

has rtorrenty => (
    is => "rw",
    isa => "AnyEvent::Rtorrent",
    required => 1,
    lazy_build => 1
);

sub app {
    my ($class, @args) = @_;
    my $self = $class->new(@args);
    $self->rtorrenty->start;
    return $self;
}

sub _build_rtorrenty {
    my ($self) = @_;

    my $rtorrenty = AnyEvent::Rtorrent->new(url=>$self->config->{url});

    $rtorrenty->reg_cb(
        refresh_status => sub {
            my ($rtorrenty, $lists) = @_;
            for my $list (reverse @$lists) {
                Social::Helpers->mq_publish({
                    %$list,
                    type => "rtorrent_status",
                });
            }
        },
        rtorrent_remove_torrent => sub {
            my ($rtorrenty, $torrent_hash) = @_;
                Social::Helpers->mq_publish({
                    hash=>$torrent_hash,
                    type => "rtorrent_remove_torrent",
                });
        }
    );

    return $rtorrenty;


}

sub update_status {
    my ($self, @args) = @_;
    print Dumper(@args);
    $self->rtorrenty->rpc_command(@args);
}

1;
