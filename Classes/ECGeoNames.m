//
//  ECGeoNames.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 9/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#import "Constants.h"
#import "ECGlobals.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ChronometerAppDelegate.h"
#import "ECErrorReporter.h"
#import "ECGeoNames.h"
#import "ECLocationManager.h"
#import "ECWatchTime.h"
#import "TSTime.h"

#include <sys/stat.h>  // For fstat
#include <fcntl.h>  // For open
#include <unistd.h>  // for lseek, read, close

@implementation ECGeoNames

-(id)init {
    if (self = [super init]) {
	cityNames = NULL;
	nameIndices = NULL;
	cityData = NULL;
	ccNames = nil;
	a1Names = nil;
	a2Names = nil;
	a1Codes = nil;
	tzIndices = NULL;
	tzNames = nil;
	tzCache = NULL;
	selectedCityIndex = -1;
	numCities = -1;
	sortedSearchIndices = nil;
	numMatchingCities = 0;
	numMatchingAtLevel[0] = 0;
	numMatchingAtLevel[1] = 0;
	numMatchingAtLevel[2] = 0;
	cityRegions = nil;
	regionDescs = nil;
	numRegionDescs = 0;
    }
    return self;
}

static void checkFreeMallocArray(void **arr) {
    if (*arr) {
	free(*arr);
	*arr = NULL;
    }
}

static void checkFreeNSArray(NSArray **arr) {
    if (*arr) {
	[*arr release];
	*arr = nil;
    }
}

-(void)clearStorage {
    checkFreeMallocArray((void*)&cityNames);
    checkFreeMallocArray((void*)&nameIndices);
    checkFreeMallocArray((void*)&cityData);
    checkFreeMallocArray((void*)&cityRegions);
    checkFreeMallocArray((void*)&regionDescs);
    checkFreeMallocArray((void*)&tzCache);
    checkFreeNSArray(&ccNames);
    checkFreeNSArray(&a1Names);
    checkFreeNSArray(&a2Names);
    checkFreeNSArray(&a1Codes);
    checkFreeMallocArray((void*)&tzIndices);
    checkFreeNSArray(&tzNames);
    checkFreeMallocArray((void*)&sortedSearchIndices);
    selectedCityIndex = -1;
    numCities = -1;
    numMatchingCities = 0;
    numMatchingAtLevel[0] = 0;
    numMatchingAtLevel[1] = 0;
    numMatchingAtLevel[2] = 0;
    numRegionDescs = -1;
}

-(void)dealloc {
    [self clearStorage];
    [super dealloc];
}

// Ideally we'd add the country/city index here, but it's only 16 bits and padding would waste 16 bits.
// If we ever need another 16 bits anyway, we could put all 32 here.
struct ECCityData {
    uint32_t population;
    float latitude;
    float longitude;
};

struct ECRegionDesc {
    short ccIndex;
    short a1Index;
    short a2Index;
};

-(void)qualifyNumCities:(int)numCitiesRead {
    if (numCities < 0) {
	numCities = numCitiesRead;
    } else {
	if (numCitiesRead != numCities) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"City file mismatch: %d != %d", numCitiesRead, numCities]];
            assert(false);
	    exit(1);
	}
    }
}

-(void)readCityData {
    size_t bytesRead;
    cityData = (ECCityData *)readBinaryFileIntoMallocedArray(@"/loc-data.dat", &bytesRead);
    [self qualifyNumCities:(bytesRead / sizeof(ECCityData))];
}

-(void)readCityNames {
    size_t bytesRead;
    cityNames = (char *)readBinaryFileIntoMallocedArray(@"/loc-names.dat", &bytesRead);
}

-(void)readNameIndices {
    size_t bytesRead;
    nameIndices = (int *)readBinaryFileIntoMallocedArray(@"/loc-index.dat", &bytesRead);
    [self qualifyNumCities:(bytesRead / sizeof(int))];
}

-(void)readRegions {
    size_t bytesRead;
    cityRegions = (short *)readBinaryFileIntoMallocedArray(@"/loc-region.dat", &bytesRead);
    [self qualifyNumCities:(bytesRead / sizeof(short))];
}

-(void)readRegionDescs {
    size_t bytesRead;
    regionDescs = (ECRegionDesc *)readBinaryFileIntoMallocedArray(@"/loc-regiondesc.dat", &bytesRead);
    numRegionDescs = bytesRead / sizeof(ECRegionDesc);
}

