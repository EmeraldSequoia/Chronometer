#!/usr/bin/perl -w

## This script may be used to *update* all of the "derived" app files from those in EC Pro,
## which can be useful if, say dependency version numbers have changed.
## In particular:
##    build.gradle
##    build.pl
##    proguard-rules.pro
##    src/main/AndroidManifest.xml
##    src/main/assets/* (as links to toplevel assets)
##    src/main/drawable-hdpi/*  (as links to EC Pro)
##    version.properties (only if nonexistent)
## It is safe to run this script if nothing has changed; in that case it will do nothing.
## NOTE:  BaseLib/, ChronometerPro/, and Chronometer/  are unchanged by this script and need
## to be changed manually (ChronometerPro needs to be changed *before* running this script
## since it is the source for all of the other files).  SCREENS, however, *is* changed by
## the script.

use strict;

# Standard Perl libraries
use File::Path qw(make_path remove_tree);
use File::Copy qw(cp);
use Carp;
use Cwd;

# Custom Perl libraries
use String::CamelCase qw(decamelize wordsplit);

my @faceDescriptors;

my $lastLine = "";
my $currentFace = "";
my $currentFaceManifest = "";
open PRO_MANIFEST, "android/project/ChronometerPro/src/main/AndroidManifest.xml"
  or die "Run from Chronometer sandbox (es/chronometer/m1).";
while (<PRO_MANIFEST>) {
    if (/android.name="com.emeraldsequoia.chronometer.wearable.([^\.]+)IWatchFaceService"/) {
        $currentFace eq ""
          or die "Found new face $1 when $currentFace still active\n";
        $currentFace = $1;
        $lastLine =~ /^\s*<service\s*$/
          or die "Found service name, but it wasn't after a '<service' line\n";
        $currentFaceManifest = $lastLine;
    }
    if ($currentFace ne "") {
        if (/^\s*$/) {
            push @faceDescriptors, [$currentFace, $currentFaceManifest];
            $currentFace = "";
            $currentFaceManifest = "";
        } else {
            $currentFaceManifest .= $_;
        }
    }
    $lastLine = $_;
}
close PRO_MANIFEST;

sub filesAreDifferent {
    my ($file1, $file2, $ignoreComments) = @_;
    if ((defined $ignoreComments) && $ignoreComments) {
	return filesAreDifferentIgnoringComments($file1, $file2);
    } else {
	return system("cmp -s \"$file1\" \"$file2\"") != 0;
    }
}

sub writeFileFromFileWithoutComments {
    my $inputFile = shift;
    my $outputFile = shift;
    open TMP, ">$outputFile"
      or die "Couldn't create $outputFile: $!\n";
    open FILE, $inputFile
      or die "Couldn't read file $inputFile: $!\n";
    while (<FILE>) {
	chomp;
	s/\#.*$//go;  # Not quite right, if escaped.  Hard to do right without complete lexing
	print TMP $_, "\n";
    }
    close FILE;
    close TMP;
}

sub filesAreDifferentIgnoringComments {
    my ($file1, $file2) = @_;
    my $tmp1 = "/tmp/extractTariffInfo.1";
    my $tmp2 = "/tmp/extractTariffInfo.2";
    writeFileFromFileWithoutComments $file1, $tmp1;
    writeFileFromFileWithoutComments $file2, $tmp2;
    my $returnValue = filesAreDifferent $tmp1, $tmp2;
    unlink $tmp1
      or die "Couldn't remove $tmp1: $!\n";
    unlink $tmp2
      or die "Couldn't remove $tmp2: $!\n";
    return $returnValue;
}

# Make a temporary name from given name by adding ".new"
sub tempName {
    my $file = shift;
    return $file . ".new";
}

my $verbosity = 1;
my $updating = 1;

# Compare the given file's (presumably new) temp file with the given file,
# and if the tempfile has changed, rename it to be the new given file.
sub commitTempIfChanged {
    my $file = shift;
    my $ignoreComments = shift;
    my $tempFile = tempName $file;
    if (! -e $file) {
	rename $tempFile, $file
	  or confess "Couldn't rename $tempFile to $file: $!\n";
	warn "Created new $file\n" if ($verbosity > 2 || ($verbosity > 0 && $updating));
	return;
    }
    if (! -e $tempFile) {
	die "Tried to commit nonexistent file: $tempFile\n";
    }
    print "Checking $file\n" if $verbosity > 5;
    if (filesAreDifferent $file, $tempFile, $ignoreComments) {
	if ($verbosity > 5) {
            print "< $file\n";
            print "> $tempFile\n";
	    system("diff $file $tempFile");
	}
	unlink $file;
	rename $tempFile, $file
	  or confess "Couldn't rename $tempFile to $file: $!\n";
	warn "Changed $file\n" if ($verbosity > 2 || ($verbosity > 0 && $updating));
    } else {
	unlink $tempFile;
    }
}

