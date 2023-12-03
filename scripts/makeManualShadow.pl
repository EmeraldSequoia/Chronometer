#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Copy qw/cp/;

my $inputFile = shift;
my $outputFile = shift;
my $opacity = shift;
my $sigma = shift;

defined $inputFile and defined $outputFile and defined $opacity and defined $sigma
  or die "Usage: $0 <inputFile> <outputFile> <opacity> <sigma>\n";

$0 =~ m%^(.*/?)scripts/makeManualShadow\.pl$%
  or die "Must run script with full pathname\n";
my $sandboxRoot = $1;
$sandboxRoot =~ s%/$%%o;
if ($sandboxRoot eq "") {
    $sandboxRoot = ".";
}

chdir $sandboxRoot
  or die "Couldn't cd to $sandboxRoot: $!\n";
#chomp(my $pd = `pwd`);
#warn "cd $pd\n";

$sandboxRoot =~ s/\./\\./go;

$inputFile =~ s%$sandboxRoot/%%;
$outputFile =~ s%$sandboxRoot/%%;

-e "tools"
  or die "Must run out of sandbox scripts directory\n";

my $imageMagick = "tools/ImageMagick-6.4.1";
my $imageMagickBin = "$imageMagick/bin";

#print "DYLD before: '$ENV{DYLD_LIBRARY_PATH}'\n";

$ENV{MAGICK_HOME} = $imageMagick;
if (defined $ENV{DYLD_LIBRARY_PATH}) {
    $ENV{DYLD_LIBRARY_PATH} = "$imageMagick/lib:$ENV{DYLD_LIBRARY_PATH}";
} else {
    $ENV{DYLD_LIBRARY_PATH} = "$imageMagick/lib";
}
$ENV{PATH} = "$imageMagick/bin:$ENV{PATH}";
delete $ENV{DYLD_ROOT_PATH};

#print "DYLD after: '$ENV{DYLD_LIBRARY_PATH}'\n";

#print "Environment:\n";
#while (my ($key, $value) = (each %ENV)) {
#    printf "%20s => %20s\n", $key, $value;
#}

-e "$imageMagickBin/convert"
  or die "Can't run without ImageMagick\n";

my $cmd = "\"$imageMagickBin/convert\" \"$inputFile\" -background black -shadow $opacity" . "x$sigma \"$outputFile\"";
#warn "$cmd\n";
system($cmd);
$cmd = "open -a 'Adobe Photoshop CS3' \"$outputFile\"";
system($cmd);