-(void)setupTimezoneRangeTable {
    traceEnter("setupTimezoneRangeTable");
    assert(tzCache);	    // malloc-ed but empty
    assert(tzNames);
    assert(tzIndices);
    int i = 0;
    for (NSString *tzName in tzNames) {
	assert([tzName compare:[tzNames objectAtIndex:i]] == NSOrderedSame);
	ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([tzName UTF8String]);
#ifndef NDEBUG
	if (!estz) {
	    printf("Couldn't construct ESTimeZone with name %s\n", [tzName UTF8String]);
	}
	assert(estz);
#endif
	NSTimeInterval now = [TSTime currentTime];
	NSInteger currentOffset = ESCalendar_tzOffsetForTimeInterval(estz, now);
	assert((currentOffset % 60) == 0);
	NSTimeInterval nextTransition = ESCalendar_nextDSTChangeAfterTimeInterval(estz, now);
	if (nextTransition) {
	    assert(nextTransition > now);
	    NSInteger postTransitionOffset = ESCalendar_tzOffsetForTimeInterval(estz, nextTransition + 7200);
	    assert((postTransitionOffset % 60) == 0);
	    tzCache[i].stdOffset = (currentOffset < postTransitionOffset ? currentOffset : postTransitionOffset) / 60;
	    tzCache[i].dstOffset = (currentOffset < postTransitionOffset ? postTransitionOffset : currentOffset) / 60;
            if (labs(currentOffset - postTransitionOffset) > 3600) {
                printf("DST > 1 hour (may have implications for Terra front DST dot channels:\n");
                printf("%03d\t%+04d\t%+04d\t%06ld\t%06ld\t%s\n",i, tzCache[i].stdOffset, tzCache[i].dstOffset,
                       (long) currentOffset, (long) postTransitionOffset, [tzName UTF8String]);
            }
	    //assert(abs(currentOffset - postTransitionOffset) <= 3600);  // no DST transition greater than an hour
	} else {
	    tzCache[i].stdOffset = tzCache[i].dstOffset = currentOffset / 60;
	}
	++i;
	ESCalendar_releaseTimeZone(estz);
    }
    traceExit ("setupTimezoneRangeTable");
}

#ifndef NDEBUG
-(void)testTZNames {
    assert(tzNames);
    assert(tzIndices);
    int i = 0;
    [ChronometerAppDelegate noteTimeAtPhase:"testTZNames begin"];
    for (NSString *tzName in tzNames) {
	ESCalendar_initTimeZoneFromOlsonID([tzName UTF8String]);  // Will assert if time zone name not found
	++i;
    }
    [ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"testTZNames end; %d", i]];
}
static BOOL testedTZ = false;
#endif

-(void)readTZ {
    traceEnter("readTZ");
    size_t bytesRead;
    tzIndices = (short *)readBinaryFileIntoMallocedArray(@"/loc-tz.dat", &bytesRead);
    [self qualifyNumCities:(bytesRead / sizeof(short))];
    assert(!tzNames);
    assert(numCities > 0);
    readStringsFileIntoNSArray(@"/loc-tzNames.dat", &tzNames, numCities);
    tzNamesChecksum = readSingleUnsignedFromFile(@"/loc-tzNames.sum");
    //printf("tzNames checksum is %u (0x%08x)\n", tzNamesChecksum, tzNamesChecksum);
#ifndef NDEBUG
    if (!testedTZ && [ChronometerAppDelegate firstRun]) {
	[self testTZNames];
	testedTZ = true;
    }
#endif
    if (tzCache) {
	assert(false);
	return;
    }
    NSString *fn = [NSString stringWithFormat:@"/loc-tzOffsets-%s-%u.dat", ESCalendar_version(), tzNamesChecksum];
    size_t cacheSize = sizeof(tzData) * [tzNames count];
    bytesRead = 0;
    tzCache = (tzData *)readBinaryFileIntoMallocedArray(fn, &bytesRead);
    if (tzCache == nil) {
	tzCache = (tzData *)readBinaryFileIntoMallocedArrayFromDocumentDirectory(fn, &bytesRead);
    }
    if (bytesRead != cacheSize) {
	if (tzCache != nil) {
	    free(tzCache);
	    tzCache = nil;
	}
    }
    if (tzCache == nil) {
	// file was missing
#ifndef NDEBUG
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"need to generate %@; copy it from the apps's Documents directory into Xcode's Resources list", fn]];
#endif
	tzCache = (tzData *)malloc(cacheSize);
	[self setupTimezoneRangeTable];
	writeBinaryFileFromMallocedArrayToDocumentDirectory(fn, (char*)tzCache, cacheSize);
    }
    traceExit("readTZ");
}

