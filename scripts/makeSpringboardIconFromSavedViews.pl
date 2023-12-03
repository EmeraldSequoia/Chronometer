#!/usr/bin/perl -w

use strict;

use File::Basename;

-e "Parser"
  or die "Run this at the top-level Harrison directory\n";

my $imageMagick = "/usr/local/ImageMagick";
my $imageMagickBin = "$imageMagick/bin";

$ENV{MAGICK_HOME} = $imageMagick;
$ENV{DYLD_LIBRARY_PATH} = "$imageMagick/lib";

-e "$imageMagickBin/convert"
  or die "Can't run without ImageMagick\n";

# 57x57

sub makeIconForImage {
    my $captureImage = shift;
    my $iconImage = fileparse $captureImage;
    $iconImage =~ s%^(.+)-saved-%Watches/Builtin/$1/$1-icon-%o
	or die "captureImage not in expected format: $captureImage\n";
    my $watch = $1;
#    my $cmd = "sips -c 310 310 \"$captureImage\" --out \"$iconImage\"";
    my $cmd = "$imageMagickBin/convert \"$captureImage\" -crop 310x310+5+65 \"$iconImage\"";
    warn "$cmd\n";
    system($cmd);
    $cmd = "sips -z 57 57 \"$iconImage\"";
    warn "$cmd\n";
    system($cmd);
}

system("scripts/recordLastInstall.pl");

-e "install"
    or die "No application installed in the simulator\n";

my $installWatchDir = "install/Chronometer.app/Watches";
opendir DIR, $installWatchDir
    or die "Couldn't read directory $installWatchDir: $!\n";
my @entries = grep !/^\./, readdir DIR;
closedir DIR;

foreach my $entry (@entries) {
    next if $entry eq "partsBin";
    my $watchImagePrefix = "$installWatchDir/$entry/$entry-saved";
    -e $watchImagePrefix . "-f.png"
	or die "Missing frontside image capture at $watchImagePrefix-f.png.\nRe-run info\n";
    -e $watchImagePrefix . "-b.png"
	or die "Missing backside image capture at $watchImagePrefix.-b.png.\nRe-run info\n";
    -e $watchImagePrefix . "-n.png"
	or die "Missing frontside image capture at $watchImagePrefix-n.png.\nRe-run info\n";
}

# OK, we have them all, now let's get to it.
foreach my $entry (@entries) {
    next if $entry eq "partsBin";
    my $watchImagePrefix = "$installWatchDir/$entry/$entry-saved";
    makeIconForImage $watchImagePrefix . "-f.png";
    makeIconForImage $watchImagePrefix . "-b.png";
    makeIconForImage $watchImagePrefix . "-n.png";
}
