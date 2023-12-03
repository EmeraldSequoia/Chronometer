#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::Bin;

use File::Path qw(make_path remove_tree);

# Nonstandard Perl modules:
use Image::ExifTool;

# Local modules
use AndroidDeviceSelector;

my $imageMagickBin = "tools/ImageMagick-6.4.1/bin";

my $appName = "com.emeraldsequoia.chronometer.screens";

my $requestFile = "files/CaptureRequest.txt";
my $responseFile = "files/CaptureResponse.txt";

my $tempDirectory = "/tmp/ScreenCaptureWatcher/";
my $captureDirectory = "android/screencaps";
my $squareDirectory = "square/";
my $roundDirectory = "round/";

my $exifTool = new Image::ExifTool;

sub imgSize {
    my $file = shift;
    my $exifInfo = $exifTool->ImageInfo($file);
    die "No EXIF info in '$file'\n" if not defined $exifInfo->{ImageSize};
    return split /x/, $exifInfo->{ImageSize};
}

remove_tree($tempDirectory);
make_path($tempDirectory);

my ($device, $humanName) = getDeviceId;

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    system($cmd);
}

sub remoteFileContents {
    my $filename = shift;
    my $cmd = "adb -s $device shell \"run-as $appName cat $filename\"";
    warn "$cmd\n";
    open PIPE, "$cmd |"
      or die "Couldn't read request file\n";
    chomp(my $line = <PIPE>);
    close PIPE;
    return $line;
}

# Returns the name of a screen capture file to create, or waits indefinitely
sub waitForAndReturnRequest {
    warn "\nWaiting for screen capture request from $humanName ($device)...\n";
    while (1) {
        my $cmd = "adb -s $device shell \"run-as $appName ls $requestFile\"";
        # warn "$cmd\n";
        open PIPE, "$cmd 2>/dev/null |"
          or die "Couldn't open pipe to test file existence\n";
        my @lines = <PIPE>;
        close PIPE;
        if (@lines) {
            chomp($lines[0]);
            if ($lines[0] ne $requestFile) {
                die "Odd: ls command didn't return file we were listing\n";
            }
            return remoteFileContents($requestFile);
        }
        sleep 2;
    }
}

sub moveIfDifferent {
    my $srcImage = shift;
    my $dstImage = shift;
    my $cmd = "$imageMagickBin/compare -metric rmse '$srcImage' '$dstImage' null: 2>&1";
    warn "$cmd\n";
    chomp(my $cmdResult = `$cmd`);
    print "cmdResult is $cmdResult\n";
    if ($cmdResult eq "0 (0)") {
        warn "Images are identical, skipping move\n";
        return 0;
    } else {
        warn "mv '$srcImage' '$dstImage'\n";
        rename $srcImage, $dstImage
          or die "Couldn't rename '$srcImage' to '$dstImage': $!\n";
    }
    return 1;
}

sub generateScreenCaptureAndStore {
    my $localFile = shift;
    my $tempPath = $tempDirectory . $localFile;
    warn "Generating screen capture into '$tempPath'\n";
    doCmd "adb -s $device shell screencap -p /sdcard/screen.png";
    doCmd "adb -s $device pull /sdcard/screen.png '$tempPath'";
    doCmd "adb -s $device shell rm /sdcard/screen.png";

    my ($width, $height) = imgSize($tempPath);
    warn "Captured screen was $width x $height\n";
    $width == 480 && $height == 480
      or die "Did not get expecteed size of 480x480\n";
    my $squareWidthDirectory = "$captureDirectory/$width/$squareDirectory";
    make_path($squareWidthDirectory);
    my $squarePath = $squareWidthDirectory . $localFile;
    if (moveIfDifferent $tempPath, $squarePath) {
        warn "Image was different, converting to round\n";
        my $size = $width . "x" . $height;
        my $halfWidth = $width / 2;
        my $halfWidthTweak = ($width - 1) / 2;
        my $center = "$halfWidthTweak,$halfWidthTweak";
        my $roundWidthDirectory = "$captureDirectory/$width/$roundDirectory";
        make_path($roundWidthDirectory);
        my $roundPath = $roundWidthDirectory . $localFile;
        doCmd "$imageMagickBin/convert -size $size xc:none -fill '$squarePath' -draw \"circle $center $halfWidth,0\" '$roundPath'";
        # doCmd "open '$roundPath'";
    }
}

sub removeRequestAndWriteResponse {
    doCmd "adb -s $device shell \"run-as $appName rm $requestFile\"";
    doCmd "adb -s $device shell \"run-as $appName touch $responseFile\"";
}

while (1) {
    my $captureFile = waitForAndReturnRequest;
    generateScreenCaptureAndStore $captureFile;
    removeRequestAndWriteResponse;
}
