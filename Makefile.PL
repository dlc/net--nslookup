use strict;
use ExtUtils::MakeMaker;

my %PREREQ_PM = (
    'Net::DNS'   => 0.00,
    'Test::More' => 0.45,
);

my %clean = (
    'FILES' => '$(DISTVNAME).tar$(SUFFIX) *.ppd'
);

my %ABSTRACT = ();
if ($] >= 5.00503) {
    %ABSTRACT = (
        'AUTHOR'        => 'darren chamberlain <darren@cpan.org>',
        'ABSTRACT_FROM' => 'lib/Net/Nslookup.pm',
    );
}

WriteMakefile(
    'NAME'      => 'Net::Nslookup',
    'VERSION'   => "1.13",
    'PREREQ_PM' => \%PREREQ_PM,
    'clean'     => \%clean,
    %ABSTRACT,
);
