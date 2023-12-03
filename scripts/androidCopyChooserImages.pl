#!/usr/bin/perl -w

use strict;

# Copies the images created by scripts/androidScreenCaptureWatcher.pl (at highest resolution) into the proper place for use
# by the Android watchface chooser.

# Standard Perl libraries
use File::Basename;
use File::Copy qw/cp/;
use FindBin;

# Local modules
use lib $FindBin::Bin;
use AndroidDeviceSelector;

my $srcDir = "android/screencaps/480";
my $dstDir = "android/project/ChronometerPro/src/main/res/drawable-hdpi";

my $quiet = 1;

sub filesAreIdentical {
    my ($file1, $file2) = @_;
    return system("cmp -s \"$file1\" \"$file2\"") == 0;
}

sub copyChangedFile {
    my $srcFile = shift;
    my $dstFile = shift;
    if (filesAreIdentical $srcFile, $dstFile) {
        warn "Skipping unchanged $dstFile\n" unless $quiet;
        return;
    }
    warn "cp $srcFile $dstFile\n";
    unlink $dstFile;
    cp $srcFile, $dstFile
      or die "Couldn't copy $srcFile to $dstFile: $!\n";
}

sub copyEntry {
    my $srcLeaf = shift;
    my $kind = shift;
    my $srcPath = "$srcDir/$kind/$srcLeaf";

    my ($name, $path, $ext) = fileparse $srcLeaf, ".png";
    my $dstLeaf = lc $name;
    $dstLeaf =~ s/ /_/go;
    $dstLeaf =~ s/-interactive//go;
    return if $dstLeaf =~ /-/;
    my $dstPath = lc "$dstDir/$dstLeaf" . "_$kind$ext";
    copyChangedFile $srcPath, $dstPath;
}

foreach my $kind ("square", "round") {
    my $kindDir = "$srcDir/$kind";
    warn "Reading directory '$kindDir'\n";
    opendir DIR, "$kindDir"
      or die "Couldn't read directory '$kindDir': $!\n";
    my @entries = grep !/^\./, readdir DIR;
    closedir DIR;
    foreach my $entry (@entries) {
        next if $entry =~ /-ambient/;
        copyEntry $entry, $kind;
    }
}
