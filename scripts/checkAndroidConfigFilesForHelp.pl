#!/usr/bin/perl -w

use strict;

use Cwd;

chdir "android/project/BaseLib/src/java/base/com/emeraldsequoia/chronometer/wearable"
  or die "Couldn't cd\n";

opendir DIR, "."
  or die;
my @checkFiles = grep /WearableConfigActivity\.java$/, readdir DIR;
closedir DIR;

foreach my $checkFile (@checkFiles) {
    # warn "\n$checkFile\n";
    open F, $checkFile
      or die;
    my $foundSomething = 0;
    my $extendsHelpOnly = 0;
    my $showHelpDefined = 0;
    while (<F>) {
        if (/extends HelpOnlyConfigActivity/) {
            $extendsHelpOnly = 1;
        }
        if ($extendsHelpOnly && /super\(/) {
            # warn "... help only, file is " . $_;
            $foundSomething = 1;
        }
        if (/onShowHelpClicked/) {
            $showHelpDefined = 1;
        }
        if ($showHelpDefined && /showHelpOnCompanionPhone\(\"([^\"]+)\"\)/) {
            # warn "... onShowHelpClicked, file is " . $1 . "\n";
            $foundSomething = 1;
        }
    }
    close F;
    if (!$foundSomething) {
        warn "**** ERROR *****  NOTHING FOUND FOR $checkFile\n";
    }
}
