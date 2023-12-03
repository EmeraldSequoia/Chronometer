#!/usr/bin/perl -w

use strict;

# Nonstandard Perl modules:
use Image::ExifTool;

my %exceptionData = (
    "Geneva/front-atlas-Z-2.png" => 1,
    "Greenwich/front-atlas-Z-2.png" => 1,
    "Terra/front-atlas-Z-2.png" => 1,
    "Thebes/front-atlas-Z-2.png" => 1,
    "Background/front-atlas-Z-2.png" => 1,

    "AtlantisIV/front-atlas-Z-2.png" => 1,
    "AtlantisIV/back-atlas-Z-2.png" => 1,
    "AtlantisIV/night-atlas-Z-2.png" => 1,
    "Cairo/front-atlas-Z-2.png" => 1,
    "Cairo/front-atlas-Z-1.png" => 1,
    "Cairo/back-atlas-Z-2.png" => 1,
    "Cairo/back-atlas-Z-1.png" => 1,
    );

my $exifTool = new Image::ExifTool;

sub insertCommas {
    my $number = shift;
    my ($integer, $fraction);
    if ($number =~ /(-?\d+)\.(\d*)/) {
	$integer = $1;
	$fraction = $2;
    } else {
	$integer = $number;
    }
    $fraction = "" if not defined $fraction;
    $integer =~ s/(\d)(\d\d\d)$/$1,$2/go;
    while ($integer =~ s/(\d)(\d\d\d,)/$1,$2/go) {
    }
    if ($fraction ne "") {
	return "$integer.$fraction";
    } else {
	return $integer;
    }
}

my @zoomPowers;
sub initZoomPowers {
    my $filename = "Classes/Constants.h";
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

sub pixelsForImage {
    my $file = shift;
    my $info = $exifTool->ImageInfo($file);
    defined $info->{ImageWidth}
      or die "Couldn't find $file\n";
    return $info->{ImageWidth} * $info->{ImageHeight};
}

initZoomPowers;

if (-e "archive") {
    opendir DIR, "archive"
	or die "Couldn't read directory archive: $!\n";
    my @entries = grep !/^\./, readdir DIR;
    closedir DIR;
    foreach my $entry (@entries) {
        next if $entry eq "archiveVersion.txt";
	foreach my $mode ("front", "night", "back") {
	    next if $entry eq "Background" and $mode ne "front";
	    my $z0Size = pixelsForImage "archive/$entry/$mode-atlas-Z0.png";
	    $z0Size /= (1024);
	    foreach my $z2 (reverse @zoomPowers) {
		next if $z2 == 0;
                next if $entry eq "Background" and $z2 < 0;
		my $zSize = pixelsForImage "archive/$entry/$mode-atlas-Z$z2.png";
		$zSize /= (1024);
		my $expectedRatio = 4 ** (-$z2);
		if ($expectedRatio != ($z0Size / $zSize)) {
		    if ($exceptionData{"$entry/$mode-atlas-Z$z2.png"}) {
			printf("Expected discrepancy for $entry/$mode $z2\n");
		    } else {
			printf("Unexpected zoomed archive size:\n");
			printf("%20s Z0 %s\n", "$entry/$mode", insertCommas($z0Size));
			printf("%20s $z2 %3s (ratio of #pixels is %d, expected ratio is %d)\n",
			       "",
			       insertCommas($zSize),
			       $z0Size / $zSize,
			       $expectedRatio)
		    }
		} else {
		    if ($exceptionData{"$entry/$mode-atlas-Z$z2.png"}) {
			printf("\n**** Unexpected non-discrepancy for $entry/$mode $z2\n\n");
		    }
		}
	    }
	}
    }
}
