#!/usr/bin/perl -w

use strict;

use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $doAirports = 0;

my $locationDir = "locationData";

-d $locationDir
  or die "Run this script at the top of the sandbox hierarchy\n";

unlink "$locationDir/loc-names.dat";
open NAMES, ">$locationDir/loc-names.dat"
  or die;

unlink "$locationDir/loc-data.dat";
open DATA, ">$locationDir/loc-data.dat"
  or die;

unlink "$locationDir/loc-index.dat";
open INDEX, ">$locationDir/loc-index.dat"
  or die;

unlink "$locationDir/loc-tz.dat";
open TZ, ">$locationDir/loc-tz.dat"
  or die;

my $currentIndex = 0;

my %tzNameHash;
my $tzCount = 0;

my %ccAdmin1Hash;  # Hash by displayCity+CC+A1 code of count of cities with that designation (when count > 1, we need admin2)

my %altNames = (  # Map from ascii name to an English name we also want to search for.
		  # If we want more than one alternate name, separate with "+" on right-hand side
		"Muenchen" => "Munich",
		"Mumbai" => "Bombay",
		"Beijing" => "Peking",
		"Bengaluru" => "Bangalore",
		"Chennai" => "Madras",
                "Nandi" => "Nadi",
		"Chongqing" => "Chungking",
		"Guangzhou" => "Canton",
		"Nanjing" => "Nanking",
		"Roma" => "Rome",
		"Faisalabad" => "Lyallpur",
		"Bucuresti" => "Bucharest",
		"Ha Noi" => "Hanoi",
		"Praha" => "Prague",
		"Kinshasa" => "Leopoldville",
		"Lubumbashi" => "Elizabethville",
		"Kisangani" => "Stanleyville",
		"Tianjin" => "Tientsin",
		"Xian" => "Sian",
		"Dalian" => "Darien",
		"Al Jizah" => "Giza",
		"Jakarta" => "Djakarta",
		"Al Basrah" => "Basra",
		"Almaty" => "Alma Ata",
		"Tombouctou" => "Timbuktu",
	       # map a few the other way
		"Cairo" => "Al Qāhirah",
		"Khartoum" => "Al Khartum",
		"Bangkok" => "Krung Thep",
		"Florence" => "Firenze",
		"Vienna" => "Wien",
		"Calcutta" => "Kolkata",
	       # plus a few special cases:
		"Hong Kong" => "Victoria",
		"Los Angeles" => "LA",
		"Emerald Lake Hills" => "Emerald Hills",
		"Thanh pho Ho Chi Minh" => "Saigon",
		"Saint Petersburg" => "Leningrad",
		"Volgograd" => "Stalingrad",
	       );

my %populationCorrectors = (  # Map for corrections to the population for given cities based on asciiname
			    "Juan Dolio" => 1000,
			    );
# Stats only:
my $cityCount = 0;
my $totalPopulation = 0;

sub insertCommas {
    my $number = shift;
    my ($integer, $fraction);
    if ($number =~ /(-?\d+)\.(\d*)/) {
	$integer = $1;
	$fraction = $2;
    } else {
	$integer = $number;
    }
    $fraction = "" if not defined $fraction;
    $integer =~ s/(\d)(\d\d\d)$/$1,$2/go;
    while ($integer =~ s/(\d)(\d\d\d,)/$1,$2/go) {
    }
    if ($fraction ne "") {
	return "$integer.$fraction";
    } else {
	return $integer;
    }
}

my %tzCorrections;

sub readTimezoneCorrections {
    open TZC, "$locationDir/timezoneCorrections.txt"
      or die "Couldn't read $locationDir/timezoneCorrections.txt: $!\n";
    while (<TZC>) {
	chomp;
	my ($city, $cc, $a1, $a2, $tz) = split /,/;
	my $key = "$city+$cc+$a1+$a2";
	$tzCorrections{$key} = $tz;
    }
    close TZC;
}

readTimezoneCorrections;

