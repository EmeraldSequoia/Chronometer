#!/usr/bin/perl -w

use strict;

my $verbose = 1;

sub filesAreIdentical {
    my ($file1, $file2) = @_;
    return system("cmp -s \"$file1\" \"$file2\"") == 0;
}

sub checkFile {
    my ($file, $newFile) = @_;
    my $created = 0;
    if (-e $file) {
	if (filesAreIdentical $file, $newFile) {
	    unlink $newFile
	      or die "Couldn't delete $newFile: $!\n";
	    return;
	} else {
	    unlink $file;
	    warn "Changed $file\n" if $verbose > 0;
	}
    } else {
	warn "Created $file\n" if $verbose > 0;
	$created = 1;
    }
    rename $newFile, $file
      or die "Couldn't rename $newFile to $file: $!\n";
    return $created;
}

sub convertFile {
    my $file = shift;
    my $newFile = "$file.new";
    unlink $newFile;

    open FILE, $file
      or die "Can't open $file: $!\n";
    open NEW, ">$newFile"
      or die "Can't create $newFile: $!n";
    while (<FILE>) {
	s/Copyright (\d+) Steve Pucci/Copyright $1 Emerald Sequoia LLC/go;
	s/Copyright Steve Pucci (\d+)/Copyright $1 Emerald Sequoia LLC/go;
	s/Copyright Bill Arnett (\d+)/Copyright $1 Emerald Sequoia LLC/go;
	s/Copyright (\d+) Bill Arnett/Copyright $1 Emerald Sequoia LLC/go;
	s/Copyright (\d+) __MyCompanyName__/Copyright $1 Emerald Sequoia LLC/go;
	print NEW $_;
    }
    close NEW;
    close FILE;

    checkFile $file, $newFile;
}

foreach my $file (@ARGV) {
    convertFile $file;
}
