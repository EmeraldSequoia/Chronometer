//
//  ECTS.m
//  Chronometer
//
//  Created by Bill Arnett on 11/11/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "TSConnection.h"
#import "ECTS.h"
#import "TSSample.h"
#undef ECTRACE
#import "ECTrace.h"
#import "TSTime.h"
#import "ECBackgroundData.h"
#import "ECWatchTime.h"
#import "ECOptions.h"

static NSThread *thread = nil;
static ECTS *sinker = nil;
static bool pendingRequest = false;
static bool goodSinceASTC = false;
static bool virgin = true;		// never synced
static NSString	    *hostname;
static NSString	    *saveIP;

@interface ECTS (ECTSPrivate)

+ (const struct _CountryFarmDescriptor *)getFarmDescriptorForCountry;

@end

@implementation ECTS

@synthesize connection, goodSync, enabled, countGood, canceled, userRequested, skewLB, skewUB, sigmaSkew;

+ (void)startNTP {
    //tracePrintf("startNTP");
    assert([NSThread isMainThread]);
    assert(!thread);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseNTP"]) {
	sinker = [[ECTS alloc] init];
	thread = [[NSThread alloc] initWithTarget:sinker selector:@selector(threadBody:) object:nil];
	[thread start];
	//[ChronometerAppDelegate addReallySignficantObserver:sinker significantTimeChangeSelector:@selector(significantTimeChanged:)];
    }
}

+ (bool)running {
    return (thread != nil);
}

+ (bool)active {
    return !(sinker.goodSync || thread == nil || sinker.canceled || sinker.connection.noNet);
}

+ (bool)synched {
    return sinker.goodSync;
}

+ (double)sigma {
    return sinker.sigmaSkew;
}

+ (double)skewLB {
    return sinker.skewLB;
}

+ (double)skewUB {
    return sinker.skewUB;
}

+ (NSString *)timeServer {
    if (hostname == nil) {
	return @"nil";
    } else {
	return hostname;
    }
}

+ (NSString *)timeServerIP {
    if (saveIP == nil) {
	return @"nil";
    } else {
	return saveIP;
    }
}

+ (NSString *)statusText {
    if ([ECOptions purpleZone]) {  // If we support alt timezones...
	return NSLocalizedString(@"Alt\ntimezone", @"possible timezone and location mismatch");
    } else if (thread == nil || !sinker.enabled) {
	return NSLocalizedString(@"Time\nsync OFF", @"NTP synching is OFF");
    } else if (sinker.goodSync) {
	return NSLocalizedString(@"Time\nsynchronized", @"watch time synchronized with NTP");
    } else if (sinker.canceled) {
	return NSLocalizedString(@"Time\nsync canceled", @"The last NTP sync was canceled");
    } else if (sinker.connection.noNet) {
	return NSLocalizedString(@"Time\nsync failed", @"last NTP sync failed");
//  } else if (sinker.countGood > 0) {
//	return [NSString stringWithFormat:@"Time syncing %d", sinker.countGood];
    } else {
	return NSLocalizedString(@"Time\nsyncing...", @"NTP sync in progress");
    }
}

+ (ECTSState)indicatorState {
    if (thread == nil || !sinker.enabled) {
	return ECTSOFF;
    } else if (sinker.goodSync) {
	return ECTSGood;
    } else if (sinker.canceled) {
	return goodSinceASTC ? ECTSGood : ECTSCanceled;
    } else if (sinker.connection.noNet) {
	return goodSinceASTC ? ECTSGood : ECTSFailed;
    } else if (sinker.countGood > 0) {
	return ECTSWorkingGood;
    } else {
	return ECTSWorkingUncertain;
    }
}

+ (void)reSync {
    //tracePrintf("reSync");
    assert([NSThread isMainThread]);
    sinker.goodSync = false;
    sinker.countGood = 0;
    goodSinceASTC = false;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseNTP"]) {
	sinker.enabled = true;
	sinker.userRequested = true;
	if (thread == nil) {
	    [self startNTP];
	}
	if (sinker.connection != nil) {
	    [sinker performSelector:@selector(cleanup) onThread:thread withObject:nil waitUntilDone:NO];
	}
	[sinker performSelector:@selector(syncNow) onThread:thread withObject:nil waitUntilDone:NO];
    }
    [ECBackgroundData refresh];
    [TSTime notifySyncStatusChanged];
}

- (void)stopReSync {
    [hostTimer invalidate];
    hostTimer = nil;
}

