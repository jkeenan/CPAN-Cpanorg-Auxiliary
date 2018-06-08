# t/002-fetch-perl-version-data.t
use 5.14.0;
use warnings;
use CPAN::Cpanorg::Auxiliary qw(fetch_perl_version_data);
use Carp;
use Cwd;
use File::Spec;
use File::Copy::Recursive::Reduced qw(dircopy);
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
    TODO: {
        local $TODO = 'Bizarre situation';
    ok(scalar @{$perl_versions},
        "fetch_perl_version_data() found non-zero number of stable releases");
    ok(scalar @{$perl_testing},
        "fetch_perl_version_data() found non-zero number of dev or RC releases");
    }

    chdir $cwd or croak "Unable to change back to $cwd";
}

{
    my $tdir = tempdir(CLEANUP => 1);
    my $datadir = File::Spec->catdir($tdir, 'data');
    my $mock_srcdir = File::Spec->catdir($tdir, qw( cpan CPAN src));
    my $jsonfile = 'perl_version_all.json';
    my $file_expected = File::Spec->catfile($datadir, $jsonfile);
    my @created = make_path($datadir, $mock_srcdir, { mode => 0711 });
    for my $d ($datadir, $mock_srcdir) {
        ok(-d $d, "Able to create $d for testing");
    }

    my $from_mockdir = File::Spec->catdir($cwd, 't', 'mockserver');
    @created = dircopy($from_mockdir, $tdir);
    ok(@created, "Copied directories and files for testing");
    my $sample_tarball = File::Spec->catfile($tdir,
        qw( cpan CPAN authors id S SH SHAY perl-5.26.2-RC1.tar.gz ));
    ok(-f $sample_tarball, "$sample_tarball copied into position for testing");

}


done_testing;