#ifndef NDEBUG
-(NSArray *)tzNames {
    if (!tzNames) {
	[self readTZ];
    }
    assert(tzNames);
    return tzNames;
}
#endif

-(void)readCCNames {
    assert(!ccNames);
    readStringsFileIntoNSArray(@"/loc-cc.dat", &ccNames, 238);
}

-(void)readA1Names {
    assert(!a1Names);
    readStringsFileIntoNSArray(@"/loc-a1.dat", &a1Names, 3269);
}

-(void)readA2Names {
    assert(!a2Names);
    readStringsFileIntoNSArray(@"/loc-a2.dat", &a2Names, 569);
}

-(void)readA1Codes {
    assert(!a1Codes);
    readStringsFileIntoNSArray(@"/loc-a1Codes.dat", &a1Codes, 3269);
}

// This is not necessarily the true distance but a metric for sorting
static float distanceBetweenTwoCoordinates(float lat1, float long1,
					   float lat2, float long2) {
    float latDiff = fabsf(lat1 - lat2);
    float longDiff = fabsf(long1 - long2);
    if (longDiff > 180) {
	longDiff = 360 - longDiff;
    }
    return latDiff*latDiff + longDiff*longDiff;
}

#ifndef NDEBUG
-(void)findWackyZones {
    int sav = selectedCityIndex;
    if (!cityData) {
	[self readCityData];
    }
    if (!tzIndices) {
	[self readTZ];
	assert(tzIndices);
    }
    NSTimeInterval now = [TSTime currentTime];
    for (int i = 0; i < numCities; i++) {
	ECCityData *thisData = cityData + i;
	float thisLongitude = thisData->longitude;
	ESTimeZone *thisTZ = ESCalendar_initTimeZoneFromOlsonID([[tzNames objectAtIndex:tzIndices[i]] UTF8String]);
	float thisTZCenter = ESCalendar_tzOffsetForTimeInterval(thisTZ, now)/3600 - ESCalendar_isDSTAtTimeInterval(thisTZ, now)*15;
	float delta = fabsf(thisLongitude - thisTZCenter);
	if (delta > 180) {
	    delta = 360 - delta;
	}
	if (delta > 25) {
	    selectedCityIndex = i;
	    tracePrintf3("(%8d) %3.0f %@", thisData->population, delta, [self selectedCityName]);
	}
    }
    selectedCityIndex = sav;
}
#endif

-(void)findClosestCityToLatitudeDegrees:(float)toLatitude longitudeDegrees:(float)toLongitude {
    if (!cityData) {
	[self readCityData];
    }
    float closestDist = 1E20;
    selectedCityIndex = -1;
    for (int i = 0; i < numCities; i++) {
	ECCityData *thisData = cityData + i;
	float thisDist = distanceBetweenTwoCoordinates(thisData->latitude, thisData->longitude,
						       toLatitude, toLongitude);
	if (thisDist < closestDist) {
	    closestDist = thisDist;
	    selectedCityIndex = i;
	}
    }
}

-(void)findBestMatchCityToLatitudeDegrees:(float)toLatitude longitudeDegrees:(float)toLongitude {
    if (!cityData) {
	[self readCityData];
    }
    float closestDist = 1E20;
    selectedCityIndex = -1;
    for (int i = 0; i < numCities; i++) {
	ECCityData *thisData = cityData + i;
	float thisDist = distanceBetweenTwoCoordinates(thisData->latitude, thisData->longitude,
						       toLatitude, toLongitude) / powf(thisData->population, .5);
	if (thisDist < closestDist) {
	    closestDist = thisDist;
	    selectedCityIndex = i;
	}
    }
}

static void readElementFromFileAtIndex(NSString *relativePath,
				       int      indx,
				       void     *element,
				       int      elementSizeInBytes) {
    
    NSString *filename = [ECbundleDirectory stringByAppendingString:relativePath];
    int fd = open([filename UTF8String], O_RDONLY);
    if (fd < 0) {
	perror([[NSString stringWithFormat:@"Error opening binary file %@", filename] UTF8String]);
	exit(1);
    }
    struct stat buf;
    int st = EC_fstat(fd, &buf);
    if (st != 0) {
	perror([[NSString stringWithFormat:@"Error running fstat on file %@", filename] UTF8String]);
	exit(1);
    }
    size_t fileSize = buf.st_size;
    fileSize = fileSize;
    size_t off = indx * elementSizeInBytes;
    assert(off + elementSizeInBytes <= fileSize);
    off_t st2 = lseek(fd, off, SEEK_SET);
    st2 = st2;
    assert(st2 == off);
    ssize_t st3 = read(fd, element, elementSizeInBytes);
    st3 = st3;
    assert(st3 == elementSizeInBytes);
    close(fd);
}