+ (void)stopNTP {
    //tracePrintf("stopNTP");
    assert([NSThread isMainThread]);
    if (thread == nil) {
	[self startNTP];
    }
    if (sinker.connection != nil) {
	sinker.canceled = true;
	[sinker performSelector:@selector(cleanup) onThread:thread withObject:nil waitUntilDone:NO];
#if 0
	[ChronometerAppDelegate showECStatusMessage:@"Time sync canceled"];
#endif
	[ChronometerAppDelegate showECTimeStatus];
    } // else already inactive
    sinker.userRequested = false;
    sinker.enabled = false;
    [sinker stopReSync];
    [TSTime setRSkew:0];
    [ECBackgroundData refresh];
    [TSTime notifySyncStatusChanged];
}

- (ECTS *)init {
    if (self = [super init]) {
	countryFarmDescriptor = [ECTS getFarmDescriptorForCountry];
	goodSync = false;
	hostNum = 0;
	enabled = true;
    }
    return self;
}

- (void)threadBody:(id)arg {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    assert(![NSThread isMainThread]);
    assert([NSThread currentThread] == thread);
    
    [NSThread setThreadPriority:0.25];  // priorities range from 0.0 to 1.0, where 1 is highest
    
    // start run loop
    NSRunLoop *threadRunLoop = [NSRunLoop currentRunLoop];  // first time called in a thread creates it if necessary
    
    NSTimeInterval runLoopLifetime = 3600*24*365.25*10;  // that's about 10 years
    
    // start the real work in a few seconds
    [self syncAfter:ECHostInitialTime];

    [threadRunLoop addTimer:hostTimer forMode:NSDefaultRunLoopMode];
    
    while (1) {
	[threadRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[NSDate timeIntervalSinceReferenceDate] + runLoopLifetime]];
    }
    
    [pool release];
}

- (void)syncNow {
    [self syncAfter:0.1];
}

//- (void)syncLater {
//    [self syncAfter:(random()/0x7fffffff)*100];
//}

- (void)syncAfter:(double)delay {	// sync once with one ntp server after delay seconds
    //tracePrintf("syncAfter");
    assert([NSThread currentThread] == thread);
    if (connection != nil) {
	// if there's already one running then do this request later
	pendingRequest = true;
	//[ChronometerAppDelegate noteTimeAtPhase:"ECTS: syncAfter (already running)"];
	return;
    }
    if (hostTimer) {
	[hostTimer invalidate];
    }
    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: syncAfter: waiting %g", delay] UTF8String]];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseNTP"]) {
	hostTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(nextHost:) userInfo:nil repeats:false];
    }
}

- (void)significantTimeChanged:(id)why {
    //tracePrintf("ECTS:significantTimeChanged");
    assert([NSThread isMainThread]);
    goodSinceASTC = false;
    if (why == nil) {
	// we were just awakened from lock; do nothing
    } else {
	// do it right away
	[self performSelector:@selector(syncNow) onThread:thread withObject:nil waitUntilDone:NO];
    }
}

typedef struct _ContinentFarmDescriptor {
    const char *farmName;
    int         numberOfServers;
} ContinentFarmDescriptor;

static const ContinentFarmDescriptor Africa 	  = { "africa",		1 };
static const ContinentFarmDescriptor Asia   	  = { "asia",		4 };
static const ContinentFarmDescriptor Europe 	  = { "europe",		4 };
static const ContinentFarmDescriptor NorthAmerica = { "north-america",	4 };
static const ContinentFarmDescriptor Oceania      = { "oceania",	4 };
static const ContinentFarmDescriptor SouthAmerica = { "south-america",	1 };

typedef struct _CountryFarmDescriptor {
    const char 		    	  *countryName;
    const char              	  *poolNameForCountry;
    int        		    	  numberOfServers;
    const ContinentFarmDescriptor *continentDescriptor;
} CountryFarmDescriptor;

