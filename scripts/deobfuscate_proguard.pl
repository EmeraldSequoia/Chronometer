#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::Bin;

# Set up to use es/scripts
BEGIN {
    use File::Basename;
    my ($name, $path) = fileparse $0;
    $path =~ s%/$%%o;
    unshift @INC, "$path/../../../../scripts";
}
use esgit;

my $workspaceRoot = findWorkspaceRoot;

my $project = "ChronometerPro";
my $sdkLocation = "$ENV{HOME}/Library/android/sdk";
my $tool = "$sdkLocation/tools/proguard/bin/retrace.sh";

my $mappingFile = "$workspaceRoot/apps/chronometer/m1/android/project/$project/build/outputs/mapping/release/mapping.txt";

my $fileToRead = shift;

my $cmd = "$tool -verbose '$mappingFile' '$fileToRead'";
warn "$cmd\n";
system($cmd);
