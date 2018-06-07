# t/002-fetch-perl-version-data.t
use strict;
use warnings;
use CPAN::Cpanorg::Auxiliary qw(fetch_perl_version_data);
use Carp;
use Cwd;
use File::Spec;
use File::Path 2.15 qw(make_path);
use File::Temp qw(tempdir);
use LWP::Simple qw(get);
use Test::More;

my $cwd = cwd();

{
    my $tdir = tempdir(CLEANUP => 1);
    my $datadir = File::Spec->catdir($tdir, 'data');
    my $jsonfile = 'perl_version_all.json';
    my $file_expected = File::Spec->catfile($datadir, $jsonfile);
    my @created = make_path($datadir, { mode => 0711 });
    ok(@created, "Able to create $datadir for testing");

    chdir $tdir or croak "Unable to change to $tdir for testing";

    my ( $perl_versions, $perl_testing ) = fetch_perl_version_data();
    for ( $perl_versions, $perl_testing ) {
        ok(defined $_, "fetch_perl_version_data() returned defined value");
        ok(ref($_) eq 'ARRAY', "fetch_perl_version_data() returned arrayref");
    }
    ok(-f $file_expected, "$file_expected was created");
    ok(scalar @{$perl_versions},
        "fetch_perl_version_data() found non-zero number of stable releases");
    ok(scalar @{$perl_testing},
        "fetch_perl_version_data() found non-zero number of dev or RC releases");

    chdir $cwd or croak "Unable to change back to $cwd";
}

done_testing;
