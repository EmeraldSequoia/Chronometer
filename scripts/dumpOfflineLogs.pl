#!/usr/bin/perl -w

use strict;

# This script was originally intended to send a broadcast intent to a running Chronometer instance, causing it to dump all of its "offline logs" to the log now.

# NOTE: It's almost certainly better to just use the script pullAndroidOfflineLogs.pl.  I'm leaving this here as an example of how to
# use a script to cause an activity to be invoked.

use FindBin;
use lib $FindBin::Bin;

use AndroidDeviceSelector;

my ($device, $humanName) = getDeviceId;

system("adb -s $device shell am broadcast -a com.emeraldsequoia.chronometer.wearable.OfflineLogger.DUMPLOGS");
