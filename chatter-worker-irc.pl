#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use YAML::XS;

use LWP::UserAgent;

use AnyEvent;
use AnyEvent::IRC::Util qw(prefix_nick);
use AnyEvent::IRC::Client;
use JSON qw(to_json);

sub stardust_send {
    my ($channel, $nick, $text) = @_;

    $channel =~ s/\W//g;

    my $ua = LWP::UserAgent->new;
    $ua->post(
        "http://localhost:5555/comet/channel/$channel",
        Content => "m=". to_json({
            type => "irc",
            data => [
                $nick, $text
            ]
        })
    );
}

my $c = AnyEvent->condvar;
my $timer;
my $con = AnyEvent::IRC::Client->new;
$con->reg_cb(
    connect => sub {
        my ($con, $err) = @_;
        if (defined $err) {
            warn "connect error: $err\n";
            return;
        }
    },

    join => sub {
        my ($con, $nick, $channel, $is_myself) = @_;
        if ($is_myself) {
            print "I just joined $channel\n";
            return;
        }
    },

    registered => sub {
        print "I'm in!\n";
        $con->send_srv (JOIN => '#jabbot');
    },

    disconnect => sub { print "I'm out!\n"; $c->broadcast },

    publicmsg => sub {
        my ($con, $channel, $ircmsg) = @_;

        my $nick = prefix_nick( $ircmsg->{prefix} );

        my (undef, $text) = @{$ircmsg->{params}};

        stardust_send($channel, $nick, $text);
    }
);

$con->connect ("chat.freenode.net", 6667, { nick => 'jabbot2' });
$c->wait;
$con->disconnect;
