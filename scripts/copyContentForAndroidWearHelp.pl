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

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    (system $cmd) == 0
      or die "Trouble with command (see above)\n";
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
    return $name;
}

my $workspaceRoot = findWorkspaceRoot;
my $destRoot = "$workspaceRoot/website/m1/aw";

warn "Destination root: $destRoot\n";

sub updateOne {
    my $name = shift;
    my $filename = fileFromName $name;
    my $dir = dirFromFilename $filename;
    my $dirPath = "$destRoot/$dir";
    if (! -d $dirPath) {
        mkdir $dirPath, 0777
          or die "Couldn't create directory '$dirPath': $!\n";
    }

    my $path = "$dirPath/$filename.html";

    warn "\nName: $name\n";
    warn "File: $path\n";

    # Copy previous file, up to the boilerplate header.
    my $newPath = "$path.new";
    open OLD, $path
      or die "Couldn't read existing '$path': $!\n";
    open NEW, ">$newPath"
      or die "Couldn't create new path at '$newPath': $!\n";

    my $foundBoilerplate = 0;
    while (<OLD>) {
        print NEW;
        if (/<!-- Boilerplate code above here -->/) {
            $foundBoilerplate = 1;
            last;
        }
    }
    close OLD;
    if (!$foundBoilerplate) {
        close NEW;
        unlink $newPath;
        die "Didn't find boilerplate in '$path'\n";
    }

    $dir =~ s/_/ /;
    if ($name eq "Chandra II") {
        $dir = "ChandraII";
    }
    my $helpPath = "Help/$dir/$dir.html";
    if (!open HELP, $helpPath) {
        warn "Couldn't open '$helpPath': $!\n";
        unlink $newPath;
        close NEW;
        return;
    }

    # Move forward through HELP to where header info is
    my $foundH1 = 0;
    my $foundCenterEnd = 0;
    while (<HELP>) {
        if (/<h1>/) {
            $foundH1 = 1;
        }
        if ($foundH1 && m%</center>%) {
            $foundCenterEnd = 1;
            last;
        }
    }
    if (!$foundCenterEnd) {
        close NEW;
        unlink $newPath;
        die "Didn't find </center> in '$helpPath'\n";
    }

    while (<HELP>) {
        s/EMERALD_PRODUCT/Emerald Chronometer/go;
        s/GENEVA_WATCH/Emerald Geneva/go;
        print NEW;
    }

    close HELP;

    close NEW;

    rename $newPath, $path
      or die "Couldn't reaname '$newPath' to '$path': $!\n";

    # Now copy other files in the destination directory
    opendir DIR, "Help/$dir"
      or die "Couldn't read directory";
    my @entries = grep !/^\./, readdir DIR;
    closedir DIR;

    foreach my $entry (@entries) {
        next if $entry =~ /\.html$/;
        my $src = "Help/$dir/$entry";
        my $dst = "$dirPath/$entry";
        cp $src, $dst
          or die "Couldn't copy '$src' to '$dst': $!\n";
    }
}

my $faceCount = 0;
foreach my $faceName (getAllUserFaceNames()) {
    print "$faceName\n";
    updateOne $faceName;
    $faceCount++;
}
print "Did $faceCount faces\n";
