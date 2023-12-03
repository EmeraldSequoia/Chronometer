#!/usr/bin/perl -w

use strict;

my $isDistributionBuild = 0;

sub getVersion {
    chomp(my $gitVersion = `git describe --match "r1"`);
    $gitVersion =~ /^r1-(\d+)-(g[\dA-Za-z]+)$/
      or die "git describe fails to produce expected pattern:  Is there no 'r1' tag in this git repository, or has the format of 'git describe' changed?\n";
    $gitVersion = $2;
    return $gitVersion;
}

-e "products"
  or die "Must run at top level of sandbox";

my $version = getVersion;

opendir PRODUCTS, "products"
  or die "Couldn't open products directory: $!\n";
my @products = grep !/^\./, readdir PRODUCTS;
closedir PRODUCTS;

foreach my $appFlavor (@products) {
    my $infoFile = "products/$appFlavor/Info.plist";

    my $foundBundleVersion;
    my $foundBundleShortVersion;
    open INFO, $infoFile
      or die "Couldn't read $infoFile: $!\n";
    my $nextOneIsBundleVersion = 0;
    my $nextOneIsBundleShortVersion = 0;
    while (<INFO>) {
	if (/>CFBundleVersion</) {
	    $nextOneIsBundleVersion = 1;
	} elsif ($nextOneIsBundleVersion) {
	    $foundBundleVersion = $1 if m/>([^<]+)</;
	    $nextOneIsBundleVersion = 0;
	} elsif (/>CFBundleShortVersionString</) {
	    $nextOneIsBundleShortVersion = 1;
	} elsif ($nextOneIsBundleShortVersion) {
	    $foundBundleShortVersion = $1 if m/>([^<]+)</;
	    $nextOneIsBundleShortVersion = 0;
        }
    }
    close INFO;

    defined $foundBundleVersion
      or die "Couldn't find bundle version pattern in $infoFile\n";
    defined $foundBundleShortVersion
      or die "Couldn't find bundle short version pattern in $infoFile\n";
    my $fullVersion = $foundBundleVersion . "_$version";

    printf "%18s: %10s %s\n", $appFlavor, $fullVersion, $foundBundleShortVersion;
}
