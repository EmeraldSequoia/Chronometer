#!/usr/bin/perl -w

use strict;

use Cwd;
use Carp;

my $isDistributionBuild = 0;

my $recursionDepth = -1;

my $ALLOW_UNPUSHED_FILES = 0;

# Recursively checks the project and all of its dependencies are unmodified,
# and if so records, checks in, and pushes a file in the deps directory
# which in turn records the exact versions of each dependent library
# The version (after that checkin/push) of the given project is returned.
# If the method returns, all is well.
sub verifyProjectForDistribution {
    my $project = shift;
    my $saveWD = cwd();
    $recursionDepth++;
    print ((".." x $recursionDepth) . "$project\n");
    chdir $project
      or confess "Couldn't cd to $project from $saveWD: $!\n";
    open PIPE, "git status --short --branch |"
      or die "Couldn't open pipe to git st: $!\n";
    while (<PIPE>) {
        if (/^.?\?/) {
            confess "Distribution builds do not allow untracked files:\n$project/$_\n";
        } elsif (/\[ahead/) {
            if ($ALLOW_UNPUSHED_FILES) {
                warn "Distribution builds do not allow unpushed files:\n$project\n$_\n";
                warn "BUT JUST THIS ONCE\n";
            } else {
                confess "Distribution builds do not allow unpushed files:\n$project\n$_\n";
            }
        } elsif (/.?M/) {
            confess "Distribution builds do not allow modified files:\n$project\n/$_\n";
        } elsif (/.?A/) {
            confess "Distribution builds do not allow added files not checked in:\n$project\n/$_\n";
        } elsif (/.?D/) {
            confess "Distribution builds do not allow deleted files not checked in:\n$project\n/$_\n";
        } elsif (/^#/) {
            # OK
        } else {
            confess "Distribution builds do not allow unexpected output from git status:\n$_\n";
        }
    }
    close PIPE;
    # So far so good
    if (-e "deps") {
        opendir DIR, "deps"
          or confess "Couldn't read directory deps from $project from $saveWD: $!\n";
        my @files = grep !/^\.|~$|^deps\.txt$|^distribution-versions\.txt$/, readdir DIR;
        closedir DIR;
        my @depsVersions;
        foreach my $file (@files) {
            if (-l "deps/$file") {
                push @depsVersions, [$file, verifyProjectForDistribution("deps/$file")];
            } else {
                warn "Odd: Unexpected non-link file $file found in deps in $project from $saveWD\n";
            }
        }
        my $depsVersionFile = "deps/distribution-versions.txt";
        if (-e "$depsVersionFile") {
            unlink "$depsVersionFile"
              or confess "Can't remove $depsVersionFile in $project from $saveWD: $!\n";
        }
        open DEPS, ">$depsVersionFile"
          or confess "Can't create $depsVersionFile in $project from $saveWD: !$\n";
        foreach my $depsVersion (@depsVersions) {
            my ($file, $version) = @$depsVersion;
            printf DEPS "%20s %s\n", $file, $version;
        }
        close DEPS;
        print ((".." x $recursionDepth) . "$project deps\n");
        chomp(my $changeCount = `git status --short | wc -l`);
        if ($changeCount != 0) {
            my $cmd = "git commit -q -a -m 'Record current versions of dependent projects'";
            warn "$cmd\n";
            system($cmd);
            $cmd = "git push -q";
            warn "$cmd\n";
            system($cmd);
        }
        open PIPE, "git status --short --branch |"
          or confess "Couldn't open pipe: $!\n";
        while (<PIPE>) {
            if (/\[ahead/) {
                if ($ALLOW_UNPUSHED_FILES) {
                    warn "git push appears to have failed; ignoring:\n$_\n";
                } else {
                    confess "git push appears to have failed:\n$_\n";
                }
            }
            next if (/^##/);
            confess "git commit/push appears to have failed:\n$_\nfrom" . cwd() . "\n";
        }
        close PIPE;
    }
    chomp(my $version = `git rev-parse HEAD`);
    #printf "Version for %s is returned as $version\n", cwd();
    chdir $saveWD
      or confess "Couldn't cd back to saved wd $saveWD: $!\n";
    $recursionDepth--;
    return $version;
}

sub getVersion {
    my $configuration = $ENV{BUILD_STYLE};
    if ((!defined $configuration) || ($configuration eq "")) {
        $configuration = $ENV{CONFIGURATION};
    }
    my $version;
    if ($configuration =~ /distrib/i) {
        # warn "Checking for hacked strip wrapper...\n";
        # my $stripLocation = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip";
        # my $actualStripLocation = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip-actual";
        # if (!-e $stripLocation) {
        #     die "\nHmm.  Are you not running XCode from the Applications directory?\n";
        # }
        # if (!-e $actualStripLocation) {
        #     die "\nCannot build distribution version of this app without the hacked strip wrapper script\n\nTry runnning\n\n  sudo install-strip-wrapper.pl\n\n";
        # }
        # chomp(my $stripType = `file $stripLocation`);
        # $stripType =~ /perl.*script/
        #   or die "\nCannot build distribution version of this app without the hacked strip wrapper script\n\nTry runnning\n\n  sudo install-strip-wrapper.pl\n\n";
        # warn "...OK\n";
        $isDistributionBuild = 1;
        my $longVersion = verifyProjectForDistribution ".";
        $longVersion =~ /^(.......)/
          or confess "Unexpected version number return: $version\n";
        my $shortVersion = $1;
        $version = "g$shortVersion";
    } else {
        warn "Checking gitVersion...\n";
        chomp(my $gitVersion = `git rev-parse --short HEAD`);
        $gitVersion =~ /^(.......)$/
          or die "No git rev-parse fails for $gitVersion\n";
        warn "gitVersion is '$gitVersion'\n";
        $gitVersion =~ /^r1-(\d+)-(g[\dA-Za-z]+)$/
          or die "git describe fails to produce expected pattern:  Is there no 'r1' tag in this git repository, or has the format of 'git describe' changed?\n";
        $version = $2;
        my $modified = "";
        open PIPE, "git status|"
          or die "Couldn't open pipe to git st: $!\n";
        while (<PIPE>) {
            if (/modified:|added:|deleted:/) {
                if ($modified !~ /M/) {
                    $modified .= "M";
                }
            } elsif (/is ahead of/) {
                $modified .= "L";
            }
        }
        close PIPE;
        $version .= $modified;
    }
    print "The $configuration version is ", $version, "\n";
    if ($isDistributionBuild) {
        # OK as is
    } elsif ($configuration =~ /debug/i) {
	$version .= " [Debug]";
    } elsif ($configuration =~ /release/i) {
	$version .= " [Release]";
    } else {
	$version .= " [?????]";
	die "Unexpected build style $configuration\n";
    }
    return $version;
}

my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

sub getDate {
    my (undef, undef, undef, $d, $m, $y) = localtime;
    return sprintf "%04d %s %02d", $y + 1900, $months[$m], $d;
}

defined $ENV{INFOPLIST_PATH} && defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode\n";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!\n";

my $version = getVersion;

my $appFlavor = shift;

my $infoFile = "products/$appFlavor/Info.plist";

my $foundBundleVersion;
my $foundShortVersion;
open INFO, $infoFile
  or die "Couldn't read $infoFile: $!\n";
my $nextOneBundle = 0;
my $nextOneShort = 0;
while (<INFO>) {
    if (/>CFBundleVersion</) {
	$nextOneBundle = 1;
    } elsif ($nextOneBundle) {
	$foundBundleVersion = $1 if m/>([^<]+)</;
	$nextOneBundle = 0;
    } elsif (/>CFBundleShortVersionString/) {
        $nextOneShort = 1;
    } elsif ($nextOneShort) {
	$foundShortVersion = $1 if m/>([^<]+)</;
	$nextOneShort = 0;
    }
}
close INFO;

my $buildDate = localtime;
chomp(my $sandboxName = `pwd`);
my $debugInfo = "<br>Built $buildDate<br>$sandboxName";

defined $foundBundleVersion
  or die "Couldn't find pattern in $infoFile\n";
if (not defined $foundShortVersion) {
    $foundShortVersion = $foundBundleVersion;
}

my $fullVersion = $foundShortVersion . "_$version ($foundBundleVersion)";

my $srcDirectory = "$ENV{SRCROOT}/Version";
my $destDirectory = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/Help";

my $emeraldProduct = "Emerald $appFlavor";
$emeraldProduct =~ s/ChronometerHD/Chronometer HD/o;

sub makeFullVersionFile {
    my $topLevelsToCheck = "Classes Chronometer.xcodeproj ECVirtualMachineOps.m Help Version scripts Watches products ECTS.[hm]";

    my $pwd = `pwd`;

    open PIPE, "git status --verbose $topLevelsToCheck |"
	or die "Couldn't open pipe: $!";
    my @lines = <PIPE>;
    close PIPE;
    my $svnStatusOutput = join "", @lines;
    open PIPE, "git diff $topLevelsToCheck |"
	or die "Couldn't open pipe: $!";
    @lines = <PIPE>;
    close PIPE;
    my $svnDiffOutput = join "", @lines;

    open FVF, ">$destDirectory/FullVersion.txt"
	or die "Couldn't create FullVersion.txt: $!";
    print FVF <<EOF
$pwd
$svnDiffOutput

=================================================

$svnStatusOutput
EOF
    ;
    close FVF;
}

my $versionLine = "$emeraldProduct Version $fullVersion";
my $fullVersionToken = $fullVersion;

if (!$isDistributionBuild) {
    makeFullVersionFile;
    $versionLine = "$emeraldProduct Version $fullVersion$debugInfo";
    $fullVersionToken = "<a href=\"FullVersion.txt\">$fullVersion<\/a>";
}

my $htmlFile = "$srcDirectory/version.html";
my $newHtmlFile = "$destDirectory/versionGen.html";
unlink $newHtmlFile;
open HTML, $htmlFile
  or die "Couldn't read $htmlFile: $!\n";
open NEWHTML, ">$newHtmlFile"
  or die "Couldn't create $newHtmlFile: $!\n";
my $foundIt = 0;
while (<HTML>) {
    $foundIt = 1 if s/EMERALD_PRODUCT Version (.*)$/$versionLine/;
    print NEWHTML $_;
}
close NEWHTML;
close HTML;

$foundIt
    or die "Didn't find version pattern in $htmlFile\n";

chmod 0444, $newHtmlFile
    or die "Couldn't change permissions of $newHtmlFile to readonly: $!\n";
print "Updated $newHtmlFile\n";

$htmlFile = "$srcDirectory/ReleaseNotes.html";
$newHtmlFile = "$destDirectory/ReleaseNotesGen.html";
unlink $newHtmlFile;
open HTML, $htmlFile
  or die "Couldn't read $htmlFile: $!\n";
open NEWHTML, ">$newHtmlFile"
  or die "Couldn't create $newHtmlFile: $!\n";
$foundIt = 0;
my $date = getDate;
while (<HTML>) {
    $foundIt = 1 if s/Version \d(.\d+)+_XXXX \(YYYY Mmm DD\)/Version $fullVersionToken ($date)/i;
    print NEWHTML $_;
}
close NEWHTML;
close HTML;

$foundIt
    or die "Didn't find pattern in ReleaseNotes file\n";

chmod 0444, $newHtmlFile
    or die "Couldn't change permissions of $newHtmlFile to readonly: $!\n";
print "Updated $newHtmlFile\n";
