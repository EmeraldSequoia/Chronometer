#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Copy qw/cp/;
use Cwd;
use IO::Handle;

use POSIX 'ceil';

use Config;
use threads;
use Thread::Queue;
use threads::shared;

STDOUT->autoflush();
STDERR->autoflush();

$ENV{LD_LIBRARY_PATH} = "";
delete $ENV{DYLD_ROOT_PATH};

my $numProcessors = `sysctl -n hw.ncpu`;
if ($numProcessors > 18) {
    $numProcessors = 18;
}

my $listFile = shift;

defined $listFile
  or die "Usage: $0 <list-of-files>\n";

open LIST, $listFile
    or die "Couldn't read list file $listFile: $!\n";
my @files = <LIST>;
close LIST;

my ($name, $path) = fileparse $listFile;
$path =~ s%/$%%o;
my $watch = fileparse $path;
#print "Creating zoom set for $watch\n";
my $isBackground = ($watch =~ /^Background$/i);

sub filesAreIdentical {
    my ($file1, $file2) = @_;
    return system("cmp -s \"$file1\" \"$file2\"") == 0;
}

sub makeZoomPartImage {
    my $sourcePartImage = shift;
    my $destPartImage = shift;
    my $zoomPower = shift;
    my $sourceWidth = shift;
    my $destWidth;
    if ($zoomPower == 0) {
	#warn "cp $sourcePartImage $destPartImage\n";
	cp $sourcePartImage, $destPartImage
	  or die "Couldn't copy $sourcePartImage to $destPartImage: $!\n";
	return;
    } elsif ($zoomPower < 0) {
	my $factor = 1 << (-$zoomPower);
	$destWidth = POSIX::ceil($sourceWidth / $factor);
    } else {
	my $factor = 1 << ($zoomPower);
	$destWidth = POSIX::ceil($sourceWidth * $factor);
    }
    unlink $destPartImage;
    my $cmd = "sips --resampleWidth $destWidth \"$sourcePartImage\" --out \"$destPartImage\"";
    #warn "$cmd\n";
    open PIPE, "$cmd |"
      or die;
    while (<PIPE>) {
	# Throw away input to avoid cluttering output
    }
    close PIPE;
}

my @zoomPowers;
share @zoomPowers;
sub initZoomPowers {
    my $filename = "deps/esastro/src/ECConstants.h";
    open CONSTANTS, "$filename"
      or die "Couldn't read $filename: $!\n";
    my $minZoom;
    my $maxZoom;
    while (<CONSTANTS>) {
	if (/^#define ECZoomMinPower2 *\( *([-\d]+) *\)/) {
	    $minZoom = $1;
	} elsif (/^#define ECZoomMaxPower2 *\( *([-\d]+) *\)/) {
	    $maxZoom = $1;
	}
    }
    close CONSTANTS;
    (defined $minZoom) && (defined $maxZoom)
      or die "Couldn't find definitions for ECZoom{Min,Max}Power2 in $filename\n";
    $minZoom < $maxZoom
      or die;
    for (my $zoom = $minZoom; $zoom <= $maxZoom; $zoom++) {
	push @zoomPowers, $zoom;
    }
}

sub findSourceWidthForPartImage {
    my $sourcePartImage = shift;
    my $cmd = "sips -g pixelWidth \"$sourcePartImage\"";
#    warn "$cmd\n";
    open PIPE, "$cmd |"
      or die "Couldn't open cmd pipe: $!\n";
    my $line = <PIPE>;  # skip past filename
    chomp($line = <PIPE>);
    close PIPE;
    my (undef, $sourceWidth) = split /: /, $line;
    return $sourceWidth;
}

my @conversionDescriptors;
share(@conversionDescriptors);

# Conversion threads are used to actually do the conversions
my @convertThreads;
my $convertWorkQueue = new Thread::Queue;
my $conversionDoneQueue = new Thread::Queue;
our $conversionsQueued = 0;
my $conversionsCompleted = 0;
share $conversionsQueued;
for (my $i = 0; $i < $numProcessors; $i++) {
    push @convertThreads, new threads(sub {
					  while (1) {
					      my $descriptorNumber = $convertWorkQueue->dequeue();
					      if ($descriptorNumber < 0) {
						  return 1;
					      }
					      my ($sourcePartImage, $dest, $zoomPower, $sourceWidth) = @{$conversionDescriptors[$descriptorNumber]};
					      defined $sourcePartImage
						or die "aasd";
					      defined $zoomPower
						or die "asdf";
					      makeZoomPartImage $sourcePartImage, $dest, $zoomPower, $sourceWidth;
					      $conversionDoneQueue->enqueue(1);
					  }
				      });
}

