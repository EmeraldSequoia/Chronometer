#!/usr/bin/perl -w

use strict;

use IO::Handle;
STDOUT->autoflush(1);
STDERR->autoflush(1);

my $startPage = "http://www.pool.ntp.org/zone";

my %countryContinentHash = (
    "ad" => ["Europe", "Andorra"],
    "ae" => ["Asia", "United Arab Emirates"],
    "af" => ["Asia", "Afghanistan"],
    "ag" => ["NorthAmerica", "Antigua and Barbuda"],
    "ai" => ["NorthAmerica", "Anguilla"],
    "al" => ["Europe", "Albania"],
    "am" => ["Asia", "Armenia"],
    "an" => ["NorthAmerica", "Netherlands Antilles"],
    "ao" => ["Africa", "Angola"],
    "aq" => ["Oceania", "Antarctica"],
    "ar" => ["SouthAmerica", "Argentina"],
    "as" => ["Oceania", "American Samoa"],
    "at" => ["Europe", "Austria"],
    "au" => ["Oceania", "Australia"],
    "aw" => ["NorthAmerica", "Aruba"],
    "az" => ["Asia", "Azerbaijan"],
    "ba" => ["Europe", "Bosnia and Herzegovina"],
    "bb" => ["NorthAmerica", "Barbados"],
    "bd" => ["Asia", "Bangladesh"],
    "be" => ["Europe", "Belgium"],
    "bf" => ["Africa", "Burkina Faso"],
    "bg" => ["Europe", "Bulgaria"],
    "bh" => ["Asia", "Bahrain"],
    "bi" => ["Africa", "Burundi"],
    "bj" => ["Africa", "Benin"],
    "bm" => ["NorthAmerica", "Bermuda"],
    "bn" => ["Asia", "Brunei"],
    "bo" => ["SouthAmerica", "Bolivia"],
    "br" => ["SouthAmerica", "Brazil"],
    "bs" => ["NorthAmerica", "Bahamas"],
    "bt" => ["Asia", "Bhutan"],
    "bw" => ["Africa", "Botswana"],
    "by" => ["Europe", "Belarus"],
    "bz" => ["NorthAmerica", "Belize"],
    "ca" => ["NorthAmerica", "Canada"],
    "cd" => ["Africa", "Congo (Kinshasa)"],
    "cf" => ["Africa", "Central African Republic"],
    "cg" => ["Africa", "Congo (Brazzaville)"],
    "ch" => ["Europe", "Switzerland"],
    "ci" => ["Africa", "Ivory Coast"],
    "cl" => ["SouthAmerica", "Chile"],
    "cm" => ["Africa", "Cameroon"],
    "cn" => ["Asia", "China"],
    "co" => ["SouthAmerica", "Colombia"],
    "cr" => ["NorthAmerica", "Costa Rica"],
    "cu" => ["NorthAmerica", "Cuba"],
    "cv" => ["Africa", "Cape Verde"],
    "cx" => ["Oceania", "Christmas Island"],
    "cy" => ["Europe", "Cyprus"],
    "cz" => ["Europe", "Czech Republic"],
    "de" => ["Europe", "Germany"],
    "dj" => ["Africa", "Djibouti"],
    "dk" => ["Europe", "Denmark"],
    "dm" => ["NorthAmerica", "Dominica"],
    "do" => ["NorthAmerica", "Dominican Republic"],
    "dz" => ["Africa", "Algeria"],
    "ec" => ["SouthAmerica", "Ecuador"],
    "ee" => ["Europe", "Estonia"],
    "eg" => ["Africa", "Egypt"],
    "eh" => ["Africa", "Western Sahara"],
    "er" => ["Africa", "Eritrea"],
    "es" => ["Europe", "Spain"],
    "et" => ["Africa", "Ethiopia"],
    "fi" => ["Europe", "Finland"],
    "fj" => ["Oceania", "Fiji"],
    "fk" => ["SouthAmerica", "Falkland Islands"],
    "fm" => ["Oceania", "Micronesia"],
    "fo" => ["Europe", "Faroe Islands"],
    "fr" => ["Europe", "France"],
    "ga" => ["Africa", "Gabon"],
    "gb" => ["Europe", "United Kingdom"],
    "gd" => ["NorthAmerica", "Grenada"],
    "ge" => ["Asia", "Georgia"],
    "gf" => ["SouthAmerica", "French Guiana"],
    "gg" => ["Europe", "Guernsey"],
    "gh" => ["Africa", "Ghana"],
    "gi" => ["Europe", "Gibraltar"],
    "gl" => ["NorthAmerica", "Greenland"],
    "gm" => ["Africa", "Gambia"],
    "gn" => ["Africa", "Guinea"],
    "gp" => ["NorthAmerica", "Guadeloupe"],
    "gq" => ["Africa", "Equatorial Guinea"],
    "gr" => ["Europe", "Greece"],
    "gs" => ["SouthAmerica", "South Georgia and the South Sandwich Islands"],
    "gt" => ["NorthAmerica", "Guatemala"],
    "gu" => ["Oceania", "Guam"],
    "gw" => ["Africa", "Guinea-Bissau"],
    "gy" => ["SouthAmerica", "Guyana"],
    "hk" => ["Asia", "Hong Kong SAR China"],
    "hm" => ["Oceania", "Heard Island and McDonald Islands"],
    "hn" => ["NorthAmerica", "Honduras"],
    "hr" => ["Europe", "Croatia"],
    "ht" => ["NorthAmerica", "Haiti"],
    "hu" => ["Europe", "Hungary"],
    "id" => ["Asia", "Indonesia"],
    "ie" => ["Europe", "Ireland"],
    "il" => ["Asia", "Israel"],
    "im" => ["Europe", "Isle of Man"],
    "in" => ["Asia", "India"],
    "io" => ["Asia", "British Indian Ocean Territory"],
    "iq" => ["Asia", "Iraq"],
    "ir" => ["Asia", "Iran"],
    "is" => ["Europe", "Iceland"],
    "it" => ["Europe", "Italy"],
    "je" => ["Europe", "Jersey"],
    "jm" => ["NorthAmerica", "Jamaica"],
    "jo" => ["Asia", "Jordan"],
    "jp" => ["Asia", "Japan"],
    "ke" => ["Africa", "Kenya"],
    "kg" => ["Asia", "Kyrgyzstan"],
    "kh" => ["Asia", "Cambodia"],
    "ki" => ["Oceania", "Kiribati"],
    "kp" => ["Asia", "North Korea"],
    "kr" => ["Asia", "South Korea"],
    "kw" => ["Asia", "Kuwait"],
    "ky" => ["NorthAmerica", "Cayman Islands"],
    "kz" => ["Asia", "Kazakhstan"],
    "la" => ["Asia", "Laos"],
    "lb" => ["Asia", "Lebanon"],
    "lc" => ["NorthAmerica", "Saint Lucia"],
    "li" => ["Europe", "Liechtenstein"],
    "lk" => ["Asia", "Sri Lanka"],
    "lr" => ["Africa", "Liberia"],
    "ls" => ["Africa", "Lesotho"],
    "lt" => ["Europe", "Lithuania"],
    "lu" => ["Europe", "Luxembourg"],
    "lv" => ["Europe", "Latvia"],
    "ly" => ["Africa", "Libya"],
    "ma" => ["Africa", "Morocco"],
    "mc" => ["Europe", "Monaco"],
    "md" => ["Europe", "Moldova"],
    "mg" => ["Africa", "Madagascar"],
    "mh" => ["Oceania", "Marshall Islands"],
    "mk" => ["Europe", "Macedonia"],
    "ml" => ["Africa", "Mali"],
    "mm" => ["Asia", "Myanmar"],
    "mn" => ["Asia", "Mongolia"],
    "mo" => ["Asia", "Macao SAR China"],
    "mp" => ["Oceania", "Northern Mariana Islands"],
    "mq" => ["NorthAmerica", "Martinique"],
    "mr" => ["Africa", "Mauritania"],
    "ms" => ["NorthAmerica", "Montserrat"],
    "mt" => ["Europe", "Malta"],
    "mu" => ["Asia", "Mauritius"],
    "mv" => ["Asia", "Maldives"],
    "mw" => ["Africa", "Malawi"],
    "mx" => ["NorthAmerica", "Mexico"],
    "my" => ["Asia", "Malaysia"],
    "mz" => ["Africa", "Mozambique"],
    "na" => ["Africa", "Namibia"],
    "nc" => ["Oceania", "New Caledonia"],
    "ne" => ["Africa", "Niger"],
    "nf" => ["Oceania", "Norfolk Island"],
    "ng" => ["Africa", "Nigeria"],
    "ni" => ["NorthAmerica", "Nicaragua"],
    "nl" => ["Europe", "Netherlands"],
    "no" => ["Europe", "Norway"],
    "np" => ["Asia", "Nepal"],
    "nr" => ["Oceania", "Nauru"],
    "nu" => ["Oceania", "Niue"],
    "nz" => ["Oceania", "New Zealand"],
    "om" => ["Asia", "Oman"],
    "pa" => ["NorthAmerica", "Panama"],
    "pe" => ["SouthAmerica", "Peru"],
    "pf" => ["Oceania", "French Polynesia"],
    "pg" => ["Oceania", "Papua New Guinea"],
    "ph" => ["Asia", "Philippines"],
    "pk" => ["Asia", "Pakistan"],
    "pl" => ["Europe", "Poland"],
    "pm" => ["NorthAmerica", "Saint Pierre and Miquelon"],
    "pn" => ["Oceania", "Pitcairn"],
    "pr" => ["NorthAmerica", "Puerto Rico"],
    "ps" => ["Asia", "Palestinian Territory"],
    "pt" => ["Europe", "Portugal"],
    "pw" => ["Oceania", "Palau"],
    "py" => ["SouthAmerica", "Paraguay"],
    "qa" => ["Asia", "Qatar"],
    "ro" => ["Europe", "Romania"],
    "ru" => ["Europe", "Russia"],
    "rw" => ["Africa", "Rwanda"],
    "sa" => ["Asia", "Saudi Arabia"],
    "sb" => ["Oceania", "Solomon Islands"],
    "sc" => ["Asia", "Seychelles"],
    "sd" => ["Africa", "Sudan"],
    "se" => ["Europe", "Sweden"],
    "sg" => ["Asia", "Singapore"],
    "sh" => ["Africa", "Saint Helena"],
    "si" => ["Europe", "Slovenia"],
    "sj" => ["Europe", "Svalbard and Jan Mayen"],
    "sk" => ["Europe", "Slovakia"],
    "sl" => ["Africa", "Sierra Leone"],
    "sm" => ["Europe", "San Marino"],
    "sn" => ["Africa", "Senegal"],
    "so" => ["Africa", "Somalia"],
    "sr" => ["SouthAmerica", "Suriname"],
    "st" => ["Africa", "Sao Tome and Principe"],
    "sv" => ["NorthAmerica", "El Salvador"],
    "sy" => ["Asia", "Syria"],
    "sz" => ["Africa", "Swaziland"],
    "td" => ["Africa", "Chad"],
    "tg" => ["Africa", "Togo"],
    "th" => ["Asia", "Thailand"],
    "tj" => ["Asia", "Tajikistan"],
    "tl" => ["Oceania", "East Timor"],
    "tm" => ["Asia", "Turkmenistan"],
    "tn" => ["Africa", "Tunisia"],
    "to" => ["Oceania", "Tonga"],
    "tr" => ["Europe", "Turkey"],
    "tt" => ["NorthAmerica", "Trinidad and Tobago"],
    "tv" => ["Oceania", "Tuvalu"],
    "tw" => ["Asia", "Taiwan"],
    "tz" => ["Africa", "Tanzania"],
    "ua" => ["Europe", "Ukraine"],
    "ug" => ["Africa", "Uganda"],
    "uk" => ["Europe", "United Kingdom"],
    "um" => ["NorthAmerica", "United States Minor Outlying Islands"],
    "us" => ["NorthAmerica", "United States"],
    "uy" => ["SouthAmerica", "Uruguay"],
    "uz" => ["Asia", "Uzbekistan"],
    "va" => ["Europe", "Vatican"],
    "vc" => ["NorthAmerica", "Saint Vincent and the Grenadines"],
    "ve" => ["SouthAmerica", "Venezuela"],
    "vg" => ["NorthAmerica", "British Virgin Islands"],
    "vi" => ["NorthAmerica", "U.S. Virgin Islands"],
    "vn" => ["Asia", "Vietnam"],
    "vu" => ["Oceania", "Vanuatu"],
    "ws" => ["Oceania", "Samoa"],
    "ye" => ["Asia", "Yemen"],
    "yu" => ["Europe", "Serbia And Montenegro"],
    "za" => ["Africa", "South Africa"],
    "zm" => ["Africa", "Zambia"],
    "zw" => ["Africa", "Zimbabwe"],
);