-(NSString *)selectedCityName {     // returns last found city
    if (selectedCityIndex < 0) {
	return nil;
    }
    if (!cityNames) {
	[self readCityNames];
    }
    int nameIndex;
    if (nameIndices) {
	nameIndex = nameIndices[selectedCityIndex];
    } else {
	readElementFromFileAtIndex(@"/loc-index.dat", selectedCityIndex, &nameIndex, 4);
    }
    char *compoundName = cityNames + nameIndex;
    char *displayNameStart = rindex(compoundName, '+');
    if (displayNameStart) {
	displayNameStart++;  // Move past '+'
    } else {
	displayNameStart = compoundName;
    }
    return [NSString stringWithUTF8String:displayNameStart];
}


-(NSString *)selectedCityRegionName {     // returns last found city's region info
    if (selectedCityIndex < 0) {
	return nil;
    }
#ifdef SHOW_POPULATION_AS_REGION
    assert(cityData);
    assert(selectedCityIndex > 0);
    ECCityData *thisData = cityData + selectedCityIndex;
    return [NSString stringWithFormat:@"%d", thisData->population];
#endif
    //[ChronometerAppDelegate noteTimeAtPhase:"selectedCityRegionName start"];
    short regionIndex;
    readElementFromFileAtIndex(@"/loc-region.dat", selectedCityIndex, &regionIndex, 2);
    //[ChronometerAppDelegate noteTimeAtPhase:"selectedCityRegionName finished reading region index"];
    ECRegionDesc regionDesc;
    readElementFromFileAtIndex(@"/loc-regiondesc.dat", regionIndex, &regionDesc, sizeof(regionDesc));
    //[ChronometerAppDelegate noteTimeAtPhase:"selectedCityRegionName finished reading region descriptor"];
    NSString *regionString = @"";
    if (regionDesc.a2Index >= 0) {
	if (!a2Names) {
	    [self readA2Names];
	}
	NSString *a2String = [a2Names objectAtIndex:regionDesc.a2Index];
	if ([a2String length] > 0) {
	    regionString = a2String;
	}
    }
    if (regionDesc.a1Index >= 0) {
	if (!a1Names) {
	    [self readA1Names];
	}
	NSString *a1String = [a1Names objectAtIndex:regionDesc.a1Index];
	if ([a1String length] > 0) {
	    if ([regionString length] > 0) {
		regionString = [NSString stringWithFormat:@"%@, %@", regionString, a1String];
	    } else {
		regionString = a1String;
	    }
	}
    }
    if (regionDesc.ccIndex >= 0) {
	if (!ccNames) {
	    [self readCCNames];
	}
	NSString *ccString = [ccNames objectAtIndex:regionDesc.ccIndex];
	if ([ccString length] > 0) {
	    if ([regionString length] > 0) {
		regionString = [NSString stringWithFormat:@"%@, %@", regionString, ccString];
	    } else {
		regionString = ccString;
	    }
	}
    }
    //[ChronometerAppDelegate noteTimeAtPhase:"selectedCityRegionName end"];
    return regionString;
}

-(NSString *)selectedCityTZName {  // returns last found city tz
    if (selectedCityIndex < 0) {
	return nil;
    }
    if (!tzIndices) {
	[self readTZ];
    }
    if (!tzIndices) {
	assert(tzIndices);
	return nil;	    // shut up warning
    }
    NSString *tzName = [tzNames objectAtIndex:tzIndices[selectedCityIndex]];
    return tzName;
}

-(float)selectedCityLatitude {
    assert(cityData);
    assert(selectedCityIndex >= 0);
    ECCityData *thisData = cityData + selectedCityIndex;
    return thisData->latitude;
}

-(float)selectedCityLongitude {
    assert(cityData);
    assert(selectedCityIndex >= 0);
    ECCityData *thisData = cityData + selectedCityIndex;
    return thisData->longitude;
}

