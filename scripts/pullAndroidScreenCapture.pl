#!/usr/bin/perl -w

use strict;

# Nonstandard Perl modules:
use Image::ExifTool;

# Local Perl modules
use FindBin;
use lib $FindBin::Bin;

my $appName = "com.emeraldsequoia.chronometer.chronometer";

my $imageMagickBin = "tools/ImageMagick-6.4.1/bin";

my $exifTool = new Image::ExifTool;

sub imgSize {
    my $file = shift;
    my $exifInfo = $exifTool->ImageInfo($file);
    die "No EXIF info in '$file'\n" if not defined $exifInfo->{ImageSize};
    return split /x/, $exifInfo->{ImageSize};
}

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    system($cmd);
}

my $origFile;
if ((defined $ARGV[0]) && "$ARGV[0]" ne "" && -e "$ARGV[0]") {
    $origFile = $ARGV[0];
} else {
    use AndroidDeviceSelector;

    my ($device, $humanName) = getDeviceId;

    $origFile = "/tmp/AndroidScreenCap.$$.orig.png";
    unlink $origFile;

    doCmd "adb -s $device shell screencap -p /sdcard/screen.png";
    doCmd "adb -s $device pull /sdcard/screen.png $origFile";
    doCmd "adb -s $device shell rm /sdcard/screen.png";
    if (! -e $origFile) {
        die "Command file ($origFile doesn't exist)\n";
    }
}

if (-z $origFile) {
    die "Warning: '$origFile' is empty\n";
}

my $squareFile = "/tmp/AndroidScreenCap.$$.square.png";
my $roundFile = "/tmp/AndroidScreenCap.$$.round.png";
unlink $squareFile;
unlink $roundFile;

my ($width, $height) = imgSize($origFile);
my $size = $width . "x" . $height;
my $halfWidth = $width / 2;
my $halfWidthTweak = ($width - 1) / 2;
my $center = "$halfWidthTweak,$halfWidthTweak";
doCmd "$imageMagickBin/convert -size $size xc:none -fill '$origFile' -draw \"circle $center $halfWidth,0\" '$roundFile'";
doCmd "$imageMagickBin/convert '$roundFile' -background black -extent $size '$squareFile'";

doCmd "open $roundFile $squareFile";