// Following table generated by scripts/getNTPPoolServers.pl
static const int numCountryFarmDescriptors = 232;
static const CountryFarmDescriptor countryFarmDescriptors[232] = {
{ "us", "us", 4, &NorthAmerica},  // United States
{ "gb", "uk", 4, &Europe},  // United Kingdom
{ "uk", "uk", 4, &Europe},  // United Kingdom
{ "au", "au", 4, &Oceania},  // Australia
{ "ca", "ca", 4, &NorthAmerica},  // Canada
{ "de", "de", 4, &Europe},  // Germany
{ "jp", "jp", 4, &Asia},  // Japan
{ "it", "it", 1, &Europe},  // Italy
{ "ch", "ch", 4, &Europe},  // Switzerland
{ "fr", "fr", 4, &Europe},  // France
{ "se", "se", 4, &Europe},  // Sweden
{ "nl", "nl", 4, &Europe},  // Netherlands
{ "es", "es", 1, &Europe},  // Spain
{ "at", "at", 4, &Europe},  // Austria
{ "no", "no", 4, &Europe},  // Norway
{ "br", "br", 1, &SouthAmerica},  // Brazil
{ "dk", "dk", 4, &Europe},  // Denmark
{ "ie", "ie", 1, &Europe},  // Ireland
{ "be", "be", 4, &Europe},  // Belgium
{ "hk", "hk", 0, &Asia},  // Hong Kong SAR China
{ "mx", "mx", 0, &NorthAmerica},  // Mexico
{ "pt", "pt", 1, &Europe},  // Portugal
{ "ru", "ru", 4, &Europe},  // Russia
{ "gr", "gr", 1, &Europe},  // Greece
{ "za", "za", 0, &Africa},  // South Africa
{ "nz", "nz", 1, &Oceania},  // New Zealand
{ "fi", "fi", 4, &Europe},  // Finland
{ "pl", "pl", 4, &Europe},  // Poland
{ "tw", "tw", 1, &Asia},  // Taiwan
{ "kr", "kr", 0, &Asia},  // South Korea
{ "sg", "sg", 1, &Asia},  // Singapore
{ "hu", "hu", 4, &Europe},  // Hungary
{ "cz", "cz", 1, &Europe},  // Czech Republic
{ "cn", "cn", 1, &Asia},  // China
{ "tr", "tr", 0, &Europe},  // Turkey
{ "my", "my", 1, &Asia},  // Malaysia
{ "sa", "sa", 0, &Asia },  // Saudi Arabia
{ "lu", "lu", 1, &Europe},  // Luxembourg
{ "in", "in", 0, &Asia},  // India
{ "ae", "ae", 0, &Asia},  // United Arab Emirates
{ "il", "il", 0, &Asia},  // Israel
{ "sk", "sk", 0, &Europe},  // Slovakia
{ "hr", "hr", 0, &Europe },  // Croatia
{ "th", "th", 1, &Asia},  // Thailand
{ "qa", "qa", 0, &Asia },  // Qatar
{ "lb", "lb", 0, &Asia },  // Lebanon
{ "ph", "ph", 0, &Asia},  // Philippines
{ "kw", "kw", 0, &Asia },  // Kuwait
{ "vn", "vn", 0, &Asia},  // Vietnam
{ "id", "id", 1, &Asia},  // Indonesia
{ "pk", "pk", 0, &Asia},  // Pakistan
{ "co", "co", 0, &SouthAmerica },  // Colombia
{ "ro", "ro", 1, &Europe},  // Romania
{ "ar", "ar", 0, &SouthAmerica},  // Argentina
{ "cl", "cl", 0, &SouthAmerica},  // Chile
{ "ad", "ad", 0, &Europe },  // Andorra
{ "af", "af", 0, &Asia },  // Afghanistan
{ "ag", "ag", 0, &NorthAmerica },  // Antigua and Barbuda
{ "ai", "ai", 0, &NorthAmerica },  // Anguilla
{ "al", "al", 0, &Europe },  // Albania
{ "am", "am", 0, &Asia },  // Armenia
{ "an", "an", 0, &NorthAmerica },  // Netherlands Antilles
{ "ao", "ao", 0, &Africa},  // Angola
{ "aq", "aq", 0, &Oceania },  // Antarctica
{ "as", "as", 0, &Oceania },  // American Samoa
{ "aw", "aw", 0, &NorthAmerica },  // Aruba
{ "az", "az", 0, &Asia },  // Azerbaijan
{ "ba", "ba", 0, &Europe },  // Bosnia and Herzegovina
{ "bb", "bb", 0, &NorthAmerica },  // Barbados
{ "bd", "bd", 0, &Asia},  // Bangladesh
{ "bf", "bf", 0, &Africa },  // Burkina Faso
{ "bg", "bg", 1, &Europe},  // Bulgaria
{ "bh", "bh", 0, &Asia },  // Bahrain
{ "bi", "bi", 0, &Africa },  // Burundi
{ "bj", "bj", 0, &Africa },  // Benin
{ "bm", "bm", 0, &NorthAmerica },  // Bermuda
{ "bn", "bn", 0, &Asia },  // Brunei
{ "bo", "bo", 0, &SouthAmerica },  // Bolivia
{ "bs", "bs", 0, &NorthAmerica},  // Bahamas
{ "bt", "bt", 0, &Asia },  // Bhutan
{ "bw", "bw", 0, &Africa },  // Botswana
{ "by", "by", 0, &Europe},  // Belarus
{ "bz", "bz", 0, &NorthAmerica },  // Belize
{ "cd", "cd", 0, &Africa },  // Congo (Kinshasa)
{ "cf", "cf", 0, &Africa },  // Central African Republic
{ "cg", "cg", 0, &Africa },  // Congo (Brazzaville)
{ "ci", "ci", 0, &Africa },  // Ivory Coast
{ "cm", "cm", 0, &Africa },  // Cameroon
{ "cr", "cr", 0, &NorthAmerica },  // Costa Rica
{ "cu", "cu", 0, &NorthAmerica },  // Cuba
{ "cv", "cv", 0, &Africa },  // Cape Verde
{ "cx", "cx", 0, &Oceania },  // Christmas Island
{ "cy", "cy", 0, &Europe },  // Cyprus
{ "dj", "dj", 0, &Africa },  // Djibouti
{ "dm", "dm", 0, &NorthAmerica },  // Dominica
{ "do", "do", 0, &NorthAmerica },  // Dominican Republic
{ "dz", "dz", 0, &Africa },  // Algeria
{ "ec", "ec", 0, &SouthAmerica },  // Ecuador
{ "ee", "ee", 0, &Europe},  // Estonia
{ "eg", "eg", 0, &Africa },  // Egypt
{ "eh", "eh", 0, &Africa },  // Western Sahara
{ "er", "er", 0, &Africa },  // Eritrea
{ "et", "et", 0, &Africa },  // Ethiopia
{ "fj", "fj", 0, &Oceania },  // Fiji
{ "fk", "fk", 0, &SouthAmerica },  // Falkland Islands
{ "fm", "fm", 0, &Oceania },  // Micronesia
{ "fo", "fo", 0, &Europe },  // Faroe Islands
{ "ga", "ga", 0, &Africa },  // Gabon
{ "gd", "gd", 0, &NorthAmerica },  // Grenada
{ "ge", "ge", 0, &Asia },  // Georgia
{ "gf", "gf", 0, &SouthAmerica },  // French Guiana
{ "gg", "gg", 0, &Europe },  // Guernsey
{ "gh", "gh", 0, &Africa },  // Ghana
{ "gi", "gi", 0, &Europe },  // Gibraltar
{ "gl", "gl", 0, &NorthAmerica },  // Greenland
{ "gm", "gm", 0, &Africa },  // Gambia
{ "gn", "gn", 0, &Africa },  // Guinea
{ "gp", "gp", 0, &NorthAmerica },  // Guadeloupe
{ "gq", "gq", 0, &Africa },  // Equatorial Guinea
{ "gs", "gs", 0, &SouthAmerica },  // South Georgia and the South Sandwich Islands
{ "gt", "gt", 0, &NorthAmerica},  // Guatemala
{ "gu", "gu", 0, &Oceania },  // Guam
{ "gw", "gw", 0, &Africa },  // Guinea-Bissau
{ "gy", "gy", 0, &SouthAmerica },  // Guyana
{ "hm", "hm", 0, &Oceania },  // Heard Island and McDonald Islands
{ "hn", "hn", 0, &NorthAmerica },  // Honduras
{ "ht", "ht", 0, &NorthAmerica },  // Haiti
{ "im", "im", 0, &Europe },  // Isle of Man
{ "io", "io", 0, &Asia },  // British Indian Ocean Territory
{ "iq", "iq", 0, &Asia },  // Iraq
{ "ir", "ir", 0, &Asia},  // Iran
{ "is", "is", 0, &Europe },  // Iceland
{ "je", "je", 0, &Europe },  // Jersey
{ "jm", "jm", 0, &NorthAmerica },  // Jamaica
{ "jo", "jo", 0, &Asia },  // Jordan
{ "ke", "ke", 0, &Africa },  // Kenya
{ "kg", "kg", 0, &Asia },  // Kyrgyzstan
{ "kh", "kh", 0, &Asia },  // Cambodia
{ "ki", "ki", 0, &Oceania },  // Kiribati
{ "kp", "kp", 0, &Asia },  // North Korea
{ "ky", "ky", 0, &NorthAmerica },  // Cayman Islands
{ "kz", "kz", 0, &Asia },  // Kazakhstan
{ "la", "la", 0, &Asia },  // Laos
{ "lc", "lc", 0, &NorthAmerica },  // Saint Lucia
{ "li", "li", 0, &Europe },  // Liechtenstein
{ "lk", "lk", 0, &Asia },  // Sri Lanka
{ "lr", "lr", 0, &Africa },  // Liberia
{ "ls", "ls", 0, &Africa },  // Lesotho
{ "lt", "lt", 0, &Europe},  // Lithuania
{ "lv", "lv", 1, &Europe},  // Latvia
{ "ly", "ly", 0, &Africa },  // Libya
{ "ma", "ma", 0, &Africa },  // Morocco
{ "mc", "mc", 0, &Europe },  // Monaco
{ "md", "md", 0, &Europe},  // Moldova
{ "mg", "mg", 0, &Africa},  // Madagascar
{ "mh", "mh", 0, &Oceania },  // Marshall Islands
{ "mk", "mk", 0, &Europe},  // Macedonia
{ "ml", "ml", 0, &Africa },  // Mali
{ "mm", "mm", 0, &Asia },  // Myanmar
{ "mn", "mn", 0, &Asia },  // Mongolia
{ "mo", "mo", 0, &Asia },  // Macao SAR China
{ "mp", "mp", 0, &Oceania },  // Northern Mariana Islands
{ "mq", "mq", 0, &NorthAmerica },  // Martinique
{ "mr", "mr", 0, &Africa },  // Mauritania
{ "ms", "ms", 0, &NorthAmerica },  // Montserrat
{ "mt", "mt", 0, &Europe },  // Malta
{ "mu", "mu", 0, &Asia },  // Mauritius
{ "mv", "mv", 0, &Asia },  // Maldives
{ "mw", "mw", 0, &Africa },  // Malawi
{ "mz", "mz", 0, &Africa },  // Mozambique
{ "na", "na", 0, &Africa },  // Namibia
{ "nc", "nc", 0, &Oceania },  // New Caledonia
{ "ne", "ne", 0, &Africa },  // Niger
{ "nf", "nf", 0, &Oceania },  // Norfolk Island
{ "ng", "ng", 0, &Africa },  // Nigeria
{ "ni", "ni", 0, &NorthAmerica },  // Nicaragua
{ "np", "np", 0, &Asia },  // Nepal
{ "nr", "nr", 0, &Oceania },  // Nauru
{ "nu", "nu", 0, &Oceania },  // Niue
{ "om", "om", 0, &Asia},  // Oman
{ "pa", "pa", 0, &NorthAmerica},  // Panama
{ "pe", "pe", 0, &SouthAmerica },  // Peru
{ "pf", "pf", 0, &Oceania },  // French Polynesia
{ "pg", "pg", 0, &Oceania },  // Papua New Guinea
{ "pm", "pm", 0, &NorthAmerica },  // Saint Pierre and Miquelon
{ "pn", "pn", 0, &Oceania },  // Pitcairn
{ "pr", "pr", 0, &NorthAmerica },  // Puerto Rico
{ "ps", "ps", 0, &Asia },  // Palestinian Territory
{ "pw", "pw", 0, &Oceania },  // Palau
{ "py", "py", 0, &SouthAmerica },  // Paraguay
{ "rw", "rw", 0, &Africa },  // Rwanda
{ "sb", "sb", 0, &Oceania },  // Solomon Islands
{ "sc", "sc", 0, &Asia },  // Seychelles
{ "sd", "sd", 0, &Africa },  // Sudan
{ "sh", "sh", 0, &Africa },  // Saint Helena
{ "si", "si", 1, &Europe},  // Slovenia
{ "sj", "sj", 0, &Europe },  // Svalbard and Jan Mayen
{ "sl", "sl", 0, &Africa },  // Sierra Leone
{ "sm", "sm", 0, &Europe },  // San Marino
{ "sn", "sn", 0, &Africa },  // Senegal
{ "so", "so", 0, &Africa },  // Somalia
{ "sr", "sr", 0, &SouthAmerica },  // Suriname
{ "st", "st", 0, &Africa },  // Sao Tome and Principe
{ "sv", "sv", 0, &NorthAmerica },  // El Salvador
{ "sy", "sy", 0, &Asia },  // Syria
{ "sz", "sz", 0, &Africa },  // Swaziland
{ "td", "td", 0, &Africa },  // Chad
{ "tg", "tg", 0, &Africa },  // Togo
{ "tj", "tj", 0, &Asia },  // Tajikistan
{ "tl", "tl", 0, &Oceania },  // East Timor
{ "tm", "tm", 0, &Asia },  // Turkmenistan
{ "tn", "tn", 0, &Africa },  // Tunisia
{ "to", "to", 0, &Oceania },  // Tonga
{ "tt", "tt", 0, &NorthAmerica },  // Trinidad and Tobago
{ "tv", "tv", 0, &Oceania },  // Tuvalu
{ "tz", "tz", 0, &Africa},  // Tanzania
{ "ua", "ua", 4, &Europe},  // Ukraine
{ "ug", "ug", 0, &Africa },  // Uganda
{ "um", "um", 0, &NorthAmerica },  // United States Minor Outlying Islands
{ "uy", "uy", 0, &SouthAmerica },  // Uruguay
{ "uz", "uz", 0, &Asia},  // Uzbekistan
{ "va", "va", 0, &Europe },  // Vatican
{ "vc", "vc", 0, &NorthAmerica },  // Saint Vincent and the Grenadines
{ "ve", "ve", 0, &SouthAmerica },  // Venezuela
{ "vg", "vg", 0, &NorthAmerica },  // British Virgin Islands
{ "vi", "vi", 0, &NorthAmerica },  // U.S. Virgin Islands
{ "vu", "vu", 0, &Oceania },  // Vanuatu
{ "ws", "ws", 0, &Oceania },  // Samoa
{ "ye", "ye", 0, &Asia },  // Yemen
{ "yu", "yu", 1, &Europe},  // Serbia And Montenegro
{ "zm", "zm", 0, &Africa },  // Zambia
{ "zw", "zw", 0, &Africa },  // Zimbabwe
};

