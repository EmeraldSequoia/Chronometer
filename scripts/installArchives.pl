#!/usr/bin/perl -w

use strict;

use File::Copy qw/cp/;
use File::Basename;
use IO::Handle;
use File::Path;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $isDistributionBuild = ($ENV{BUILD_STYLE} =~ /distrib/i);
my $unapprovedWatchesRequested = $ENV{EC_EXTRA_WATCHES};

if ($isDistributionBuild && $unapprovedWatchesRequested) {
    die "Distribution builds may not have unapproved watches; turn off EC_EXTRA_WATCHES in target settings\n";
}

defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode\n";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!\n";

my $appFlavor = shift;

($appFlavor eq $ENV{PRODUCT_NAME}) or ($appFlavor eq "ChronoAll" and $ENV{PRODUCT_NAME} eq "Chrono Plus")
  or die "appFlavor $appFlavor isn't the same as PRODUCT_NAME $ENV{PRODUCT_NAME}";  # Otherwise installHelp.pl isn't going to work right

my $archiveDir = "archiveHD";
my $copyZ2Atlases = 1;
warn "Using archiveHD atlases for this product...\n";

system("scripts/recordEffectiveArchiveVersion.pl $archiveDir") == 0
    or die "Trouble recording archive version\n";

my $appDir = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";
my $destArchiveDir = "$appDir/archive";
my $srcArchiveDir = "$ENV{SRCROOT}/$archiveDir";

my %approvedWatches;

if (!$unapprovedWatchesRequested) {
    my $approvedWatchFile = "$ENV{SRCROOT}/products/$appFlavor/Watches.txt";
    open APPROVE, $approvedWatchFile
	or die "Couldn't read $approvedWatchFile: $!\n";
    while (<APPROVE>) {
	chomp;
	next if (/^\s*\#/);
	$approvedWatches{$_} = 1;
    }
    close APPROVE;
}

sub maybeCopyFile {
    my $srcPath = shift;
    my $destPath = shift;
    if (-e $srcPath) {
	cp $srcPath, $destPath
	  or die "Couldn't copy $srcPath to $destPath: $!\n";
    }
}

sub copyFile {
    my $srcPath = shift;
    my $destPath = shift;
    cp $srcPath, $destPath
      or die "Couldn't copy $srcPath to $destPath: $!\n";
}

sub copyArchivesForMode {
    my $watchDir = shift;
    my $destWatchDir = shift;
    my $archive = shift;
    my $missingOK = shift;
    if ($missingOK) {
        if ($copyZ2Atlases) {
            maybeCopyFile "$watchDir/$archive-Z2.png",  "$destWatchDir/$archive-Z2.png";
            maybeCopyFile "$watchDir/$archive-Z2.dat",  "$destWatchDir/$archive-Z2.dat";
        }
        maybeCopyFile "$watchDir/$archive-Z1.png",  "$destWatchDir/$archive-Z1.png";
	maybeCopyFile "$watchDir/$archive-Z0.png",  "$destWatchDir/$archive-Z0.png";
	maybeCopyFile "$watchDir/$archive-Z-1.png", "$destWatchDir/$archive-Z-1.png";
	maybeCopyFile "$watchDir/$archive-Z-2.png", "$destWatchDir/$archive-Z-2.png";
	maybeCopyFile "$watchDir/$archive-Z1.dat",  "$destWatchDir/$archive-Z1.dat";
	maybeCopyFile "$watchDir/$archive-Z0.dat",  "$destWatchDir/$archive-Z0.dat";
	maybeCopyFile "$watchDir/$archive-Z-1.dat", "$destWatchDir/$archive-Z-1.dat";
	maybeCopyFile "$watchDir/$archive-Z-2.dat", "$destWatchDir/$archive-Z-2.dat";
    } else {
	copyFile "$watchDir/$archive-Z0.png", "$destWatchDir/$archive-Z0.png";
	copyFile "$watchDir/$archive-Z0.dat", "$destWatchDir/$archive-Z0.dat";
	# FIX FIX: Need background Z1 archives to be created but they aren't yet
	maybeCopyFile "$watchDir/$archive-Z1.png", "$destWatchDir/$archive-Z1.png";
	maybeCopyFile "$watchDir/$archive-Z1.dat", "$destWatchDir/$archive-Z1.dat";
        if ($copyZ2Atlases) {
            maybeCopyFile "$watchDir/$archive-Z2.png", "$destWatchDir/$archive-Z2.png";
            maybeCopyFile "$watchDir/$archive-Z2.dat", "$destWatchDir/$archive-Z2.dat";
        }
	my $leaf = fileparse $watchDir;
	if ($leaf !~ /^Background$/i && $leaf !~ /^BackgroundHD$/i) {
	    copyFile "$watchDir/$archive-Z-1.png", "$destWatchDir/$archive-Z-1.png";
	    copyFile "$watchDir/$archive-Z-2.png", "$destWatchDir/$archive-Z-2.png";
	    copyFile "$watchDir/$archive-Z-1.dat", "$destWatchDir/$archive-Z-1.dat";
	    copyFile "$watchDir/$archive-Z-2.dat", "$destWatchDir/$archive-Z-2.dat";
	}
    }
}

sub copyWatchDir {
    my $watch = shift;
    my $srcDir = shift;
    my $destDir = shift;
    my $watchDir = "$srcDir/$watch";

    my $destWatchDir = "$destDir/$watch";
    if (!-d $destWatchDir) {
	mkdir $destWatchDir, 0777
	  or die "Couldn't create directory $destWatchDir: $!\n";
    }

    copyFile "$watchDir/archive.dat", "$destWatchDir/archive.dat";
    copyArchivesForMode $watchDir, $destWatchDir, "front-atlas", 0;
    copyArchivesForMode $watchDir, $destWatchDir, "back-atlas", 1;
    copyArchivesForMode $watchDir, $destWatchDir, "night-atlas", 1;
}

opendir DIR, $srcArchiveDir
  or die "Couldn't read directory $srcArchiveDir: !$\n";
my @watches = grep !/^\.|^archiveVersion\.txt$/, readdir DIR;
closedir DIR;

if (!-d $destArchiveDir) {
    mkdir $destArchiveDir, 0777
	or die "Couldn't create directory $destArchiveDir: $!\n";
}

my %srcWatchHash;

copyFile "$srcArchiveDir/archiveVersion.txt", "$destArchiveDir/archiveVersion.txt";

foreach my $watch (@watches) {
    if ($approvedWatches{$watch} || $unapprovedWatchesRequested) {
	# print "Copying watch '$watch'\n";
	copyWatchDir $watch, $srcArchiveDir, $destArchiveDir;
    } else {
	print "Skipping unapproved watch '$watch'\n";
	! -e "$destArchiveDir/$watch"
	    or die "Unapproved watch directory already present in destination bundle: $destArchiveDir/$watch\n";
    }
    $srcWatchHash{$watch} = 1;
}

# Now check for obsolete watches in the build directory
opendir DIR, $destArchiveDir
  or die "Couldn't read dest dir $destArchiveDir: $!\n";
my @entries = grep !/^\.|^archiveVersion\.txt$/, readdir DIR;
closedir DIR;

foreach my $entry (@entries) {
    if (!defined $srcWatchHash{$entry}) {
	my $dest = "$destArchiveDir/$entry";
	warn "Obsolete watch directory present in build area: $dest\n";
	rmtree("$dest", 1);
	die "Couldn't remove tree $dest" if -e $dest;
    }
}

print "Copied watch archives from $srcArchiveDir to $destArchiveDir\n";
