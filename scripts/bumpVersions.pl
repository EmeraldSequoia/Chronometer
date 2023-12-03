#!/usr/bin/perl -w

use strict;

# This script bumps a component of the version number.  By default, it bumps the component at index 3 (the
# fourth or build number).  You can specify a different index with -index <N>.
#
# In all cases it first walks through all products, finding the most recent version.  Then it bumps the given
# index, and if that index is not the last, reinitializes the number (the build number is initialized to 1,
# and all others are initialized to 0).
#
# Thus if the current version is 3.9.7.2,
#
# default (and -index 3)  => 3.9.7.3
# -index 2                => 3.9.8.1
# -index 1                => 3.10.0.1
# -index 0                => 4.0.0.1
#
# You can just print all of the current versions with -list

my $indexToChange = 2;  # Default, the build number.
my $listOnly = 0;

my $arg = shift;
while (defined $arg) {
    if ($arg eq "-index") {
        $arg = shift;
        defined $arg
          or die "Missing index number\n\nUsage: $0  [ -index N | -list ]\n";
        $indexToChange = int($arg);
        $indexToChange eq $arg
          or die "-index '$arg' was not an integer\n";
    } elsif ($arg eq "-list") {
        $listOnly = 1;
    } else {
        die "Usage: $0  [ -index N | -list ]\n";
    }
    $arg = shift;
}
$indexToChange >= 0 && $indexToChange <= 3
  or die "Index $indexToChange out of range from 0 to 3\n";

printf("Changing index %d\n\n", $indexToChange);

-e "products"
  or die "Must run at top level of sandbox";

opendir PRODUCTS, "products"
  or die "Couldn't open products directory: $!\n";
my @products = grep !/^\./, readdir PRODUCTS;
closedir PRODUCTS;

sub makeSortableVersion {
    my $version = shift;
    my @components = split /\./, $version;
    return join(".", map { sprintf("%04d", $_) } @components);
}

sub makeActualVersion {
    my $version = shift;
    my @components = split /\./, $version;
    return join(".", map { sprintf("%d", $_) } @components);
}

my $highestShortVersion = makeSortableVersion("0.0.0");
my $highestShortVersionFlavor = "?";
my $highestBundleVersion = makeSortableVersion("0.0.0.0");
my $highestBundleVersionFlavor = "?";

printf("****  CURRENT STATE  ****\n");

foreach my $appFlavor (@products) {
    my $infoFile = "products/$appFlavor/Info.plist";

    open INFO, $infoFile
      or die "Couldn't read $infoFile: $!\n";

    my $foundBundleVersion;
    my $foundBundleShortVersion;
    my $derivedFoundShortVersion;
    my $nextOneIsBundleVersion = 0;
    my $nextOneIsBundleShortVersion = 0;
    while (<INFO>) {
	if (/>CFBundleVersion</) {
	    $nextOneIsBundleVersion = 1;
	} elsif ($nextOneIsBundleVersion) {
            if (m/>([^<]+)</) {
                $foundBundleVersion = $1;
            } else {
                die "Didn't find appropriate bundle version after key in $infoFile\n";
            }
            if ($foundBundleVersion =~ /^(\d+\.\d+\.\d+)(\.\d+)?$/) {
                $derivedFoundShortVersion = $1;
            } else {
                die "Existing bundle version is not XX.XX.XX(.XX)? in $infoFile\n";
            }
	    $nextOneIsBundleVersion = 0;
	} elsif (/>CFBundleShortVersionString</) {
	    $nextOneIsBundleShortVersion = 1;
	} elsif ($nextOneIsBundleShortVersion) {
            if (m/>([^<]+)</) {
                $foundBundleShortVersion = $1;
            } else {
                die "Didn't find appropriate bundle short version after key\n";
            }
	    $nextOneIsBundleShortVersion = 0;
        }
    }
    close INFO;

    defined $foundBundleVersion
      or die "Couldn't find bundle version pattern in $infoFile\n";
    defined $foundBundleShortVersion
      or die "Couldn't find bundle short version pattern in $infoFile\n";
    $derivedFoundShortVersion eq $foundBundleShortVersion
      or die "Short version '$foundBundleShortVersion' doesn't match start of bundle version '$derivedFoundShortVersion' in $infoFile\n";

    my $foundMaxHere = 0;
    my $sortableBundleVersion = makeSortableVersion($foundBundleVersion);
    if ($sortableBundleVersion gt $highestBundleVersion) {
        $highestBundleVersion = $sortableBundleVersion;
        $highestBundleVersionFlavor = $appFlavor;
        $foundMaxHere = 1;
    }
    printf("bundle $foundBundleVersion ($sortableBundleVersion) for $appFlavor\n");

    my $sortableShortVersion = makeSortableVersion($foundBundleShortVersion);
    if (($sortableShortVersion gt $highestShortVersion) or
        ($foundMaxHere && ($sortableShortVersion eq $highestShortVersion))) {
        $highestShortVersion = $sortableShortVersion;
        $highestShortVersionFlavor = $appFlavor;
    }
    printf(" short $foundBundleShortVersion ($sortableShortVersion) for $appFlavor\n");

    print "\n";
}