static const CountryFarmDescriptor defaultCountryDescriptor = { "us", "us", 4, &Europe };

+ (const struct _CountryFarmDescriptor *)getFarmDescriptorForCountry {
    NSString *CC = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    const char *cc = [CC UTF8String];
    //cc = "GB";  // For testing
    if (cc) {
	for (int i = 0; i < numCountryFarmDescriptors; i++) {
	    const CountryFarmDescriptor *farmDescriptor = &countryFarmDescriptors[i];
	    if (strcasecmp(cc, farmDescriptor->countryName) == 0) {
		return farmDescriptor;
	    }
	}
    }
    return &defaultCountryDescriptor;
}

#undef EC_TEST_ALL_SERVERS
#ifdef EC_TEST_ALL_SERVERS
#define numContintinentDescriptors 6
static const ContinentFarmDescriptor *continentDescriptors[numContintinentDescriptors] = { &Africa, &Asia, &Europe, &NorthAmerica, &Oceania, &SouthAmerica };
static int testi = 0, testj= 0;
static int testphase = 2;
#endif

- (void)nextHost:(id)data {	// runs in a secondary thread    // sync once with one ntp server
    assert([NSThread currentThread] == thread);
    hostTimer = nil;
    [hostname release];
    // set up a server
#ifdef EC_TEST_ALL_SERVERS
again:
    switch (testphase) {
	case 0:
	    if (testi < numCountryFarmDescriptors) {
		const CountryFarmDescriptor *farmDescriptor = &countryFarmDescriptors[testi];
		if (testj < farmDescriptor->numberOfServers) {
		    hostname = [NSString stringWithFormat:@"%d.%s.pool.ntp.org", testj, farmDescriptor->poolNameForCountry];
		    ++testj;
		    break;
		} else {
		    testj=0;
		    ++testi;
		    goto again;
		}
		break;
	    } else {
		++testphase;
		testi = 0;
		// fall thru
	    }
	case 1:
	    if (testi < numContintinentDescriptors) {
		const ContinentFarmDescriptor *farmDescriptor = continentDescriptors[testi];
		if (testj < farmDescriptor->numberOfServers) {
		    hostname = [NSString stringWithFormat:@"%d.%s.pool.ntp.org", testj, farmDescriptor->farmName];
		    ++testj;
		    break;
		} else {
		    ++testi;
		    testj = 0;
		    goto again;
		}
		break;
	    } else {
		++testphase;
		testi = 0;
		// fall thru
	    }
	case 2:
	    if (testi < 4) {
		hostname = [NSString stringWithFormat:@"%d.pool.ntp.org", testi];
		++testi;
		break;
	    } else {
		++testphase;
		testi = 0;
		// fall thru
	    }
	case 3:
	    hostname = @"time.apple.com";
	    testphase = 0;
	    testi = 0;
	    break;
    }
    printf("Test host %s\n", [hostname UTF8String]);
#else
    int serverNumber = random() & 03;  // Random number between 0 and 3
    int numCountryServers = countryFarmDescriptor->numberOfServers;
    int numContinentServers = countryFarmDescriptor->continentDescriptor->numberOfServers;
    if (hostNum < numCountryServers) {		// first try the country pool
	if (numCountryServers == 4) {
	    serverNumber = hostNum;
	}
	hostname = [NSString stringWithFormat:@"%d.%s.pool.ntp.org", serverNumber, countryFarmDescriptor->poolNameForCountry];
    } else if (hostNum < numCountryServers + numContinentServers) {	// then the continent pool
	if (numContinentServers == 4) {
	    serverNumber = hostNum - numCountryServers;
	}
	hostname = [NSString stringWithFormat:@"%d.%s.pool.ntp.org", serverNumber, countryFarmDescriptor->continentDescriptor->farmName];
    } else if (hostNum < numCountryServers + numContinentServers + 4) {	// then the global pool
	serverNumber = hostNum - numCountryServers - numContinentServers;
	hostname = [NSString stringWithFormat:@"%d.pool.ntp.org", serverNumber];
    } else {			// finally the Apple default
	hostname = @"time.apple.com";
	hostNum = 0;
    }
#endif
    pollInterval = ECNTPInterval;
    sigmaSkew = meanSkew = meanRTT = sumSkews = sumSkews2 = countGood = countBad = 0;
    skewLB = -1e9;  skewUB = 1e9;
    canceled = false;
    goodSync = false;
    goodSinceASTC = false;

    assert(connection == nil);
    connection = [[TSNTPConnection alloc] initWithDelegate:(TSConnectionDelegate*)self hostname:hostname];
    assert(connection);

    //tracePrintf1("nextHost: %@", hostname);

    if (userRequested) {
	[ChronometerAppDelegate showECTimeStatus];
    }    
    // begin the resolution process; asynchronously calls startDone when finished or failed
    [connection startResolution];
    [hostname retain];
    [ECBackgroundData refresh];
    [TSTime notifySyncStatusChanged];
}

