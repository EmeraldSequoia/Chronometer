#!/usr/bin/perl -w

use strict;

use File::Path;  # for rmtree

defined $ENV{HOME}
  or die "No HOME environment variable\n";

my $simulatorAppDirRoot = "$ENV{HOME}/Library/Application Support/iPhone Simulator";

if (! -d "Chronometer.xcodeproj") {
    die "This script must be run from a top-level Harrison directory\n";
}

if (-e "build") {
    warn "Removing local build directory\n";
    rmtree "build"
      or die "Couldn't remove local build directory: $!\n";
}

sub getProductList {
    opendir PRODUCTS, "products"
	or die "Couldn't read products directory.  Run in top-level of sandbox.\n";
    my @entries = grep !/^\./, readdir PRODUCTS;
    closedir PRODUCTS;
    return @entries;
}

my @products = getProductList;

opendir DIR, $simulatorAppDirRoot
  or die "Couldn't read directory $simulatorAppDirRoot: $!\n";
my @entries = grep /^\d[\d\.]+$/, readdir DIR;
closedir DIR;

foreach my $xcodeVersion (@entries) {
    my $simulatorAppDir = "$simulatorAppDirRoot/$xcodeVersion/Applications";
    if (-e $simulatorAppDir) {
	warn "Looking in $simulatorAppDir\n";
	opendir DIR, $simulatorAppDir
	  or die "Couldn't read directory $simulatorAppDir: $!\n";
	my @entries = grep !/^\./, readdir DIR;
	closedir DIR;
	
	foreach my $entry (@entries) {
	    my $path = "$simulatorAppDir/$entry";
	    warn "Removing $path\n";
	    rmtree $path
	      or die "Couldn't remove $path: $!\n";
	}
    } else {
	warn "?? No simulator app directory $simulatorAppDir\n";
    }
}
