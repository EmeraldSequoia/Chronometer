#!/usr/bin/perl -w

use strict;

my %changeHash = ("Chandra" => "Selene",
                  "Firenze" => "Padua",
                  "Geneva" => "Basel",
                  "Haleakala" => "Hana",
                  "Mauna Kea" => "Mauna Loa",
                  "Miami" => "Venezia",
                  "Terra" => "Gaia");

sub changeString {
    my $str = shift;

    while (my ($fromRoot, $toRoot) = each %changeHash) {
        my $fromRootLC = lc $fromRoot;
        my $toRootLC = lc $toRoot;
        $str =~ s/super\("${fromRoot} II"\)/super\("${toRoot} I"\)/g;
        $str =~ s/${fromRoot} II/${toRoot}/g;
        $str =~ s/${fromRoot}II/${toRoot}I/g;
        $str =~ s/${fromRootLC}_ii/${toRootLC}_i/g;
    }
    return $str;
}

sub changeFile {
    my $file = shift;
    my $newFile = "$file.new";
    open FILE, $file
      or die "Couldn't open '$file': $!\n";
    open NEW, ">$newFile"
      or die "Couldn't create '$newFile': $!\n";
    while (<FILE>) {
        print NEW changeString($_);
    }
    close NEW;
    close FILE;

    rename $newFile, $file
      or die "Couldn't rename '$newFile' to '$file': $!\n";
}

foreach my $file (@ARGV) {
    changeFile $file;
}
