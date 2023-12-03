#!/usr/bin/perl -w

use strict;

use File::Copy qw/cp/;
use IO::Handle;
use Cwd;
use Carp;

STDOUT->autoflush(1);
STDERR->autoflush(1);

defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode\n";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!\n";

sub resolvePhysicalPath {
    my $path = shift;
    my $saveWD = cwd();
    chdir $path
      or confess "Couldn't cd to $path: $!\n";
    chomp(my $physicalPath = `pwd -P`);
    chdir $saveWD
      or confess "Couldn't cd back to $saveWD: $!\n";
    return $physicalPath;
}

my $appDir = resolvePhysicalPath "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";
my $destChooserDir = "$appDir/chooser";
my $srcIconDir = resolvePhysicalPath "$ENV{SRCROOT}/Help";

sub copyWatch {
    my $watch = shift;
    my $srcDir = shift;
    my $destDir = shift;

    my $cmd = "sips --resampleHeightWidth 160 160 \"$srcDir/$watch/$watch-icon-f.png\" --out \"$destDir/$watch.png\" > /dev/null";
    # warn "$cmd\n";
    (system $cmd) == 0
	or die "Problem resampling watch icon image for $watch: $!";
}

opendir DIR, $srcIconDir
  or die "Couldn't read directory $srcIconDir: $!";
my @entries = grep !/^\./, readdir DIR;
closedir DIR;

my @watches;
foreach my $entry (@entries) {
    my $path = "$srcIconDir/$entry/$entry-icon-f.png";
    if (-e "$srcIconDir/$entry/$entry-icon-f.png") {
	push @watches, $entry;
    }
}

(scalar @watches) > 0
    or die "Didn't find any chooser icons to copy";

if (!-d $destChooserDir) {
    mkdir $destChooserDir, 0777
	or die "Couldn't create directory $destChooserDir: $!";
}

foreach my $watch (@watches) {
    copyWatch $watch, $srcIconDir, $destChooserDir;
}

print "Copied watch chooser icons\n";
