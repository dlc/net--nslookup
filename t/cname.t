#!/usr/bin/perl -w

# vim: set ft=perl:

use strict;
use Test::More tests => 3;
my ($res, @res);

use_ok("Net::Nslookup");

# Get CNAME record
$res = nslookup(host => "ctest.boston.com", type => "CNAME");
is($res, "www.boston.com", "nslookup(host => 'ctest.boston.com', type => CNAME) -> www.boston.com");

# Get A record for a CNAME (double lookup)
$res = nslookup(host => "ctest.boston.com", type => "CNAME", recurse => 1);
is($res, "66.151.183.41", "nslookup(host => 'ctest.boston.com', type => CNAME, recurse => 1) -> 66.151.183.41");