-(unsigned long)selectedCityPopulation {
    assert(cityData);
    assert(selectedCityIndex >= 0);
    ECCityData *thisData = cityData + selectedCityIndex;
    return thisData->population;
}

struct ECGeoSortDescriptor {
    int	    index;
    float   sortValue;
    int	    sortValue2;
};

int comparator(const void *v1, const void *v2) {
    ECGeoSortDescriptor *desc1 = (ECGeoSortDescriptor *)v1;
    ECGeoSortDescriptor *desc2 = (ECGeoSortDescriptor *)v2;
    if (desc1->sortValue < desc2->sortValue) {
	return -1;
    } else if (desc1->sortValue == desc2->sortValue) {
	return 0;
    } else {
	return 1;
    }
}

// the concept here is to assign a "confidence value" to each city which we will then sort on to pick the best one
// the values for state, country and code (countryCode) come from the users's address book and hence may be unreliable:
//  - some or all may be empty
//  - they may be misspeled
//  - they may use abbreviations (eg "USA" instead of "United States") or the code may appear in the country field
// so the idea is to match find as much matching info as possible and assign a higher confidence level based on:
//  - which things match (eg. state is more definitive than country)
//  - how many of the quantities match
// we'll probably want to catch a few special cases (eg. "GB" for "UK", "USA" for "United States")
// it must all be case-insensitive compares
- (int) regionMatchConfidenceForIndex:(int)cityIndex state:(NSString *)state country:(NSString *)country code:(NSString *)code {
    traceEnter("regionMatchConfidence");
    assert(cityIndex >= 0);
    assert(cityIndex < numCities);
    
    if (!a1Codes) {
	[self readA1Codes];
	[self readRegions];
	[self readRegionDescs];
    }

    short regionIndex = cityRegions[cityIndex];
    ECRegionDesc *regionDesc = regionDescs + regionIndex;

#ifndef NDEBUG
    static bool firstTime = false;
    if (firstTime) {
	int count = [a1Codes count];
	int count2 = [a1Names count];
	assert(count == count2);
	for (int i = 0; i < count; i++) {
	    printf("%15s: %s\n", [[a1Codes objectAtIndex:i] UTF8String], [[a1Names objectAtIndex:i] UTF8String]);
	}
	firstTime = false;
    }
#endif

    int confidenceLevel = 0;
    NSString *a1String = nil;
    NSString *a1Code = nil;
    NSString *cString = nil;
    NSString *cCode = nil;
    if (regionDesc->a1Index >= 0) {
	if (!a1Names) {
	    [self readA1Names];
	}
	a1String = [a1Names objectAtIndex:regionDesc->a1Index];
	a1Code = [[a1Codes objectAtIndex:regionDesc->a1Index] substringWithRange:NSMakeRange(3,2)];
	assert(a1String);
	assert(a1Code);
    }
    if (regionDesc->ccIndex >= 0) {
	if (!ccNames) {
	    [self readCCNames];
	}
	cString = [ccNames objectAtIndex:regionDesc->ccIndex];
	cCode = [[a1Codes objectAtIndex:regionDesc->a1Index] substringWithRange:NSMakeRange(0,2)];
    }

    BOOL statesMatch = false;
    BOOL countriesMatch = false;
    if (([a1String length] > 0 && [state length] > 0 && [state caseInsensitiveCompare:a1String] == NSOrderedSame) ||
	([a1Code length] > 0   && [state length] > 0 && [state caseInsensitiveCompare:a1Code] == NSOrderedSame)) {
	statesMatch = true;
	confidenceLevel++;
    }
    if (([cCode length] > 0   && [code length] > 0    && ( [code caseInsensitiveCompare:cCode] == NSOrderedSame ||
						          ([code caseInsensitiveCompare:@"GB"] == NSOrderedSame && [cCode caseInsensitiveCompare:@"UK"] == NSOrderedSame))) ||
	([cCode length] > 0   && [country length] > 0 && ( [country caseInsensitiveCompare:cCode] == NSOrderedSame ||
						          ([country caseInsensitiveCompare:@"GB"] == NSOrderedSame && [cCode caseInsensitiveCompare:@"UK"] == NSOrderedSame))) ||
        ([cString length] > 0 && [country length] > 0 && ( [country caseInsensitiveCompare:cString] == NSOrderedSame ||
				                          ([country caseInsensitiveCompare:@"USA"] == NSOrderedSame && [cString caseInsensitiveCompare:@"United States"] == NSOrderedSame) ||
							  ([country caseInsensitiveCompare:@"GB"] == NSOrderedSame && [cString caseInsensitiveCompare:@"United Kingdom"] == NSOrderedSame)))) {
	countriesMatch = true;
	confidenceLevel++;
    }
    
    if ((!statesMatch &&    [state length] > 0) ||
	(!countriesMatch && ([code length] > 0 || [country length] > 0))) {
	confidenceLevel = 0;
    }
    // subtract some if the city name matches only partially?

#ifdef ECTRACE
    NSString *tmp = [NSString stringWithFormat:@"%@ %@ %@ %@", a1String, a1Code, cString, cCode];
    NSString *tmp2 = [NSString stringWithFormat:@"%@ %@ %@", state, country, code];
    tracePrintf3("'%s' matches '%s' with confidence %d", [tmp2 UTF8String], [tmp UTF8String], confidenceLevel);
    traceExit ("regionMatchConfidence");
#endif
    return confidenceLevel;
}

