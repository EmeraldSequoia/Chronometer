#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::Bin;

use AndroidDeviceSelector;

my $appName = "com.emeraldsequoia.chronometer.chronometer";

my $root = 0;

foreach my $arg (@ARGV) {
    if ($arg eq "-root") {
        $root = 1;
    }
}

my ($device, $humanName) = getDeviceId;

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    system($cmd);
}

if ($root) {
    doCmd "adb -s $device shell";
} else {
    doCmd "adb -s $device shell -t \"run-as $appName sh\"";
}
