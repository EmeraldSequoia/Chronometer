package AndroidHelpImages;

use strict;

require Exporter;

use Carp;

use File::Basename;
use File::Copy qw/cp/;

our @ISA = qw(Exporter);
our @EXPORT = qw(joinImagesHorizontally getAllFaceNames getAllUserFaceNames resizeImage constructAllAppsImage constructPromoImage doCmd fileFromName dirFromFilename moveIfDifferentElseDeleteSrc openImg doImageMagickCommand);
our @EXPORT_OK = qw();
our @VERSION = 1.00;

my $imageMagickBin = "tools/ImageMagick-6.4.1/bin";
my $screencapSource = "android/screencaps/480/round";

srand(42);

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    (system $cmd) == 0
      or die "Trouble with command (see above)\n";
}

sub doImageMagickCommand {
    my $cmd = shift;
    doCmd "tools/ImageMagick-6.4.1/bin/$cmd";
}

sub fileFromName {
    my $name = shift;
    my $filename = lc $name;
    if ($filename !~ / i+$/) {
        $filename .= "_i";
    }
    $filename =~ s/ /_/go;
    return $filename;
}

sub dirFromFilename {
    my $filename = shift;
    my $name = $filename;
    $name =~ s/_i+$//o
      or die "Filename not in expected format: '$filename'\n";
    $name =~ s/selene/chandra/;
    $name =~ s/padua/firenze/;
    $name =~ s/basel/geneva/;
    $name =~ s/hana/haleakala/;
    $name =~ s/mauna_loa/mauna_kea/;
    $name =~ s/venezia/miami/;
    $name =~ s/gaia/terra/;
    return $name;
}

sub moveIfDifferentElseDeleteSrc {
    my $srcImage = shift;
    my $dstImage = shift;
    my $cmd = "$imageMagickBin/compare -metric rmse '$srcImage' '$dstImage' null: 2>&1";
    warn "$cmd\n";
    chomp(my $cmdResult = `$cmd`);
    print "cmdResult is $cmdResult\n";
    if ($cmdResult eq "0 (0)") {
        warn "Images are identical, skipping move and removing src\n";
        unlink $srcImage
          or die "Couldn't remove '$srcImage': $!\n";
        return 0;
    } else {
        warn "mv '$srcImage' '$dstImage'\n";
        rename $srcImage, $dstImage
          or die "Couldn't rename '$srcImage' to '$dstImage': $!\n";
    }
    return 1;
}

sub openImg {
    my $filename = shift;
    doCmd "open '$filename'";
}

sub joinImagesHorizontally {
    my $leftImg = shift;
    my $rightImg = shift;
    my $outputImg = shift;
    my $borderPixels = shift;

    # There's probably a simpler way to do this in ImageMagick but 'montage' wants to either create equal-sized cells or
    # cells exactly the size of the images, and convert --append doesn't seem to have any spacing options.
    # So instead we first create an empty image, then stick it in the middle.
    my $tmpBlankImage = "/tmp/blankImage.png";
    doImageMagickCommand "convert -size '$borderPixels" . "x1<' xc:transparent $tmpBlankImage";
    doImageMagickCommand "convert \"$leftImg\" $tmpBlankImage \"$rightImg\" -background transparent +append \"$outputImg\"";
}

sub constructAllAppsImage {
    my $srcImageRef = shift;
    my $dstImage = shift;
    my $dstImageWidth = shift;
    my $dstImageHeight = shift;
    my @srcImages = @{$srcImageRef};

    (0+@srcImages == 44)
      or die "unexpected number of images\n";

    # We make 3 rows 7x2, 8x2, 7x2
    my $scaledImageSize = 400;
    my $ambientOffsetX = 50;
    my $ambientOffsetY = 300;
    my $usedWidthA = ($scaledImageSize + $ambientOffsetX) * 7;
    my $usedWidthB = ($scaledImageSize + $ambientOffsetX) * 8;
    my $xPaddingA = ($dstImageWidth - $usedWidthA) / 8;
    my $xPaddingB = ($dstImageWidth - $usedWidthB) / 9;
    my $usedHeight = ($scaledImageSize + $ambientOffsetY) * 3;
    my $yPadding = ($dstImageHeight - $usedHeight) / 4;

    my $tmpDir = "/tmp/all_apps_image";
    if (! -d $tmpDir) {
        mkdir $tmpDir
          or die;
    }

    my $compositeImage = "$tmpDir/composite.png";
    unlink $compositeImage;

    doImageMagickCommand "convert -size $dstImageWidth" . "x$dstImageHeight xc:none $compositeImage";

    my $row = 0;
    my $column = 0;
    my $item = 0;
    foreach my $srcImage (@srcImages) {
        my $isAmbient = ($item % 2) != 0;
        warn "$srcImage\n";
        my $scaledSrcImage = fileparse $srcImage;
        $scaledSrcImage = "$tmpDir/$scaledSrcImage";
        resizeImage($srcImage, $scaledSrcImage, $scaledImageSize, $scaledImageSize);

        my $compositeImageNew = "$tmpDir/composite-new.png";
        my $offsetX = ($column + 1) * ($row == 1 ? $xPaddingB : $xPaddingA) + $column * ($scaledImageSize + $ambientOffsetX);
        if ($isAmbient) {
            $offsetX += $ambientOffsetX;
        }
        my $offsetY = ($row + 1) * $yPadding + $row * ($scaledImageSize + $ambientOffsetY);
        if ($isAmbient) {
            $offsetY += $ambientOffsetY;
        }
        doImageMagickCommand "composite -compose dst_over '$scaledSrcImage' -geometry +$offsetX+$offsetY '$compositeImage' '$compositeImageNew'";
        rename $compositeImageNew, $compositeImage
          or die "Couldn't rename";

        if ($isAmbient) {
            $column++;
            if (($row == 1 && $column == 8) || ($row != 1 && $column == 7)) {
                $row++;
                $column = 0;
            }
        }
        $item++;
    }

    doCmd "open $tmpDir";
}

