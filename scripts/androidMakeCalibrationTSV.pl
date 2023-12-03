#!/usr/bin/perl -w

use strict;

# Takes a calibration file created by pullAndroidCalibrationFile.pl and makes a simple TSV out of it.

while (<>) {
    /^([0-9\.]+) (-?[0-9\.]+) ([0-9\.]+) ([0-9\.]+) ([0-9\.]+) (([-0-9\.]+) )?([TF])$/
      or die "Unrecognized line: $_";
    my $sysTime = $1;
    my $contSkew = $2;
    my $skewError = $3;
    my $boottimeSeconds = $4;
    my $monotonicSeconds = $5;
    my $monotonicRawSeconds = $7;
    my $isBootString = $8;
    my $isBoot = ($8 eq "T");

    $monotonicRawSeconds = "" if not defined $monotonicRawSeconds;

    print "$sysTime\t$contSkew\t$skewError\t$boottimeSeconds\t$monotonicSeconds\t$monotonicRawSeconds\t$isBootString\n";
}
