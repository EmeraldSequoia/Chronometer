#!/usr/bin/perl -w

use strict;

use IO::Handle;
use File::Path;  # for rmtree

STDOUT->autoflush(1);
STDERR->autoflush(1);

defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode\n";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!\n";

my $appDir = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";
my $destWatchDir = "$appDir/Watches";
my $destHelpDir = "$appDir/Help";
my $destArchiveDir = "$appDir/archive";

if (-l $destWatchDir) {
    unlink $destWatchDir
      or die "Couldn't remove previous Henry link at $destWatchDir\n";
    print "Removed Henry link to src watches\n";
}

if (-l $destHelpDir) {
    unlink $destHelpDir
      or die "Couldn't remove previous Henry link at $destHelpDir\n";
    print "Removed Henry link to src help files\n";
}

if (-l $destArchiveDir) {
    unlink $destArchiveDir
      or die "Couldn't remove previous Henry link at $destArchiveDir\n";
    print "Removed Henry link to src archive files\n";
}
