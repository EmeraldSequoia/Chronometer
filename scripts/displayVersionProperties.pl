#!/usr/bin/perl -w

use strict;

use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $file1 = "android/project/Chronometer/version.properties";
my $file2 = "android/project/ChronometerPro/version.properties";

sub getVersionForFile {
    my $file = shift;
    if (!open FILE, $file) {
        return "???";
    }
    while (<FILE>) {
        if (/^VERSION_BUILD=(\d+)$/) {
            return $1;
        }
    }
    close FILE;
    return "---";
}

# warn "$file1: " . (getVersionForFile $file1) . "\n";
# warn "$file2: " . (getVersionForFile $file2) . "\n";

my $lastModAge1 = 0;
my $lastModAge2 = 0;

my $lastMod1 = 0;
my $lastMod2 = 0;

my $version1 = "xxx";
my $version2 = "xxx";

sub lastModOf_ {
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime)
      = stat(_);
    return $mtime;
}

sub refreshData {
    my $anyChange = 0;
    if ((-M $file1) != $lastModAge1) {
        $version1 = getVersionForFile $file1;
        $lastModAge1 = -M _;
        $lastMod1 = lastModOf_;
        $anyChange = 1;
    }
    if ((-M $file2) != $lastModAge2) {
        $version2 = getVersionForFile $file2;
        $lastModAge2 = -M _;
        $lastMod2 = lastModOf_;
        $anyChange = 1;
    }
    return $anyChange;
}

while (1) {
    if (refreshData()) {
        my ($mod1s, $mod1m, $mod1h) = localtime $lastMod1;
        my ($mod2s, $mod2m, $mod2h) = localtime $lastMod2;
        printf "\rEC: $version1 (%02d:%02d:%02d), ECPro: $version2 (%02d:%02d:%02d)",
          $mod1h, $mod1m, $mod1s, $mod2h, $mod2m, $mod2s;

    }
    sleep 1;
}
