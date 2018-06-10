# t/002-fetch-perl-version-data.t
use 5.14.0;
use warnings;
#use CPAN::Cpanorg::Auxiliary qw(
#    fetch_perl_version_data
#    add_release_metadata
#    write_security_files_and_symlinks
#);
use CPAN::Cpanorg::Auxiliary;
use Carp;
use Cwd;
use File::Copy;
use File::Copy::Recursive::Reduced qw(dircopy);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;
use Data::Dump qw(dd pp);
#use File::Path 2.15 qw(make_path);
#use File::Slurp 9999.19;
#use JSON qw(decode_json);
#use LWP::Simple qw(get);

my $cwd = cwd();

{
    my $tdir = tempdir(CLEANUP => 1);
    my $from_mockdir = File::Spec->catdir($cwd, 't', 'mockserver');
    my @created = dircopy($from_mockdir, $tdir);
    ok(@created, "Copied directories and files for testing");
    my $mockdata_from = File::Spec->catfile($cwd, 't', 'mock.perl_version_all.json');
    my $mockdata_to   = File::Spec->catfile($tdir, 'data', 'perl_version_all.json');
    copy $mockdata_from => $mockdata_to
        or croak "Unable to copy $mockdata_from for testing";

    my %dirs_required = (
        CPANdir     => [ $tdir, qw| CPAN | ],
        srcdir      => [ $tdir, qw| CPAN src | ],
        fivedir     => [ $tdir, qw| CPAN src 5.0 | ],
        authorsdir  => [ $tdir, qw| CPAN authors | ],
        iddir       => [ $tdir, qw| CPAN authors id | ],
        contentdir  => [ $tdir, qw| content | ],
        datadir     => [ $tdir, qw| data | ],
    );
    for my $el (keys %dirs_required) {
        my $dir = File::Spec->catdir(@{$dirs_required{$el}});
        ok(-d $dir, "Created directory '$dir' for testing");
    }

    my $self = CPAN::Cpanorg::Auxiliary->new({ path => $tdir });
    ok(defined $self, "new: returned defined value");
    isa_ok($self, 'CPAN::Cpanorg::Auxiliary');
dd($self);

    ok(-f $self->{path_versions_json},
        "$self->{path_versions_json} located for testing.");

    my $mock_api_results = $self->{path_versions_json};
    no warnings 'redefine';
    *CPAN::Cpanorg::Auxiliary::make_api_call = sub {
        my $self = shift;
        my $json_text;
        open my $IN, '<', $mock_api_results
            or croak "Unable to open $mock_api_results for reading";
        $json_text = <$IN>;
        while (<$IN>) {
            chomp;
            $json_text .= $_;
        }
        close $IN
            or croak "Unable to close $mock_api_results after reading";
        return $json_text;
    };
    use warnings;

    chdir $tdir or croak "Unable to change to $tdir for testing";

    my ( $perl_versions, $perl_testing ) = $self->fetch_perl_version_data;
    pass($0);
}

done_testing;


