#!/usr/bin/perl -w

# This script traverses the simulator directory, constructing a hierarchy of links to installed
# simulator applications, by device and by app.

# Strict checking
use strict;

# Standard Perl modules
use Data::Dumper;
use File::Basename;
use File::Copy qw/cp/;
use File::Path;
use IO::Handle;
use Cwd;
use Carp;


STDOUT->autoflush(1);
STDERR->autoflush(1);

my $silent = 0;
if ((defined $ARGV[0]) && $ARGV[0] =~ /-s/i) {
    shift;
    $silent = 1;
}

sub createLink {
    my $to = shift;
    my $from = shift;
    my $existingSameOK = shift;
    (defined $to) and (defined $from)
      or confess "Missing parameter";
    if (-l $from) {
        my $exist = readlink $from;
        if ($to eq $exist) {
            warn "Skipping pre-existing link $from => $to\n" if not $existingSameOK;
            return;
        } else {
            die "Link already exists but pointing to the wrong place: '$from' => '$exist' instead of '$from' => '$to'\n";
        }
    }
    symlink $to, $from
      or die "Couldn't link from $from to $to: $!\n";
}

sub createDirectory {
    my $directory = shift;
    defined $directory
      or confess "Missing \$directory parameter";
    mkdir $directory, 0777
      or confess "Couldn't create directory $directory: $!";
}

sub renameFile {
    my $from = shift;
    my $to = shift;
    rename $from, $to
      or die "Couldn't rename $from to $to: $!\n";
}

# TODO(spucci): Use a real plist parser, if we can find one without too many dependencies...
sub getPlist {
    my $pListFile = shift;
    open PLIST, $pListFile
      or die "Couldn't open $pListFile: $!\n";
    my @currentDictsByLevel = ({});
    my $currentDepth = 0;
    my $key;
    while (<PLIST>) {
        my $newKey;
        if (m%<plist%) {
            $newKey = "plist";
        } elsif (m%</plist>%) {
            $currentDepth == 0
              or die "Depth $currentDepth not zero as expected\n";
            close PLIST;
            last;
        } elsif (m%<dict>%) {
            defined $key
              or die "No key defined";
            my $newDict = {};
            $currentDictsByLevel[$currentDepth]->{$key} = $newDict;
            $currentDictsByLevel[++$currentDepth] = $newDict;
        } elsif (m%</dict>%) {
            $currentDepth--;
        } elsif (m%<key>([^<]+)</key>%) {
            $newKey = $1;
        } elsif (m%<string>([^<]+)</string>%) {
            defined $key
              or die "No key defined";
            $currentDictsByLevel[$currentDepth]->{$key} = $1;
        } elsif (m%<true/>%) {
            defined $key
              or die "No key defined";
            $currentDictsByLevel[$currentDepth]->{$key} = 1;
        } elsif (m%<false/>%) {
            defined $key
              or die "No key defined";
            $currentDictsByLevel[$currentDepth]->{$key} = 0;
        }
        $key = $newKey;
    }
    close PLIST;
    defined $currentDictsByLevel[0]->{"plist"}
      or die "Didn't find <plist> at top level\n";
    return $currentDictsByLevel[0]->{"plist"}
}

((-d "scripts") &&
 (-d "specs") &&
 (-d "tools")) or die "Must run at Chronometer root directory\n";

my $simulatorLinkRoot = "sims";

if (-e $simulatorLinkRoot) {
    rmtree $simulatorLinkRoot
      or die "Couldn't remove existing simulator link tree at $simulatorLinkRoot: $!\n";
}

createDirectory $simulatorLinkRoot;
createDirectory "$simulatorLinkRoot/os";
my $appLinkDir = "$simulatorLinkRoot/app";
createDirectory $appLinkDir;

my $simulatorAppDir = "$ENV{HOME}/Library/Developer/CoreSimulator/Devices";
opendir DIR, $simulatorAppDir
  or die "Couldn't read directory $simulatorAppDir: $!\n";
my @entries = grep !/\.|device_set\.plist/, readdir DIR;
closedir DIR;

# my $devicePlist = getPlist("$simulatorAppDir/device_set.plist");

# print Dumper($devicePlist);

# while (my ($key, $value) = each %$devicePlist->{DevicePairs}) {
#     my $gizmo = $value->{"gizmo"};
#     my $companion = $value->{"companion"};
#     my $devicePath = "$simulatorAppDir/$companion";
#     if (-d $devicePath) {
#         # print "$devicePath EXISTS\n";
#         my $deviceDescriptorPlist = getPlist("$devicePath/device.plist");
#         # print Dumper($deviceDescriptorPlist);
#         my $runtime = $deviceDescriptorPlist->{"runtime"};
#         $runtime =~ s/com\.apple\.CoreSimulator\.SimRuntime\.iOS-//o;
#         $runtime =~ s/-/./go;
#         my $name = $deviceDescriptorPlist->{"name"};
#         print "$runtime $name\n";
#     } else {
#         print "$devicePath MISSING\n";
#     }
# }