sub placeAtRowColumn {
    my $srcImage = shift;
    my $row = shift;
    my $column = shift;
    my $dstImageWidth = shift;
    my $dstImageHeight = shift;
    my $compositeImage = shift;
    my $tmpDir = shift;

    my $itemsInRow = ($row == 1 ? 16 : 14);
    my $compositeImageNew = "$tmpDir/composite-new.png";
    my $offsetX = $column * ($dstImageWidth / ($itemsInRow - 0.5));
    my $offsetY = (rand(1) - 0.5 + $row) * ($dstImageHeight / 2.5);
    doImageMagickCommand "composite -compose dst_over '$srcImage' -geometry +$offsetX+$offsetY '$compositeImage' '$compositeImageNew'";
    rename $compositeImageNew, $compositeImage
      or die "Couldn't rename";
}

sub constructPromoImage {
    my $srcImageRef = shift;
    my $dstImage = shift;
    my $dstImageWidth = shift;
    my $dstImageHeight = shift;
    my @srcImages = @{$srcImageRef};

    (0+@srcImages == 44)
      or die sprintf "unexpected number of images (%d)\n", (0+@srcImages);

    # We make 3 rows 7,8,7 (14, 16, 14)
    my $scaledImageSize = 240;

    my $tmpDir = "/tmp/all_apps_image";
    if (! -d $tmpDir) {
        mkdir $tmpDir
          or die;
    }

    my $compositeImage = "$tmpDir/composite.png";
    unlink $compositeImage;

    my $canvasImageWidth = $dstImageWidth + $scaledImageSize/2;
    my $canvasImageHeight = $dstImageHeight + $scaledImageSize/2;

    doImageMagickCommand "convert -size $canvasImageWidth" . "x$canvasImageHeight xc:none $compositeImage";

    my $row = 0;
    my $column = 0;
    foreach my $srcImage (@srcImages) {
        warn "$srcImage\n";

        placeAtRowColumn $srcImage, $row, $column, $dstImageWidth, $dstImageHeight, $compositeImage, $tmpDir;

        $row++;
        if ($row == 3) {
            $column++;
            $row = 0;
        }
        if ($column > 14 && $row != 1) {
            $row++;
        }
    }

    doCmd "open $tmpDir";
}

sub getAllFaceNames {
    opendir DIR, $screencapSource
      or die "Couldn't read $screencapSource: $!\n";
    my @entries = grep /\.png$/, readdir DIR;
    closedir DIR;

    my %faces;
    foreach my $entry (sort @entries) {
        next if $entry =~ /^Status I/;
        $entry =~ /^([^-]+)-/
          or die "Unrecognized file $entry in $screencapSource: '$entry'\n";
        $faces{$1} = 1;
    }
    return sort keys %faces;
}

sub getAllUserFaceNames {
    my %faces;
    foreach my $entry (getAllFaceNames) {
        my $root = $entry;
        $root =~ s/ I+//
          or die "Unexpected file $entry in $screencapSource: '$entry'\n";
        if (defined $faces{$root}) {
            $faces{$root}++;
        } else {
            $faces{$root} = 1;
        }
    }
    my @faces;
    while (my ($root, $count) = each %faces) {
        my $suffix = " ";
        $root =~ s/Haleakala/Haleakal\&#257/o;
        if ($count == 1) {
            push @faces, $root;
        } else {
            for (my $i = 0; $i < $count; $i++) {
                $suffix .= "I";
                push @faces, $root . $suffix;
            }
        }
    }
    return sort @faces;
}

sub resizeImage {
    my $src = shift;
    my $dst = shift;
    my $maxWidth = shift;
    my $maxHeight = shift;

    doCmd "sips --resampleHeightWidthMax $maxWidth" . "x$maxHeight \"$src\" --out \"$dst\"";
}

1;
