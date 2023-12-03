#!/usr/bin/perl -w

use strict;

use POSIX qw(strftime);

my $archiveDir = shift;

-d $archiveDir
  or die "Run at the top-level of the sandbox; no $archiveDir directory\n";

chdir $archiveDir
  or die "Can't cd to $archiveDir directory: $!\n";

open PIPE, "git log --oneline --abbrev=8 -- .|"
  or die "Couldn't open pipe to git: $!\n";
my $line = <PIPE>;
$line =~ /^([a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]) /
  or die "Unexpected git log output: $line\n";
close PIPE;
my $versionNumber = $1;

#print "Effective $archiveDir version is $versionNumber\n";

my @modifiedFiles;
open PIPE, "git status|"
  or die "Couldn't open pipe to git: $!\n";
my $lookingForUntrackedFiles = 0;
while (<PIPE>) {
    if (/modified:\s+(.*)$/) {
        my $path = $1;
        next if $path =~ /^\.\.\//;  # Skip stuff not actually in this subtree
        push @modifiedFiles, $path;
    } elsif ($lookingForUntrackedFiles && (/^#\t(.+)$/)) {
        my $path = $1;
        next if $path =~ /^\.\.\//;  # Skip stuff not actually in this subtree
        push @modifiedFiles, $path;
    } elsif (/Untracked files:/) {
        $lookingForUntrackedFiles = 1;
    }
}

close PIPE;

if ((scalar @modifiedFiles) > 0) {
    my $mostRecentModDate;
    foreach my $modifiedFile (@modifiedFiles) {
	#print "Checking $modifiedFile\n";
	my $modDate = (stat $modifiedFile)[9];
	if ((!defined $mostRecentModDate) || ($modDate > $mostRecentModDate)) {
	    $mostRecentModDate = $modDate;
	}
    }
    my $modString = strftime "_%Y.%m.%d-%H.%M.%S", localtime $mostRecentModDate;
    $versionNumber .= $modString;
}

#print "... translated to $versionNumber\n";

open F, ">archiveVersion.txt"
  or die "Couldn't create $archiveDir/archiveVersion.txt: $!\n";
print F "$versionNumber\n";
close F;

print "Recorded effective $archiveDir version as $versionNumber\n";
