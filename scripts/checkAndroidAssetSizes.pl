#!/usr/bin/perl -w

use strict;

# Ensure we are running in a chronometer sandbox
-e "Classes" and -e "Watches" and -e "archive" and -e "archiveHD"
  or die "Run from the top level of a 'chronometer' sandbox.\n";

chdir "android/project/assets"
  or die "Couldn't cd to Android EC assets directory\n";

my $cmd = "imgsize.pl */*-W480.png */*-W400.png";
warn "$cmd\n";

open PIPE, "$cmd |"
  or die;

my @data;

while (<PIPE>) {
    if (/(\d+)\s+(\d+)\s+(.*)$/) {
        my $width = $1;
        my $height = $2;
        my $file = $3;
        my $area = $width * $height;
        push @data, [$area, $width, $height, $file];
    }
}

close PIPE;

@data = sort {
    my $ans = $$a[0] <=> $$b[0];
    $ans;
} @data;

foreach my $data (@data) {
    my ($area, $width, $height, $file) = @$data;
    printf "%7d %4d %4d %s\n", $area, $width, $height, $file;
}
