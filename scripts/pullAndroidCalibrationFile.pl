#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::Bin;

use AndroidDeviceSelector;

my $appName = "com.emeraldsequoia.chronometer.chronometer";

my ($device, $humanName) = getDeviceId;

my ($s, $m, $h, $D, $M, $Y) = localtime;
my $dateString = sprintf("%04d%02d%02d-%02d%02d%02d",
                         $Y + 1900, $M + 1, $D, $h, $m, $s);

my $appDir = "/data/user/0/$appName";
my $localFile = "/tmp/$humanName-calibration.$dateString.txt";
my $localTSV = "/tmp/$humanName-calibration.$dateString.tsv";

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    return system($cmd);
}

my $remoteFile;
my $cmd = "adb -s $device shell \"run-as $appName ls -1 files\"";
warn "$cmd\n";
open PIPE, "$cmd |"
  or die "Couldn't open pipe to get file list\n";
while (<PIPE>) {
    chomp;
    if (/^([0-9a-f]+-calibration_data.txt)$/) {
        $remoteFile = "files/$1";
    }
}
close PIPE;
defined $remoteFile
  or die "Couldn't find a calibration file on remote system\n";

unlink $localFile;
doCmd("adb -s $device shell \"run-as $appName cat $remoteFile\" > $localFile");
if (! -e $localFile) {
    die "Command file ($localFile doesn't exist)\n";
}
if (-z $localFile) {
    die "Warning: $localFile is empty\n";
}
# doCmd("open $localFile");

doCmd("$FindBin::Bin/androidMakeCalibrationTSV.pl $localFile > $localTSV");

doCmd("open $localTSV");
