#!/usr/bin/perl -w

use strict;

use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $project = "Chronometer.xcodeproj";
my $target = "HenryForAndroid";
my $buildConfig = "Debug";

my $platform = "iphonesimulator";

sub build {
    open PIPE, "xcodebuild -parallelizeTargets -target '$target' -configuration '$buildConfig' -project $project -destination 'platform=iOS Simulator,name=iPhone 4S,OS=8.1' 2>&1 |"
	or die "Couldn't open pipe: $!\n";
    while (<PIPE>) {
	next if /^    setenv/;
	next if /^    cd/;
	next if /^$/;
	next if /^GenerateDSYMFile/;
	next if /^Touch/;
	next if /^Checking Dependencies/;
	next if /^PhaseScriptExecution/;
	next if m%^    .*/usr/bin/dsymutil%    ;
	next if m%^    .*/usr/bin/gcc%;
	next if m%^    /usr/bin/touch%;
	next if m%^    /bin/sh -c%;
	print;
    }
    close PIPE;
}

sub killInSim {
    system("killall -v -SIGTERM $target");
}

sub launchInSim {
    open PIPE, "|osascript >& /dev/null"
      or die "Couldn't open pipe to osascript: $!\n";
    print PIPE <<EOF
      tell application "Xcode" to launch project "$target"
      tell application "iPhone Simulator" to activate
EOF
      ;
    close PIPE;
    print "Launching in simulator...\n";
}

if (build) {
    killInSim;
    # Sleep 1/2 second
    select(undef, undef, undef, 0.5);
    launchInSim;
    select(undef, undef, undef, 4.0);
    system("scripts/recordLastInstall.pl");
    select(undef, undef, undef, 5.0);
    system("ls -l \"install/Documents/archive/Haleakala/front-atlas.png\"");
    system("open -a \"Adobe Photoshop CS3\" \"install/Documents/archive/Haleakala/front-atlas.png\"");
}
