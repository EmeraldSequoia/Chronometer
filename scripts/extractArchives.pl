#!/usr/bin/perl -w

# This script extracts archives from the most recent simulator versions of ChronoWithH and ChronoWithHHD
# into archive/ and archiveHD/ in the current directory.

# Use '-and[roid]' to extract HenryForAndroid archives.

use strict;

# Perl standard modules
use File::Copy qw/cp/;
use File::Find;

my @androidWidths = ("480");

my @androidFaces = ("Alexandria I", "Alexandria I-south",
                    "Atlantis I",
                    "Babylon I", "Babylon I-monday", "Babylon I-saturday",
                    "Chandra I", "Selene I",
                    "Firenze I", "Padua I",
                    "Geneva I", "Basel I",
                    "Haleakala I", "Hana I",
                    "Mauna Kea I", "Mauna Loa I",
                    "McAlester I",
                    "Miami I", "Venezia I",
                    "Milano I",
                    "Paris I", "Paris I-black",
                    "Terra I", "Gaia I",
                    "Vienna I", "Vienna I-midnight",

                    "Demo Control");
my $android = 0;
my $quiet = 0;
my $force = 0;
while (defined $ARGV[0] && $ARGV[0] =~ /^-/) {
    $_ = shift;
    if (/^-and/i) {
        $android = 1;
    } elsif (/^-q/) {
	$quiet = 1;
    } elsif (/^-f/) {
        $force = 1;
    } else {
	die "\nUnrecognized argument $_\n";
    }
}

# If any archive is older than this, the script will fail and do nothing.
my $ageThresholdInMinutes = 120;

sub ageInMinutesOfOldestFileInTree {
    my $tree = shift;
    my $shortName = shift;
    if (not -d $tree) {
        warn "No $shortName archive directory\n" if not -d $tree;
        die "... looking at $tree\n";
    }
    my $oldestAge = 0;
    my $oldestFile;
    find(sub {
             my $age = -M;
             return if $File::Find::name eq $tree;
             if ($age > $oldestAge) {
                 $oldestAge = $age;
                 $oldestFile = $File::Find::name;
             }
    }, $tree);
    $oldestFile =~ s/^$tree\///;
    my $ageInMinutes = $oldestAge * 24 * 60;
    printf "Oldest archive in $shortName is %s (in %s) at %.1f minutes\n", $oldestFile, $tree, $ageInMinutes;
    return $ageInMinutes;
}

sub filesAreIdentical {
    my ($file1, $file2) = @_;
    return system("cmp -s \"$file1\" \"$file2\"") == 0;
}

sub copyChangedFile {
    my $srcWatchDir = shift;  # e.g., <something>/archive/Terra
    my $dstWatchDir = shift;  # e.g., <something>/archiveHD/Terra
    my $leaf = shift; # e.g., "archive.dat" or "back-atlas-Z1.dat"
    my $srcFile = "$srcWatchDir/$leaf";
    my $dstFile = "$dstWatchDir/$leaf";
    if ($android && $dstFile !~ /\.png$/i) {
        $dstFile = $dstFile . ".png";
    }
    if (filesAreIdentical $srcFile, $dstFile) {
        warn "Skipping unchanged $dstFile\n" unless $quiet;
        return;
    }
    warn "cp $srcFile $dstFile\n";
    unlink $dstFile;
    cp $srcFile, $dstFile
      or die "Couldn't copy $srcFile to $dstFile: $!\n";
}

sub copyChangedFilesForSideAndZoom {
    my $srcWatchDir = shift;  # e.g., <something>/archive/Terra
    my $dstWatchDir = shift;  # e.g., <something>/archiveHD/Terra
    my $side = shift; # e.g., front, back, or night
    my $zoomOrWidth = shift; # e.g., "Z-2" or "Z0"
    copyChangedFile $srcWatchDir, $dstWatchDir, "$side-atlas-$zoomOrWidth.dat";
    if ($dstWatchDir !~ m%/Background$% || $side eq "front") {
        copyChangedFile $srcWatchDir, $dstWatchDir, "$side-atlas-$zoomOrWidth.png";
    }
}