- (void)getSample {
    assert(sampleTimer == nil);
    // get the data after a short delay
    sampleTimer = [NSTimer scheduledTimerWithTimeInterval:pollInterval target:self selector:@selector(getASample:) userInfo:nil repeats:false];
}
- (void)getASample:(id)data {
    sampleTimer = nil;
    [connection getOneSample];	// will call sampleReady when the data arrives or there's an error
}

- (void)startDone:(id)obj {	// called when connection initialization is finished
    if (obj) {		    // non-nil means initialization succeeded
	[saveIP release];
	saveIP = [connection.ipaddr retain];
	pollInterval = .25;
	[self getSample];
    } else {
	//[ChronometerAppDelegate noteTimeAtPhase:"ECTS: startDone (trying another)"];
	[connection release];
	connection = nil;
	[hostname release];
	[saveIP release];
	hostname = nil;
	saveIP = nil;
	// try another host after a delay
	++hostNum;
	[self syncAfter:ECHostTimeOut];
    }
    [ECBackgroundData refresh];
    [TSTime notifySyncStatusChanged];
}

- (void)cleanup {
    [sampleTimer invalidate];
    sampleTimer = nil;
    // clean up the current connection
    [connection stop];
    [connection release];
    connection = nil;
    [ECBackgroundData refresh];
    [TSTime notifySyncStatusChanged];
}