sub readRawFile {
    my $rawFile = shift;
    open RAW, $rawFile
      or die "Couldn't read $locationDir/cities1000.txt: $!\n";
    while (<RAW>) {
	chomp;   # Remove trailing NL
	die "Delimiter '+' appears in data line:\n" . $_ if /\+/;
	my ($geonameid, $name, $asciiname, $alternatenames, $latitude, $longitude, $featureClass, $featureCode,
	    $countryCode, $cc2, $admin1Code, $admin2Code, $admin3Code, $admin4Code, $population, $elevation, $gtopo30, $timezoneID, $modDate) = split /\t/;
	
	my $tzCorrectionKey = "$asciiname+$countryCode+$admin1Code+$admin2Code";
	my $correctedTZ = $tzCorrections{$tzCorrectionKey};
	if (defined $correctedTZ) {
	    if ($correctedTZ eq "USED") {
		die "Specification for corrected tz city not unique: $tzCorrectionKey\n";
	    } else {
		if ($correctedTZ eq $timezoneID) {
		    warn "TZ correction for city apparently no longer required: $tzCorrectionKey is already $timezoneID\n";
		} else {
		    #warn "$tzCorrectionKey: $timezoneID => $correctedTZ\n";
		    $timezoneID = $correctedTZ;
		}
		$tzCorrections{$tzCorrectionKey} = "USED";
	    }
	}
	
	my $archiveName;  # The search string, with the display name ($name) last
	if ($name eq $asciiname) {
	    $archiveName = $name;
	} else {
	    $archiveName = "$asciiname+$name";
	}
	my $altName = $altNames{$asciiname};
	if (defined $altName) {
	    $archiveName = "$altName+$archiveName";
	}
	print NAMES "$archiveName\0";
	my $indexData = pack("L",$currentIndex);
	$currentIndex += (1 + do {use bytes; length $archiveName});
	print INDEX $indexData;
	
	my $nameStr = "$name+$countryCode+$admin1Code";   # Checking for duplicate names when just cc and a1 are specified
	if (defined $ccAdmin1Hash{$nameStr}) {
	    $ccAdmin1Hash{$nameStr}++;
	} else {
	    $ccAdmin1Hash{$nameStr} = 1;
	}
	
	my $pop = $populationCorrectors{$asciiname};
	if (defined $pop) {
	    $population = $pop;
	} elsif ($population < 3) {
	    $population = 3;  # So log2 doesn't go negative
	}
	my $dataData = pack("Lff", $population, $latitude, $longitude);
	print DATA $dataData;
	$totalPopulation += $population;
	
	if (!defined $tzNameHash{$timezoneID}) {
	    $tzNameHash{$timezoneID} = $tzCount++;
	}
	my $tzNum = int $tzNameHash{$timezoneID};
	my $tzData = pack("S", $tzNum);
	print TZ $tzData;
	
	$cityCount++;
    }
    close RAW;
}

readRawFile "$locationDir/cities1000.txt";
readRawFile "$locationDir/addCities.txt";

while (my ($key, $value) = each %tzCorrections) {
    if ($value ne "USED") {
	warn "TZ correction is for city not in our db: $key\n";
    }
}

if ($doAirports) {
    open RAWAIRPORT, "$locationDir/airportCodes.txt"
	or die "Couldn't read $locationDir/airportCodes.txt: $!\n";

    while (<RAWAIRPORT>) {
	chomp;   # Remove trailing NL
	next if /^\#/;
	my ($name, $admin, $countryCode, $latitude, $longitude, $timezoneID) = split /\t/;
	
	my $archiveName = $name;

	print NAMES "$archiveName\0";
	my $indexData = pack("L",$currentIndex);
	$currentIndex += (1 + do {use bytes; length $archiveName});
	print INDEX $indexData;

	my $nameStr = "$name+$countryCode+$admin";   # Checking for duplicate names when just cc and a1 are specified
	if (defined $ccAdmin1Hash{$nameStr}) {
	    die;  # Shouldn't be any duplicate airport names
	    $ccAdmin1Hash{$nameStr}++;
	} else {
	    $ccAdmin1Hash{$nameStr} = 1;
	}

	my $population = 1000000;  # Make an airport like a big city; could order by passenger count but not for now
	my $dataData = pack("Lff", $population, $latitude, $longitude);
	print DATA $dataData;
	$totalPopulation += $population;

	if (!defined $tzNameHash{$timezoneID}) {
	    $tzNameHash{$timezoneID} = $tzCount++;
	}
	my $tzNum = int $tzNameHash{$timezoneID};
	my $tzData = pack("S", $tzNum);
	print TZ $tzData;
	
	$cityCount++;
    }

    close RAWAIRPORT;
}

close NAMES;
close DATA;
close INDEX;
close TZ;

