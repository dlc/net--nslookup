package Net::Nslookup;

# -------------------------------------------------------------------
# $Id: Nslookup.pm,v 1.2 2003/03/14 21:41:32 dlc Exp $
# -------------------------------------------------------------------
#  Net::Nslookup - Provide nslookup(1)-like capabilities
#  Copyright (C) 2002 darren chamberlain <darren@cpan.org>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; version 2.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#  02111-1307  USA
# -------------------------------------------------------------------

use strict;
use vars qw($VERSION $DEBUG @EXPORT $TIMEOUT $WIN32);
use base qw(Exporter);

$VERSION = 1.12;
@EXPORT  = qw(nslookup);
$DEBUG   = 0 unless defined $DEBUG;
$TIMEOUT = 15 unless defined $TIMEOUT;

# Win32 doesn't implement alarm; what about MacOS?
# Added check based on bug report from Roland Bauer 
# (not RT'ed)
$WIN32   = $^O =~ /win/i; 

use Carp;
use Exporter;
use Socket qw/ inet_ntoa inet_aton /;

my %_lookups = (
    'a'     => \&_lookup_a,
    'cname' => \&_lookup_a,
    'mx'    => \&_lookup_mx,
    'ns'    => \&_lookup_ns,
);

# ----------------------------------------------------------------------
# qslookup($term)
#
# "quick" nslookup, doesn't require Net::DNS.
#
# ----------------------------------------------------------------------
# Bugs:
#
#   * RT#1947 (Scott Schnieder)
#       The qslookup subroutine fails if no records for the domain
#       exist, because inet_ntoa freaks out about inet_aton not
#       returning anything.
# ----------------------------------------------------------------------
sub qslookup($) {
    my $a = inet_aton $_[0];
    return $a ? inet_ntoa $a : '';
}

# ----------------------------------------------------------------------
# nslookup(%args)
#
# Does the actual lookup, deferring to helper functions as necessary.
# ----------------------------------------------------------------------
sub nslookup {
    my $options = isa($_[0], 'HASH') ? shift : @_ % 2 ? { 'host', @_ } : { @_ };
    my ($term, $type, @answers, $sub);

    # Some reasonable defaults.
    $term = lc ($options->{'term'} ||
                $options->{'host'} ||
                $options->{'domain'} || return);
    $type = lc ($options->{'type'} ||
                $options->{'qtype'} || "A");

    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $TIMEOUT unless $WIN32;
        $sub = $_lookups{$type};
        defined $sub ? @answers = $sub->($term)
                     : die "Invalid type '$type'";
        alarm 0 unless $WIN32;
    };

    if ($@) {
        die "Bad things happened: $@"
            unless $@ eq "alarm\n";
        carp qq{Timeout: nslookup("type" => "$type", "host" => "$term")};
    }

    return $answers[0] if (@answers == 1);
    return (wantarray) ? @answers : $answers[0];
}

sub _lookup_a {
    my $term = shift;
    my (@terms, $query);

    debug("Performing 'A' lookup on `$term'");
    return qslookup($term);
}

sub _lookup_mx {
    my $term = shift;
    my $res = ns();
    my (@mx, $rr, @answers);

    debug("Performing 'MX' lookup on `$term'");
    @mx = mx($res, $term);
    for $rr (@mx) {
        push @answers, nslookup(type => "A", host => $rr->exchange);
    }

    return @answers;
}

sub _lookup_ns {
    my $term = shift;
    my $res = ns();
    my (@answers, $query, $rr);

    debug("Performing 'NS' lookup on `$term'");

    $query = $res->search($term, "NS") || return;
    for $rr ($query->answer) {
        push @answers, nslookup(type => "A", host => $rr->nsdname);
    }

    return @answers;
}

{
    my $res;
    sub ns {
        unless (defined $res) {
            require Net::DNS;
            import Net::DNS;
            $res = Net::DNS::Resolver->new;
        }

        return $res;
    }
}

sub isa { &UNIVERSAL::isa }

sub debug { carp @_ if ($DEBUG) }

1;
__END__

=head1 NAME

Net::Nslookup - Provide nslookup(1)-like capabilities

=head1 SYNOPSIS

  use Net::Nslookup;
  my @addrs = nslookup $host;

  my @mx = nslookup(qtype => "MX", domain => "perl.org");

=head1 DESCRIPTION

Net::Nslookup provides the capabilities of the standard UNIX command
line tool nslookup(1). Net::DNS is a wonderful and full featured module,
but quite often, all you need is `nslookup $host`.  This module
provides that functionality.

Net::Nslookup exports a single function, called C<nslookup>.
C<nslookup> can be used to retrieve A, PTR, CNAME, MX, and NS records.

  my $a  = nslookup(host => "use.perl.org", type => "A");

  my @mx = nslookup(domain => "perl.org", type => "MX");

  my @ns = nslookup(domain => "perl.org", type => "NS");

B<nslookup> takes a hash of options, one of which should be I<term>,
and performs a DNS lookup on that term.  The type of lookup is
determined by the I<type> (or I<qtype>) argument.

If only a single argument is passed in, the type defaults to I<A>,
that is, a normal A record lookup.  This form is significantly faster
than using the full version, as it doesn't load Net::DNS for this.

If B<nslookup> is called in a list context, and there is more than one
address, an array is returned.  If B<nslookup> is called in a scalar
context, and there is more than one address, B<nslookup> returns the
first address.  If there is only one address returned (as is usually
the case), then, naturally, it will be the only one returned,
regardless of the calling context.

I<domain> and I<host> are synonyms for I<term>, and can be used to
make client code more readable.  For example, use I<domain> when
getting NS records, and use I<host> for A records; both do the same
thing.

=head1 TIMEOUTS

Lookups timeout after $Net::Nslookup::TIMEOUT seconds (default 15).
Set this to something more reasonable for your site or script.

=head1 DEBUGGING

Set $Net::Nslookup::DEBUG to a true value to get debugging messages
carped to STDERR.

=head1 TODO

=over 4

=item *

Support for TXT and SOA records.

=back

=head1 AUTHOR

darren chamberlain <darren@cpan.org>

