#!/usr/bin/perl -w

# vim: set ft=perl:

use strict;
use Test::More tests => 5;
my ($res, @res);

use_ok("Net::Nslookup");

@res = nslookup(domain => "boston.com", type => "MX");
@res = sort @res;
is($res[0], "mail.boston.com", "nslookup(domain => 'boston.com', type => MX) -> mail.boston.com");
is($res[1], "mail3.boston.com", "nslookup(domain => 'boston.com', type => MX) -> mail3.boston.com");

@res = nslookup(domain => "boston.com", type => "MX", recurse => 1);
@res = sort @res;
is($res[0], "206.33.105.249", "nslookup(domain => 'boston.com', type => MX, recurse => 1) -> 206.33.105.249");
is($res[1], "66.151.183.192", "nslookup(domain => 'boston.com', type => MX, recurse => 1) -> 66.151.183.192");