sub makeDirectoryIfNotPresent {
    my $dir = shift;
    if (! -d $dir) {
        mkdir $dir, 0777
          or die "Couldn't create directory '$dir': $!\n";
    }
}

sub internalNameFromFaceName {
    my $faceName = shift;
    my $internalName;
    if ($faceName eq "McAlester") {
        $internalName = "mcalester";
    } else {
        $internalName = decamelize $faceName;
    }
    return $internalName;
}

sub makeManifestForFace {
    my $face = shift;
    my $internalName = shift;
    my $faceManifest = shift;
    my $faceDirectory = shift;
    makeDirectoryIfNotPresent "$faceDirectory/src";
    makeDirectoryIfNotPresent "$faceDirectory/src/main";
    my $manifestFile = "$faceDirectory/src/main/AndroidManifest.xml";
    my $newManifestFile = tempName $manifestFile;
    unlink $newManifestFile;
    open NEW_MANIFEST, ">$newManifestFile"
      or die "Couldn't open new manifest '$newManifestFile' for writing: $!\n";

    print NEW_MANIFEST <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="com.emeraldsequoia.chronometer.${internalName}">

  <application
      android:icon="\@drawable/${internalName}_i_round"
      android:label="\@string/emerald_${internalName}">

EOF
      ;
    print NEW_MANIFEST $faceManifest;

    print NEW_MANIFEST <<EOF

  </application>
</manifest>
EOF
      ;
    close NEW_MANIFEST;

    commitTempIfChanged $manifestFile, 0;
}

sub copyGradleFile {
    my $face = shift;
    my $internalName = shift;
    my $faceDirectory = shift;
    my $gradleFile = "$faceDirectory/build.gradle";
    my $newGradleFile = tempName $gradleFile;
    unlink $newGradleFile;
    open PRO_GRADLE, "android/project/ChronometerPro/build.gradle"
      or die "Couldn't read ChronometerPro/build.gradle: $!\n";
    open GRADLE, ">$newGradleFile"
      or die "Couldn't create '$newGradleFile': $!\n";
    while (<PRO_GRADLE>) {
        s/chronometer_pro/$internalName/g;
        print GRADLE $_;
    }
    close GRADLE;
    close PRO_GRADLE;

    commitTempIfChanged $gradleFile, 0;
}

sub copyFileUnchanged {
    my $leafName = shift;
    my $faceDirectory = shift;
    my $file = "$faceDirectory/$leafName";
    my $newFile = tempName $file;
    unlink $newFile;
    my $ecProFile = "android/project/ChronometerPro/$leafName";
    cp $ecProFile, $newFile
      or die "Couldn't copy '$ecProFile' to '$newFile': $!\n";
    commitTempIfChanged $file, 0;
}

sub maybeCreateVersionProperties {
    my $faceDirectory = shift;
    my $file = "$faceDirectory/version.properties";
    if (! -e $file) {
        open FILE, ">$file"
          or die "Couldn't create '$file': $!\n";
        print FILE "VERSION_BUILD=1\n";
        close FILE;
        print "Created $file\n";
    }
}

sub copyLink {
    my $entry = shift;
    my $srcDir = shift;
    my $dstDir = shift;
    my $linkTarget = readlink "$srcDir/$entry";
    defined $linkTarget
      or die "Couldn't read link at '$srcDir/$entry': $!\n";
    if (-l "$dstDir/$entry") {
        my $currentLinkTarget = readlink "$dstDir/$entry";
        defined $currentLinkTarget
          or die "Couldn't read link at '$dstDir/$entry': $!\n";
        if ($currentLinkTarget eq $linkTarget) {
            return;
        }
        unlink "$dstDir/$entry"
          or die "Couldn't remove existing link at '$dstDir/$entry': $!\n";
    }
    symlink $linkTarget, "$dstDir/$entry"
      or confess "Couldn't create link at '$dstDir/$entry': $!\n";
    print "Created '$dstDir/$entry' -> '$linkTarget'\n";
}

