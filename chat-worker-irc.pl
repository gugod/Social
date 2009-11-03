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

use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;
use Tatsumaki::MessageQueue;
use Tatsumaki::Server;
use Tatsumaki::Middleware::BlockingFallback;
use Plack::Middleware::Static;
use Encode;
use AnyEvent;
use AnyEvent::IRC::Util qw(prefix_nick);
use AnyEvent::IRC::Client;

my $IRC_CLIENT;
{
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
                my $mq = Tatsumaki::MessageQueue->instance("irc");
                $mq->publish({
                    type => "message",
                    address => "chat.freenode.net",
                    time => scalar localtime,
                    channel => $channel,
                    name => $who,
                    ident => "$who\@gmail.com", # let's just assume everyone's gmail :)
                    html => IrcPostHandler->format_message( Encode::decode_utf8($msg) )
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
            say "Joined $channel";
        }
    );
    $IRC_CLIENT->connect("chat.freenode.net", 6667, { nick => CONFIG->{nick} });

    sub IRC_CLIENT { $IRC_CLIENT }
}

package IrcHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my ($self) = @_;

    $self->render('irc.html', {
        channels => [map { s/^#//; $_ } keys %{ $IRC_CLIENT->channel_list} ],
        nick => $IRC_CLIENT->nick,
    });
}

package IrcMultipartPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my($self) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");

    my $channel = $self->request->param('channel')
        or Tatsumaki::Error::HTTP->throw(500, "'channel' needed");

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance($channel);
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
    my($self) = @_;

    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");
    $session = rand(1) if $session eq 'dummy'; # for benchmarking stuff

    my $channel = $self->request->param("channel")
        or Tatsumaki::Error::HTTP->throw(500, "'channel' needed");

    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->poll_once($session, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my($self, @events) = @_;
    $self->write(\@events);
    $self->finish;
}

package IrcPostHandler;
use base qw(Tatsumaki::Handler);

sub post {
    my($self) = @_;
    my $v = $self->request->params;

    my $channel = $v->{channel};
    my $text = Encode::decode_utf8($v->{text});

    $IRC_CLIENT->send_srv('PRIVMSG', "#" . $channel, $v->{text});

    my $html = $self->format_message($text);
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->publish({
        type => "message", html => $html, ident => $v->{ident},
        channel => $channel,
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

package main;

use File::Basename;

my $chat_re = '[\w\.\-]+';

my $app = Tatsumaki::Application->new([
    "/irc" => "IrcHandler",
    "/irc/poll" => "IrcPollHandler",
    "/irc/mpoll" => "IrcMultipartPollHandler",
    "/irc/post" => "IrcPostHandler",
]);

$app->template_path(dirname(__FILE__) . "/templates");

$app = Plack::Middleware::Static->wrap($app, path => qr/^\/static/, root => dirname(__FILE__));

$app = Tatsumaki::Middleware::BlockingFallback->wrap($app);

Tatsumaki::Server->new(port => 9999)->run($app);
