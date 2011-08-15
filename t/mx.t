#!/usr/bin/perl -w

# vim: set ft=perl:

use strict;
use Test::More tests => 6;
my ($res, @res);

use_ok("Net::Nslookup");

# Get MX records
$res = nslookup(domain => "boston.com", type => "MX");
is($res, "mail3.boston.com", "nslookup(domain => 'boston.com', type => MX) -> mail3.boston.com");

@res = nslookup(domain => "boston.com", type => "MX");
is($res[0], "mail3.boston.com", "nslookup(domain => 'boston.com', type => MX) -> mail3.boston.com");
is($res[1], "mail.boston.com", "nslookup(domain => 'boston.com', type => MX) -> mail.boston.com");

@res = nslookup(domain => "boston.com", type => "MX", recurse => 1);
is($res[0], "66.151.183.192", "nslookup(domain => 'boston.com', type => MX, recurse => 1) -> 66.151.183.192");
is($res[1], "206.33.105.249", "nslookup(domain => 'boston.com', type => MX, recurse => 1) -> 206.33.105.249");