- (void)cleanupAndReschedule:(int)interval {
    [self cleanup];
    
    // and do another later
    if (pendingRequest) {
	[self syncNow];
	pendingRequest = false;
    } else {
	[self syncAfter:interval];
    }
}

- (void)cleanupAndReschedule1:(NSTimer*)theTimer {
    [self cleanupAndReschedule:ECHostTimeOut];
}

- (void)cleanupAndReschedule2:(NSTimer*)theTimer {
#ifdef EC_TEST_ALL_SERVERS
    [self cleanupAndReschedule:1];
#else
    [self cleanupAndReschedule:ECNTPInterval];
#endif
}

- (void)sampleReady:(TSSample *)sample {	    // TSConnection delegate method:  process result from the server
    double s = 0;
    double r = 1e9;
    double center = -1e9;
    double uncertainty = 1e9;
    goodSync = false;
    if (sample == nil) {
	++countBad;
	pollInterval = pollInterval * 2;
	sigmaSkew = sigmaHuge;
	//[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady: nil; %d bad", countBad] UTF8String]];
    } else {
	s = sample.clockSkew;
	r = sample.roundTripTime;
	//[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady: skew= %+05.3f; rtt= %05.3f ", s, r] UTF8String]];
	// sanity check
	if (r < minRTT			||  // unreasonably short
	    r > maxRTT			||  // unreasonbly long
	    ((countGood > samplesUB) && (s > meanSkew + sigmaSpread*sigmaSkew || s < meanSkew - sigmaSpread*sigmaSkew)) || // more than 3 sigma from mean
	    fabs(s) > maxSkew ) {	    // off by more than 3000 years?!?
	    ++countBad;
	    pollInterval = pollInterval * 2;
	    sigmaSkew = sigmaHuge;
	    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady (insane): %d good, %d bad", countGood, countBad] UTF8String]];
	} else {
	    ++countGood;
	    countBad = 0;
	    sumSkews += s;
	    sumSkews2 += s * s;
	    meanSkew = sumSkews / countGood;
	    sigmaSkew = sqrt(sumSkews2/countGood - meanSkew*meanSkew);
	    meanRTT = ((meanRTT * (countGood-1)) + r) / countGood;
	    skewLB = fmax(skewLB, s - r/2);
	    skewUB = fmin(skewUB, s + r/2);
	    center =      (skewUB + skewLB) / 2;
	    uncertainty = (skewUB - skewLB) / 2;
	    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady 4: (%d/%d) [%4.3f : %4.3f] center= %4.3f ±%4.3f, meanSkew= %4.3f, sigmaSkew= %4.3f, meanRTT= %4.3f", countGood, countBad, skewLB, skewUB, center, uncertainty, meanSkew, sigmaSkew, meanRTT] UTF8String]];
	    if (uncertainty > 0 && uncertainty < (virgin ? sortaGoodRTT : goodRTT)) {
		[TSTime setRSkew:center];
		virgin = false;			    // :-)
	    }
	}
    }
    
    if (uncertainty <= 0 || countBad >= tooBad) {
	//[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady 5 (giving up): %d good, %d bad", countGood, countBad] UTF8String]];
	// cleanup and reschedule in the next run loop loop
	++hostNum;
	[NSTimer scheduledTimerWithTimeInterval:.0001 target:self selector:@selector(cleanupAndReschedule1:) userInfo:nil repeats:false];
    } else if (countGood >= samplesUB || (countGood > 1 && (uncertainty < reallyGoodRTT))) {
	assert(uncertainty<1e9); assert(center>-1e9);
	if (fabs(sigmaSkew) < defaultAccuracy) {
	    goodSync = true;
	    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady 7 (success): %d good, %d bad", countGood, countBad] UTF8String]];
	    [TSTime setRSkew:center];
#if 0
	    if (userRequested) {
		[ChronometerAppDelegate showECStatusMessage:[NSString stringWithFormat:@"clock error was %5.3f ±%5.3f seconds", center, uncertainty ]];
	    }
#endif    
	    // cleanup and reschedule in the next run loop loop
	    [NSTimer scheduledTimerWithTimeInterval:.0001 target:self selector:@selector(cleanupAndReschedule2:) userInfo:nil repeats:false];
	} else {
	    // reset and keep trying for a more consistent sample
	    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"ECTS: sampleReady 8 (reset): %g", sigmaSkew] UTF8String]];
	    sigmaSkew = meanSkew = meanRTT = sumSkews = sumSkews2 = countGood = countBad = 0;
	    skewLB = -1e9;  skewUB = 1e9;
	    [self getSample];
	}
    } else {
	// need more data
	[self getSample];
    }
    if (userRequested) {
	[ChronometerAppDelegate showECTimeStatus];
    } else {
	[ChronometerAppDelegate setNetworkActivityIndicator:[ECTS active]];
    }
    if (goodSync) {
	userRequested = false;
	goodSinceASTC = true;
    }
    [ECBackgroundData refresh];
    [TSTime notifySyncStatusChanged];
}

@end
