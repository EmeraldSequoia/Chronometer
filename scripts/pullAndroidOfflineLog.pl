#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::Bin;

use AndroidDeviceSelector;

my $appName = "com.emeraldsequoia.chronometer.chronometer";

my ($device, $humanName) = getDeviceId;

my $appDir = "/data/user/0/$appName";
my $remoteFile = "files/OfflineLog.txt";
my $remotePrevFile = "files/OfflineLog-previous.txt";
my $localFile = "/tmp/AndroidPulledFile.$$.txt";
my $localPrevFile = "/tmp/AndroidPulledFile-previous.$$.txt";

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

doCmd("adb -s $device shell \"run-as $appName cat $remotePrevFile\" > $localPrevFile");
if (! -e $localPrevFile) {
    warn "Command file ($localPrevFile doesn't exist)\n";
}
if (-z $localFile) {
    warn "Warning: $localPrevFile is empty\n";
}

print STDERR "Remove remote files (y/n)? [n] ";
chomp(my $ans = <STDIN>);
if ($ans =~ /^y$/i) {
    doCmd "adb -s $device shell \"run-as $appName rm $remoteFile\"";
    doCmd "adb -s $device shell \"run-as $appName rm $remotePrevFile\"";
}

doCmd("open $localFile $localPrevFile");
