use strict;
use vars qw(%PREREQ_PM %ABSTRACT %clean %macro);
use ExtUtils::MakeMaker;

%PREREQ_PM = map { ($_ => undef) } ('Net::DNS', 'Test::More');
%clean = ('FILES' => '$(DISTVNAME).tar$(SUFFIX) *.asc *.ppd distdir');
%macro = (
    'GPG'    => 'gpg',
    'AUTHOR' => 'darren@cpan.org',
    'SIGN'   => '--detach-sign --armor',
);
%ABSTRACT = ();
if ($] >= 5.00503) {
    %ABSTRACT = (
        'AUTHOR'        => 'darren chamberlain <darren@cpan.org>',
        'ABSTRACT_FROM' => 'lib/Net/Nslookup.pm',
    );
}

WriteMakefile(
    'NAME'          => 'Net::Nslookup',
    'VERSION_FROM'  => 'lib/Net/Nslookup.pm', # finds $VERSION
    'PREREQ_PM'     => \%PREREQ_PM,
    'clean'         => \%clean,
    'macro'         => \%macro,
    %ABSTRACT,
);

package MY;
sub dist_dir {
	my $self = shift;
	my $stuff = $self->SUPER::dist_dir(@_);

	return "$stuff\ttouch distdir\n\n";
}

sub postamble {
    return <<'P';
distsign :: $(DISTVNAME).tar$(SUFFIX)
	$(GPG) $(SIGN) -u $(AUTHOR) $(DISTVNAME).tar$(SUFFIX)
	@cat $(DISTVNAME).tar$(SUFFIX).asc
P
}
