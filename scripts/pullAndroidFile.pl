#!/usr/bin/perl -w

use strict;

use File::Basename;
use FindBin;
use lib $FindBin::Bin;

use AndroidDeviceSelector;

my $appName = "com.emeraldsequoia.chronometer.chronometer";

my $remoteFile = shift;
defined $remoteFile
  or die "Usage: $0 <remote-path>\n";

my ($device, $humanName) = getDeviceId;

my @suffixes = (".txt", ".png", ".jpg");
my ($name, $path, $suffix) = fileparse($remoteFile, @suffixes);
$suffix = ".txt" if $suffix eq "";

my $appDir = "/data/user/0/$appName";
my $localFile = "/tmp/AndroidPulledFile.$$" . $suffix;

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    return system($cmd);
}

unlink $localFile;
doCmd("adb -s $device shell \"run-as $appName cat $remoteFile\" > $localFile");
if (! -e $localFile) {
    die "Command file ($localFile doesn't exist)\n";
}
if (-z $localFile) {
    die "Warning: $localFile is empty\n";
}

print STDERR "Remove remote file (y/n)? [n] ";
chomp(my $ans = <STDIN>);
if ($ans =~ /^y$/i) {
    doCmd "adb -s $device shell \"run-as $appName rm $remoteFile\"";
}

doCmd("open $localFile");