printf("$highestBundleVersionFlavor max bundle \%s ($highestBundleVersion)\n", makeActualVersion($highestBundleVersion));
printf("$highestShortVersionFlavor max  short \%s ($highestShortVersion)\n", makeActualVersion($highestShortVersion));

printf("\n");
printf("****  CHANGE ANALYSIS  ****\n");

my @versions = split /\./, makeActualVersion($highestBundleVersion);

while ((scalar @versions) > $indexToChange + 1) {
    pop @versions;
}

# Bump the version requested.
$versions[$indexToChange]++;

# Now add numbers if we shortened.
while ((scalar @versions) < 4) {
    # if ((scalar @versions) == 3) {
    #     push @versions, 1;
    # } else {
    #     push @versions, 0;
    # }
    push @versions, 0;
}
my $newBundleVersion = join(".", @versions);
pop @versions;
my $newShortVersion = join(".", @versions);
$newBundleVersion = $newShortVersion;  # HACK HACK
# $newShortVersion =~ s/\.0$//o;  # Chop only the last .0 off so 3.3.0 becomes 3.3 but 3.0.0 becomes 3.0

print("New version $newShortVersion ($newBundleVersion)\n");

if ($listOnly) {
    exit(0);
}

printf("\n");
printf("****  CHANGES  ****\n");

foreach my $appFlavor (@products) {
    my $infoFile = "products/$appFlavor/Info.plist";
    my $newInfoFile = "$infoFile.new";

    open INFO, $infoFile
      or die "Couldn't read $infoFile: $!\n";
    open NEWINFO, ">$newInfoFile"
      or die "Couldn't create new info file: $!\n";

    my $foundBundleVersion;
    my $foundBundleShortVersion;
    my $derivedFoundShortVersion;
    my $nextOneIsBundleVersion = 0;
    my $nextOneIsBundleShortVersion = 0;
    while (<INFO>) {
	if (/>CFBundleVersion</) {
	    $nextOneIsBundleVersion = 1;
	} elsif ($nextOneIsBundleVersion) {
            if (m/>([^<]+)</) {
                $foundBundleVersion = $1;
            } else {
                die "Didn't find appropriate bundle version after key\n";
            }
	    $nextOneIsBundleVersion = 0;
            if ($foundBundleVersion =~ /^(\d+\.\d+\.\d+)(\.\d+)?$/) {
                $derivedFoundShortVersion = $1;
            } else {
                die "Existing bundle version is not XX.XX.XX(.XX)?\n";
            }
            if ($foundBundleVersion eq $newBundleVersion) {
                # Do nothing, we're already at the new version.
            } else {
                s/>([^<]+)</>$newBundleVersion</o;
                printf "%18s: %10s -> %s\n", $appFlavor, $foundBundleVersion, $newBundleVersion;
            }
	} elsif (/>CFBundleShortVersionString</) {
	    $nextOneIsBundleShortVersion = 1;
	} elsif ($nextOneIsBundleShortVersion) {
            if (m/>([^<]+)</) {
                $foundBundleShortVersion = $1;
            } else {
                die "Didn't find appropriate bundle short version after key\n";
            }
	    $nextOneIsBundleShortVersion = 0;
            if ($newShortVersion eq $foundBundleShortVersion) {
                # Do nothing, we're already there
            } else {
                s/>([^<]+)</>$newShortVersion</o;
                printf "%18s: %10s -> %s\n", $appFlavor, $foundBundleShortVersion, $newShortVersion;
            }
        }
        print NEWINFO $_;
    }
    close INFO;
    close NEWINFO;

    defined $foundBundleVersion
      or die "Couldn't find bundle version pattern in $infoFile\n";
    defined $foundBundleShortVersion
      or die "Couldn't find bundle short version pattern in $infoFile\n";
    $derivedFoundShortVersion eq $foundBundleShortVersion
      or die "Short version '$foundBundleShortVersion' doesn't match start of bundle version '$derivedFoundShortVersion'\n";

    rename $newInfoFile, $infoFile
      or die "Couldn't rename '$newInfoFile' to '$infoFile': $!\n";

    print "\n";
}
