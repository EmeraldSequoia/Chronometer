#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Copy qw/cp/;

my $inputDir = "archive";
my $outputDir = "archive-red";

-e "tools"
  or die "Run this at the top-level Harrison directory\n";

my $imageMagick = "tools/ImageMagick-6.4.1";
my $imageMagickBin = "$imageMagick/bin";

$ENV{MAGICK_HOME} = $imageMagick;
$ENV{DYLD_LIBRARY_PATH} = "$imageMagick/lib";
$ENV{PATH} = "$imageMagickBin:$ENV{PATH}";

-e "$imageMagickBin/convert"
  or die "Can't run without ImageMagick\n";

sub makeRedForPart {
    my $inputFile = shift;
    my $outputFile = shift;
    my $cmd = "convert \"$inputFile\" -colorspace Gray -fill black -colorize 20,100,100 \"$outputFile\"";
    warn "$cmd\n";
    system($cmd);
    #system("open -a Preview \"$inputFile\"");
    #system("open -a Preview \"$outputFile\"");
}

sub doWatch {
    my $watch = shift;
    my $inputWatchDir = "$inputDir/$watch";
    my $outputWatchDir = "$outputDir/$watch";
    if (! -d $outputWatchDir) {
	mkdir $outputWatchDir, 0777
	  or die "Couldn't create $outputWatchDir directory: $!\n";
    }
    if (-e "$inputWatchDir/archive.dat") {
	cp "$inputWatchDir/archive.dat", "$outputWatchDir/archive.dat"
	  or die "Couldn't copy archive.dat: $!\n";
    }
    if (-e "$inputWatchDir/variable-names.txt") {
	cp "$inputWatchDir/variable-names.txt", "$outputWatchDir/variable-names.txt"
	  or die "Couldn't copy variable-names.txt: $!\n";
    }
    if (-e "$inputWatchDir/front-atlas.png") {
	makeRedForPart "$inputWatchDir/front-atlas.png", "$outputWatchDir/front-atlas.png";
    }
    if (-e "$inputWatchDir/back-atlas.png") {
	makeRedForPart "$inputWatchDir/back-atlas.png", "$outputWatchDir/back-atlas.png";
    }
    if (-e "$inputWatchDir/night-atlas.png") {
	makeRedForPart "$inputWatchDir/night-atlas.png", "$outputWatchDir/night-atlas.png";
    }
}

if (! -d $outputDir) {
    mkdir $outputDir, 0777
      or die "Couldn't create $outputDir directory: $!\n";
}

opendir ARCHIVE, $inputDir
  or die "Couldn't read directory $inputDir: $!\n";

my @entries = grep !/^\./, readdir ARCHIVE;

closedir ARCHIVE;

foreach my $watch (@entries) {
    doWatch $watch;
}
