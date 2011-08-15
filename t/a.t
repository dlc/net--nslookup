#!/usr/bin/perl -w

# vim: set ft=perl:

use strict;
use Test::More tests => 3;
my ($res, @res);

use_ok("Net::Nslookup");

# Get A record
$res = nslookup(host => "www.boston.com", type => "A");
is($res, "66.151.183.41", "nslookup(host => www.boston.com, type => A) -> 66.151.183.41");

# Get A record (shortcut usage)
$res = nslookup("www.boston.com");
is($res, "66.151.183.41", "nslookup(www.boston.com) -> 66.151.183.41");
