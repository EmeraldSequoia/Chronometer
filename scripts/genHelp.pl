#!/usr/bin/perl -w

# Generate help files that depend on product, placing in app bundle area.  For CwH the app bundle area links back to the sandbox, so the output will appear there.

use strict;

use IO::Handle;
use File::Copy qw/cp/;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $isDistributionBuild = ($ENV{BUILD_STYLE} =~ /distrib/i);
my $unapprovedWatchesRequested = $ENV{EC_EXTRA_WATCHES};

if ($isDistributionBuild && $unapprovedWatchesRequested) {
    die "Distribution builds may not have unapproved watches; turn off EC_EXTRA_WATCHES in target settings";
}

defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!";

my $appFlavor = $ENV{PRODUCT_NAME};
$appFlavor = "ChronoAll" if $appFlavor eq "Chrono Plus";

my $appDir = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";
my $destHelpDir = "$appDir/Help";
my $srcHelpDir = "$ENV{SRCROOT}/Help";

my %approvedWatches;

if (!$unapprovedWatchesRequested) {
    my $approvedWatchFile = "$ENV{SRCROOT}/products/$appFlavor/Watches.txt";
    open APPROVE, $approvedWatchFile
	or die "Couldn't read $approvedWatchFile: $!";
    while (<APPROVE>) {
	chomp;
	next if (/^\s*\#/);
	$approvedWatches{$_} = 1;
    }
    close APPROVE;
}

opendir DIR, $srcHelpDir
  or die "Couldn't read directory $srcHelpDir: $!";
my @files = grep !/^\./, readdir DIR;
closedir DIR;

if (!-d $destHelpDir) {
    mkdir $destHelpDir, 0777
	or die "Couldn't create directory $destHelpDir: $!";
}

my @watches;
foreach my $file (@files) {
    my $path = "$srcHelpDir/$file/$file.html";
    if (-e $path && ($unapprovedWatchesRequested || $approvedWatches{$file})) {
	push @watches, $file;
    }
}

sub translateFile {
    my $src = shift;
    my $dest = shift;
    open SRC, $src
      or die "Couldn't open $src for reading: $!";
    unlink $dest;
    open DEST, ">$dest"
      or die "Coulen't open $dest for writing: $!";
    while (<SRC>) {
	if (/^\[WatchHelpLinks\]$/) {
	    foreach my $watch (@watches) {
		print DEST "  <a href=\"$watch/$watch.html\"><img src=\"../chooser/$watch.png\" height=40 width=40 align=center vspace=6> $watch</a><br>\n";
	    }
	} elsif (/^\[WatchColumnHeader\]$/) {
	    if (scalar @watches == 1) {  # Only one watch
		print DEST "  Watch Info\n";
	    } else {
		print DEST "  The Watches\n";
	    }
	} else {
	    print DEST $_;
	}
    }
    close SRC;
    close DEST;
}

sub sortComp {
    my $stra = $a;
    my $strb = $b;
    if ($stra =~ m%\[WIKI \S+ ([^]]+)%) {
	$stra = $1;
    }
    if ($strb =~ m%\[WIKI \S+ ([^]]+)%) {
	$strb = $1;
    }
    return $stra cmp $strb;
}

sub createComplicationsFile {
    my $srcDir = "$ENV{SRCROOT}/Watches/Builtin";
    my $src = "$srcHelpDir/ComplicationsTemplate.html";
    my $dest = "$destHelpDir/Complications.html";
    my %complications;
    foreach my $watch (@watches) {
	my $xml = "$srcDir/$watch/$watch.xml";
	open XML, $xml
	    or die "Couldn't read $xml: $!";
	my $foundIt = 0;
	while (<XML>) {
	    if (/<!-- COMPLICATIONS/) {
		$foundIt = 1;
		last;
	    }
	}
	$foundIt
	    or die "Didn't find COMPLICATIONS section in $xml";
	my $kind;
	while (<XML>) {
	    next if /^\s*$/;
	    if (/^\[(BOTH|FRONT|BACK|NIGHT)\]/i) {
		$kind = lc $1;
	    } elsif (/-->/) {
		last;
	    } else {
		chomp;
		my $complication = $_;
		defined $kind
		  or die "Complication not in FRONT/BACK/BOTH section of watch $watch: $complication";
		my $compList = $complications{$complication};
		if (!defined $compList) {
		    $compList = [];
		    $complications{$complication} = $compList;
		}
		push @$compList, [$watch, $kind];
	    }
	}
	close XML;
    }
    open SRC, $src
	or die "Couldn't read $src: $!";
    unlink $dest;
    open DEST, ">$dest"
	or die "Couldn't create $dest: $!";
    my $foundIt = 0;
    while (<SRC>) {
	if (/\[COMPLICATIONS\]/) {
	    $foundIt = 1;
	    last;
	}
	print DEST $_;
    }
    $foundIt
	or die "Didn't find COMPLICATIONS section in $src";
    my $justOneWatch = ((scalar @watches) == 1);
    foreach my $complication (sort sortComp keys %complications) {
	my $watchList = $complications{$complication};
	if ($complication =~ /^\[WIKI (\S+) ([^\]]+)\]\s*$/) {
	    $complication = "<a href='http://en.m.wikipedia.org/wiki/$1'>$2<img src='extlink.png'></a>";
	}
	if ($complication =~ /WIKI/) {
	    die "Malformed WIKI line $complication";
	}
	print DEST "  <tr><td>$complication</td><td>";
	my $firstOne = 1;
	foreach my $watchDesc (@$watchList) {
	    my ($watch, $kind) = @$watchDesc;
	    if ($justOneWatch) {
		if ($kind eq "both") {
		    print DEST "&nbsp;";
		} else {
		    print DEST $kind;
		}
 	    } else {
		if ($kind ne "both") {
		    $watch .= " <font size='-3'>($kind)</font>";
		}
		if ($firstOne) {
		    $firstOne = 0;
		} else {
		    $watch = "<br>$watch";
		}
		print DEST $watch;
	    }
	}
	print DEST "</tr>\n";
    }
    # Now finish up file
    while (<SRC>) {
	print DEST $_;
    }
    close SRC;
    close DEST;
}

sub copyProductCSS {
    my $src = "$srcHelpDir/$appFlavor.css";
    my $dest = "$destHelpDir/product.css";
    unlink $dest;
    cp $src, $dest
      or die "Couldn't copy $src to $dest: $!";
}

sub copyRoundedIcon {
    my $src = "$ENV{SRCROOT}/products/$appFlavor/roundedIcon.png";
    my $dest = "$destHelpDir/roundedIcon.png";
    unlink $dest;
    cp $src, $dest
      or die "Couldn't copy $src to $dest: $!";
}

translateFile "$srcHelpDir/HelpContentsTemplate.html", "$destHelpDir/Help Contents.html";
createComplicationsFile;
copyProductCSS;
copyRoundedIcon;
