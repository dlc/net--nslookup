#!/usr/bin/perl -w
# vim: set ft=perl:

use strict;
use vars qw(%hosts $host);

use Net::Nslookup;
use Test::More;

# Populate %hosts
unless (open HOSTS, "/etc/hosts") {
    plan skip_all => "Can't open /etc/hosts: $!";
}

while (<HOSTS>) {
    s/#.*//;
    next if /^\s*$/;

    my ($ip, @hosts) = split /\s+/;

    @hosts{@hosts} = ($ip) x @hosts;
}

close HOSTS;


plan tests => scalar keys %hosts;
for $host (keys %hosts) {
    my $addr = nslookup($host);
    ok($addr eq $hosts{$host}, "$host => $hosts{$host}");
}
