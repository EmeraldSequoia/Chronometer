#!/usr/bin/perl -w

use strict;

use IO::Handle;
use File::Copy::Recursive qw(dircopy);
use File::Path;  # for rmtree

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $isDistributionBuild = ($ENV{BUILD_STYLE} =~ /distrib/i);

if ($isDistributionBuild) {
    die "Why on earth are you making a distribution build of Chronometer with Henry? :-)\n";
}

defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode\n";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!\n";

my $appDir = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";

my $isForAndroid = ($ENV{PRODUCT_NAME} =~ /^ChronoWithHAndroid$|^HenryForAndroid$/);

my $destWatchDir = "$appDir/Watches";
warn "destWatchDir is $destWatchDir\n";
my $srcWatchDir = "$ENV{SRCROOT}/Watches/Builtin";
if ($isForAndroid) {
    warn "Copying from Builtin-Android\n";
    $srcWatchDir = "$ENV{SRCROOT}/Watches/Builtin-Android";
}

my $destHelpDir = "$appDir/Help";
my $srcHelpDir = "$ENV{SRCROOT}/Help";

my $destProductsDir = "$appDir/products";
my $srcProductsDir = "$ENV{SRCROOT}/products";

my $destArchiveDir = "$appDir/archive";
print "destArchiveDir is $destArchiveDir\n";

sub doDirectory {
    my $srcDir = shift;
    my $destDir = shift;
    my $what = shift;

    if (-e $destDir || -l $destDir) {
        if (-l $destDir) {
            unlink $destDir
              or die "Couldn't remove previous link at $destDir\n";
        } else {
            rmtree $destDir
              or die "Couldn't remove previous directory tree at $destDir\n";
        }
    }
    my ($num_files_and_dirs, $num_dirs, $depth) = dircopy $srcDir, $destDir;
    if ($num_files_and_dirs <= 0) {
        die "Copy of $srcDir failed\n";
    }
    print "Copied $num_files_and_dirs files (including $num_dirs dirs) to a depth of $depth into $what\n";
}

doDirectory $srcWatchDir,     $destWatchDir,     "watches directory";
if ($isForAndroid) {
    doDirectory "$ENV{SRCROOT}/Watches/Builtin/Background", "$destWatchDir/Background", "background watch";
    doDirectory "$ENV{SRCROOT}/Watches/Builtin/partsBin",  "$destWatchDir/partsBin", "parts bin";
}
doDirectory $srcHelpDir,      $destHelpDir,      "help directory";
doDirectory $srcProductsDir,  $destProductsDir,  "products directory";

if (-e $destArchiveDir || -l $destArchiveDir) {
    if (-l $destArchiveDir) {
	unlink $destArchiveDir
	    or die "Couldn't remove previous link at $destArchiveDir\n";
    } else {
	rmtree $destArchiveDir
	    or die "Couldn't remove previous directory tree at $destArchiveDir\n";
    }
}

mkdir $destArchiveDir, 0777
  or die "Couldn't create $destArchiveDir: $!\n";

print "Created archive directory\n";