__END__
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
    my $mock_srcdir = File::Spec->catdir($tdir, qw( CPAN src));
    my $jsonfile = 'perl_version_all.json';
    my $file_expected = File::Spec->catfile($datadir, $jsonfile);
    my @created = make_path($datadir, $mock_srcdir, { mode => 0711 });
    for my $d ($datadir, $mock_srcdir) {
        ok(-d $d, "Able to create $d for testing");
    }

    my $from_mockdir = File::Spec->catdir($cwd, 't', 'mockserver');
    @created = dircopy($from_mockdir, $tdir);
    ok(@created, "Copied directories and files for testing");
    my $CPANdir = File::Spec->catdir($tdir, qw( CPAN ));
    ok(-d $CPANdir, "Located directory '$CPANdir'");
    my $sample_tarball = File::Spec->catfile($tdir,
        qw( CPAN authors id S SH SHAY perl-5.26.2-RC1.tar.gz ));
    ok(-f $sample_tarball, "$sample_tarball copied into position for testing");
    my $sample_checksums = File::Spec->catfile($tdir,
        qw( CPAN authors id S SH SHAY CHECKSUMS ));
    ok(-f $sample_checksums, "$sample_checksums copied into position for testing");

    my $mock_api_results = File::Spec->catfile($cwd, 't', 'mock.perl_version_all.json');
    ok(-f $mock_api_results, "Located $mock_api_results for testing");
    no warnings 'redefine';
    *CPAN::Cpanorg::Auxiliary::_make_api_call = sub {
        my $json_text;
        open my $IN, '<', $mock_api_results
            or croak "Unable to open $mock_api_results for reading";
        $json_text = <$IN>;
        while (<$IN>) {
            chomp;
            $json_text .= $_;
        }
        #say "AAA: ", $json_text;
        close $IN
            or croak "Unable to close $mock_api_results after reading";
        return $json_text;
    };
    use warnings;

    chdir $tdir or croak "Unable to change to $tdir for testing";

    my ( $perl_versions, $perl_testing ) = fetch_perl_version_data();
    for ( $perl_versions, $perl_testing ) {
        ok(defined $_, "fetch_perl_version_data() returned defined value");
        ok(ref($_) eq 'ARRAY', "fetch_perl_version_data() returned arrayref");
    }
    ok(-f $file_expected, "$file_expected was created");
    my $spv = scalar @{$perl_versions};
    my $spt = scalar @{$perl_testing};
    TODO: {
        local $TODO = 'Bizarre situation';
    ok($spv,
        "fetch_perl_version_data() found non-zero number ($spv) of stable releases");
    ok($spt,
        "fetch_perl_version_data() found non-zero number ($spt) of dev or RC releases");
    }

    chdir $CPANdir or croak "Unable to chdir to $CPANdir";

    ( $perl_versions, $perl_testing ) = add_release_metadata( $perl_versions, $perl_testing );

    my %statuses = ();
    my $expect = { stable => 3, testing => 15 };
    for my $release (@{$perl_versions}, @{$perl_testing}) {
        $statuses{$release->{status}}++;
    }
    TODO: {
        local $TODO = 'If both inputs to add_release_metadata() are empty lists, no statuses will be recorded';
    is_deeply(\%statuses, $expect, "Got expected statuses");
    }
    TODO: {
        local $TODO = 'If both inputs to add_release_metadata() are empty lists, no metadata will be added';
    my $sample_release_metadata = $perl_testing->[0];
		for my $k ( qw|
        released
        released_date
        released_time
        status
        type
        url
        version
        version_iota
        version_major
        version_minor
        version_number
    | ) {
        no warnings 'uninitialized';
        ok(length($sample_release_metadata->{$k}),
            "$k: Got non-zero-length string <$sample_release_metadata->{$k}>");
    }
		my $srm_files_metadata = $sample_release_metadata->{files}->[0];
		for my $k ( qw|
        file
        filedir
        filename
        md5
        mtime
        sha1
        sha256
    | ) {
        no warnings 'uninitialized';
        ok(length($srm_files_metadata->{$k}),
            "$k: Got non-zero-length string <$srm_files_metadata->{$k}>");
    }

    chdir $mock_srcdir or croak "Unable to change back to $mock_srcdir";

    my $rv = write_security_files_and_symlinks( $perl_versions, $perl_testing );
    ok($rv, "write_security_files_and_symlinks() returned true value");
    my @expected_security_files =
        map { File::Spec->catfile(
            '5.0',
            "perl-5.27.11.tar.gz." . $_ . ".txt"
        ) }
        qw( sha1 sha256 md5 );
    for my $security (@expected_security_files) {
        ok(-f $security, "Security file '$security' located");
    }
    note("Test creation of symlinks");
    {
        my ($expected_symlink, $target);
        $expected_symlink = File::Spec->catfile(
                '5.0',
                "perl-5.27.11.tar.gz"
        );
        ok(-l $expected_symlink, "Found symlink '$expected_symlink'");
        $target = readlink($expected_symlink);
        chdir '5.0' or croak "Unable to chdir to 5.0";
        ok(-f $target, "Found target of symlink: '$target'");
        chdir $mock_srcdir or croak "Unable to change back to $mock_srcdir";
    }
    {
        my ($expected_symlink, $target);
        $expected_symlink = File::Spec->catfile(
                '5.0',
                "perl-5.26.0.tar.gz"
        );
        ok(-l $expected_symlink, "Found symlink '$expected_symlink'");
        $target = readlink($expected_symlink);
        chdir '5.0' or croak "Unable to chdir to 5.0";
        ok(-f $target, "Found target of symlink: '$target'");
        chdir $mock_srcdir or croak "Unable to change back to $mock_srcdir";
    }
    {
        my ($expected_symlink, $target);
        $expected_symlink = File::Spec->catfile("perl-5.26.0.tar.gz");
        $target = readlink($expected_symlink);
        ok(-f $target, "Found target of symlink: '$target'");
    }
    } # END TODO

    chdir $cwd or croak "Unable to change back to $cwd";
}