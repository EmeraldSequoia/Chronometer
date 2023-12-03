#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Copy qw/cp/;
use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $firstVersionRun = shift;
my $latestVersionMsgGiven = shift;
defined $latestVersionMsgGiven
  or die "Usage:  $0  <first-version-run>  <latest-version-message-given>\n";

my $simulatorAppDirRoot = "$ENV{HOME}/Library/Application Support/iPhone Simulator";

my $plistAgeInDays;
my $plistFile;
my $mostRecentProduct;

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
    next if !-d $simulatorAppDir;
    opendir DIR, $simulatorAppDir
      or die "No directory $simulatorAppDir\n";
    my @entries = grep !/\./, readdir DIR;
    closedir DIR;
    foreach my $entry (@entries) {
	foreach my $product (@products) {
	    my $path = "$simulatorAppDir/$entry/Library/Preferences/com.emeraldsequoia.$product.plist";
	    if (-e $path) {
		my $pathAge = -M $path;
		defined $pathAge or die "Couldn't determine age of '$path'\n";
		if (!(defined $plistFile) || ($pathAge < $plistAgeInDays)) {
		    $plistFile = $path;
		    $plistAgeInDays = $pathAge;
		    $mostRecentProduct = $product;
		}
	    }
	}
    }
}

defined $plistAgeInDays
  or die "No EC-based apps installed in Simulator\n";
defined $plistFile
  or die "Internal error; plistFile undefined\n";

my $plistAgeInMinutes = $plistAgeInDays * 24 * 60;

printf "Plist file (for $mostRecentProduct) was last modified %.2f minutes ago:\n", $plistAgeInMinutes;
print "$plistFile\n";

if ($plistAgeInMinutes > 60) {
    die "Your preferences file appears to be more than an hour old\n";
}

open PIPE, "plutil -convert xml1 -o - \"$plistFile\" |"
  or die "Couldn't open pipe to plutil: $!\n";
my $tmpFile = "/tmp/resetSimulator.out";
open TMP, ">$tmpFile"
  or die "Couldn't create $tmpFile: $!\n";

my $nextIsFirstVersion = 0;
my $nextIsLatestVersion = 0;
while (<PIPE>) {
    if (/ECFirstVersionRun/) {
	$nextIsFirstVersion = 1;
    } elsif (/ECVersionMsg/) {
	$nextIsLatestVersion = 1;
    } elsif ($nextIsFirstVersion) {
	s%<string>[\d\.]+</string>%<string>$firstVersionRun</string>%;
	$nextIsFirstVersion = 0;
    } elsif ($nextIsLatestVersion) {
	s%<string>[\d\.]+</string>%<string>$latestVersionMsgGiven</string>%;
	$nextIsLatestVersion = 0;
    }
    print TMP $_;
}

close PIPE;
close TMP;

unlink $plistFile
  or warn "Couldn't remove existing $plistFile: $!\n..attempting to overwrite.\n";
cp $tmpFile, $plistFile
  or die "Couldn't copy $tmpFile to $plistFile: $!\n";

print "Plist file updated.\n";
