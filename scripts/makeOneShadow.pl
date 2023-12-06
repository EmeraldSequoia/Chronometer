#!/usr/bin/perl -w

use strict;

use Cwd;
use File::Basename;
use File::Copy qw/cp/;

my $inputFile = shift;
my $outputFile = shift;
my $z = shift;
my $thickness = shift;

$0 =~ m%^(.*)/scripts/makeOneShadow\.pl$%
  or die "Must run script with full pathname\n";
my $sandboxRoot = $1;

$inputFile =~ s%$sandboxRoot/%%;
$outputFile =~ s%$sandboxRoot/%%;

chdir $sandboxRoot
  or die "Couldn't cd to $sandboxRoot: $!\n";
#chomp(my $pd = `pwd`);
#warn "cd $pd\n";

sub filesAreIdentical {
    my ($file1, $file2) = @_;
    return system("cmp -s \"$file1\" \"$file2\"") == 0;
}

my $cachedInput = "$outputFile.cachedInput-$z-$thickness";
if (-e $cachedInput &&
    -e $outputFile &&
    filesAreIdentical($cachedInput, $inputFile)) {
    exit;
}

-e "tools"
  or die "Must be run at root of Chronometer directory.\n";

my $imageMagick = cwd() . "/tools/ImageMagick-7.0.10";
my $imageMagickBin = "$imageMagick/bin";

$ENV{MAGICK_HOME} = $imageMagick;
$ENV{DYLD_LIBRARY_PATH} = "$imageMagick/lib";

-e "$imageMagickBin/convert"
  or die "Can't run without ImageMagick\n";

my $percentOpacity = 50;
my $sigma = sprintf("%.1f", ($z + 2)/2);
if ($thickness < 3.0) {
    $sigma *= $thickness/3.0;
    $percentOpacity += 50 * (3.0 - $thickness)/3.0;
}

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

my $cmd = "'$imageMagickBin/convert' '$inputFile' -background black -shadow $percentOpacity" . "x$sigma '$outputFile'";
doCommand($cmd);

unlink $cachedInput;
cp $inputFile, $cachedInput
    or die "Couldn't copy: $!\n";
-e $cachedInput
    or die "Copy failed\n";

