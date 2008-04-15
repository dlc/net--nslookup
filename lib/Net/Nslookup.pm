package Net::Nslookup;

# -------------------------------------------------------------------
# $Id: Nslookup.pm,v 1.11 2008/04/15 15:20:54 dlc Exp $
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
use vars qw($VERSION $DEBUG $DEBUG_NET_DNS @EXPORT $TIMEOUT $MX_IS_NUMERIC $WIN32);
use base qw(Exporter);

$VERSION = 1.18;
@EXPORT  = qw(nslookup);
$DEBUG   = 0 unless defined $DEBUG;
$DEBUG_NET_DNS = 0 unless defined $DEBUG_NET_DNS;
$TIMEOUT = 15 unless defined $TIMEOUT;
$MX_IS_NUMERIC = 0 unless defined $MX_IS_NUMERIC;

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
    'ptr'   => \&_lookup_ptr,
	'txt'	=> \&_lookup_txt,
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
# Context!
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
    my ($term, $type, $server, @answers, $sub);

    # Some reasonable defaults.
    $term = lc ($options->{'term'} ||
                $options->{'host'} ||
                $options->{'domain'} || return);
    $type = lc ($options->{'type'} ||
                $options->{'qtype'} || "A");
    $server = $options->{'server'} || '';

    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $TIMEOUT unless $WIN32;
        $sub = $_lookups{$type};
        defined $sub ? @answers = $sub->($term, $server)
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
    my ($term, $server) = @_;

    debug("Performing 'A' lookup on `$term'");
    return qslookup($term);
}

sub _lookup_mx {
    my ($term, $server) = @_;
    my $res = ns($server);
    my (@mx, $rr, @answers);

    debug("Performing 'MX' lookup on `$term'");
    @mx = mx($res, $term);

    unless($MX_IS_NUMERIC) {
        for $rr (@mx) { push(@answers, $rr->exchange); }
        return @answers;
    }

    for $rr (@mx) {
        push @answers, nslookup(type => "A", host => $rr->exchange);
    }

    return @answers;
}

sub _lookup_ns {
    my ($term, $server) = @_;
    my $res = ns($server);
    my (@answers, $query, $rr);

    debug("Performing 'NS' lookup on `$term'");

    $query = $res->search($term, "NS") || return;
    for $rr ($query->answer) {
        push @answers, nslookup(type => "A", host => $rr->nsdname);
    }

    return @answers;
}

sub _lookup_ptr {
    my ($term, $server) = @_;
    my $res = ns($server);
    my (@answers, $query, $rr);

    debug("Performing 'PTR' lookup on `$term'");

    $query = $res->search($term, "PTR") || return;
    for $rr ($query->answer) {
        if ($rr->can('ptrdname')) {
            push @answers, $rr->ptrdname;
        }
    }

    return @answers;
}

sub _lookup_txt ($\@) {
    my ($term, $server) = @_;
    my $res = ns($server);
    my (@answers, $query, $rr);

    debug("Performing 'TXT' lookup on `$term'");

    $query = $res->search($term, "TXT") || return;
    for $rr ($query->answer) {
        push @answers, $rr->rdatastr();
    }

    return @answers;
}	

{
    my %res;
    sub ns {
        my $server = shift || "";

        unless (defined $res{$server}) {
            require Net::DNS;
            import Net::DNS;
            $res{$server} = Net::DNS::Resolver->new(debug => $DEBUG_NET_DNS);

            # $server might be empty
            if ($server) {
                if (ref($server) eq 'ARRAY') {
                    $res{$server}->nameservers(@$server);
                }
                else {
                    $res{$server}->nameservers($server);
                }
            }
        }

        return $res{$server};
    }

    sub dump_res {
        require Data::Dumper;
        return Data::Dumper::Dumper(\%res);
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

  my $name = nslookup(host => "206.33.105.41", type => "PTR");

C<nslookup> takes a hash of options, one of which should be I<term>,
and performs a DNS lookup on that term.  The type of lookup is
determined by the I<type> (or I<qtype>) argument.  If I<server> is
specified (it should be an IP address, or a reference to an array
of IP addresses), that server will be used for lookups.

If only a single argument is passed in, the type defaults to I<A>,
that is, a normal A record lookup.  This form is significantly faster
than using the full version, as it doesn't load Net::DNS for this.

If C<nslookup> is called in a list context, and there is more than one
address, an array is returned.  If C<nslookup> is called in a scalar
context, and there is more than one address, C<nslookup> returns the
first address.  If there is only one address returned (as is usually
the case), then, naturally, it will be the only one returned,
regardless of the calling context.

I<domain> and I<host> are synonyms for I<term>, and can be used to
make client code more readable.  For example, use I<domain> when
getting NS records, and use I<host> for A records; both do the same
thing.

I<server> should be a single IP address or a reference to an array
of IP addresses:

  my @a = nslookup(host => 'boston.com', server => '4.2.2.1');

  my @a = nslookup(host => 'boston.com', server => [ '4.2.2.1', '128.103.1.1' ])

By default, C<nslookup> returns addresses when looking up MX records;
however, the Unix tool C<nslookup> returns names.  Set
$Net::Nslookup::MX_IS_NUMERIC to a true value to have MX lookups
return numbers instead of names.  This is a change in behavior from
previous versions of C<Net::Nslookup>, and is more consistent with
other DNS tools.

=head1 TIMEOUTS

Lookups timeout after $Net::Nslookup::TIMEOUT seconds (default 15).
Set this to something more reasonable for your site or script.

=head1 DEBUGGING

Set $Net::Nslookup::DEBUG to a true value to get debugging messages
carped to STDERR.

Set $Net::Nslookup::DEBUG_NET_DNS to a true value to put L<Net::DNS>
into debug mode.

=head1 TODO

=over 4

=item *

Support for TXT and SOA records.

=back

=head1 AUTHOR

darren chamberlain <darren@cpan.org>