sub copyChangedFilesForSide {
    my $srcWatchDir = shift;  # e.g., <something>/archive/Terra
    my $dstWatchDir = shift;  # e.g., <something>/archiveHD/Terra
    my $side = shift; # e.g., front, back, or night
    if ($android) {
        foreach my $width (@androidWidths) {
            copyChangedFilesForSideAndZoom $srcWatchDir, $dstWatchDir, $side, "W$width";
        }
    } else {
        if ($dstWatchDir !~ m%/Background$%) {
            copyChangedFilesForSideAndZoom $srcWatchDir, $dstWatchDir, $side, "Z-2";
            copyChangedFilesForSideAndZoom $srcWatchDir, $dstWatchDir, $side, "Z-1";
        }
        copyChangedFilesForSideAndZoom $srcWatchDir, $dstWatchDir, $side, "Z0";
        copyChangedFilesForSideAndZoom $srcWatchDir, $dstWatchDir, $side, "Z1";
        if ($dstWatchDir =~ /archiveHD/) {
            copyChangedFilesForSideAndZoom $srcWatchDir, $dstWatchDir, $side, "Z2";
        }
    }
}

sub copyChangedAtlasesAndDataForWatch {
    my $srcWatchDir = shift;  # e.g., <something>/archive/Terra
    my $dstWatchDir = shift;  # e.g., <something>/archiveHD/Terra
    if (! -d $dstWatchDir) {
        warn "mkdir $dstWatchDir\n";
        mkdir $dstWatchDir, 0777
          or die "Couldn't create $dstWatchDir: $!\n";
    }
    if ($android) {
        foreach my $width (@androidWidths) {
            copyChangedFile $srcWatchDir, $dstWatchDir, "archive-W$width.dat";
        }
    } else {
        copyChangedFile $srcWatchDir, $dstWatchDir, "archive.dat";
    }
    copyChangedFile $srcWatchDir, $dstWatchDir, "variable-names.txt";
    copyChangedFilesForSide $srcWatchDir, $dstWatchDir, "front";
    if (!$android) {
        copyChangedFilesForSide $srcWatchDir, $dstWatchDir, "back";
    }
    copyChangedFilesForSide $srcWatchDir, $dstWatchDir, "night";
}

sub copyChangedAtlasesAndDataForRoot {
    my $srcRoot = shift;  # e.g., <something>/archive
    my $dstRoot = shift;  # e.g., <something>/archiveHD
    -d $srcRoot
      or die "No source directory $srcRoot\n";
    -d $dstRoot
      or die "No dest directory $dstRoot\n";
    opendir DIR, $srcRoot
      or die "Couldn't open directory $srcRoot: $!\n";
    my @srcs = grep !/^\./, readdir DIR;
    closedir DIR;

    foreach my $src (@srcs) {
        # These should all be watches.
        copyChangedAtlasesAndDataForWatch "$srcRoot/$src", "$dstRoot/$src";
    }
}

# Ensure we are running in a chronometer sandbox
-e "Classes" and -e "Watches" and -e "archive" and -e "archiveHD"
  or die "Run from the top level of a 'chronometer' sandbox.\n";

# First, set up links to most recent simulator apps.
my $cmd = "scripts/recordInstalls.pl -s";
warn "$cmd\n";
system($cmd);

my $sims = "./sims";

# Now go find the archives, check the age.
if ($android) {
    my $cwhArchive = "$sims/app/com.emeraldsequoia.HenryForAndroid/latest/Documents/archive";
    my $ageInMinutesCWH = ageInMinutesOfOldestFileInTree $cwhArchive, "HenryForAndroid";

    if ($ageInMinutesCWH > $ageThresholdInMinutes) {
        warn "You must run this script within $ageThresholdInMinutes minutes of running HenryForAndroid, after first clearing the archives with clearArchives.pl -android\n";
        die "\n" if not $force;
        warn "\n";
        warn "\n";
        warn "--------------------------------------------------------------------\n";
        warn "OVERRIDING RECENCY CHECK -- DO NOT USE FOR FINAL RUN BEFORE SHIPPING\n";
        warn "--------------------------------------------------------------------\n";
        warn "\n";
        warn "\n";
    }

    foreach my $face (@androidFaces) {
        warn "... face $face\n";
        my $dst = "android/project/assets";
        copyChangedAtlasesAndDataForWatch "$cwhArchive/$face", "$dst/$face";
    }
} else {
    my $cwhHDArchive = "$sims/app/com.emeraldsequoia.ChronoWithHHD/latest/Documents/archive";
    my $ageInMinutesCWHHD = ageInMinutesOfOldestFileInTree $cwhHDArchive, "CwHHD";

    if ($ageInMinutesCWHHD > $ageThresholdInMinutes) {
        die "You must run this script within $ageThresholdInMinutes minutes of running *both* CwH and CwHHD, after first clearing the archives with clearArchives.pl\n";
    }

    copyChangedAtlasesAndDataForRoot $cwhHDArchive, "./archiveHD";
}