my @sims;
foreach my $entry (@entries) {
    my $devicePath = "$simulatorAppDir/$entry";
    my $applicationsPath = "$devicePath/data/Containers/Data/Application";
    if (-d $applicationsPath) {
        # print "$applicationsPath EXISTS\n";
        my $deviceDescriptorPlist = getPlist("$devicePath/device.plist");
        # print Dumper($deviceDescriptorPlist);
        my $runtime = $deviceDescriptorPlist->{"runtime"};
        $runtime =~ s/com\.apple\.CoreSimulator\.SimRuntime\.iOS-//o;
        $runtime =~ s/-/./go;
        $runtime =~ s/^([^1-7])/ $1/o;
        my $name = $deviceDescriptorPlist->{"name"};
        push @sims, ["$runtime $name", $applicationsPath];
        print "Pushing '$runtime $name'\n";
    } else {
        # print "$applicationsPath MISSING\n";
    }
}

# Hashes of [$dir, $mtime]
my $latestByOs = {};
my $latestByApp = {};

sub checkLatest {
    my $hash = shift;
    my $dir = shift;
    my $name = shift;
    my $age = shift;

    if (exists $hash->{$name}) {
        if ($hash->{$name}->[1] > $age) {
            $hash->{$name}->[0] = $dir;
            $hash->{$name}->[1] = $age;
        }
    } else {
        $hash->{$name} = [$dir, $age];
    }
}

@sims = sort {$$a[0] cmp $$b[0]} @sims;
foreach my $sim (@sims) {
    my $name = $$sim[0];
    my $name_as_file = $name;
    $name_as_file =~ s/^ *//go;
    $name_as_file =~ s/ /-/go;
    $name_as_file =~ s/[()]//go;
    my $nameLinkDir = "$simulatorLinkRoot/os/$name_as_file";
    createDirectory $nameLinkDir;
    my $applicationsPath = $$sim[1];
    # print "$name\n";
    # print "$applicationsPath\n";
    if (-d $applicationsPath) {
        opendir DIR, $applicationsPath
          or die "Couldn't read directory $applicationsPath: $!\n";
        my @applications = grep !/^\./, readdir DIR;
        closedir DIR;
        foreach my $applicationDir (@applications) {
            my $preferencesDir = "$applicationsPath/$applicationDir/Library/Preferences";
            # printf "...app $preferencesDir\n";
            my $documentsDir = "$applicationsPath/$applicationDir/Documents";
            if (-d $preferencesDir and -d $documentsDir) {
                opendir DIR, $preferencesDir
                  or die "Couldn't read directory $preferencesDir: $!\n";
                my @preferencesEntries = grep !/^com\.apple/, grep /\.plist$/, readdir DIR;
                closedir DIR;
                next if (scalar @preferencesEntries) == 0;
                (scalar @preferencesEntries == 1)
                  or die "found non-one at $preferencesDir\n";
                foreach my $pref (@preferencesEntries) {
                    my $appName = $pref;
                    $appName =~ s/\.plist$//o;
                    # If either of these createLinks fails, it means we have more than one entry for
                    # name/app, and we should make a list of them.
                    createLink "$applicationsPath/$applicationDir", "$nameLinkDir/$appName", 1;
                    my $appDir = "$appLinkDir/$appName";
                    if (!-d $appDir) {
                        createDirectory $appDir;
                    }
                    createLink "$applicationsPath/$applicationDir", "$appDir/$name_as_file", 1;
                    my $prefAge = -M "$preferencesDir/$pref";
                    checkLatest $latestByOs, "$appName", "$name_as_file", $prefAge;
                    checkLatest $latestByApp, "$name_as_file", "$appName", $prefAge;
                    checkLatest $latestByApp, "app/$appName/$name_as_file", "latest", $prefAge;
                }
            }
        }
    } else {
        warn "No Application directory at $applicationsPath\n";
    }
}

#print Dumper($latestByOs);
#print Dumper($latestByApp);

while (my ($name, $descriptor) = each %$latestByOs) {
    createLink $descriptor->[0], "$simulatorLinkRoot/os/$name/latest"
}

while (my ($name, $descriptor) = each %$latestByApp) {
    if ($name ne "latest") {
        createLink $descriptor->[0], "$simulatorLinkRoot/app/$name/latest"
    }
}

exists $latestByApp->{"latest"}
  or die "Didn't find 'latest' entry in latestByApp\n";
createLink $latestByApp->{"latest"}->[0], "$simulatorLinkRoot/latest";

if (!$silent) {
    print "Done, look in sims/ for results.\n";
    print "\n";
    print "Note that you will have to run this script again EVERY TIME YOU RUN AN APP as apps move around\n";
}