my %recommendedServersForZone;
my %continentServersForZone;
my %continentPoolForZone;
my %countryCodesListed;

sub doPage {
    my $zoneCode = shift;
    my $continentZone = shift;
    my @continentFarm = @_;
    my $url = "$startPage/$zoneCode";
    # print "\n **** $url\n";
    open PIPE, "curl -s $url |"
      or die "Couldn't open pipe\n";
    my @serverFarm;
    my @urls;
    while (<PIPE>) {
	if (m%<a href=\"/zone/([^\"]+)\">([^<]+)<.*; ([-a-z\.]+\.ntp\.org)%) {
	    my $zoneURL = $1;
	    my $zoneName = $2;
	    my $zoneServer = $3;
	    #print "\nZone URL: $zoneURL\n";
	    #print "Zone Name: $zoneName\n";
	    #print "Server: $zoneServer\n";
	    push @urls, $zoneURL;
	} elsif (/server (\d\.[^\.]+\.pool\.ntp\.org)/) {
	    my $thisServerFarm = $1;
	    push @serverFarm, $thisServerFarm;
	}
    }
    close PIPE;
    if (scalar @serverFarm) {
	#print "$zoneCode $serverFarm[0]\n";
	$recommendedServersForZone{$zoneCode} = [@serverFarm];
	$continentServersForZone{$zoneCode} = [@continentFarm];
	$continentPoolForZone{$zoneCode} = $continentZone;
    } else {
	warn "No server farm listed for $zoneCode\n" if $zoneCode ne "\@";
    }
    foreach my $url (@urls) {
	doPage($url, $zoneCode, @serverFarm);
    }
}

