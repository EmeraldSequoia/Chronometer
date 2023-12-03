#!/usr/bin/perl -w

# Install help files into app bundle (not used in CwH)

use strict;

use File::Basename;
use File::Copy qw/cp/;
use IO::Handle;

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

my $appFlavor = $ENV{PRODUCT_NAME};

my $appDir = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";
my $destHelpDir = "$appDir/Help";
my $srcHelpDir = "$ENV{SRCROOT}/Help";

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

my $emeraldProduct = "Emerald $appFlavor";
$emeraldProduct =~ s/ChronometerHD/Chronometer/o;
my $genevaWatch = $appFlavor eq "Geneva" ? "the watch" : "Geneva";

sub copyFile {
    my $srcPath = shift;
    my $destPath = shift;
    unlink $destPath;
    if ($srcPath =~ /\.html$/i) {
	open SRC, $srcPath
	  or die "Couldn't read $srcPath: $!";
	open DEST, ">$destPath"
	  or die "Couldn't create $destPath: $!";
	while (<SRC>) {
	    s/\bEMERALD_PRODUCT\b/$emeraldProduct/g;
	    s/\bGENEVA_WATCH\b/$genevaWatch/g;
	    print DEST $_;
	}
	close SRC;
	close DEST;
    } else {
	cp $srcPath, $destPath
	  or die "Couldn't copy $srcPath to $destPath: $!\n";
    }
}

sub maybeCopyDir {
    my $watch = shift;
    my $srcPath = shift;
    my $destPath = shift;
    if ($unapprovedWatchesRequested || defined $approvedWatches{$watch}) {
	if (!-d $destPath) {
	    mkdir $destPath, 0777
		or die "Couldn't create directory $destPath: $!\n";
	}
	opendir DIR, $srcPath
	    or die "Couldn't read directory $srcHelpDir: !$\n";
	my @files = grep !/^\./, readdir DIR;
	closedir DIR;
	foreach my $file (@files) {
	    copyFile "$srcPath/$file", "$destPath/$file";
	}
    }
}

opendir DIR, $srcHelpDir
  or die "Couldn't read directory $srcHelpDir: !$\n";
my @files = grep !/^\./, readdir DIR;
closedir DIR;

if (!-d $destHelpDir) {
    mkdir $destHelpDir, 0777
	or die "Couldn't create directory $destHelpDir: $!\n";
}

foreach my $file (@files) {
    my $path = "$srcHelpDir/$file";
    if (-d $path) {
	maybeCopyDir $file, $path, "$destHelpDir/$file";
    } else {
	next if $file =~ /HelpContentsTemplate|Help Contents|Complications|product\.css|roundedIcon\.png/;
	copyFile "$srcHelpDir/$file", "$destHelpDir/$file";
    }
}

print "Copied watch help files\n";