int comparator2(const void *v1, const void *v2) {
    ECGeoSortDescriptor *desc1 = (ECGeoSortDescriptor *)v1;
    ECGeoSortDescriptor *desc2 = (ECGeoSortDescriptor *)v2;
    if (desc1->sortValue2 > desc2->sortValue2) {
	return -1;
    } else if (desc1->sortValue2 == desc2->sortValue2) {
	if (desc1->sortValue < desc2->sortValue) {
	    return -1;
	} else if (desc1->sortValue == desc2->sortValue) {
	    return 0;
	} else {
	    return 1;
	}
    } else {
	return 1;
    }

}

static bool
searchForString(const char *searchIn,
		const char *searchFor) {
    while (1) {
	const char *searchResult = strcasestr(searchIn, searchFor);
	if (!searchResult) {
	    return false;
	}
	if (searchResult == searchIn ||   // If it's not the start of the string, then it's past the start of the string and we can look back one char
	    searchResult[-1] == ' ' ||
	    searchResult[-1] == '+') {
	    return true;
	}
	searchIn = searchResult + 1;
    }
}

-(void)searchForCityNameFragment:(NSString *)cityNameFragment withProximity:(bool)proximity {
    if (!cityData) {
	[self readCityData];
    }
    if (!cityNames) {
	[self readCityNames];
    }
    if (!nameIndices) {
	[self readNameIndices];
    }
    if (!nameIndices) {
	assert(nameIndices);
	return;		// shut up warning
    }

    ECLocationManager *locMgr = [ECLocationManager theLocationManager];
    float nameSearchCenterLat = [locMgr lastLatitudeDegrees];
    float nameSearchCenterLong = [locMgr lastLongitudeDegrees];

    //[ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"search for fragment start: '%@'", cityNameFragment]];

    const char *targetChars = [cityNameFragment UTF8String];
    
    if (!sortedSearchIndices) {
	sortedSearchIndices = (ECGeoSortDescriptor *)malloc(numCities * sizeof(ECGeoSortDescriptor));
    }
    numMatchingCities = 0;
    numMatchingAtLevel[0] = 0;
    numMatchingAtLevel[1] = 0;
    numMatchingAtLevel[2] = 0;
    bool getEmAll = [cityNameFragment length] == 0;
    for (int i = 0; i < numCities; i++) {
	sortedSearchIndices[i].index = i;
	const char *searchMe = cityNames + nameIndices[i];
	if (getEmAll || searchForString(searchMe, targetChars)) {
	    ECCityData *data = cityData + i;
	    sortedSearchIndices[numMatchingCities].index = i;
	    if (proximity) {
		sortedSearchIndices[numMatchingCities++].sortValue = distanceBetweenTwoCoordinates(data->latitude, data->longitude, nameSearchCenterLat, nameSearchCenterLong) / powf(data->population, 2.8);
	    } else {
		sortedSearchIndices[numMatchingCities++].sortValue = -data->population;
	    }
	}
    }
    //[ChronometerAppDelegate noteTimeAtPhase:"sort search start"];
    qsort(sortedSearchIndices, numMatchingCities, sizeof(ECGeoSortDescriptor), comparator);
    //[ChronometerAppDelegate noteTimeAtPhase:"sort search finish"];
}

+(bool)validTZCenteredAt:(short)tzCenter forSlot:(int)offsetHours {
    int centerSlotMinutes = offsetHours * 60 + 30;
    int distanceToCenterFromSlot = centerSlotMinutes - tzCenter;
    if (distanceToCenterFromSlot > 12 * 60) {
	distanceToCenterFromSlot -= 24 * 60;
    } else if (distanceToCenterFromSlot < -12 * 60) {
	distanceToCenterFromSlot += 24 * 60;
    }
    return (abs(distanceToCenterFromSlot) <= 30);
}

