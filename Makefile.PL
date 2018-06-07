

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'CPAN::Cpanorg::Auxiliary',
    VERSION_FROM => 'lib/CPAN/Cpanorg/Auxiliary.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Functions used in cpan.org infrastructure',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
