package CPAN::Cpanorg::Auxiliary;
use 5.14.0;
use warnings;
use parent 'Exporter';
our $VERSION = '0.01';
our @EXPORT_OK = qw(
    print_file
    fetch_perl_version_data
    sort_versions
    extract_first_per_version_in_list
    add_release_metadata
    write_security_files_and_symlinks
);
use Cwd;
use File::Basename qw(basename dirname);
use File::Spec;
use File::Slurp 9999.19 qw(read_file write_file);
use JSON ();
use LWP::Simple qw(get);

=head1 SUBROUTINES

=head2 C<print_file()>

=over 4

=item * Purpose

Write out data from an array reference, here, data from the result of an HTTP
F<get> call which returns data in JSON format.

=item * Arguments

    write_file($file, $array_ref);

Two arguments:  basename of a file to be written to (implicitly, in a subdirectory called F<data/>); reference to an array of JSON elements.

=item * Return Value

Implicitly returns true value upon success.  Dies otherwise.

=item * Comment

Currently a wrapper around C<File::Slurp::write_file()>.  With perl 5.26 and
later, use of File::Slurp throws a deprecation warning.

=back

=cut

sub print_file {
    my ( $file, $data ) = @_;

    write_file( "data/$file", { binmode => ':utf8' }, $data )
        or die "Could not open data/$file: $!";
}

=head2 C<sort_versions()>

=over 4

=item * Purpose

Produce appropriately sorted list of Perl releases.

=item * Arguments

    my $latest = sort_versions( [ values %{$latest_per_version} ] )->[0];

=item * Return Value

=item * Comment

Call last.

=back

=cut

sub sort_versions {
    my $list = shift;

    my @sorted = sort {
               $b->{version_major} <=> $a->{version_major}
            || int( $b->{version_minor} ) <=> int( $a->{version_minor} )
            || $b->{version_iota} <=> $a->{version_iota}
    } @{$list};

    return \@sorted;

}

=head2 C<extract_first_per_version_in_list()>

=over 4

=item * Purpose

=item * Arguments

=item * Return Value

=item * Comment

=back

=cut

sub extract_first_per_version_in_list {
    my $versions = shift;

    my $lookup = {};
    foreach my $version ( @{$versions} ) {
        my $minor_version = $version->{version_major} . '.'
            . int( $version->{version_minor} );

        $lookup->{$minor_version} = $version
            unless $lookup->{$minor_version};
    }
    return $lookup;
}

=head2 C<fetch_perl_version_data()>

=over 4

=item * Purpose

Compares JSON data found on disk to result of API call to CPAN for 'perl' distribution.

=item * Arguments

None at the present time.

=item * Return Value

List of two array references:

=over 4

=item *

List of hash references, one per stable perl release.

=item *

List of hash references, one per developmental or RC perl release.

=back

Side effect:  Guarantees existence of file F<data/perl_version_all.json> beneath current working directory.

=item * Comment

Assumes existence of subdirectory F<data/> beneath current working directory.

Internally makes calls to C<File::Slurp::read_file()>, C<LWP::Simple::get()>,
C<File::Slurp::write_file()> (which throws warning in perl-5.26+).

=back

=cut

sub fetch_perl_version_data {

    my $filename = 'perl_version_all.json';

    # See what we have on disk
    my $disk_json = '';
    $disk_json = read_file("data/$filename")
        if -r "data/$filename";

    my $cpan_json = _make_api_call();

    if ( $cpan_json eq $disk_json ) {

        # Data has not changed so don't need to do anything
        #exit;
        return;
    }
    else {
        # Save for next fetch
        print_file( $filename, $cpan_json );
    }

    my $json = JSON->new->pretty(1);
    my $data = $json->decode($cpan_json);

    my @perls;
    my @testing;
    foreach my $module ( @{ $data->{releases} } ) {
        #next unless $module->{authorized} eq 'true';
        #next unless $module->{authorized};

        my $version = $module->{version};

        $version =~ s/-(?:RC|TRIAL)\d+$//;
        $module->{version_number} = $version;

        my ( $major, $minor, $iota ) = split( '[\._]', $version );
        $module->{version_major} = $major;
        $module->{version_minor} = int($minor);
        $module->{version_iota}  = int( $iota || '0' );

        $module->{type}
            = $module->{status} eq 'testing'
            ? 'Devel'
            : 'Maint';

        # TODO: Ask - please add some validation logic here
        # so that on live it checks this exists
        my $zip_file = $module->{distvname} . '.tar.gz';

        $module->{zip_file} = $zip_file;
        $module->{url} = "http://www.cpan.org/src/5.0/" . $module->{zip_file};

        ( $module->{released_date}, $module->{released_time} )
            = split( 'T', $module->{released} );

        next if $major < 5;

        if ( $module->{status} eq 'stable' ) {
            push @perls, $module;
        }
        else {
            push @testing, $module;
        }
    }
    return \@perls, \@testing;
}

