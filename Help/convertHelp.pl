#!/usr/bin/perl -w

use strict;

if ((scalar @ARGV) < 0) {
    die "Usage:  $0  <file> ...\n";
}

foreach my $file (@ARGV) {
    ((defined $file) && (-e $file))
      or die "Usage:  $0  <file>\n";

    my $newFile = "$file.new";

    if ($newFile) {
        unlink $newFile;
    }

    my $foundOne = 0;

    open F, $file
      or die "Couldn't read file $file: $!\n";
    open N, ">$newFile"
      or die "Couldn't create file $newFile: $!\n";

    while (<F>) {
        if (s/(meta.*viewport.*width=)320/$1device-width/o) {
            $foundOne = 1;
        }
        print N $_;
    }

    close N;
    close F;

    if ($foundOne) {
        unlink $file;
        rename $newFile, $file
          or die "Couldn't rename $newFile to $file: $!\n";
        print "Converted $file\n";
    } else {
        unlink $newFile
          or die "Couldn't remove unneeded $newFile: $!\n";
    }
}