sub writeCheckSumFile {
    my $checkSumFile = shift;
    my $fileToCheckSum = shift;
    open PIPE, "cksum $fileToCheckSum |"
	or die "Couldn't open pipe to cksum: $!\n";
    my $outputLine = <PIPE>;
    close PIPE;
    my ($sum, $size, $name) = split /\s/, $outputLine;
    $name eq $fileToCheckSum
	or die "Unexpected output from checksum: $outputLine\n";
    $sum =~ /^\d+$/
	or die "Unexpected output from checksum: $outputLine\n";
    open SUM, ">$checkSumFile"
	or die "Couldn't create $checkSumFile: $!\n";
    my $sumData = pack("L", $sum);
    print SUM $sumData;
    close SUM;
}

# Write out the names in the hash, ordered by hash key (index)
sub writeNamesFile {
    my $hashRef = shift;
    my $filename = shift;
    my $translateFile = shift;
    my $nameColumn = shift;

    my $translator;
    if (defined $translateFile) {
	$translator = {};
	open TRANSLATOR, $translateFile
	  or die;
	while (<TRANSLATOR>) {
	    next if /^#/;
	    chomp;
	    my @columns = split /\t/;
	    my $code = $columns[0];
	    my $translation = $columns[$nameColumn];
	    $translator->{$code} = $translation;
	}
	close TRANSLATOR;
    }

    my @names = sort { $hashRef->{$a} <=> $hashRef->{$b} } keys %$hashRef;

    unlink $filename;
    open NAMES, ">$filename"
      or die;
    foreach my $name (@names) {
	if (defined $translator) {
	    my $translated = $translator->{$name};
	    if (defined $translated) {
		$name = $translated;
	    } elsif ($name =~ /^[^\.][^\.]\.(\.|[^\.][^\.]\.)/) {
		# warn "No translation for '$name' in $translateFile\n" if $name !~ /\.$/;
		$name = "";
	    } else {
		$name =~ s/^[^\.][^\.]\.//o
		  or die "Unexpected key name for translation '$name'\n";
	    }
	}
	print NAMES "$name\0";
    }
    close NAMES;
}

writeNamesFile \%tzNameHash, "$locationDir/loc-tzNames.dat";
writeCheckSumFile "$locationDir/loc-tzNames.sum", "$locationDir/loc-tzNames.dat";

# OK, now that we know which City+CC+A1 designations are unique, we reload file and output region codes

unlink "$locationDir/loc-region.dat";
open REGION, ">$locationDir/loc-region.dat"
  or die;

my %regionHash;
my $regionCount = 0;

my %countryIndexHash;  # Hash of index given country code
my $countryCount = 0;  # Next unused country index;

my %a1IndexHash;  # Hash of index given A1 (admin1) code
my $a1Count = 0;  # Next unused A1 index;

my %a2IndexHash;  # Hash of index given A2 (admin2) code
my $a2Count = 0;  # Next unused A2 index;

sub reloadRaw {
    my $rawFile = shift;
    open RAW, $rawFile
      or die "Couldn't read $locationDir/cities1000.txt: $!\n";
    while (<RAW>) {
	chomp;   # Remove trailing NL
	my ($geonameid, $name, $asciiname, $alternatenames, $latitude, $longitude, $featureClass, $featureCode,
	    $countryCode, $cc2, $admin1Code, $admin2Code, $admin3Code, $admin4Code, $population, $elevation, $gtopo30, $timezoneID, $modDate) = split /\t/;
	if (!defined $countryIndexHash{$countryCode}) {
	    $countryIndexHash{$countryCode} = $countryCount++;
	}
	# print "$name\t$countryCode\t$admin1Code\t$admin2Code\n" if $countryCode eq "PR";
	my $a1Code = "$countryCode.$admin1Code";
	if (!defined $a1IndexHash{$a1Code}) {
	    $a1IndexHash{$a1Code} = $a1Count++;
	}
	my $nameStr = "$name+$countryCode+$admin1Code";
	defined $ccAdmin1Hash{$nameStr}
	  or die "Internal error";
	my $uniqueRegion;
	if ($ccAdmin1Hash{$nameStr} == 1) {
	    $uniqueRegion = "$countryCode+$admin1Code";
	} else {
	    #if ($countryCode eq "US") {
	    #    printf("Non-unique city $nameStr at lat $latitude long $longitude\n");
	    #}
	    $uniqueRegion = "$countryCode+$admin1Code+$admin2Code";
	    my $a2Code = "$a1Code.$admin2Code";
	    if (!defined $a2IndexHash{$a2Code}) {
		$a2IndexHash{$a2Code} = $a2Count++;
	    }
	}
	my $regionIndex = $regionHash{$uniqueRegion};
	if (!defined $regionIndex) {
	    $regionIndex = $regionCount++;
	    $regionHash{$uniqueRegion} = $regionIndex;
	}
	my $regionData = pack("S", $regionIndex);
	print REGION $regionData;
    }
    close RAW;
}

