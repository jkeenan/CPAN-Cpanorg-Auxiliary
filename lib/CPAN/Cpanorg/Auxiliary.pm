package CPAN::Cpanorg::Auxiliary;
use 5.14.0;
use warnings;
use parent 'Exporter';
our $VERSION = '0.01';
our @EXPORT_OK = qw(
);
use Carp qw/confess/;
use File::Basename qw/dirname basename/;
use File::Slurp 9999.19;
use Getopt::Long;
use JSON ();
use LWP::Simple qw(get);

my $json = JSON->new->pretty(1);

sub print_file {
    my ( $file, $data ) = @_;

    write_file( "data/$file", { binmode => ':utf8' }, $data )
        or die "Could not open data/$file: $!";
}

sub sort_versions {
    my $list = shift;

    my @sorted = sort {
               $b->{version_major} <=> $a->{version_major}
            || int( $b->{version_minor} ) <=> int( $a->{version_minor} )
            || $b->{version_iota} <=> $a->{version_iota}
    } @{$list};

    return \@sorted;

}

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

sub fetch_perl_version_data {
    my $perl_dist_url = "http://search.cpan.org/api/dist/perl";

    my $filename = 'perl_version_all.json';

    # See what we have on disk
    my $disk_json = '';
    $disk_json = read_file("data/$filename")
        if -r "data/$filename";

    my $cpan_json = get($perl_dist_url);
    die "Unable to fetch $perl_dist_url" unless $cpan_json;

    if ( $cpan_json eq $disk_json ) {

        # Data has not changed so don't need to do anything
        exit;
    } else {

        # Save for next fetch
        print_file( $filename, $cpan_json );
    }

    my $data = $json->decode($cpan_json);

    my @perls;
    my @testing;
    foreach my $module ( @{ $data->{releases} } ) {
        next unless $module->{authorized} eq 'true';

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
        } else {
            push @testing, $module;
        }
    }
    return \@perls, \@testing;
}


