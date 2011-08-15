#!/usr/bin/perl -w

# vim: set ft=perl:

use strict;
use Test::More tests => 9;
my ($res, @res);

use_ok("Net::Nslookup");

@res = nslookup(domain => "boston.com", type => "NS");
@res = sort @res;
is($res[0], "ns-a.pnap.net", "nslookup(domain => 'boston.com', type => NS) -> ns-a.pnap.net");
is($res[1], "ns-b.pnap.net", "nslookup(domain => 'boston.com', type => NS) -> ns-b.pnap.net");
is($res[2], "ns-c.pnap.net", "nslookup(domain => 'boston.com', type => NS) -> ns-c.pnap.net");
is($res[3], "ns-d.pnap.net", "nslookup(domain => 'boston.com', type => NS) -> ns-d.pnap.net");

@res = nslookup(domain => "boston.com", type => "NS", recurse => 1);
@res = sort @res;
is($res[0], "64.94.123.36", "nslookup(domain => 'boston.com', type => NS, recurse => 1) -> 64.94.123.36");
is($res[1], "64.94.123.4", "nslookup(domain => 'boston.com', type => NS, recurse => 1) -> 64.94.123.4");
is($res[2], "64.95.61.36", "nslookup(domain => 'boston.com', type => NS, recurse => 1) -> 64.95.61.36");
is($res[3], "64.95.61.4", "nslookup(domain => 'boston.com', type => NS, recurse => 1) -> 64.95.61.4");

