#!/usr/bin/perl -w

use strict;

use Carp;

use IO::Handle;
STDOUT->autoflush(1);
STDERR->autoflush(1);

my $versionMajor = 1;
my $versionMinor = 4;
my $versionPatch = 1;
my $versionNumber = 43;

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

my $verbosity = 6;
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

sub checkLine {
    my $whatVersionName = shift;
    my $whatVersionNumber = shift;
    if (/^(\s*def $whatVersionName = )\d+(\s*)$/) {
        my $prefix = $1;
        my $suffix = $2;
        $_ = "$prefix$whatVersionNumber$suffix";
    }
}

sub processDir {
    my $dir = shift;
    my $gradle = "$dir/build.gradle";
    my $gradleNew = tempName $gradle;
    unlink $gradleNew;
    open GRADLE, $gradle
      or die "Couldn't open '$gradle': $!\n";
    open NEW, ">$gradleNew"
      or die "Couldn't create '$gradleNew': $!\n";
    while (<GRADLE>) {
        checkLine "versionMajor",  $versionMajor;
        checkLine "versionMinor",  $versionMinor;
        checkLine "versionPatch",  $versionPatch;
        checkLine "versionNumber", $versionNumber;
        print NEW;
    }
    close GRADLE;
    close NEW;

    commitTempIfChanged $gradle, 1;
}

my $dir = "android/project";
opendir DIR, $dir
  or die "Couldn't read directory $dir: $!\n";
my @entries = grep !/^\./, readdir DIR;
closedir DIR;

foreach my $entry (@entries) {
    my $gradlePath = "$dir/$entry/build.gradle";
    if (-e $gradlePath) {
        processDir "$dir/$entry";
    }
}
