package AndroidDeviceSelector;

require Exporter;

use Carp;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(getDeviceId);
our @EXPORT_OK = qw();
our @VERSION = 1.00;

my $devicesById = {};

sub getDevices {
    my $cmd = "adb devices -l";
    open PIPE, "$cmd |"
      or die "Couldn't run 'adb devices -l' to get device list\n";
    my @deviceLines = <PIPE>;
    close PIPE;

    my %devices;
    foreach my $deviceLine (@deviceLines) {
        chomp $deviceLine;
        next if $deviceLine =~ /^List of devices/;
        next if $deviceLine =~ /^$/;
        next if $deviceLine =~ /offline/;
        my $deviceDescriptor = {};
        $deviceLine =~ /^(\S+)\s+device (usb:(\S+) )?product:(\S+) model:(\S+) device:(\S+)/
          or die "Didn't recognize line in 'adb -l' output:\n$deviceLine\n";
        $deviceDescriptor->{deviceId} = $1;
        $deviceDescriptor->{usb} = $3;
        $deviceDescriptor->{product} = $4;
        $deviceDescriptor->{model} = $5;
        $deviceDescriptor->{device} = $6;
        $devices{$deviceDescriptor->{deviceId}} = $deviceDescriptor;
    }
    return \%devices;
}

sub getHumanNameForDevice {
    my $deviceDescriptor = shift;
    if ($deviceDescriptor->{model} =~ /^sdk_google/) {
        return $deviceDescriptor->{deviceId};  # "emulator-5554"
    }
    return $deviceDescriptor->{model};
}

sub warnWithListOfDevices {
    warn "Available devices:\n";
    my $index = 0;
    my @deviceIds;
    foreach my $deviceId (sort { getHumanNameForDevice($devicesById->{$a}) cmp getHumanNameForDevice($devicesById->{$b}) } keys %$devicesById) {
        my $device = $devicesById->{$deviceId};
        $index++;
        warn sprintf "%d %-20s%s\n", $index, getHumanNameForDevice($device), $deviceId;
        push @deviceIds, $deviceId;
    }
    return @deviceIds;
}

sub getDeviceId {
    my $lookingForDeviceId = 0;
    foreach my $arg (@ARGV) {
        if ($lookingForDeviceId) {
            my $deviceId = $arg;
            if (defined $devicesById->{$deviceId}) {
                my $humanName = getHumanNameForDevice($devicesById->{$deviceId});
                warn "Using -d, device is $humanName ($deviceId)\n";
                return $deviceId, $humanName;
            } else {
                warn "-d lists nonexistent device id ($deviceId)\n";
            }
            last;
        }
        $lookingForDeviceId = ($arg eq "-d");
    }
    my $deviceId = $ENV{ANDROID_SERIAL};
    if (defined $deviceId) {
        if (defined $devicesById->{$deviceId}) {
            my $humanName = getHumanNameForDevice($devicesById->{$deviceId});
            warn "Using ANDROID_SERIAL environment variable, device is $humanName ($deviceId)\n";
            return $deviceId;
        } else {
            warn "ANDROID_SERIAL environment variable has nonexistent device id ($deviceId)\n";
        }
    }
    my $index = -1;
    my @deviceIds;
    while (1) {
        my @deviceIds = warnWithListOfDevices;
        my $largestIndex = scalar @deviceIds;
        if ($largestIndex == 0) {
            die "No online devices\n";
        }
        if ((defined $ARGV[0]) && ($ARGV[0] =~ /^([0-9]+)$/)) {
            my $index = $1;
            if ($index <= $largestIndex) {
                my $humanName = getHumanNameForDevice($devicesById->{$deviceIds[$index - 1]});
                warn "Using index $index: $humanName\n";
                return $deviceIds[$index - 1], $humanName;
            }
        }
        if ($largestIndex == 1) {
            print STDERR "Confirm use of only device (y/n) [Y]: ";
            chomp($index = <STDIN>);
            if ($index =~ /^y$|^$/i) {
                my $humanName = getHumanNameForDevice($devicesById->{$deviceIds[0]});
                return $deviceIds[0], $humanName;
            }
        } else {
            print STDERR "Enter number (from 1 to $largestIndex): ";
            chomp($index = <STDIN>);
            if ($index >= 1 && $index <= $largestIndex) {
                my $humanName = getHumanNameForDevice($devicesById->{$deviceIds[$index - 1]});
                return $deviceIds[$index - 1], $humanName;
            }
        }
        warn "Invalid response\n";
    }
}

$devicesById = getDevices;

1;
