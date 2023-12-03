#!/usr/bin/perl -w

use strict;

# This script will output a path (separated by ':') which contains the jar files in .android/build-cache/
# This is useful to find class files when generating JNI .h files for classes.
# Note that they are output in reverse chronological order so the most recent jar found which defines
# a class will be used.

#my $cmd = "ls -t ~/.android/build-cache/*/output/jars/classes.jar";
my $cmd = "ls -t build/intermediates/intermediate-jars/*/classes.jar";
open PIPE, "$cmd |"
  or die $!;

my @jars;
while (<PIPE>) {
    chomp;
    push @jars, $_;
}
close PIPE;

print join ":", @jars;
