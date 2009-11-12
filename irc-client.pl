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

my $CONFIG = LoadFile($opts{c});

use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::HTTPClient;
use Tatsumaki::MessageQueue;
use Tatsumaki::Server;

use Social::Application;
use Social::IRCClient;
use Social::Helpers;

use Social::Controller::Welcome;
use Social::Controller::Irc;
use Social::Controller::IrcPoll;
use Social::Controller::IrcMultipartPoll;

use Plack::Middleware::AccessLog;

$Tatsumaki::MessageQueue::BacklogLength = $CONFIG->{MessageQueueBacklogLength} || 1000;

my $IRC_CLIENT;

use File::Basename;

my $chat_re = '[\w\.\-]+';

my $app = Social::Application->new([
    "/irc/mpoll" => "Social::Controller::IrcMultipartPoll",
    "/irc/poll"  => "Social::Controller::IrcPoll",
    "/irc"       => "Social::Controller::Irc",
    "/"          => "Social::Controller::Welcome"
]);

$app->config($CONFIG);

$app->template_path(dirname(__FILE__) . "/templates");

my %IRC_CLIENT = ();
while (my ($network, $config) = each %{$CONFIG->{networks}}) {
    my $x = Social::IRCClient->new;
    $x->heap->{config}  = $config;
    $x->heap->{network} = $network;

    $x->connect(
        $config->{host},
        $config->{port} || 6667,
        {
            nick     => $CONFIG->{nick},
            password => $config->{password}
        }
    );

    $IRC_CLIENT{$network} = $x;
    $IRC_CLIENT = $x;
}
$app->irc_clients(\%IRC_CLIENT);

$app = Plack::Middleware::AccessLog->wrap($app);

if ($0 eq __FILE__) {
    Tatsumaki::Server->new(
        port => $opts{p} || 9999,
        host => $opts{h},
    )->run($app);
}
else {
    return $app;
}
