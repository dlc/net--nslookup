#!/usr/bin/perl -w
# vim: set ft=perl:

use strict;
my ($ntests, $hostfile, %hosts, $host);
my @windows_hosts_file_locations = qw(
    c:/windows/hosts
    c:/winnt/system32/hosts
);

use Net::Nslookup;
use Test::More;

if ($^O =~ /win/i) {
    for my $wf (@windows_hosts_file_locations) {
        if (-e $wf) {
            $hostfile = $wf;
            last;
        }
    }
}

$hostfile ||= "/etc/hosts";

# Populate %hosts
unless (open HOSTS, $hostfile) {
    plan skip_all => "Can't open /etc/hosts: $!";
}

while (<HOSTS>) {
    s/#.*//;
    next if /^\s*$/;

    my ($ip, @hosts) = split /\s+/;

    # Cribbed from Regexp::Common::net
    next unless $ip =~ /^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.
                         (25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.
                         (25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.
                         (25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})$/x;

    @hosts{@hosts} = ($ip) x @hosts;
}

close HOSTS;

$ntests = scalar keys %hosts;
plan tests => $ntests;
SKIP: {
    skip "No network" => $ntests
        if $ENV{'NO_NET'};

    for $host (keys %hosts) {
        my $addr = nslookup($host);
        ok($addr eq $hosts{$host}, "$host => $hosts{$host}");
    }
}
