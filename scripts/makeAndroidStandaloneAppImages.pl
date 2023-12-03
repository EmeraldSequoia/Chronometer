#!/usr/bin/perl -w

use strict;

use Cwd;
use File::Copy 'cp';

use FindBin;
use lib $FindBin::Bin;

use AndroidHelpImages;

# Set up to use es/scripts
BEGIN {
    use File::Basename;
    my ($name, $path) = fileparse $0;
    $path =~ s%/$%%o;
    unshift @INC, "$path/../../../../scripts";
}
use esgit;

my $imageMagickBin = "tools/ImageMagick-6.4.1/bin";
my $workspaceRoot = findWorkspaceRoot;


my $destRoot = "android/screencaps/store-banner-app-images";
my $srcRoot = "android/screencaps/480";

my $bgFile = "$workspaceRoot/images/android/Feature-graphic-bg.png";

my $tmpDir = "/tmp/individual_scaled_image";
if (! -d $tmpDir) {
    mkdir $tmpDir
      or die;
}

sub scaleAndPlaceImage {
    my $srcImage = shift;
    my $rightNotLeft = shift;
    my $compositeImage = shift;
    my $compositeImageNew = shift;
    warn "$srcImage\n";
    my $scaledImageSize = 400;
    my $spacing = (1024 - (2 * $scaledImageSize)) / 3;
    my $offsetX = $spacing;
    if ($rightNotLeft) {
        $offsetX = 1024 - $spacing - $scaledImageSize;
    }
    my $offsetY = (500 - $scaledImageSize) / 2;

    print "Placing at $offsetX, $offsetY\n";

    my $scaledSrcImage = fileparse $srcImage;
    $scaledSrcImage = "$tmpDir/$scaledSrcImage";

    resizeImage($srcImage, $scaledSrcImage, $scaledImageSize, $scaledImageSize);

    doImageMagickCommand("composite -compose src_over '$scaledSrcImage' -geometry +$offsetX+$offsetY '$compositeImage' '$compositeImageNew'");
    rename $compositeImageNew, $compositeImage
      or die "Couldn't rename";
}

sub createOne {
    my $name = shift;
    my $srcImgRoot = "android/screencaps/480/round/$name";
    if ($srcImgRoot !~ / I+$/) {
        $srcImgRoot .= " I";
    }
    my $src1 = $srcImgRoot . "-interactive.png";
    my $src2 = $srcImgRoot . "-ambient.png";
    my $dst = "$destRoot/$name.png";
    my $dstNew = "$destRoot/$name-new.png";
    my $dstTmp = "$destRoot/$name-tmp.png";
    unlink $dstTmp;

    # Place background.
    cp $bgFile, $dstNew
      or die "Couldn't copy '$bgFile' to '$dstNew': $!\n";

    # Place interactive image.
    scaleAndPlaceImage $src1, 0, $dstNew, $dstTmp;
    # Place ambient image.
    scaleAndPlaceImage $src2, 1, $dstNew, $dstTmp;

    # See if it changed.
    moveIfDifferentElseDeleteSrc $dstNew, $dst;
}

my @faceNames = getAllFaceNames;

foreach my $faceName (@faceNames) {
    warn "$faceName\n";
    createOne $faceName;
}
