#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use YAML qw(LoadFile);
use Getopt::Std;

my %opts;
getopt('c:', \%opts);
die "Usage: $0 -c /path/to/config.yml\n" unless $opts{c};

my $CONFIG = LoadFile($opts{c});

sub CONFIG { $CONFIG }

use AnyEvent;
use AnyEvent::IRC::Util qw(prefix_nick);
use AnyEvent::IRC::Client;
use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;
use Tatsumaki::MessageQueue;
use Plack::Middleware::Static;
use Tatsumaki::Middleware::BlockingFallback;
use Encode;

my $IRC_CLIENT;

package ChatMultipartPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my($self, $channel) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->poll($session, sub {
        my @events = @_;
        for my $event (@events) {
            $self->stream_write($event);
        }
    });
}

package ChatPostHandler;
use base qw(Tatsumaki::Handler);
use HTML::Entities;

sub post {
    my($self, $channel) = @_;
    my $v = $self->request->params;
    my $text = Encode::decode_utf8($v->{text});

    print "Post to $channel\n";
    $IRC_CLIENT->send_srv('PRIVMSG', "#" . $channel, $v->{text});

    my $html = $self->format_message($text);
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->publish({
        type => "message", html => $html, ident => $v->{ident},
        avatar => $v->{avatar}, name => $v->{name},
        address => $self->request->address, time => scalar localtime(time),
    });

    $self->write({ success => 1 });
}

sub format_message {
    my($self, $text) = @_;
    $text =~ s{ (https?://\S+) | ([&<>"']+) }
              { $1 ? do { my $url = HTML::Entities::encode($1); qq(<a target="_blank" href="$url">$url</a>) } :
                $2 ? HTML::Entities::encode($2) : '' }egx;
    $text;
}

package ChatRoomHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my($self, $channel) = @_;

    $IRC_CLIENT->send_srv(JOIN => "#" . $channel);

    $self->render('chat.html');
}

package main;

use File::Basename;

my $chat_re = '[\w\.\-]+';

my $app = Tatsumaki::Application->new([
    "/chat/($chat_re)/mxhrpoll" => 'ChatMultipartPollHandler',
    "/chat/($chat_re)/post" => 'ChatPostHandler',
    "/chat/($chat_re)" => 'ChatRoomHandler'
]);

$app->template_path(dirname(__FILE__) . "/templates");

$app = Plack::Middleware::Static->wrap($app, path => qr/^\/static/, root => dirname(__FILE__));

$app = Tatsumaki::Middleware::BlockingFallback->wrap($app);

$IRC_CLIENT = AnyEvent::IRC::Client->new;
$IRC_CLIENT->reg_cb(
    disconnect => sub { warn @_; undef $IRC_CLIENT },
    publicmsg  => sub {
        my($con, $channel, $packet) = @_;
        $channel =~ s/\@.*$//;
        $channel =~ s/^#//;
        if ($packet->{command} eq 'NOTICE' || $packet->{command} eq 'PRIVMSG') { # NOTICE for bouncer backlog
            my $msg = $packet->{params}[1];
            (my $who = $packet->{prefix}) =~ s/\!.*//;
            my $mq = Tatsumaki::MessageQueue->instance($channel);
            $mq->publish({
                type => "message",
                address => "chat.freenode.net",
                time => scalar localtime,
                name => $who,
                ident => "$who\@gmail.com", # let's just assume everyone's gmail :)
                text => Encode::decode_utf8($msg),
            });
        }
    },
    registered => sub {
        my ($con) = @_;
        my $channels = CONFIG->{channels};
        for my $x (@$channels) {
            my (undef, $channel, $password) = @$x;
            $con->send_srv('JOIN', '#'.$channel, $password);
        }
    },
    join => sub {
        my ($con, $nick, $channel) = @_;
        say "joined $channel";
    }
);

$IRC_CLIENT->connect("chat.freenode.net", 6667, { nick => CONFIG->{nick} });

require Tatsumaki::Server;
Tatsumaki::Server->new(port => 9999)->run($app);