doPage "@";

print "CONTINENTS\n";

foreach my $zone (sort keys %recommendedServersForZone) {
    next if $zone =~ /^..$/;  # Skip countries first pass
    foreach my $server (@{$recommendedServersForZone{$zone}}) {
	printf "%13s %s\n", $zone, $server;
    }
}

print "\nCOUNTRIES\n";

sub continentServersNotIncludedInCountryServers {
    my $continentServers = shift;
    my $countryServers = shift;
    my %countryServerHash;
    foreach my $countryServer (@$countryServers) {
	$countryServerHash{$countryServer} = 1;
    }
    my @uniqueServers;
    foreach my $server (@$continentServers) {
	push @uniqueServers, $server if not defined $countryServerHash{$server};
    }
    return [@uniqueServers];
}

foreach my $zone (sort keys %recommendedServersForZone) {
    next if $zone !~ /^..$/;  # Skip countries first pass
    print "\n";
    foreach my $server (@{$recommendedServersForZone{$zone}}) {
	printf "%10s %s\n", $zone, $server;
    }
    my $nonredundantContinentServers = continentServersNotIncludedInCountryServers $continentServersForZone{$zone}, $recommendedServersForZone{$zone};
    foreach my $server (@$nonredundantContinentServers) {
	printf "%10s %s\n", $zone, $server;
    }
}

