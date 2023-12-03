#!/usr/bin/perl -w

use strict;
use Cwd;

use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

# Standard 
use File::Basename;
use File::Copy qw/cp/;
use File::Path;

my $outputFile = shift;
my $width = shift;
my $height = shift;
my $opacity = shift;
my $sigma = shift;
my $offset = shift;

warn "makeOneWindowShadow.pl HELLO\n";

my $percentOpacity = $opacity * 100;

$0 =~ m%^(.*)/scripts/makeOneWindowShadow\.pl$%
  or die "Must run script with full pathname\n";
my $sandboxRoot = $1;

chdir $sandboxRoot
  or die "Couldn't cd to $sandboxRoot: $!\n";
#chomp(my $pd = `pwd`);
#warn "cd $pd\n";

$outputFile =~ s%$sandboxRoot/%%;
my ($leaf, $dir) = fileparse $outputFile;
if (! -d $dir) {
    mkpath $dir, 0666
	or die "Couldn't create directory $dir: $!\n";
}

sub filesAreIdentical {
    my ($file1, $file2) = @_;
    return system("cmp -s \"$file1\" \"$file2\"") == 0;
}

-e "tools"
  or die "Must run out of sandbox scripts directory\n";

my $imageMagick = cwd() . "/tools/ImageMagick-7.0.10";
my $imageMagickBin = "$imageMagick/bin";


$ENV{MAGICK_HOME} = $imageMagick;
$ENV{DYLD_LIBRARY_PATH} = "$imageMagick/lib";

-e "$imageMagickBin/convert"
  or die "Can't run without ImageMagick\n";

my $halfBorder = 5;
my $border = $halfBorder * 2;
my $imgWidth = $width + $border * 2;
my $imgHeight = $height + $border * 2;
my $xlo = $halfBorder - 0.5;
my $ylo = $halfBorder - 0.5;
my $xhi = $imgWidth - $halfBorder - 0.5;
my $yhi = $imgHeight - $halfBorder - 0.5;

my $tmp = "/tmp/makeOneWindowShadow.$$.png";
unlink $tmp;
! -e $tmp
    or die "Couldn't remove $tmp: $!\n";

# The Apple System Integrity Protect (SIP) system apparently disallows passing LD_LIBRARY_PATH as an environment variable to and from child processes: https://stackoverflow.com/a/60128194
# Though an exception is made for bash, apparently, or nothing would work.  Why such an exception is not made for Perl I have no idea.  But it clearly doesn't work in Catalina with /usr/bin/perl.
# So we hack around it by constructing a bash command that includes setting the environment variable directly.
sub doCommand {
    my $cmd = shift;
    $cmd !~ /\"/
      or die "Commands may not include a double quote character\n";
    $cmd = "DYLD_LIBRARY_PATH='$ENV{DYLD_LIBRARY_PATH}' $cmd";
    $cmd = "bash -c \"$cmd\"";
    warn "  BEGIN $cmd\n";
    system($cmd);
    warn "  *-END $cmd\n";
}

my $cmd = "'$imageMagickBin/convert' -format PNG32 -size $imgWidth" . "x$imgHeight xc:none -strokewidth $border -stroke black -fill none -draw 'Rectangle $xlo,$ylo $xhi,$yhi' -background black -shadow $percentOpacity" . "x$sigma '$tmp'";
doCommand($cmd);

-e $tmp
  or die "Convert failed to construct $tmp\n";

$cmd = "sips -g pixelWidth -g pixelHeight \"$tmp\"";
#warn "$cmd\n";
open PIPE, "$cmd |"
    or die;
my $shadowWidth;
my $shadowHeight;
while (<PIPE>) {
    chomp;
    if (/pixelWidth:\s*(\d+)[^\d]?$/) {
	$shadowWidth = $1;
    } elsif (/pixelHeight:\s*(\d+)[^\d]?$/) {
	$shadowHeight = $1;
    }
}
close PIPE;

defined $shadowWidth && defined $shadowHeight
    or die;

#print "Shadow has width $shadowWidth, height $shadowHeight, cropping back to $width x $height \n";
my $shadowOffX = ($shadowWidth - $width)/2 - $offset;
my $shadowOffY = ($shadowHeight - $height)/2 - 2 * $offset;
$cmd = "'$imageMagickBin/convert' '$tmp' -crop $width" . "x$height+$shadowOffX+$shadowOffY '$outputFile'";
doCommand($cmd);
#system("open -a 'Adobe Photoshop CS3' \"$outputFile\"");