sub _make_api_call {
    my $perl_dist_url = "http://search.cpan.org/api/dist/perl";
    my $cpan_json = get($perl_dist_url);
    die "Unable to fetch $perl_dist_url" unless $cpan_json;
    return $cpan_json;
}

sub add_release_metadata {
    my ($perl_versions, $perl_testing) = @_;

    my $thiscwd = cwd();

    # check disk for files
    foreach my $perl ( @{$perl_versions}, @{$perl_testing} ) {
        #say join('|' => $perl->{version}, $perl->{cpanid});
        my $id = $perl->{cpanid};

        if ( $id =~ /^(.)(.)/ ) {
            my $path     = "authors/id/$1/$1$2/$id";
            my $fileroot = "$path/" . $perl->{distvname};
            my @files    = glob("${fileroot}.*tar.*");

            die "Could not find perl ${fileroot}.*" unless scalar(@files);

            $perl->{files} = [];
            # The file_meta() sub in bin/perl-sorter.pl assumes the presence
            # of checksum files for each perl release.
            foreach my $file (@files) {
                my $ffile = File::Spec->catfile($thiscwd, $file);
                my $meta = file_meta($ffile);
                push( @{ $perl->{files} }, $meta );
            }
        }
    }
    return ($perl_versions, $perl_testing);
}

#my $src = "src";
#
sub write_security_files_and_symlinks {
    my ($perl_versions, $perl_testing) = @_;

    my $thiscwd = cwd();
    foreach my $perl ( ( @{$perl_versions}, @{$perl_testing} ) ) {

        # For a perl e.g. perl-5.12.4-RC1
        # create or symlink:
        foreach my $file ( @{ $perl->{files} } ) {
    
            my $filename = $file->{file};
            say "FFF: $filename";
    
            #my $out = "${src}/5.0/" . $file->{filename};
            my $out = "5.0/" . $file->{filename};
    
            foreach my $security (qw(md5 sha1 sha256)) {
                say "GGG: qq|${out}.${security}.txt|";
    
                print_file_if_different( "${out}.${security}.txt",
                    $file->{$security} );
            }
    
            create_symlink( ( ( '../' x 2 ) . $file->{file} ), $out );
    
            # only link stable versions directly from src/
            next unless $perl->{status} eq 'stable';
            say "HHH: stable: $perl->{version}";
                #"${src}/" . $file->{filename}
                #. 
            create_symlink(
                ( ( '../' x 1 ) . $file->{file} ),
                $file->{filename}
            );
    
        }
    }
    return 1;
}

=head2 file_meta

    my $meta = file_meta($file);

	print $meta->{file};
	print $meta->{filename};
	print $meta->{filedir};
    print $meta->{md5};
    print $meta->{sha256};
    print $meta->{mtime};
    print $meta->{sha1};

Get or calculate meta information about a file

=cut

sub file_meta {
    my $file     = shift;
    my $filename = basename($file);
    my $dir      = dirname($file);
    my $checksum = File::Spec->catfile($dir, 'CHECKSUMS');
    say "XXX: $checksum";

    # The CHECKSUM file has already calculated
    # lots of this so use that
    my $cksum;
    unless ( defined( $cksum = do $checksum ) ) {
        die qq[Checksums file "$checksum" not found\n];
    }

    # Calculate the sha1
    my $sha1;
    if ( open( my $fh, "openssl sha1 $file |" ) ) {
        while (<$fh>) {
            if (/^SHA1\(.+?\)= ([0-9a-f]+)$/) {
                $sha1 = $1;
                last;
            }
        }
    }
    die qq[Failed to compute sha1 for $file\n] unless defined $sha1;

    return {
        file     => $file,
        filedir  => $dir,
        filename => $filename,
        mtime    => ( stat($file) )[9],
        md5      => $cksum->{$filename}->{md5},
        sha256   => $cksum->{$filename}->{sha256},
        sha1     => $sha1,
    };
}

sub print_file_if_different {
    my ( $file, $data ) = @_;

    if ( -r $file ) {
        my $content = read_file($file);
        return if $content eq $data;
    }

    write_file( "$file", { binmode => ':utf8' }, $data )
        or die "Could not open $file: $!";
}

=head2 create_symlink

    create_symlink($oldfile, $newfile);

Will unlink $newfile if it already exists and then create
the symlink.

=cut

sub create_symlink {
    my ( $oldfile, $newfile ) = @_;

    # Clean out old symlink if it does not point to correct location
    if ( -l $newfile && readlink($newfile) ne $oldfile ) {
        unlink($newfile);
    }
    symlink( $oldfile, $newfile ) unless -l $newfile;
}

1;