+(bool)validTZ:(ESTimeZone *)tz forSlot:(int)offsetHours {
    NSTimeInterval now = [TSTime currentTime];
    NSInteger currentOffset = ESCalendar_tzOffsetForTimeInterval(tz, now);
    assert((currentOffset % 60) == 0);
    NSTimeInterval nextTransition = ESCalendar_nextDSTChangeAfterTimeInterval(tz, now);
    short tzCenter;
    if (nextTransition) {
	NSInteger postTransitionOffset = rint(ESCalendar_tzOffsetForTimeInterval(tz, nextTransition + 7200));
	assert((postTransitionOffset % 60) == 0);
	assert(labs(currentOffset - postTransitionOffset) <= 3600);  // no DST transition greater than an hour
	tzCenter = ((currentOffset + postTransitionOffset) / 60) / 2;
    } else {
	tzCenter = currentOffset / 60;
    }
    return [self validTZCenteredAt:tzCenter forSlot:offsetHours];
}

-(bool)validCity:(int)cityIndex forSlot:(int)offsetHours {
    if (!tzIndices) {
	[self readTZ];
    }
    if (!tzIndices) {
	assert(tzIndices);
	return false;	    // shut up warning
    }
    if (!tzCache) {
	assert(tzCache);
	return false;	    // shut up warning
    }
    short tzCenter = (tzCache[tzIndices[cityIndex]].stdOffset + tzCache[tzIndices[cityIndex]].dstOffset) / 2;
    return [ECGeoNames validTZCenteredAt:tzCenter forSlot:offsetHours];
}

-(bool)selectedCityValidForSlotAtOffsetHour:(int)offsetHours {
    return [self validCity:selectedCityIndex forSlot:offsetHours];
}

-(ECSlotInclusionClass)selectedCityInclusionClassForSlotAtOffsetHour:(int)offsetHours {
    if ([self selectedCityValidForSlotAtOffsetHour:offsetHours]) {
	short std = tzCache[tzIndices[selectedCityIndex]].stdOffset;
	short dst = tzCache[tzIndices[selectedCityIndex]].dstOffset;
	if (std<0) {
	    std += 24*60;
	    dst += 24*60;
	}
	if (offsetHours<0) {
	    offsetHours += 24;
	}
	if (std == 24*60) {
	    std = 0;
	}
	if (dst == 24*60) {
	    dst = 0;
	}
	if (offsetHours == 24) {
	    offsetHours = 0;
	}
	if (std == dst) {
	    // no DST in this zone
	    if ((std % 60) == 0) {
		return (offsetHours * 60) == std ? normalNoDSTRight : normalNoDSTLeft;
	    } else if ((std % 30) == 0) {
		return halfNoDST;
	    }
	    return oddNoDST;
	} else {
	    assert(dst == (std+60) % (24*60));
	    if ((std % 60) == 0) {
		return normalHasDST;
	    } else if ((std % 30) == 0) {
		return (offsetHours * 60) > std ? halfHasDSTRight : halfHasDSTLeft;
	    }
	    return oddHasDST;
	}
    } else {
	return notIncluded;
    }
}	 

-(void)searchForCityNameFragment:(NSString *)cityNameFragment appropriateForNominalTZSlot:(int)offsetHours {
    traceEnter("searchForCityNameFragment");
    if (!tzIndices) {
	[self readTZ];
    }
    if (!tzIndices) {
	assert(tzIndices);
	return;	    // shut up warning
    }
    if (!tzCache) {
	assert(tzCache);
	return;	    // shut up warning
    }
    if (!cityData) {
	[self readCityData];  // for population, for sorting
    }
    if (!cityNames) {
	[self readCityNames];
    }
    if (!nameIndices) {
	[self readNameIndices];
    }
    if (!nameIndices) {
	assert(nameIndices);
	return;		// shut up warning
    }

    //[ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"search for fragment start: '%@'", cityNameFragment]];

    const char *targetChars = [cityNameFragment UTF8String];

    if (!sortedSearchIndices) {
	sortedSearchIndices = (ECGeoSortDescriptor *)malloc(numCities * sizeof(ECGeoSortDescriptor));
    }
    numMatchingCities = 0;
    numMatchingAtLevel[0] = 0;
    numMatchingAtLevel[1] = 0;
    numMatchingAtLevel[2] = 0;
    bool getEmAll = [cityNameFragment length] == 0;
    for (int i = 0; i < numCities; i++) {
	sortedSearchIndices[i].index = i;
	const char *searchMe = cityNames + nameIndices[i];
	if (getEmAll || searchForString(searchMe, targetChars)) {
	    if ([self validCity:i forSlot:offsetHours]) {
		ECCityData *data = cityData + i;
		sortedSearchIndices[numMatchingCities].index = i;
		sortedSearchIndices[numMatchingCities++].sortValue = -data->population;
	    }
	}
    }
    //[ChronometerAppDelegate noteTimeAtPhase:"sort search start"];
    qsort(sortedSearchIndices, numMatchingCities, sizeof(ECGeoSortDescriptor), comparator);
    //[ChronometerAppDelegate noteTimeAtPhase:"sort search finish"];
    traceExit("searchForCityNameFragment");
}

