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
my $destRoot = "$workspaceRoot/website/m1/aw";
my $resourceRoot = "$workspaceRoot/apps/chronometer/m1/android/project/ChronometerPro/src/main/res/drawable-hdpi";

sub createOne {
    my $name = shift;
    my $filename = fileFromName $name;
    my $dir = dirFromFilename $filename;
    my $dirPath = "$destRoot/$dir";
    if (! -d $dirPath) {
        mkdir $dirPath, 0777
          or die "Couldn't create directory '$dirPath': $!\n";
    }

    # Copy in banner image with composite of interactive and ambient modes
    my $srcImgRoot = "android/screencaps/480/round/$name";
    if ($srcImgRoot !~ / I+$/) {
        $srcImgRoot .= " I";
    }
    my $src1 = $srcImgRoot . "-interactive.png";
    my $src2 = $srcImgRoot . "-ambient.png";
    my $dst = "$dirPath/$filename-banner.png";
    my $dstTmp = "$dirPath/$filename-banner-tmp.png";
    joinImagesHorizontally $src1, $src2, $dstTmp, 50;
    moveIfDifferentElseDeleteSrc $dstTmp, $dst;

    # Now an icon for each watch, for inclusion in tables
    my $dst1 = "$dirPath/$filename-icon.png";
    my $dst1Tmp = "$dirPath/$filename-icon-tmp.png";
    resizeImage $src1, $dst1Tmp, 50, 50;
    moveIfDifferentElseDeleteSrc $dst1Tmp, $dst1;
    my $dst2 = "$dirPath/$filename-icon-ambient.png";
    my $dst2Tmp = "$dirPath/$filename-icon-ambient-tmp.png";
    resizeImage $src2, $dst2Tmp, 50, 50;
    moveIfDifferentElseDeleteSrc $dst2Tmp, $dst2;

    # Now construct the banner image for the purchase activity.
    # First construct smaller images, then composite them together.
    my $tmp1 = "/tmp/purchase-image-interactive.png";
    my $tmp2 = "/tmp/purchase-image-ambient.png";

    resizeImage $src1, $tmp1, 200, 200;
    resizeImage $src2, $tmp2, 200, 200;
    $dst = "$resourceRoot/${filename}_smbanner.png";
    $dstTmp = "$resourceRoot/${filename}_smbanner-tmp.png";
    joinImagesHorizontally $tmp1, $tmp2, $dstTmp, 10;
    moveIfDifferentElseDeleteSrc $dstTmp, $dst;
}

my @faceNames = getAllFaceNames;

foreach my $faceName (@faceNames) {
    warn "$faceName\n";
    createOne $faceName;
}
