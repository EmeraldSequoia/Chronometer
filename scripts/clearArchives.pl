#!/usr/bin/perl -w

use strict;

use File::Path;  # for rmtree
use Carp;

my $android = 0;
my $quiet = 0;
my $arg = shift;
if (defined $arg) {
    if ($arg =~ /^-and/) {
        $android = 1;
        $arg = shift;
    }
    if ((defined $arg) and $arg =~ /^-q/) {
        $quiet = 1;
    }
}

sub ask {
    my $prompt = shift;
    my $default = shift;
    $prompt =~ s/\n$//go;
    $prompt =~ s/\s+$//go;
    $prompt =~ s/:$//go;
    if (defined $default) {
        $prompt .= " (default $default)";
    }
    $prompt .= ": ";
    print STDERR $prompt;
    chomp (my $ans = <STDIN>);
    defined $ans
      or confess "Broken prompting";
    if (($ans eq "") and (defined $default)) {
        $ans = $default;
    }
    return $ans;
}

# Ensure we are running in a chronometer sandbox
-e "Classes" and -e "Watches" and -e "archive" and -e "archiveHD"
  or die "Run from the top level of a 'chronometer' sandbox.\n";

if ($android) {
    warn "Removing:\n";
    warn "archiveAndroid\n";
    rmtree "archiveAndroid";
    mkdir "archiveAndroid", 0777;

    my $wildcard = "android/project/assets";
    my $cmd = "ls -d $wildcard";
    warn "$cmd\n";
    open PIPE, "$cmd 2>&1 | cat |"
      or die "Couldn't open pipe: $!\n";
    my @productAssetDirs = <PIPE>;
    close PIPE;

    foreach my $productAssetDir (@productAssetDirs) {
        chomp($productAssetDir);
        opendir DIR, $productAssetDir
          or die;
        my @productAssetDirEntries = grep !/^\./, readdir DIR;
        closedir DIR;
        foreach my $productAssetDirEntry (@productAssetDirEntries) {
            next if $productAssetDirEntry !~ / II?(-[a-z]+)?$/;
            warn "rmtree $productAssetDir/$productAssetDirEntry\n";
            rmtree "$productAssetDir/$productAssetDirEntry";
        }
    }
} else {
    warn "Removing:\n";
    warn "archive\n";
    rmtree "archive";
    mkdir "archive", 0777;

    warn "archiveHD\n";
    rmtree "archiveHD";
    mkdir "archiveHD", 0777;
}
my $wildcard = "$ENV{HOME}/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/archive*";
my $cmd = "ls -ldtr $wildcard";
warn "$cmd\n";
open PIPE, "$cmd 2>&1 | cat |"
  or die "Couldn't open pipe: $!\n";
my @entries = <PIPE>;
close PIPE;

my $noFiles = 0;
foreach my $entry (@entries) {
    if ($entry =~ m/No such file/) {
        $noFiles = 1;
    } else {
        warn $entry;
    }
}

if ($noFiles) {
    warn "Nothing more to do (no simulator archives), quitting\n";
    exit 0;
}

$cmd = "ls -1d $wildcard";
open PIPE, "$cmd |"
  or die "Couldn't open pipe: $!\n";
@entries = <PIPE>;
close PIPE;

foreach my $entry (@entries) {
    chomp($entry);
    warn "rmtree $entry\n";
    rmtree $entry
      or die "Couldn't remove $entry: $!\n"
}