foreach my $poolCountry (sort keys %recommendedServersForZone) {
    next if $poolCountry !~ /^..$/;
    if (!defined $countryContinentHash{$poolCountry}) {
	die "No listing for $poolCountry in script's list of countries\n";
    }
}

my %sortOrderByCountry;

READFILE:
while (1) {
    warn "Enter the by-country sales data from a nightly EC sales summary mail (beginning with the line that says 'Total all countries (2008.07.28 => ...')\n";
    print STDERR "into a file, and enter that filename here: ";
    chomp(my $file = <STDIN>);
    -e $file
	or next;
    if (!open F, $file) {
	warn "$!\n";
	next;
    }
  LINE:
    while (<F>) {
      chomp;
      if (/Total all countries \(2008\.07\.28 =>/) {
	  last READFILE;
      }
    }
    warn "File must have the line 'Total all countries (2008.07.28 ...'\n";
}
my $rank = 1;
while (<F>) {
    my ($count, $code) = split;
    $sortOrderByCountry{lc $code} = $rank++;
}
close F;

my @sortedKeys = sort {
    my $ax = ($a eq "uk") ? "gb" : $a;
    my $bx = ($b eq "uk") ? "gb" : $b;
    my $sortA = $sortOrderByCountry{$ax};
    my $sortB = $sortOrderByCountry{$bx};
    if (defined $sortA) {
	if (defined $sortB) {
	    return $sortA - $sortB;
	} else {
	    return -1;
	}
    } elsif (defined $sortB) {
	return 1;
    } else {
	return $a cmp $b;
    }
} keys %countryContinentHash;

# OK, now generate code
my $countryCount = scalar keys %countryContinentHash;
print <<EOF


// Following table generated by scripts/getNTPPoolServers.pl
static const int numCountryFarmDescriptors = $countryCount;
static const CountryFarmDescriptor countryFarmDescriptors[$countryCount] = {
EOF
  ;

foreach my $zone (@sortedKeys) {
    my $lookupZone = $zone;
    if ($lookupZone eq "gb") {
	$lookupZone = "uk";
    }
    my ($continent, $countryComment) = @{$countryContinentHash{$zone}};
    if (defined $recommendedServersForZone{$lookupZone}) {
	my $serverCount = 0;
	my $continentZone = $continentPoolForZone{$lookupZone};
	defined $continentZone
	  or die;
	my $checkContinent = lc $continentZone;
	$checkContinent =~ s/-//go;
	if ($checkContinent ne lc $continent) {
	    if ($zone eq "tr") {
		warn "Overriding continent for Turkey to $continent\n";
	    } else {
		die "Continents for $zone don't agree: $continentZone and $continent\n";
	    }
	}
	my @serverList = @{$recommendedServersForZone{$lookupZone}};
	foreach my $server (@serverList) {
	    $server =~ s/^\d\.//o
	      or die "Server for $zone in unexpected format: $server\n";
	    if ($server =~ /^$lookupZone\./) {
		$serverCount++;
	    } else {
		# Just for verification, make sure it's either the continent or the global zone
		if ($server !~ /^$continentZone\.|^pool\.ntp\.org$/) {
		    die "Server for $zone not country, continent, or global: $server\n";
		}
	    }
	}
	print <<EOF
{ "$zone", "$lookupZone", $serverCount, \&$continent},  // $countryComment
EOF
	  ;
    } else {
	print <<EOF
{ "$zone", "$lookupZone", 0, \&$continent },  // $countryComment
EOF
	  ;
    }
}

print <<EOF
};
EOF
  ;

