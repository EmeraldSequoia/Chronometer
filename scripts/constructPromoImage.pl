#!/usr/bin/perl -w

use strict;

use Cwd;
use File::Copy 'cp';

use FindBin;
use lib $FindBin::Bin;

use AndroidHelpImages;

my $dstImage = "android/screencaps/promo_image.png";
my $dstImageWidth = 1024;
my $dstImageHeight = 500;

my @srcImages;

# my @faceNames = getAllFaceNames;

# foreach my $name (@faceNames) {
#     my $filename = fileFromName $name;

#     # Copy in banner image with composite of interactive and ambient modes
#     my $srcImgRoot = "android/screencaps/240-derived/round/$name";
#     if ($srcImgRoot !~ / I+$/) {
#         $srcImgRoot .= " I";
#     }
#     push @srcImages, $srcImgRoot . "-interactive.png";
#     push @srcImages, $srcImgRoot . "-ambient.png";
# }

### ROW 1

push @srcImages, "android/screencaps/240-derived/round/Alexandria I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Alexandria I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Atlantis I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Atlantis I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Basel I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Basel I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Chandra I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Chandra I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Firenze I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Firenze I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Gaia I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Gaia I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Mauna Loa I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Mauna Loa I-ambient.png";

### ROW 2

### First column is covered by left sidebar

push @srcImages, "android/screencaps/240-derived/round/Vienna I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Vienna I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Terra I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Terra I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Venezia I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Venezia I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Geneva I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Geneva I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Haleakala I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Haleakala I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Mauna Kea I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Mauna Kea I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/McAlester I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/McAlester I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Miami I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Miami I-ambient.png";

### ROW 3

push @srcImages, "android/screencaps/240-derived/round/Hana I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Hana I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Milano I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Milano I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Babylon I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Babylon I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Padua I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Padua I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Paris I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Paris I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Selene I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Selene I-ambient.png";

push @srcImages, "android/screencaps/240-derived/round/Status I-interactive.png";
push @srcImages, "android/screencaps/240-derived/round/Status I-ambient.png";

constructPromoImage \@srcImages, $dstImage, $dstImageWidth, $dstImageHeight;
