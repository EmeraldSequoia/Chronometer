#!/usr/bin/perl -w

use strict;

# Standard modules
use File::Copy;
use File::Path;
use IO::Handle;

# Special Perl modules
use LWP::UserAgent;
use Crypt::SSLeay;

# Local modules:
use lib "/Users/spucci/bin";
use mail;
use GetPage;

STDOUT->autoflush(1);
STDERR->autoflush(1);

our $cookieJar = "/tmp/fetch2Cookie.txt";

our $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/4.0 (compatible; MSIE 5.12; Mac_PowerPC)");
$ua->cookie_jar(HTTP::Cookies->new(file => $cookieJar, autosave => 0));

my $url = "http://www.world-airport-codes.com/world-top-30-airports.html";

sub parseLatLong {
    my $str = shift;
    $str =~ /^(\d+)\&#176; (\d+)\&\#8217; (\d+)\&\#8221; ([NSEW]) *$/
      or die "Bad lat/long '$str'\n";
    my $deg = $1;
    my $min = $2;
    my $sec = $3;
    my $dir = $4;
    my $angle = $deg + ($min / 60) + ($sec / 3600);
    if ($dir =~ /[WS]/) {
	$angle = -$angle;
    }
    return $angle;
}

my $response = $ua->get($url);
my $page = $response->as_string;
my $count = 0;
foreach my $line (split /[\r\n]/, $page) {
    if ($line =~ m!<span class="airport"><a href=\"([^"]+)\"!) {
	my $airportURL = "http://www.world-airport-codes.com$1";
	#print "Airport URL: $airportURL\n";
	my $resp = $ua->get($airportURL);
	if (!$resp->is_success) {
	    die $resp->status_line;
	}
	my $pg = $resp->as_string;
	my $keyName;
	my %keys;
	foreach my $ln (split /[\r\n]/, $pg) {
	    if (defined $keyName) {
		if ($ln =~ m!<span class="detail">: ([^<]+) ?<!) {
		    #print "$keyName => $1\n";
		    my $value = $1;
		    $value =~ s/^ *//go;
		    $value =~ s/ *$//go;
		    $keys{$keyName} = $value;
		}
		$keyName = undef;
		next;
	    }
	    if ($ln =~ m!<label class="detail">([^<]+)<!) {
		$keyName = $1;
	    }
	}
	my $latString = $keys{Latitude};
	my $latitude = parseLatLong $latString;
	my $longString = $keys{Longitude};
	my $longitude = parseLatLong $longString;
	print $keys{"Airport Name"} . "+" . $keys{"Airport Code"} . "\t" . $keys{City} . "\t" . $keys{"Country Abbrev."} . " \t$latitude\t$longitude\n";
    }
}
