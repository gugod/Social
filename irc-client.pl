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

use Social::IRCClient;
use Social::Helpers;

use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;
use Tatsumaki::MessageQueue;
use Tatsumaki::Server;
use Tatsumaki::Middleware::BlockingFallback;
use Plack::Middleware::Static;
use Encode;
use HTML::Entities;

my $IRC_CLIENT;

package IrcHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my ($self) = @_;

    $self->render('irc.html', {
        channels => [sort keys %{ $IRC_CLIENT->channel_list} ],
        nick => $IRC_CLIENT->nick,
    });
}

sub post {
    my ($self) = @_;

    my $v = $self->request->params;

    my $channel = $v->{channel};
    my $text = Encode::decode_utf8($v->{text});

    $IRC_CLIENT->send_srv('PRIVMSG', $channel, $v->{text});

    my $html = Social::Helpers->format_message($text);
    my $mq = Tatsumaki::MessageQueue->instance("irc");
    $mq->publish({
        type => "message",
        html => $html,
        ident => $v->{ident},
        channel => $channel,
        avatar => $v->{avatar},
        name => $v->{name},
        address => $self->request->address,
        time => scalar localtime(time),
    });

    $self->write({ success => 1 });
}

package IrcMultipartPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my($self) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance("irc");
    $mq->poll($session, sub {
        my @events = @_;
        for my $event (@events) {
            $self->stream_write($event);
        }
    });
}

package IrcPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

use Tatsumaki::MessageQueue;

sub get {
    my ($self) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");
    $session = rand(1) if $session eq 'dummy'; # for benchmarking stuff

    my $mq = Tatsumaki::MessageQueue->instance("irc");
    $mq->poll_once($session, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my($self, @events) = @_;
    $self->write(\@events);
    $self->finish;
}

package main;

use File::Basename;

my $chat_re = '[\w\.\-]+';

my $app = Tatsumaki::Application->new([
    "/irc/mpoll" => "IrcMultipartPollHandler",
    "/irc/poll" => "IrcPollHandler",
    "/irc" => "IrcHandler",
]);

$app->template_path(dirname(__FILE__) . "/templates");
$app->template->{tag_start}  = "<%";
$app->template->{tag_end}    = "%>";
$app->template->{line_start} = "%";

$app = Plack::Middleware::Static->wrap($app, path => qr/^\/static/, root => dirname(__FILE__));

$app = Tatsumaki::Middleware::BlockingFallback->wrap($app);

my %IRC_CLIENT = ();
while (my ($network, $config) = each %{$CONFIG->{networks}}) {
    my $x = Social::IRCClient->new;
    $x->heap->{config} = $config;

    require YAML;
    print YAML::Dump({ heap => $x->heap });

    $x->connect( $config->{host}, $config->{port} || 6667, { nick => $CONFIG->{nick} });

    $IRC_CLIENT{$network} = $x;
    $IRC_CLIENT = $x;
}

if ($0 eq __FILE__) {
    Tatsumaki::Server->new(
        port => $opts{p} || 9999,
        host => $opts{h},
    )->run($app);
}
else {
    return $app;
}
