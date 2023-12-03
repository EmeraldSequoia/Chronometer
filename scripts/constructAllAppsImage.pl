#!/usr/bin/perl -w

use strict;

use Cwd;
use File::Copy 'cp';

use FindBin;
use lib $FindBin::Bin;

use AndroidHelpImages;

my $dstImage = "android/screencaps/all_watches.png";
my $dstImageWidth = 4096;
my $dstImageHeight = 2304;

my @srcImages;

# my @faceNames = getAllFaceNames;

# foreach my $name (@faceNames) {
#     my $filename = fileFromName $name;

#     # Copy in banner image with composite of interactive and ambient modes
#     my $srcImgRoot = "android/screencaps/480/round/$name";
#     if ($srcImgRoot !~ / I+$/) {
#         $srcImgRoot .= " I";
#     }
#     push @srcImages, $srcImgRoot . "-interactive.png";
#     push @srcImages, $srcImgRoot . "-ambient.png";
# }

### ROW 1

push @srcImages, "android/screencaps/480/round/Alexandria I-interactive.png";
push @srcImages, "android/screencaps/480/round/Alexandria I-ambient.png";

push @srcImages, "android/screencaps/480/round/Atlantis I-interactive.png";
push @srcImages, "android/screencaps/480/round/Atlantis I-ambient.png";

push @srcImages, "android/screencaps/480/round/Basel I-interactive.png";
push @srcImages, "android/screencaps/480/round/Basel I-ambient.png";

push @srcImages, "android/screencaps/480/round/Chandra I-interactive.png";
push @srcImages, "android/screencaps/480/round/Chandra I-ambient.png";

push @srcImages, "android/screencaps/480/round/Firenze I-interactive.png";
push @srcImages, "android/screencaps/480/round/Firenze I-ambient.png";

push @srcImages, "android/screencaps/480/round/Gaia I-interactive.png";
push @srcImages, "android/screencaps/480/round/Gaia I-ambient.png";

push @srcImages, "android/screencaps/480/round/Mauna Loa I-interactive.png";
push @srcImages, "android/screencaps/480/round/Mauna Loa I-ambient.png";

### ROW 2

### First column is covered by left sidebar

push @srcImages, "android/screencaps/480/round/Vienna I-interactive.png";
push @srcImages, "android/screencaps/480/round/Vienna I-ambient.png";

push @srcImages, "android/screencaps/480/round/Terra I-interactive.png";
push @srcImages, "android/screencaps/480/round/Terra I-ambient.png";

push @srcImages, "android/screencaps/480/round/Venezia I-interactive.png";
push @srcImages, "android/screencaps/480/round/Venezia I-ambient.png";

push @srcImages, "android/screencaps/480/round/Geneva I-interactive.png";
push @srcImages, "android/screencaps/480/round/Geneva I-ambient.png";

push @srcImages, "android/screencaps/480/round/Haleakala I-interactive.png";
push @srcImages, "android/screencaps/480/round/Haleakala I-ambient.png";

push @srcImages, "android/screencaps/480/round/Mauna Kea I-interactive.png";
push @srcImages, "android/screencaps/480/round/Mauna Kea I-ambient.png";

push @srcImages, "android/screencaps/480/round/McAlester I-interactive.png";
push @srcImages, "android/screencaps/480/round/McAlester I-ambient.png";

push @srcImages, "android/screencaps/480/round/Miami I-interactive.png";
push @srcImages, "android/screencaps/480/round/Miami I-ambient.png";

### ROW 3

push @srcImages, "android/screencaps/480/round/Hana I-interactive.png";
push @srcImages, "android/screencaps/480/round/Hana I-ambient.png";

push @srcImages, "android/screencaps/480/round/Milano I-interactive.png";
push @srcImages, "android/screencaps/480/round/Milano I-ambient.png";

push @srcImages, "android/screencaps/480/round/Babylon I-interactive.png";
push @srcImages, "android/screencaps/480/round/Babylon I-ambient.png";

push @srcImages, "android/screencaps/480/round/Padua I-interactive.png";
push @srcImages, "android/screencaps/480/round/Padua I-ambient.png";

push @srcImages, "android/screencaps/480/round/Paris I-interactive.png";
push @srcImages, "android/screencaps/480/round/Paris I-ambient.png";

push @srcImages, "android/screencaps/480/round/Selene I-interactive.png";
push @srcImages, "android/screencaps/480/round/Selene I-ambient.png";

push @srcImages, "android/screencaps/480/round/Status I-interactive.png";
push @srcImages, "android/screencaps/480/round/Status I-ambient.png";

constructAllAppsImage \@srcImages, $dstImage, $dstImageWidth, $dstImageHeight;
