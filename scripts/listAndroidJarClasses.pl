#!/usr/bin/perl -w

use strict;

use File::Find;

sub processFile {
    if (/\.class$/) {
        print "$File::Find::name\n";
    } elsif (/\.jar$/) {
        print "$File::Find::name:\n";
        my $cmd = "jar tvf \"$File::Find::name\"";
        system($cmd);
    }
}

find(\&processFile, "$ENV{HOME}/Library/Android/sdk");
find(\&processFile, "$ENV{HOME}/.android/build-cache");
