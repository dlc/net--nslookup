package Net::Nslookup;

# -------------------------------------------------------------------
#  Net::Nslookup - Provide nslookup(1)-like capabilities
#  Copyright (C) 2002-2011 darren chamberlain <darren@cpan.org>
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

$VERSION    = "2.00";
@EXPORT     = qw(nslookup);
$DEBUG      = 0 unless defined $DEBUG;
$TIMEOUT    = 15 unless defined $TIMEOUT;
$WIN32      = $^O =~ /win32/i; 

use Exporter;

my %_methods = qw(
    A       address
    CNAME   cname
    MX      exchange
    NS      nsdname
    PTR     ptrdname
    TXT     rdatadir
    SOA     dummy
);

# ----------------------------------------------------------------------
# nslookup(%args)
#
# Does the actual lookup, deferring to helper functions as necessary.
# ----------------------------------------------------------------------
sub nslookup {
    my $options = isa($_[0], 'HASH') ? shift : @_ % 2 ? { 'host', @_ } : { @_ };
    my ($term, $type, @answers);

    # Some reasonable defaults.
    $term = lc ($options->{'term'} ||
                $options->{'host'} ||
                $options->{'domain'} || return);
    $type = uc ($options->{'type'} ||
                $options->{'qtype'} || "A");
    $options->{'server'} ||= '';
    $options->{'recurse'} ||= 0;

    $options->{'debug'} = $DEBUG 
        unless defined $options->{'debug'};

    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $TIMEOUT unless $WIN32;

        my $meth = $_methods{ $type } || die "Unknown type '$type'";
        my $res = ns($options->{'server'});

        if ($options->{'debug'}) {
            warn "Performing `$type' lookup on `$term'\n";
        }

        if (my $q = $res->search($term, $type)) {
            if ('SOA' eq $type) {
                my $a = ($q->answer)[0];
                @answers = (join " ", map { $a->$_ }
                    qw(mname rname serial refresh retry expire minimum));
            }
            else {
                @answers = map { $_->$meth() } grep { $_->type eq $type } $q->answer;
            }

            # If recurse option is set, for NS, MX, and CNAME requests,
            # do an A lookup on the result.  False by default.
            if ($options->{'recurse'}   &&
                (('NS' eq $type)        ||
                 ('MX' eq $type)        ||
                 ('CNAME' eq $type)
                )) {

                @answers = map {
                    nslookup(
                        host    => $_,
                        type    => "A",
                        server  => $options->{'server'},
                        debug   => $options->{'debug'}
                    );
                } @answers;
            }
        }

        alarm 0 unless $WIN32;
    };

    if ($@) {
        die "nslookup error: $@"
            unless $@ eq "alarm\n";
        warn qq{Timeout: nslookup("type" => "$type", "host" => "$term")};
    }

    return $answers[0] if (@answers == 1);
    return (wantarray) ? @answers : $answers[0];
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
}

sub isa { &UNIVERSAL::isa }

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