-(int)searchForCity:(NSString *)cityName state:(NSString *)state country:(NSString *)country code:(NSString *)code {
    traceEnter("searchForCity");
    if (!cityData) {
	[self readCityData];
    }
    if (!cityNames) {
	[self readCityNames];
    }
    if (!nameIndices) {
	[self readNameIndices];
    }
    if (!nameIndices) {
	assert(nameIndices);
	return 0;		// shut up warning
    }
    
    ECLocationManager *locMgr = [ECLocationManager theLocationManager];
    float nameSearchCenterLat = [locMgr lastLatitudeDegrees];
    float nameSearchCenterLong = [locMgr lastLongitudeDegrees];
    
#ifdef ETRACE
    NSString *tmp = [NSString stringWithFormat:@"%@, %@ %@ %@", cityName, state, country, code];
    tracePrintf1("search for: '%s'", [tmp UTF8String]);
#endif

    assert([cityName length] > 0);
    const char *targetChars = [cityName UTF8String];
    
    if (!sortedSearchIndices) {
	sortedSearchIndices = (ECGeoSortDescriptor *)malloc(numCities * sizeof(ECGeoSortDescriptor));
    }

    int confidenceLevel = -1;
    numMatchingCities = 0;
    numMatchingAtLevel[0] = 0;
    numMatchingAtLevel[1] = 0;
    numMatchingAtLevel[2] = 0;
    for (int i = 0; i < numCities; i++) {
	sortedSearchIndices[i].index = i;
	const char *searchMe = cityNames + nameIndices[i];
	if (searchForString(searchMe, targetChars)) {
	    ECCityData *data = cityData + i;
	    sortedSearchIndices[numMatchingCities].index = i;
	    sortedSearchIndices[numMatchingCities].sortValue  = distanceBetweenTwoCoordinates(data->latitude, data->longitude, nameSearchCenterLat, nameSearchCenterLong) / powf(data->population, 2.8);
	    int conf = [self regionMatchConfidenceForIndex:i state:state country:country code:code];
	    sortedSearchIndices[numMatchingCities].sortValue2 = conf;
	    confidenceLevel = fmax(confidenceLevel, conf);
	    numMatchingCities++;
	    numMatchingAtLevel[conf]++;
	}
    }
    //tracePrintf1("sort search2 start %d matches", numMatchingCities);
    qsort(sortedSearchIndices, numMatchingCities, sizeof(ECGeoSortDescriptor), comparator2);
    traceExit("searchForCity");
    return confidenceLevel;
}

-(void)clearSelection {
    selectedCityIndex = -1;
    numMatchingCities = 0;
    numMatchingAtLevel[0] = 0;
    numMatchingAtLevel[1] = 0;
    numMatchingAtLevel[2] = 0;
}

-(void)selectNthTopCity:(int)indx {  // after search; then after calling this you can use selected* methods above
    assert(sortedSearchIndices);
    if (indx >= numMatchingCities) {
	selectedCityIndex = -1;
    } else {
	selectedCityIndex = sortedSearchIndices[indx].index;
    }
}

-(NSString *)topCityNameAtIndex:(int)indx {  // after search
    if (indx >= numMatchingCities) {
	return nil;
    }
    [self selectNthTopCity:indx];
    return [self selectedCityName];
}

-(int)numMatches {  // after search; number of matching city entries
    return numMatchingCities;
}

-(int)numMatchesAtLevel:(int)level {
    return numMatchingAtLevel[level];
}

@end
