#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Copy 'cp';
use Cwd;

my $sandboxDirectory = shift;
my $watchDirectory = shift;

$ENV{LD_LIBRARY_PATH} = "";
delete $ENV{DYLD_ROOT_PATH};

sub makeZoomArchive {
    my $sourceArchive = shift;
    my $destArchive = shift;
    my $zoomPower = shift;
    my $sourceWidth = shift;
    my $destWidth;
    if ($zoomPower == 0) {
	warn "cp $sourceArchive $destArchive\n";
	cp $sourceArchive, $destArchive
	  or die "Couldn't copy $sourceArchive to $destArchive: $!\n";
	return;
    } elsif ($zoomPower < 0) {
	$destWidth = $sourceWidth >> (-$zoomPower);
    } else {
	$destWidth = $sourceWidth >> $zoomPower;
    }
    unlink $destArchive;
    my $cmd = "sips --resampleWidth $destWidth \"$sourceArchive\" --out \"$destArchive\"";
    warn "$cmd\n";
    system($cmd) == 0
      or die "Problem resizing archive: $!\n";
}

my @zoomPowers;

sub findSourceWidthForArchive {
    my $sourceArchive = shift;
    my $cmd = "sips -g pixelWidth \"$sourceArchive\"";
    warn "$cmd\n";
    open PIPE, "$cmd |"
      or die "Couldn't open cmd pipe: $!\n";
    my $line = <PIPE>;  # skip past filename
    chomp($line = <PIPE>);
    close PIPE;
    my (undef, $sourceWidth) = split /: /, $line;
    return $sourceWidth;
}

sub makeZoomArchivesForArchive {
    my $sourceArchive = shift;
    my $sourceRoot = $sourceArchive;
    $sourceRoot =~ s/\.png$//i
      or die "source archive is not a png: $sourceArchive\n";
    my $sourceWidth;
    foreach my $zoomPower (@zoomPowers) {
	my $dest = sprintf "$sourceRoot-ZoomPower%d.png", $zoomPower;
	if (-e $dest && (-M _ < -M $sourceArchive)) {
	    # print "dest already newer than source: $destArchive\n";
	    next;
	}
	if (!defined $sourceWidth) {
	    $sourceWidth = findSourceWidthForArchive $sourceArchive;
	}
	#print "\nZoom $zoomPower\n$sourceArchive\n$dest\n";
	makeZoomArchive $sourceArchive, $dest, $zoomPower, $sourceWidth;
    }
}

sub makeZoomArchivesForWatch {
    my $path = shift;
    foreach my $side ("front", "back", "night") {
	my $archive = "$path/$side-atlas.png";
	$archive =~ s/^\.\///o;
	next if ! -e $archive;
	makeZoomArchivesForArchive $archive;
    }
}

sub initZoomPowers {
    my $filename = "$sandboxDirectory/Classes/Constants.h";
    open CONSTANTS, "$filename"
      or die "Couldn't read $filename: $!\n";
    my $minZoom;
    my $maxZoom;
    while (<CONSTANTS>) {
	if (/^#define ECZoomMinPower2 *\( *([-\d]+) *\)/) {
	    $minZoom = $1;
	} elsif (/^#define ECZoomMaxPower2 *\( *([-\d]+) *\)/) {
	    $maxZoom = $1;
	}
    }
    close CONSTANTS;
    (defined $minZoom) && (defined $maxZoom)
      or die "Couldn't find definitions for ECZoom{Min,Max}Power2 in $filename\n";
    $minZoom < $maxZoom
      or die;
    for (my $zoom = $minZoom; $zoom <= $maxZoom; $zoom++) {
	push @zoomPowers, $zoom;
    }
}

defined $sandboxDirectory
  or $sandboxDirectory = ".";

initZoomPowers;

if (defined $watchDirectory) {
    chdir $watchDirectory
      or die "Couldn't cd to $watchDirectory: $!\n";
    my $wd = cwd();
    print "New pwd is $wd\n";
    makeZoomArchivesForWatch ".";
    exit;
}

opendir ARCH, "archive"
  or die "Couldn't open 'archive' directory: $!\n";
my @watches = grep !/^\./, readdir ARCH;
close ARCH;

foreach my $watch (@watches) {
    my $path = "archive/$watch";
    next if ! -d $path;
    makeZoomArchivesForWatch $path;
}