sub createLink {
    my $entry = shift;
    my $srcDir = shift;
    my $dstDir = shift;
    my $saveWD = cwd();
    chdir $dstDir
      or confess "Couldn't cd to '$dstDir': $!\n";
    my $linkTarget = "$srcDir/$entry";
    if (-l $entry) {
        my $currentLinkTarget = readlink $entry;
        defined $currentLinkTarget
          or confess "Couldn't read link at '$dstDir/$entry': $!\n";
        if ($currentLinkTarget eq $linkTarget) {
            chdir $saveWD
              or die "Couldn't cd back to '$saveWD': $!\n";
            return;
        }
        unlink $entry
          or die "Couldn't remove existing link at '$dstDir/$entry': $!\n";
    }
    symlink $linkTarget, $entry
      or confess "Couldn't create link at '$dstDir/$entry': $!\n";
    print "Created '$dstDir/$entry' -> '$linkTarget'\n";
    chdir $saveWD
      or die "Couldn't cd back to '$saveWD': $!\n";
}

sub updateAssetDirectory {
    my $face = shift;
    my $faceDirectory = shift;
    my $assetDirectory = "$faceDirectory/src/main/assets";
    makeDirectoryIfNotPresent $assetDirectory;
    my $proAssetDirectory = "android/project/ChronometerPro/src/main/assets";

    opendir PRO_DIR, $proAssetDirectory
      or confess "Couldn't read directory '$proAssetDirectory': $!\n";
    my @pro_entries = grep !/^\./, readdir PRO_DIR;
    closedir PRO_DIR;
    my $faceWithSplitWords = join " ", wordsplit $face;
    foreach my $entry (@pro_entries) {
        if ($entry =~ /^$faceWithSplitWords|^es/) {
            copyLink $entry, $proAssetDirectory, $assetDirectory;
        }
    }
}

sub updateResDirectory {
    my $face = shift;
    my $faceDirectory = shift;
    my $resDirectory = "$faceDirectory/src/main/res";
    makeDirectoryIfNotPresent $resDirectory;
    my $proResDirectory = "android/project/ChronometerPro/src/main/res";
    my $relativeProResDirectory = "../../../../ChronometerPro/src/main/res";
    opendir PRO_DIR, $proResDirectory
      or die "Couldn't read directory '$proResDirectory': $!\n";
    my @pro_entries = grep !/^\./, readdir PRO_DIR;
    closedir PRO_DIR;
    my $faceWithSplitWords = join "_", wordsplit $face;
    foreach my $entry (@pro_entries) {
        if ($entry =~ /^drawable-/) {
            # Copy only the drawables we need.
            my $proDrawableDir = "$proResDirectory/$entry";
            my $relativeProDrawableDir = "../../../../../ChronometerPro/src/main/res/$entry";
            my $drawableDir = "$resDirectory/$entry";
            makeDirectoryIfNotPresent $drawableDir;
            opendir DRAWABLE_DIR, $proDrawableDir
              or die "Couldn't read directory '$proDrawableDir': $!\n";
            my @drawableEntries = grep !/^\./, readdir DRAWABLE_DIR;
            closedir DRAWABLE_DIR;
            foreach my $drawableEntry (@drawableEntries) {
                if ($drawableEntry =~ /^$faceWithSplitWords|^es/) {
                    createLink $drawableEntry, $relativeProDrawableDir, $drawableDir;
                }
            }
        } else {
            createLink $entry, $relativeProResDirectory, $resDirectory;
        }
    }
}

sub doOne {
    my $face = shift;
    my $serviceManifest = shift;
    my $faceDirectory = "android/project/$face";
    my $internalName = internalNameFromFaceName $face;
    printf "%20s => %s\n", $internalName, $faceDirectory;
    makeDirectoryIfNotPresent $faceDirectory;
    copyFileUnchanged "build.pl", $faceDirectory;
    if (defined $serviceManifest) {
        makeManifestForFace $face, $internalName, $serviceManifest, $faceDirectory;
    }
    copyGradleFile $face, $internalName, $faceDirectory;
    copyFileUnchanged "proguard-rules.pro", $faceDirectory;
    maybeCreateVersionProperties $faceDirectory;
    updateAssetDirectory $face, $faceDirectory;
    updateResDirectory $internalName, $faceDirectory;
}

foreach my $faceDescriptor (@faceDescriptors) {
    my ($face, $serviceManifest) = @$faceDescriptor;
    doOne $face, $serviceManifest;
}

doOne "SCREENS", undef;
