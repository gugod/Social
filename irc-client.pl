#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use FindBin;
use lib "$FindBin::Bin/lib";

use YAML qw(LoadFile);
use Getopt::Std;

my %opts;
getopt('cph', \%opts);
die "Usage: $0 -c /path/to/config.yml\n" unless $opts{c};

use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::HTTPClient;
use Tatsumaki::MessageQueue;
use Tatsumaki::Server;
use Social::Application;

my $CONFIG = LoadFile($opts{c});

$Tatsumaki::MessageQueue::BacklogLength = $CONFIG->{MessageQueueBacklogLength} || 1000;

my $app = Social::Application->new(config => $CONFIG);

if ($0 eq __FILE__) {
    Tatsumaki::Server->new(
        port => $opts{p} || 9999,
        host => $opts{h},
    )->run($app);
}
else {
    return $app;
}
