#!/usr/bin/perl -w

# This script was run one time in November 2009 to extract the individual watches' complications from the manual Complications.html file that existed at that time.

use strict;

open TEMPLATE, "ComplicationsTemplate.html"
  or die;

my %watches;
my @allComplex;
my @allWithYear;

my $count = 0;
while (<TEMPLATE>) {
    if (m%^<tr><td>(.*)</td><td>(.*)</td></tr>%) {
	my $complication = $1;
	my $watches = $2;
#	print "Watches = '$watches'\n";
	$complication =~ s%<a href=['"]http://en\.m\.wikipedia\.org/wiki/([^'"]+)['"]>([^<]+)<img src=['"]extlink\.png['"]></a>%[WIKI $1 $2]%;
	die "Bad complication '$complication'\n" if $complication =~ /wikipedia/;
	if ($watches =~ /^All complex watches/) {
	    push @allComplex, $complication;
	} elsif ($watches =~ /^all watches with year displays/) {
	    push @allWithYear, $complication;
	} else {
	    my @watches = split /<br>/, $watches;
	    foreach my $watchDesc (@watches) {
		$watchDesc =~ m%^<a href=['"]([^'"]+)['"]>([^<]+)</a>( ?\((front|back)\))?$%
		  or die "Bad pattern $watchDesc for $complication\n";
		my $link = $1;
		my $watch = $2;
		my $frontBack = $4;
		$frontBack = "both" if not defined $frontBack;
		$link eq "$watch.html" or die "Link '$link' doesn't match watch '$watch'\n";
		my $watchDesc = $watches{$watch};
		if (!defined $watchDesc) {
		    $watchDesc = {};
		    $watches{$watch} = $watchDesc;
		}
		my $watchList = $watchDesc->{$frontBack};
		if (!defined $watchList) {
		    $watchList = [];
		    $watchDesc->{$frontBack} = $watchList;
		}
		push @$watchList, $complication;
	    }
	}
	$count++;
    } elsif (/<tr>/) {
	die "Unexpected line $_";
    }
}

close TEMPLATE;

print "Found $count complications:\n";

sub printList {
    my $desc = shift;
    my $kind = shift;
    my $list = $desc->{$kind};
    if (defined $list) {
	my $uckind = uc $kind;
	print NEWXML "\n[$uckind]\n";
	print "\n[$uckind]\n";
	foreach my $complication (@$list) {
	    print NEWXML "$complication\n";
	    print "$complication\n";
	}
    }
}

foreach my $watch (sort keys %watches) {
    print "\n========================================   $watch  =============================================\n";
    my $xml = "../Watches/Builtin/$watch/$watch.xml";
    die "No xml file $xml\n" if not -e $xml;
    my $newXML = "$xml.new";
    open XML, $xml
      or die;
    unlink $newXML;
    open NEWXML, ">$newXML"
      or die;
    while (<XML>) {
	if (/COMPLICATIONS/) {
	    warn "COMPLICATIONS already found in $watch\n";
	}
	print NEWXML $_;
    }
    close XML;
    print NEWXML "\n\n<!-- COMPLICATIONS\n";
    my $desc = $watches{$watch};
    printList $desc, "both";
    printList $desc, "front";
    printList $desc, "back";
    print NEWXML "\n-->\n";
    close NEWXML;

    my $old = "$xml.old";
    unlink $old;
    rename $xml, $old
      or die "Can't rename $xml";
    rename $newXML, $xml
      or die "Can't rename $newXML";
}
