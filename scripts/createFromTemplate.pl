#!/usr/bin/perl -w

# This script is of no use directly as written, but the idea of copying from one
# template file to a bunch of others, based on filenames, may come in useful for
# configuring different sub-bundles of EC for AW.

use strict;

my $templateName = "AtlantisIWearableConfigActivity.java";

my $name = shift;

defined $name
  or die "Usage: $0  <face name>\n\ne.g.,\n\n$0  \"Miami I\"\n";

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    (system $cmd) == 0
      or die "Trouble with command (see above)\n";
}

my $helpname = lc $name;
if ($helpname !~ /i$/) {
    $helpname .= "_i";
}
$helpname .= ".html";
$helpname =~ s/ /_/go;

my $classname = $name . "WearableConfigActivity";
$classname =~ s/ //go;

my $filename = $classname . ".java";

warn "Name:  $name\n";
warn "Class: $classname\n";
warn "File:  $filename\n";
warn "Help:  $helpname\n";

open FILE, ">$filename"
  or die "Couldn't create $filename: $!\n";
open TEMPLATE, $templateName
  or die "Couldn't read $templateName: $!\n";
while (<TEMPLATE>) {
    s/Atlantis I/$name/g;
    s/AtlantisIWearableConfigActivity/$classname/g;
    s/atlantis_i.html/$helpname/g;
    print FILE $_;
}
close TEMPLATE;
close FILE;