sub setupConversions {
    my $sourcePartImage = shift;
    defined $sourcePartImage
      or die "Bar\n";
    share $sourcePartImage;
    my $sourceRoot = $sourcePartImage;
    $sourceRoot =~ s/\.png$//i
      or die "source partImage is not a png: $sourcePartImage\n";
    my $zoom0 = "$sourceRoot-Z0.png";
    if (-e $zoom0 &&
	filesAreIdentical($zoom0, $sourcePartImage)) {
	return;
    }
    my $sourceWidth = findSourceWidthForPartImage $sourcePartImage;
    my @z = @zoomPowers;
    if ($isBackground) {
	@z = (0);
    }
    foreach my $zoomPower (@z) {
	next if $zoomPower > 0;    # Parts for Z=1 are created elsewhere
	my $dest = sprintf "$sourceRoot-Z%d.png", $zoomPower;
	share $dest;
	defined $sourcePartImage
	  or die "Huh?";
	my $index;
	{
	    lock @conversionDescriptors;
	    $index = $#conversionDescriptors + 1;
	    $conversionDescriptors[$index] = &share([]);
	    ${conversionDescriptors[$index]}[0] = $sourcePartImage;
	    ${conversionDescriptors[$index]}[1] = $dest;
	    ${conversionDescriptors[$index]}[2] = $zoomPower;
	    ${conversionDescriptors[$index]}[3] = $sourceWidth;
	}
	$convertWorkQueue->enqueue($index);
	$conversionsQueued++;
    }
}

# Setup threads are used to examine the source images and determine the sizes for the conversions
my @setupThreads;
my $setupWorkQueue = new Thread::Queue;
my $setupDoneQueue = new Thread::Queue;
my $setupsQueued = 0;
my $setupsCompleted = 0;
for (my $i = 0; $i < $numProcessors; $i++) {
    push @setupThreads, new threads(sub {
					while (1) {
					    my $inputFile = $setupWorkQueue->dequeue();
					    defined $inputFile
					      or die "Foo\n";
					    if (!length $inputFile) {
						return 1;
					    }
					    setupConversions $inputFile;
					    $setupDoneQueue->enqueue(1);
					}
				    });
}

$Config{useithreads} or die "Recompile Perl with threads to use this program.\n";

$0 = cwd() . "/$0" if $0 !~ m%^/%o;

$0 =~ m%^(.*)/scripts/makeOneWatchZoomSet\.pl$%
  or die "Must run script with full pathname\n";
my $sandboxRoot = $1;

chdir $sandboxRoot
  or die "Couldn't cd to $sandboxRoot: $!\n";
#chomp(my $pd = `pwd`);
#warn "cd $pd\n";

initZoomPowers;

foreach my $inputFile (@files) {
    chomp $inputFile;
    $inputFile = cwd() . "/$inputFile" if $inputFile !~ m%^/%o;

    # $inputFile =~ s%$sandboxRoot/%%
    #     or die "Input file is not in sandbox: $inputFile\n";
    $setupWorkQueue->enqueue($inputFile);
    $setupsQueued++;
}

while ($setupsCompleted < $setupsQueued) {
    $setupDoneQueue->dequeue();
    $setupsCompleted++;
}

# At this point we know all conversions have been enqueued, so $conversionsQueued is correct
while ($conversionsCompleted < $conversionsQueued) {
    $conversionDoneQueue->dequeue();
    $conversionsCompleted++;
}

# Here we're all done.  We join all of the threads to keep Perl from issuing a warning, and in order to do that
# we have to make sure the threads finish properly.  So add one "end marker" task for each thread to its queue:
for (my $i = 0; $i < $numProcessors; $i++) {
    $setupWorkQueue->enqueue("");
}
for (my $i = 0; $i < $numProcessors; $i++) {
    $convertWorkQueue->enqueue(-1);
}
foreach my $thread (@setupThreads) {
    $thread->join;
}
foreach my $thread (@convertThreads) {
    $thread->join;
}
