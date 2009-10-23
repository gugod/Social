#!/usr/bin/env perl
use strict;
use warnings;

use CGI;
use LWP::UserAgent;

my $q = CGI->new;

my $ua = LWP::UserAgent->new;
$ua->post(
    "http://localhost:11236/say", {
        text    => $q->param("text"),
        channel => $q->param("channel")
    });

print "Content-Type: text/plain\n\nSAY OK\n";