reloadRaw "$locationDir/cities1000.txt";
reloadRaw "$locationDir/addCities.txt";

if ($doAirports) {

    open RAWAIRPORT, "$locationDir/airportCodes.txt"
      or die "Couldn't read $locationDir/airportCodes.txt: $!\n";

    while (<RAWAIRPORT>) {
	chomp;   # Remove trailing NL
	next if /^\#/;
	my ($name, $admin, $countryCode, $latitude, $longitude) = split /\t/;
	
	defined $countryIndexHash{$countryCode}
	  or die;
	
	my $a1Code = "$countryCode.$admin";
	if (!defined $a1IndexHash{$a1Code}) {
	    $a1IndexHash{$a1Code} = $a1Count++;
	}
	
	my $nameStr = "$name+$countryCode+$admin";   # Checking for duplicate names when just cc and a1 are specified
	defined $ccAdmin1Hash{$nameStr}
	  or die "Internal error";
	my $uniqueRegion;
	if ($ccAdmin1Hash{$nameStr} == 1) {
	    $uniqueRegion = "$countryCode+$admin";
	} else {
	    die;  # We have no airport admin2 codes to qualify with
	}
	my $regionIndex = $regionHash{$uniqueRegion};
	if (!defined $regionIndex) {
	    $regionIndex = $regionCount++;
	    $regionHash{$uniqueRegion} = $regionIndex;
	}
	my $regionData = pack("S", $regionIndex);
	print REGION $regionData;
    }
    close RAWAIRPORT;
}

close REGION;

writeNamesFile \%countryIndexHash, "$locationDir/loc-cc.dat", "$locationDir/countryinfo.txt", 4;
writeNamesFile \%a1IndexHash, "$locationDir/loc-a1.dat", "$locationDir/admin1Codes.txt", 1;
writeNamesFile \%a2IndexHash, "$locationDir/loc-a2.dat", "$locationDir/admin2Codes.txt", 1;

writeNamesFile \%a1IndexHash, "$locationDir/loc-a1Codes.dat";

my @names = sort { $regionHash{$a} <=> $regionHash{$b} } keys %regionHash;
my $filename = "$locationDir/loc-regiondesc.dat";
unlink $filename;
open NAMES, ">$filename"
  or die;
foreach my $name (@names) {
    $name =~ /^([^+]+)\+([^+]*)(\+([^+]*))?$/
      or die "Bad CC+A1 name: $name\n";
    my $cc = $1;
    my $a1 = $2;
    my $a2 = $4;
    defined $cc and defined $a1
      or die "Bad CC+A1 name: $name\n";
    my $ccIndex = $countryIndexHash{$cc};
    defined $ccIndex
      or die "Can't find CC index $cc";
    my $a1Index = $a1IndexHash{"$cc.$a1"};
    defined $a1Index
      or die "Can't find A1 index '$cc.$a1'";
    my $a2Index;
    if (defined $a2 and length $a2) {
	$a2Index = $a2IndexHash{"$cc.$a1.$a2"};
	defined $a2Index
	  or die "Can't find A2 index '$cc.$a1.$a2' for '$cc' '$a1' '$a2' in '$name'";
    } else {
	$a2Index = -1;
    }
    print NAMES pack "SSS", $ccIndex, $a1Index, $a2Index;
}
close NAMES;

# Print statistics:
printf "%s bytes of names in %s cities, $countryCount countries, $a1Count admin1s, $a2Count admin2s, $regionCount unique regions, total population %s\n",
  insertCommas($currentIndex),
  insertCommas($cityCount),
  insertCommas($totalPopulation);

system("wc -c $locationDir/loc-*.dat");

system("tar czf /tmp/munchGeoNames.tgz $locationDir/loc-*.dat");
print "Compressed:\n";
system("wc -c /tmp/munchGeoNames.tgz");
unlink "/tmp/munchGeoNames.tgz";
