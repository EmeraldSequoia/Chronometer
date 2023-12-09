//
//  ESCalendar.m
//  Emerald Sequoia LLC
//
//  Created by Steve Pucci 5/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#include <pthread.h>

#include "ESCalendar.h"

#include "TSTime.h"  // for +[TSTime currentTime] only

#ifndef NDEBUG  // Testing only
#include "ECGeoNames.h"
#endif

struct _ESTimeZone {
    NSTimeZone *nsTimeZone;
    NSCalendar *nsCalendar;
    NSCalendar *utcCalendar;
    int refCount;
};

// Input time is presumed to be in Cocoa format (seconds since 1/1/2001 UTC)

#define kECJulianDayOf1990Epoch (2447891.5)
#define kEC1990Epoch (-347241600.0)  // 12/31/1989 GMT - 1/1/2001 GMT, calculated as 24 * 3600 * (365 * 8 + 366 * 3 + 1) /*1992, 1996, 2000*/ and verified with NSCalendar
#define kECAverageDaysInGregorianYear (365.2425)
#define kECDaysInGregorianCycle (kECAverageDaysInGregorianYear * 400)
#define kECDaysInJulianCycle (365.25 * 4)
#define kECDaysInNonLeapCentury (36525)

#define kECJulianGregorianSwitchoverTimeInterval (-13197600000)

static double
ES_fmod(double arg1,
	double arg2)
{
    return (arg1 - floor(arg1/arg2)*arg2);
}

// These methods work in terms of UTC.  To work in terms of local, add tz offset to timeInterval before breaking out (or subtract after combining)

// Return calendar components from an NSTimeInterval (UTC)
void
ESCalendar_UTCComponentsFromTimeInterval(NSTimeInterval timeInterval,
                                         int            *era,
					 int            *year,
					 int            *month,
					 int            *day,
					 int            *hour,
					 int            *minute,
					 double         *seconds) {
    double xRemainder;
    int signedYear;
    double x0;
    if (timeInterval < kECJulianGregorianSwitchoverTimeInterval) {
        double x1F = 730793 + timeInterval/(24 * 3600);
        double x1 = floor(x1F);  // Algorithm only works on even day boundaries?  At least that's true of Gregorian
        xRemainder = x1F - x1;
        signedYear = floor((4 * x1 + 3) / kECDaysInJulianCycle);
        x0 = x1 - floor(kECDaysInJulianCycle * signedYear / 4.0);
    } else {
        double x2F = 730791 + timeInterval/(24 * 3600);

        double x2 = floor(x2F);  // Algorithm only works on even day boundaries; else has trouble at end of year, e.g., 12/31/1997 23:59:59 and back several hours
        xRemainder = x2F - x2;

        int century = floor(4 * x2 + 3) / kECDaysInGregorianCycle;
        double x1 = x2 - floor(kECDaysInGregorianCycle * century / 4.0);
        int yearWithinCentury = floor((100 * x1 + 99) / kECDaysInNonLeapCentury);
        signedYear = (100 * century) + yearWithinCentury;
        x0 = x1 - floor(kECDaysInNonLeapCentury * yearWithinCentury / 100.0);
    }
    int monthI = floor((5 * x0 + 461) / 153);
    if (monthI > 12) {
        *month = monthI - 12;
        signedYear++;
    } else {
        *month = monthI;
    }
    if (signedYear <= 0) {
        *era = 0;
        *year = 1 - signedYear;
    } else {
        *era = 1;
        *year = signedYear;
    }
    double dayF = x0 - floor((153 * monthI - 457) / 5.0) + 1;
    *day = round(dayF);
    double hoursF = xRemainder * 24;
    int hoursI = floor(hoursF);
    *hour = hoursI;
    double minutesF = (hoursF - hoursI) * 60;
    int minutesI = floor(minutesF);
    *minute = minutesI;
    *seconds = (minutesF - minutesI) * 60;
}

void
ESCalendar_UTCDateComponentsFromTimeInterval(NSTimeInterval   timeInterval,
					     ESDateComponents *cs) {
    ESCalendar_UTCComponentsFromTimeInterval(timeInterval, &cs->era, &cs->year, &cs->month, &cs->day, &cs->hour, &cs->minute, &cs->seconds);
}

// Return an NSTimeInterval from calendar components (UTC)
double
ESCalendar_timeIntervalFromUTCComponents(int    era,
					 int    year,
					 int    month,
					 int    day,
					 int    hour,
					 int    minute,
					 double seconds) {
    int signedYear = era == 0 ? 1 - year : year;
    int monthI;
    if (month < 3) {
        monthI = month + 12;
        signedYear--;
    } else {
        monthI = month;
    }
    double J;
    if (era == 0 ||
        year < 1582 ||
        (year == 1582 &&
         (month < 10 ||
          month == 10 && day < 15))) {  // Could be < 5 instead; 5-14 inclusive are really undefined in this convention
        J = 1721116.5 + floor(1461 * signedYear / 4.0);
    } else {
        // Gregorian
        double c = floor(signedYear/100.0);
        double x = signedYear - 100 * c;
        J = 1721118.5 + floor(146097 * c / 4.0) + floor(36525 * x / 100);
    }
    J += floor((153 * monthI - 457) / 5.0) + day;
    NSTimeInterval returnTimeInterval = (J - kECJulianDayOf1990Epoch)*24*3600 + kEC1990Epoch + hour * 3600 + minute * 60 + seconds;
    //printf("timeIntervalFromUTC %d-%04d-%02d-%02d-%02d:%02d returning %.2f\n", era, year, month, day, hour, minute, returnTimeInterval);
    return returnTimeInterval;
}

// Return an NSTimeInterval from calendar components (UTC)
NSTimeInterval
ESCalendar_timeIntervalFromUTCDateComponents(ESDateComponents *cs) {
    return ESCalendar_timeIntervalFromUTCComponents(cs->era, cs->year, cs->month, cs->day, cs->hour, cs->minute, cs->seconds);
}

// Allocate and init ("new") a time zone
ESTimeZone *
ESCalendar_initTimeZoneFromOlsonID(const char *olsonID) {
    ESTimeZone *tz = (ESTimeZone *)malloc(sizeof(ESTimeZone));
    tz->nsTimeZone = [[NSTimeZone alloc] initWithName:[NSString stringWithCString:olsonID encoding:NSUTF8StringEncoding]];
    assert(tz->nsTimeZone);
    tz->nsCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    assert(tz->nsCalendar);
    [tz->nsCalendar setTimeZone:tz->nsTimeZone];
    tz->utcCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    assert(tz->utcCalendar);
    [tz->utcCalendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    tz->refCount = 1;
    return tz;
}

// Clean up and Free the time zone
static void
ESCalendar_freeTimeZone(ESTimeZone *tz) {
    assert(tz->refCount == 0);
    [tz->nsTimeZone release];
    tz->nsTimeZone = nil;
    [tz->nsCalendar release];
    tz->nsCalendar = nil;
    [tz->utcCalendar release];
    tz->utcCalendar = nil;
    free(tz);
}

extern ESTimeZone *
ESCalendar_retainTimeZone(ESTimeZone *estz) {
    ++estz->refCount;
    return estz;
}

extern void
ESCalendar_releaseTimeZone(ESTimeZone *estz) {
    if (estz) {
	if (--estz->refCount == 0) {
	    ESCalendar_freeTimeZone(estz);
	}
    }
}


extern bool
ESCalendar_validOlsonID(const char *olsonID) {
    NSTimeZone *tz = [[NSTimeZone alloc] initWithName:[NSString stringWithCString:olsonID encoding:NSUTF8StringEncoding]];
    bool ok = (tz != nil);
    [tz release];
    return ok;
}


extern const char *
ESCalendar_timeZoneName(ESTimeZone *estz) {
    return [[estz->nsTimeZone name] UTF8String];
}

#ifdef ESCALENDAR_NS
extern NSTimeZone *
ESCalendar_nsTimeZone(ESTimeZone *estz) {
    return estz->nsTimeZone;
}
#endif

void
ESCalendar_gregorianToHybrid(int *era,
			     int *year,
			     int *month,
			     int *day) {
    // If the specified date is in the hybrid's Gregorian section, there's nothing to do
    if (*era == 1 &&
	(*year > 1582 ||
	 (*year == 1582 &&
	  (*month > 10 ||
	   (*month == 10 &&
	    *day >= 15))))) {
	return;
    }
    //NSTimeInterval testInterval = ESCalendar_timeIntervalFromUTCComponents(*era, *year, *month, *day, 12, 0, 0);
    //printf("gTH input timeInterval (assuming UTC) of %.2f\n", testInterval);
    // Convert from Gregorian date to Julian day number
    int signedYear = *era == 0 ? 1 - *year : *year;
    int monthI;
    if (*month < 3) {
        monthI = *month + 12;
        signedYear--;
    } else {
        monthI = *month;
    }
    //printf("\nyear %d\n", *year);
    //printf("signedYear %d\n", signedYear);
    double c = floor(signedYear/100.0);
    //printf("c %.1f\n", c);
    double x = signedYear - 100 * c;
    //printf("x %.1f\n", x);
    double J = 1721118.5 + floor(146097 * c / 4) + floor(36525 * x / 100);
    J += floor((153 * monthI - 457) / 5.0) + *day;
    //printf("Julian gTH %.1f\n", J);

    // Then from Julian day number to Julian date
    double x1F = J - 1721117.5;
    double x1 = floor(x1F);  // Algorithm only works on even day boundaries?  At least that's true of Gregorian
    signedYear = floor((4 * x1 + 3) / kECDaysInJulianCycle);
    double x0 = x1 - floor(kECDaysInJulianCycle * signedYear / 4.0);
    monthI = floor((5 * x0 + 461) / 153);
    if (monthI > 12) {
        *month = monthI - 12;
        signedYear++;
    } else {
        *month = monthI;
    }
    if (signedYear <= 0) {
        *era = 0;
        *year = 1 - signedYear;
    } else {
        *era = 1;
        *year = signedYear;
    }
    double dayF = x0 - floor((153 * monthI - 457) / 5.0) + 1;
    *day = round(dayF);
    //testInterval = ESCalendar_timeIntervalFromUTCComponents(*era, *year, *month, *day, 12, 0, 0);
    //printf("gTH output timeInterval (assuming UTC) of %.2f\n", testInterval);
}

void
ESCalendar_hybridToGregorian(int *era,
			     int *year,
			     int *month,
			     int *day) {
    // If the specified date is in the hybrid's Gregorian section, there's nothing to do
    if (*era == 1 &&
	(*year > 1582 ||
	 (*year == 1582 &&
	  (*month > 10 ||
	   (*month == 10 &&
	    *day >= 15))))) {
	return;
    }
    //NSTimeInterval testInterval = ESCalendar_timeIntervalFromUTCComponents(*era, *year, *month, *day, 12, 0, 0);
    //printf("hTG input timeInterval (assuming UTC) of %.2f\n", testInterval);
    // Convert from Julian date to Julian day number
    int signedYear = *era == 0 ? 1 - *year : *year;
    int monthI;
    if (*month < 3) {
        monthI = *month + 12;
        signedYear--;
    } else {
        monthI = *month;
    }
    double J = 1721116.5 + floor(1461 * signedYear / 4.0);
    J += floor((153 * monthI - 457) / 5.0) + *day;
    //printf("\nJulian %.1f\n", J);

    // Then from Julian day number to Gregorian date
    double x2F = J - 1721119.5;
    int x2 = floor(x2F);  // Algorithm only works on even day boundaries; else has trouble at end of year, e.g., 12/31/1997 23:59:59 and back several hours

    int century = floor((4 * x2 + 3) / kECDaysInGregorianCycle);
    double x1 = x2 - floor(kECDaysInGregorianCycle * century / 4.0);
    int yearWithinCentury = floor((100 * x1 + 99) / kECDaysInNonLeapCentury);
    signedYear = (100 * century) + yearWithinCentury;
    double x0 = x1 - floor(kECDaysInNonLeapCentury * yearWithinCentury / 100.0);
    monthI = floor((5 * x0 + 461) / 153);
    if (monthI > 12) {
        *month = monthI - 12;
        signedYear++;
    } else {
        *month = monthI;
    }
    if (signedYear <= 0) {
        *era = 0;
        *year = 1 - signedYear;
    } else {
        *era = 1;
        *year = signedYear;
    }
    double dayF = x0 - floor((153 * monthI - 457) / 5.0) + 1;
    *day = round(dayF);
    //testInterval = ESCalendar_timeIntervalFromUTCComponents(*era, *year, *month, *day, 12, 0, 0);
    //printf("hTG output timeInterval (assuming UTC) of %.2f\n", testInterval);
}

#ifndef NDEBUG
static void testHybridConversion(void) {
    NSTimeInterval timeInterval = ESCalendar_timeIntervalFromUTCComponents(0, 3999, 1, 1, 12, 0, 0);
    for (int i = 0; i < 1000; i++) {
	int eraReturn;
	int yearReturn;
	int monthReturn;
	int dayReturn;
	int hourReturn;
	int minuteReturn;
	double secondsReturn;
	ESCalendar_UTCComponentsFromTimeInterval(timeInterval, &eraReturn, &yearReturn, &monthReturn, &dayReturn, &hourReturn, &minuteReturn, &secondsReturn);
	//printf("\nHybrid %d-%04d-%02d-%02d-%02d:%02d => ", eraReturn, yearReturn, monthReturn, dayReturn, hourReturn, minuteReturn);
	int eraReturn2 = eraReturn;
	int yearReturn2 = yearReturn;
	int monthReturn2 = monthReturn;
	int dayReturn2 = dayReturn;
	int hourReturn2 = hourReturn;
	int minuteReturn2 = minuteReturn;
	double secondsReturn2 = secondsReturn;
	ESCalendar_hybridToGregorian(&eraReturn2, &yearReturn2, &monthReturn2, &dayReturn2);
	//printf("hTG => %d-%04d-%02d-%02d-%02d:%02d => ", eraReturn2, yearReturn2, monthReturn2, dayReturn2, hourReturn2, minuteReturn2);
	//assert(dayReturn != dayReturn2);
	ESCalendar_gregorianToHybrid(&eraReturn2, &yearReturn2, &monthReturn2, &dayReturn2);
	//printf("gTH => %d-%04d-%02d-%02d-%02d:%02d\n", eraReturn2, yearReturn2, monthReturn2, dayReturn2, hourReturn2, minuteReturn2);
	assert(eraReturn == eraReturn2);
	assert(yearReturn == yearReturn2);
	assert(monthReturn == monthReturn2);
	assert(dayReturn == dayReturn2);
	assert(hourReturn == hourReturn2);
	assert(minuteReturn == minuteReturn2);
	assert(fabs(secondsReturn - secondsReturn2) < 0.001);
	timeInterval -= 24*3600;
    }
}
#endif

static bool ESCalendar_nscalendarIsPureGregorian = false;
static bool ESCalendar_initialized = false;

static NSDateFormatter *dateFormatter = nil;
static NSDateFormatter *timeFormatter = nil;

static ESTimeZone *localTimeZone;

void
ESCalendar_init(void) {
    NSTimeInterval testTimeInterval = kECJulianGregorianSwitchoverTimeInterval - 10;
    NSCalendar *utcCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [utcCalendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    // NSDateComponents *dcdbg0 = [utcCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
    //                                           fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:kECJulianGregorianSwitchoverTimeInterval]];
    // printf("switchover interval: %04d/%02d/%02d %02d:%02d:%02d\n",
    //        dcdbg0.year, dcdbg0.month, dcdbg0.day, dcdbg0.hour, dcdbg0.minute, dcdbg0.second);
    NSDateComponents *dc = [utcCalendar components:(NSCalendarUnitDay)
                                          fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:testTimeInterval]];
    // NSDateComponents *dcdbg = [utcCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
    //                                       fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:testTimeInterval]];
    // printf("test interval: %04d/%02d/%02d %02d:%02d:%02d\n",
    //        dcdbg.year, dcdbg.month, dcdbg.day, dcdbg.hour, dcdbg.minute, dcdbg.second);
    [utcCalendar release];
    if (dc.day == 14) {
	ESCalendar_nscalendarIsPureGregorian = true;
    } else {
	assert(dc.day == 4);
	ESCalendar_nscalendarIsPureGregorian = false;
    }

    dateFormatter = [[NSDateFormatter alloc] init];
    timeFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [timeFormatter setDateFormat:@"h:mm:ss a"];

    assert(!localTimeZone);
    localTimeZone = ESCalendar_initTimeZoneFromOlsonID([[[NSTimeZone localTimeZone] name] UTF8String]);

    ESCalendar_initialized = true;
#ifndef NDEBUG
    // printf("Calendar is%s pure Gregorian\n", ESCalendar_nscalendarIsPureGregorian ? "" : " NOT");
    // assert(ESCalendar_nscalendarIsPureGregorian);
    testHybridConversion();
#endif
}

extern void printADateWithTimeZone(NSTimeInterval dt, ESTimeZone *estz);

// Number of seconds ahead of UTC at the given time in the given time zone
double
ESCalendar_tzOffsetForTimeInterval(ESTimeZone     *estz,
				   NSTimeInterval dt) {
    if (!estz) {
	return 0;  // Bogus but reproduces prior behavior
    }
    NSCalendar *ltCalendar = estz->nsCalendar;
    NSCalendar *utcCalendar = estz->utcCalendar;

    // This should really be [[calendar timeZone] secondsFromGMTForDate:[self currentDate]]
    // but NSCalendar and NSTimeZone developers don't seem to talk to each other

    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:dt];
    double fractionalSeconds = dt - floor(dt);

    // Note:  Even if ltCalendar and utcCalendar are pure Gregorian, the time zone is not going to be different before 1583 on different days, since no DST was present then.

    // The LT representation of the given date.  We need to do it this way because GMT is unambiguous going back from CS to date, but LT isn't
    NSDateComponents *ltCS = [ltCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
					   fromDate:date];
    //printf("ltCalendar reports %.0f as %d-%04d-%02d-%02d %02d:%02d:%02d\n", dt, ltCS.era, ltCS.year, ltCS.month, ltCS.day, ltCS.hour, ltCS.minute, ltCS.second);
    NSTimeInterval utcForDate = [[utcCalendar dateFromComponents:ltCS] timeIntervalSinceReferenceDate];
    //printf("...which, when interpreted as a UTC date, returns the time %.0f\n", utcForDate);
    // Assume PST, -8h.  UTC for a given *calendar date* will be 8 hours *behind* the corresponding local time for the same calendar date (because UTC gets to a given calendar date first).
    // So, counter-intuitively, we must return utc - lt rather than lt - utc here:
    double offset = utcForDate + fractionalSeconds - dt;
#undef TEST_NSCALENDAR_TZOFFSET_BUG
#ifdef TEST_NSCALENDAR_TZOFFSET_BUG
    double nsOffset = [[ltCalendar timeZone] secondsFromGMTForDate:date];
    if (fabs(offset - nsOffset) > .00001) {
	printf("%s %04d-%02d-%02d %02d:%02d:%02d lt: calculated offset %3.1f hours, ns offset %3.1f hours\n",
	       ltCS.era ? " CE" : "BCE",
	       ltCS.year, ltCS.month, ltCS.day, ltCS.hour, ltCS.minute, ltCS.second,
	       offset/3600, nsOffset/3600);
    }
#endif
    return offset;
}

// Return calendar components in the given time zone from an NSTimeInterval
void
ESCalendar_localComponentsFromTimeInterval(NSTimeInterval timeInterval,
                                           ESTimeZone     *timeZone,
                                           int            *era,
                                           int            *year,
                                           int            *month,
                                           int            *day,
                                           int            *hour,
                                           int            *minute,
                                           double         *seconds) {
    assert(ESCalendar_initialized);  // Call ESCalendar_init() before calling this function
    double fractionalSeconds = timeInterval - floor(timeInterval);
    //printf("localComponentsFromTimeInterval starting with %.2f\n", timeInterval);
    NSDateComponents *ltCS = [timeZone->nsCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
						     fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval]];
    *era = ltCS.era;
    *year = ltCS.year;
    *month = ltCS.month;
    *day = ltCS.day;
    if (ESCalendar_nscalendarIsPureGregorian) {
	//printf("gregorianToHybrid translating %d-%04d-%02d-%02d to ",
	//       *era, *year, *month, *day);
	ESCalendar_gregorianToHybrid(era, year, month, day);
	//printf("%d-%04d-%02d-%02d\n",
	//       *era, *year, *month, *day);
    }
    *hour = ltCS.hour;
    *minute = ltCS.minute;
    *seconds = ltCS.second + fractionalSeconds;
}

void
ESCalendar_localDateComponentsFromTimeInterval(NSTimeInterval   timeInterval,
					       ESTimeZone       *timeZone,
					       ESDateComponents *cs) {
    ESCalendar_localComponentsFromTimeInterval(timeInterval, timeZone, &cs->era, &cs->year, &cs->month, &cs->day, &cs->hour, &cs->minute, &cs->seconds);
}

// Return an NSTimeInterval from the calendar components in the given time zone
NSTimeInterval
ESCalendar_timeIntervalFromLocalComponents(ESTimeZone *timeZone,
                                           int         era,
                                           int         year,
                                           int         month,
                                           int         day,
                                           int         hour,
                                           int         minute,
                                           double      seconds) {
    if (ESCalendar_nscalendarIsPureGregorian) {
	//printf("hybridToGregorian translating %d-%04d-%02d-%02d to ",
	//       era, year, month, day);
	ESCalendar_hybridToGregorian(&era, &year, &month, &day);
	//printf("%d-%04d-%02d-%02d\n",
	//       era, year, month, day);
    }
    NSDateComponents *dc = [[NSDateComponents alloc] init];
    dc.era = era;
    dc.year = year;
    dc.month = month;
    dc.day = day;
    dc.hour = hour;
    dc.minute = minute;
    int secondsI = floor(seconds);
    double secondsF = seconds - secondsI;
    dc.second = secondsI;
    NSTimeInterval timeInterval = [[timeZone->nsCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + secondsF;
    [dc release];
    //printf("timeIntervalFromLocalComponents returning %.2f\n", timeInterval);
    return timeInterval;
}

NSTimeInterval
ESCalendar_timeIntervalFromLocalDateComponents(ESTimeZone       *timeZone,
					       ESDateComponents *cs) {
    return ESCalendar_timeIntervalFromLocalComponents(timeZone, cs->era, cs->year, cs->month, cs->day, cs->hour, cs->minute, cs->seconds);
}

int
ESCalendar_daysInYear(ESTimeZone     *estz,
		      NSTimeInterval forTime)
{
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(forTime, estz, &cs);
    cs.day = 1;
    cs.month = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    double d1 = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
    cs.day = 31;
    cs.month = 12;
    cs.hour = 23;
    cs.minute = 23;
    cs.seconds = 59;
    double d2 = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
    return rint((d2 - d1) / (3600.0 * 24.0));
}

void
ESCalendar_localDateComponentsFromDeltaTimeInterval(ESTimeZone     *estz,
						    NSTimeInterval time1,
						    NSTimeInterval time2,
    						    ESDateComponents *cs) {
// The NSCalendar routines have a bug attempting to find the delta between two dates when one is BCE and one is CE.  Possibly other BCE-related bugs too.
    // So we do our own math.  First we find the number of years, then we pick two years with the proper leap/noleap relationship in CE territory, and let the
    // NSCalendar routine do those, then we add the two together.
    ESDateComponents cs1;
    ESCalendar_localDateComponentsFromTimeInterval(time1, estz, &cs1);
    ESDateComponents cs2;
    ESCalendar_localDateComponentsFromTimeInterval(time2, estz, &cs2);
    int year1 = cs1.era ? cs1.year : 1 - cs1.year;  // 1 BCE => 0, 2 BCE => -1
    int year2 = cs2.era ? cs2.year : 1 - cs2.year;  // 1 BCE => 0, 2 BCE => -1
    int deltaYear = year2 - year1;
    assert(deltaYear >= 0);
    bool year1IsLeap = ESCalendar_daysInYear(estz, time1) > 365.25;
    bool year2IsLeap = ESCalendar_daysInYear(estz, time2) > 365.25;

    NSDateComponents *nscs1 = [[NSDateComponents alloc] init];
    nscs1.era = 1;
    nscs1.month = cs1.month;
    nscs1.day = cs1.day;
    nscs1.hour = cs1.hour;
    nscs1.minute = cs1.minute;
    nscs1.second = floor(cs1.seconds);
    NSDateComponents *nscs2 = [[NSDateComponents alloc] init];
    nscs2.era = 1;
    nscs2.month = cs2.month;
    nscs2.day = cs2.day;
    nscs2.hour = cs2.hour;
    nscs2.minute = cs2.minute;
    nscs2.second = floor(cs2.seconds);

    // Pick two years always 4 years apart
    if (year1IsLeap) {  // 1900
	if (year2IsLeap) {
	    nscs1.year = 2004;  // leap
	    nscs2.year = 2008;  // leap
	} else {
	    nscs1.year = 1896;  // leap
	    nscs2.year = 1900;  // not leap
	}
    } else {
	if (year2IsLeap) {
	    nscs1.year = 1900;  // not leap
	    nscs2.year = 1904;  // leap
	} else {
	    nscs1.year = 2005;  // not leap
	    nscs2.year = 2009;  // not leap
	}
    }

    NSDateComponents *nscs
	= [estz->nsCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitYear | NSCalendarUnitEra)
			      fromDate:[estz->nsCalendar dateFromComponents:nscs1]
				toDate:[estz->nsCalendar dateFromComponents:nscs2]
			       options:0];
    [nscs1 release];
    [nscs2 release];
    cs->era = 0;
    cs->year = nscs.year + deltaYear - 4;
//    cs->month = nscs.month;
    cs->day = nscs.day;
    cs->hour = nscs.hour;
    cs->minute = nscs.minute;
    cs->seconds = nscs.second;
}

// Return the weekday from an ESTimeInterval (UTC)  (0 == Sunday)
int
ESCalendar_UTCWeekdayFromTimeInterval(NSTimeInterval timeInterval) {
    double intervalDays = timeInterval / (24 * 3600);
    double weekday = ES_fmod(intervalDays + 1, 7);
    //printf("weekdayNumber is %d (%.4f)\n", (int)floor(weekday), weekday);
    return (int)floor(weekday);
}

// Return the weekday in the given timezone from an ESTimeInterval  (0 == Sunday)
int
ESCalendar_localWeekdayFromTimeInterval(NSTimeInterval timeInterval,
                                        ESTimeZone     *timeZone) {
    double localNow = timeInterval + ESCalendar_tzOffsetForTimeInterval(timeZone, timeInterval);
    double localNowDays = localNow / (24 * 3600);
    double weekday = ES_fmod(localNowDays + 1, 7);
    //printf("weekdayNumber is %d (%.4f)\n", (int)floor(weekday), weekday);
    return (int)floor(weekday);
}

NSTimeInterval
ESCalendar_addDaysToTimeInterval(NSTimeInterval now,
				 ESTimeZone     *estz,
				 int            days) {
    int eraNow;
    int yearNow;
    int monthNow;
    int dayNow;
    int hourNow;
    int minuteNow;
    double secondsNow;
    ESCalendar_localComponentsFromTimeInterval(now, estz, &eraNow, &yearNow, &monthNow, &dayNow, &hourNow, &minuteNow, &secondsNow);
    double timeSinceMidnightNow = hourNow * 3600 + minuteNow * 60 + secondsNow;

    // Go the given number of exact 24-hour segments.  Then find the closest time which reproduces hour, minute, second of current time
    NSTimeInterval then = now + days * 86400.0;
    int eraThen;
    int yearThen;
    int monthThen;
    int dayThen;
    int hourThen;
    int minuteThen;
    double secondsThen;
    ESCalendar_localComponentsFromTimeInterval(then, estz, &eraThen, &yearThen, &monthThen, &dayThen, &hourThen, &minuteThen, &secondsThen);
    double timeSinceMidnightThen = hourThen * 3600 + minuteThen * 60 + secondsThen;
    
    double deltaError = timeSinceMidnightThen - timeSinceMidnightNow;
    if (fabs(deltaError) < 0.001) {
	return then;
    } else { // must have been a DST change
	if (deltaError > 0) {
	    if (deltaError > 12 * 3600) {   // e.g., now 12:30am, then 11:30p
		deltaError -= 24 * 3600;      //  => logically we moved backwards 1 hour
	    }
	} else {  // deltaError <= 0
	    if (deltaError < -12 * 3600) {  // e.g., now 11:30p, then 12:30am
		deltaError += 24 * 3600;       // => logically we moved forwards 1 hour
	    }
	}
	return then - deltaError;   // If now 2pm, then 3pm, delta +1hr, need to move back by 1 hour to stay at 2pm per spec
    }
}

int
ESCalendar_daysInMonth(int eraNumber, int yearNumber, int monthNumber) {
    switch(monthNumber - 1) {
      case  0: return 31;	// Jan
      case  1: 
	{
	    ESDateComponents cs;
	    cs.era = eraNumber;
	    cs.year = yearNumber;
	    cs.month = 2;
	    cs.day = 1;
	    cs.hour = 0;
	    cs.minute = 0;
	    cs.seconds = 0;
	    NSTimeInterval firstOfFeb = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	    cs.month = 3;
	    NSTimeInterval firstOfMar = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	    return (int)(rint((firstOfMar - firstOfFeb)/(24 * 3600)));
	}
      case  2: return 31;	// Mar
      case  3: return 30;	// Apr
      case  4: return 31;	// May
      case  5: return 30;	// Jun
      case  6: return 31;	// Jul
      case  7: return 31;	// Aug
      case  8: return 30;	// Sep
      case  9: return 31;	// Oct
      case 10: return 30;	// Nov
      case 11: return 31;	// Dec
    }
    assert(0);
    return 0;
}

NSTimeInterval
ESCalendar_addMonthsToTimeInterval(NSTimeInterval now,
				   ESTimeZone     *estz,
				   int            months) {
    int eraNow;
    int yearNow;
    int monthNow;
    int dayNow;
    int hourNow;
    int minuteNow;
    double secondsNow;
    ESCalendar_localComponentsFromTimeInterval(now, estz, &eraNow, &yearNow, &monthNow, &dayNow, &hourNow, &minuteNow, &secondsNow);
    int signedYearNow = eraNow == 0 ? 1 - yearNow : yearNow;
    int zeroMonthNow = monthNow - 1;
    double yearMonthThen = signedYearNow + (zeroMonthNow + months) / 12.0;
    int signedYearThen = floor(yearMonthThen);
    int zeroMonthThen = rint((yearMonthThen - signedYearThen) * 12);
    int monthThen = zeroMonthThen + 1;
    int eraThen;
    int yearThen;
    if (signedYearThen <= 0) {
	eraThen = 0;
	yearThen = 1 - signedYearThen;
    } else {
	eraThen = 1;
	yearThen = signedYearThen;
    }
    int daysInMonthThen = ESCalendar_daysInMonth(eraThen, yearThen, monthThen);
    int dayThen = dayNow;
    if (dayThen > daysInMonthThen) {
	dayThen = daysInMonthThen;
    }
    return ESCalendar_timeIntervalFromLocalComponents(estz, eraThen, yearThen, monthThen, dayThen, hourNow, minuteNow, secondsNow);
}

NSTimeInterval
ESCalendar_addYearsToTimeInterval(NSTimeInterval now,
				  ESTimeZone     *estz,
				  int            years) {
    int eraNow;
    int yearNow;
    int monthNow;
    int dayNow;
    int hourNow;
    int minuteNow;
    double secondsNow;
    ESCalendar_localComponentsFromTimeInterval(now, estz, &eraNow, &yearNow, &monthNow, &dayNow, &hourNow, &minuteNow, &secondsNow);
    int signedYearNow = eraNow == 0 ? 1 - yearNow : yearNow;
    int signedYearThen = signedYearNow + years;
    int eraThen;
    int yearThen;
    if (signedYearThen <= 0) {
	eraThen = 0;
	yearThen = 1 - signedYearThen;
    } else {
	eraThen = 1;
	yearThen = signedYearThen;
    }
    return ESCalendar_timeIntervalFromLocalComponents(estz, eraThen, yearThen, monthNow, dayNow, hourNow, minuteNow, secondsNow);
}

NSTimeInterval
ESCalendar_nextDSTChangeAfterTimeInterval(ESTimeZone     *estz,
					  NSTimeInterval fromDateInterval) {
    NSDate *fromDate = [NSDate dateWithTimeIntervalSinceReferenceDate:fromDateInterval];
    NSDate *transitionDate = [estz->nsTimeZone nextDaylightSavingTimeTransitionAfterDate:fromDate];
    NSTimeInterval transitionDateInterval = [transitionDate timeIntervalSinceReferenceDate];
    if (transitionDateInterval == 0) {
	return 0;
    }
    if (transitionDateInterval <= fromDateInterval) {
	if (transitionDateInterval <= fromDateInterval - 1) {
	    //printf("bad date %.1f from nextDST of %.1f (delta %.1f): %s\n", transitionDateInterval, fromDateInterval, transitionDateInterval - fromDateInterval, [[transitionDate description] UTF8String]);
	    return 0;
	}
	transitionDate = [estz->nsTimeZone nextDaylightSavingTimeTransitionAfterDate:[NSDate dateWithTimeIntervalSinceReferenceDate:(fromDateInterval + 1)]];
	transitionDateInterval = [transitionDate timeIntervalSinceReferenceDate];
	if (transitionDateInterval == 0) {
	    return 0;
	}
	assert(transitionDateInterval > fromDateInterval);
    }
    return transitionDateInterval;
}

bool
ESCalendar_isDSTAtTimeInterval(ESTimeZone     *estz,
			       NSTimeInterval timeInterval) {
    return [estz->nsTimeZone isDaylightSavingTimeForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval]] ? true : false;
}

extern ESTimeZone *
ESCalendar_localTimeZone(void) {
    assert(ESCalendar_initialized);
    assert(localTimeZone);
    return localTimeZone;
}

extern void
ESCalendar_localTimeZoneChanged(void) {
    assert(localTimeZone);
    [NSTimeZone resetSystemTimeZone];	// resets the cached version of it
    ESCalendar_releaseTimeZone(localTimeZone);
    localTimeZone = ESCalendar_initTimeZoneFromOlsonID([[[NSTimeZone localTimeZone] name] UTF8String]);
    [dateFormatter setTimeZone:localTimeZone->nsTimeZone];
    [timeFormatter setTimeZone:localTimeZone->nsTimeZone];
}

const char *
ESCalendar_localTimeZoneName(void) {
    return [[localTimeZone->nsTimeZone name] UTF8String];
}

const char *
ESCalendar_formatTZOffset(float off) {
    if (off == 0) {
	return "";
    }
    int hr = trunc(off);
    int mn = (off-hr)*60;
    if (mn == 0) {
	return [[NSString stringWithFormat:@"%+2d", hr] UTF8String];
    } else {
	return [[NSString stringWithFormat:NSLocalizedString(@"%+2d:%2d", @"format for hours:minutes in timezone offset"), hr, abs(mn)] UTF8String];
    }
}

const char *
ESCalendar_formatInfoForTZ(ESTimeZone *estz,
			   int typ) {                     	    // typ == 1: "CHAST = UTC+12:45"  or  "CHADT = UTC+13:45 (Daylight)"
    NSTimeZone *tz = estz->nsTimeZone;
    if ([[tz name] compare:@"UTC"] == NSOrderedSame) {		    // typ == 2: "CHAST = UTC+12:45 : CHADT = UTC+13:45"
	return "UTC";						    // typ == 3: "CHAST = UTC+12:45; (CHADT = UTC+13:45 on Nov 22, 2009)"
    }								    // typ == 4: "-10: -9" or "-10:-10"
    [dateFormatter setTimeZone:tz];				    // typ == 5: "CHAST"
    [timeFormatter setTimeZone:tz];
    NSTimeInterval nowTime = [TSTime currentTime];
    NSDate *now = [NSDate dateWithTimeIntervalSinceReferenceDate:nowTime];
    NSString *abbrevNow = [tz abbreviationForDate:now];
    double offsetNow = ESCalendar_tzOffsetForTimeInterval(estz, nowTime)/3600.0;
    NSTimeInterval nextDSTTransition = ESCalendar_nextDSTChangeAfterTimeInterval(estz, nowTime);
    NSString *abbrevThen = nextDSTTransition ? [tz abbreviationForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:(nextDSTTransition + 1)]] : abbrevNow;
    double offsetThen = nextDSTTransition ? ESCalendar_tzOffsetForTimeInterval(estz,nextDSTTransition+1)/3600.0 : offsetNow;
    if (typ == 4) {
	return [[NSString stringWithFormat:@"%+3d:%+3d", (int)trunc(fmin(offsetNow, offsetThen)), (int)trunc(fmax(offsetNow, offsetThen))] UTF8String];
    }
    NSString *transitionDate = nil;
    if (!nextDSTTransition) {
	if ([abbrevNow caseInsensitiveCompare:abbrevThen] == NSOrderedSame) {
	    if (typ != 5) {
		typ = 1;	    // no DST
	    }
	} else {
	    transitionDate = @"?";	// permanent DST?
	}
    } else {
	transitionDate = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:nextDSTTransition]];
    }
    NSString *ret = nil;
    if (NSEqualRanges([abbrevNow rangeOfString:@"GMT"], NSMakeRange(0,3))) {
	switch (typ) {
	    case 1:
		if ([tz isDaylightSavingTime]) {
		    ret = [NSString stringWithFormat:NSLocalizedString(@"%@ (Daylight)", @"short format for timezone description in DST with no tz TLA"), abbrevNow];
		} else {
		    ret = abbrevNow;
		}
		break;
	    case 2:
		ret = [NSString stringWithFormat:NSLocalizedString(@"%@ : %@", @"format for partial timezone description with no tz TLA"), abbrevNow, abbrevThen];
		break;
	    case 3:
		ret = [NSString stringWithFormat:NSLocalizedString(@"%@; %@ on %@", @"format for full timezone description with no tz TLA"), abbrevNow, abbrevThen, transitionDate];
		break;
	    case 5:
		ret = abbrevNow;
		break;
	    default:
		assert(false);
	}
    } else {
	switch (typ) {
	    case 1:
		if ([tz isDaylightSavingTime]) {
		    ret = [NSString stringWithFormat:NSLocalizedString(@"%@ = UTC%s (Daylight)", @"short format for timezone description in DST"), abbrevNow, ESCalendar_formatTZOffset(offsetNow)];
		} else {
		    ret = [NSString stringWithFormat:NSLocalizedString(@"%@ = UTC%s", @"short format for timezone description in standard time"), abbrevNow, ESCalendar_formatTZOffset(offsetNow)];
		}
		break;
	    case 2:
		ret = [NSString stringWithFormat:NSLocalizedString(@"%@ = UTC%s : %@ = UTC%s", @"format for partial timezone description"), abbrevNow, ESCalendar_formatTZOffset(offsetNow), abbrevThen, ESCalendar_formatTZOffset(offsetThen)];
		break;
	    case 3:
		ret = [NSString stringWithFormat:NSLocalizedString(@"%@ = UTC%s; %@ = UTC%s on %@", @"format for full timezone description"), abbrevNow, ESCalendar_formatTZOffset(offsetNow), abbrevThen, ESCalendar_formatTZOffset(offsetThen), transitionDate];
		break;
	    case 5:
		ret = abbrevNow;
		break;
	    default:
		assert(false);
	}
    }
    return [ret UTF8String];
}

const char *
ESCalendar_version(void) {
#if __IPHONE_4_0
    if ([NSTimeZone respondsToSelector:@selector(timeZoneDataVersion)]) {
#if __IPHONE_4_0
	return [[NSTimeZone timeZoneDataVersion] UTF8String];
#else
	assert(false);
	return "??";
#endif
    } else {
	return "3x";
    }
#else
    return "3x";
#endif
}

const char *
ESCalendar_formatTime(void) {
    NSDate *now = [NSDate dateWithTimeIntervalSinceReferenceDate:[TSTime currentTime]];
    return [[NSString stringWithFormat:NSLocalizedString(@"%@ %@", @"date time"),[dateFormatter stringFromDate:now], [timeFormatter stringFromDate:now]] UTF8String];
}

const char *
ESCalendar_formatTimeInterval(NSTimeInterval timeInterval,
			      ESTimeZone     *estz,
			      const char     *formatString) {
    NSDateFormatter *dateFormatterHere = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatterHere setDateFormat:[NSString stringWithCString:formatString encoding:NSUTF8StringEncoding]];
    assert(estz);
    [dateFormatterHere setTimeZone:estz->nsTimeZone];
    return [[dateFormatterHere stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval]] UTF8String];
}

const char *
ESCalendar_dateIntervalDescription(NSTimeInterval dt) {
    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, localTimeZone, &ltcs);
    int second = floor(ltcs.seconds);
    int microseconds = round((ltcs.seconds - second) * 1000000);  // ugliness one half of a microsecond before a second boundary
    return [[NSString stringWithFormat:@"%s %04d/%02d/%02d %02d:%02d:%02d.%06d LT",
		   ltcs.era ? " CE" : "BCE", ltcs.year, ltcs.month, ltcs.day, ltcs.hour, ltcs.minute, second, microseconds] UTF8String];
}


#ifndef NDEBUG
NSLock *printLock = nil;

static void printOne(NSTimeInterval timeInterval,
		     ESTimeZone     *estz,
		     bool           doLocal) {
    double secondsF = timeInterval - floor(timeInterval);
    NSDateComponents *dc = [estz->utcCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
						fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval]];
    int eraESCal;
    int yearESCal;
    int monthESCal;
    int dayESCal;
    int hourESCal;
    int minuteESCal;
    double secondsESCal;
    ESCalendar_UTCComponentsFromTimeInterval(timeInterval, &eraESCal, &yearESCal, &monthESCal, &dayESCal, &hourESCal, &minuteESCal, &secondsESCal);

    // UTC time first (we know this works, so don't bother with NSDate)
    printf("%15.2f %3s %04d/%02d/%02d %02d:%02d:%05.2f ",
	   timeInterval, eraESCal ? " CE" : "BCE", yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);

    if (doLocal) {
	// Now ESCalendar's idea of the local time
	ESCalendar_localComponentsFromTimeInterval(timeInterval, estz, &eraESCal, &yearESCal, &monthESCal, &dayESCal, &hourESCal, &minuteESCal, &secondsESCal);
	printf("%5.3f (%7.1f) %3s %04d/%02d/%02d %02d:%02d:%05.2f ",
	       ESCalendar_tzOffsetForTimeInterval(estz, timeInterval) / 3600, ESCalendar_tzOffsetForTimeInterval(estz, timeInterval), eraESCal ? " CE" : "BCE", yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);

	// And NSDate's idea of the local time
	dc = [estz->nsCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
			   fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval]];
    }
    
    printf("%3s %04ld/%02ld/%02ld %02ld:%02ld:%05.2f\n",
	   dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, (long)dc.second + secondsF);

}

static void printSpread(NSTimeInterval timeInterval,
			ESTimeZone     *estz,
			bool           doLocal) {
    if (doLocal) {
	printf("%15s %26s %5s %26s %26s\n",
	       "time interval", "UTC time", "offs", "ESCalendar local", "NSDate local");
    } else {
	printf("%15s %26s %26s\n",
	       "time interval", "ESCalendar UTC time", "NSDate UTC time");
    }
    printOne(timeInterval - 2.0, estz, doLocal);
    printOne(timeInterval - 1.5, estz, doLocal);
    printOne(timeInterval - 1.0, estz, doLocal);
    printOne(timeInterval - 0.5, estz, doLocal);
    printOne(timeInterval - 0.0, estz, doLocal);
    printOne(timeInterval + 0.5, estz, doLocal);
    printOne(timeInterval + 1.0, estz, doLocal);
    printOne(timeInterval + 1.5, estz, doLocal);
    printOne(timeInterval + 2.0, estz, doLocal);
}

static void
pushUpComponents(int *era1,
		 int *year1,
		 int *month1,
		 int *day1,
		 int *hour1,
		 int *minute1,
		 double *seconds1) {
    if (*seconds1 > 59.999) {
	*seconds1 -= 60;
	(*minute1)++;
    }
    if (*minute1 > 59) {
	*minute1 -= 60;
	(*hour1)++;
    }
    if (*hour1 > 23) {
	*hour1 -= 24;
	(*day1)++;
    }
    // Let's assume, for now, that we don't care about day number overflow...
}

static bool
componentsAreEquivalent(int era1,
			int year1,
			int month1,
			int day1,
			int hour1,
			int minute1,
			double seconds1,
			int era2,
			int year2,
			int month2,
			int day2,
			int hour2,
			int minute2,
			double seconds2) {
    pushUpComponents(&era1, &year1, &month1, &day1, &hour1, &minute1, &seconds1);
    pushUpComponents(&era2, &year2, &month2, &day2, &hour2, &minute2, &seconds2);
    return (era2 == era1 &&
	    year2 == year1 &&
	    month2 == month1 &&
	    day2 == day1 &&
	    hour2 == hour1 &&
	    minute2 == minute1 &&
	    fabs(seconds2 - seconds1) < 0.0001);
}

// First, compare the components returned by NSCalendar (set to UTC) and ESCalendar_UTCComponentsFromTimeInterval to ensure they are the same for this time interval
// Then, using those components (specifically, the ones from ESCalendar), go back using ESCalendar_timeIntervalFromUTCComponents and ensure we get the same time interval we started from
// Next, do the two steps above using local time instead of UTC
static bool testTimeInterval(bool shortError,
			     NSTimeInterval timeInterval,
			     ESTimeZone     *estz) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    double timeIntervalI = floor(timeInterval);
    double secondsF = timeInterval - timeIntervalI;
    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeIntervalI];

    // UTC ***************
    NSDateComponents *dc = [estz->utcCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
						fromDate:date];
    //printf("dc.day is %d\n", dc.day);
    int eraESCal;
    int yearESCal;
    int monthESCal;
    int dayESCal;
    int hourESCal;
    int minuteESCal;
    double secondsESCal;
    ESCalendar_UTCComponentsFromTimeInterval(timeInterval, &eraESCal, &yearESCal, &monthESCal, &dayESCal, &hourESCal, &minuteESCal, &secondsESCal);
    bool success = componentsAreEquivalent(dc.era, dc.year, dc.month, dc.day, dc.hour, dc.minute, dc.second + secondsF,
					   eraESCal, yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);
    bool alwaysPrint = false;
    if (alwaysPrint || !success) {
	[printLock lock];
	if (!shortError) {
	    printf("\n");
	}
	printf("testTimeInterval %s for UTC timeInterval %.9f --\n", alwaysPrint ? "report" : "mismatch", timeInterval);
	printf("...NSDate got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
	       dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, (long)dc.second + secondsF);
	printf("...ESCal  got %3s %4d/%02d/%02d %02d:%02d:%05.20f\n",
	       eraESCal ? " CE" : "BCE", yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);
	if (!shortError) {
	    printSpread(timeInterval, estz, false);
	}
	[printLock unlock];
	assert(0);
    }
    NSTimeInterval roundTrip = ESCalendar_timeIntervalFromUTCComponents(eraESCal, yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);
    alwaysPrint = false;
    bool roundTripSuccess = fabs(roundTrip - timeInterval) < 0.0001;
    if (alwaysPrint || !roundTripSuccess) {
	[printLock lock];
        printf("\ntestTimeInterval roundTrip %s for UTC timeInterval %.9f => %.9f (%.4f) --\n", alwaysPrint ? "report" : "mismatch", timeInterval, roundTrip, roundTrip - timeInterval);
        printf("... input got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
               dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, (long)dc.second + secondsF);
        dc = [estz->utcCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
				  fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:roundTrip]];
        printf("...output got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
               dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, (long)dc.second + secondsF);
	printSpread(timeInterval, estz, false);
	[printLock unlock];
    }

    // LOCAL ***************

    dc = [estz->nsCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
                       fromDate:date];
    ESCalendar_localComponentsFromTimeInterval(timeInterval, estz, &eraESCal, &yearESCal, &monthESCal, &dayESCal, &hourESCal, &minuteESCal, &secondsESCal);
    success = componentsAreEquivalent(dc.era, dc.year, dc.month, dc.day, dc.hour, dc.minute, dc.second + secondsF,
				      eraESCal, yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);
    alwaysPrint = false;
    if (alwaysPrint || !success) {
	if (eraESCal != 1 || yearESCal < 1918 || (yearESCal > 1919 && yearESCal < 2038)) {
	    [printLock lock];
	    if (!shortError) {
		printf("\n");
	    }
	    printf("testTimeInterval %s for LOCAL (%s, %.2f hours from UTC) timeInterval %.9f --\n",
		   alwaysPrint ? "report" : "mismatch",
		   [[estz->nsTimeZone name] UTF8String],
		   ESCalendar_tzOffsetForTimeInterval(estz, timeInterval) / 3600,
		   timeInterval);
	    printf("...NSDate got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
		   dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, dc.second + secondsF);
	    printf("...ESCal  got %3s %4d/%02d/%02d %02d:%02d:%05.20f\n",
		   eraESCal ? " CE" : "BCE", yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);
	    if (!shortError) {
		printSpread(timeInterval, estz, true);
	    }
	    [printLock unlock];
	} else {
	    static bool messageGiven = false;
	    if (!messageGiven) {
		printf("Problem with 1918-1919 or > 2038 detected and ignored\n");
		messageGiven = true;
	    }
	    success = true;
	}
    }
    roundTrip = ESCalendar_timeIntervalFromLocalComponents(estz, eraESCal, yearESCal, monthESCal, dayESCal, hourESCal, minuteESCal, secondsESCal);
    alwaysPrint = false;
    roundTripSuccess = fabs(roundTrip - timeInterval) < 0.0001;
    if (alwaysPrint || !roundTripSuccess) {
        NSDateComponents *dc2 = [estz->nsCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
					      fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:roundTrip]];
	// Could be DST thingie around fall transition -- the same date components can represent two different time intervals
	if (//fabs(fabs(roundTrip-timeInterval) - 3600) > 0.0001 ||  // could also be switching to a different UTC offset interval; just make sure both intervals go to the same date rep
	    !componentsAreEquivalent(dc.era, dc.year, dc.month, dc.day, dc.hour, dc.minute, dc.second,
				     dc2.era, dc2.year, dc2.month, dc2.day, dc2.hour, dc2.minute, dc2.second)) {
	    [printLock lock];
	    printf("\ntestTimeInterval roundTrip %s for LOCAL (%s, %.2f hours from UTC) timeInterval %.9f => %.9f (%.2f) --\n",
		   alwaysPrint ? "report" : "mismatch",
		   [[estz->nsTimeZone name] UTF8String],
		   ESCalendar_tzOffsetForTimeInterval(estz, timeInterval) / 3600,
		   timeInterval,
		   roundTrip,
		   roundTrip - timeInterval);
	    printf("... input got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
		   dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, dc.second + secondsF);
	    printf("...output got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
		   dc2.era ? " CE" : "BCE", (long)dc2.year, (long)dc2.month, (long)dc2.day, (long)dc2.hour, (long)dc2.minute, dc2.second + secondsF);
	    printSpread(timeInterval, estz, true);
	    printSpread(roundTrip, estz, true);
	    [printLock unlock];
	} else {
	    // Ensure that the *other* time interval also resolves to the same 
	    // We already know that 

	    static bool messageGiven = true;
	    if (!messageGiven) {
		printf("DST offset roundtrip 'error' detected and ignored:\n");
		[printLock lock];
		printf("\ntestTimeInterval roundTrip %s for LOCAL (%s, %.2f hours from UTC) timeInterval %.9f => %.9f (%.2f) --\n",
		       alwaysPrint ? "report" : "mismatch",
		       [[estz->nsTimeZone name] UTF8String],
		       ESCalendar_tzOffsetForTimeInterval(estz, timeInterval) / 3600,
		       timeInterval,
		       roundTrip,
		       roundTrip - timeInterval);
		printf("... input got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
		       dc.era ? " CE" : "BCE", (long)dc.year, (long)dc.month, (long)dc.day, (long)dc.hour, (long)dc.minute, dc.second + secondsF);
		printf("...output got %3s %4ld/%02ld/%02ld %02ld:%02ld:%05.20f\n",
		       dc2.era ? " CE" : "BCE", (long)dc2.year, (long)dc2.month, (long)dc2.day, (long)dc2.hour, (long)dc2.minute, dc2.second + secondsF);
		printSpread(timeInterval, estz, true);
		printSpread(roundTrip, estz, true);
		[printLock unlock];
		messageGiven = true;
	    }
	    roundTripSuccess = true;
	}
    }

    [pool release];
    return success && roundTripSuccess;
}

static bool testDate(ESTimeZone *estz, NSDateComponents *dc, int era, int year, int month, int day, int hour, int minute, double seconds) {
    assert(estz);
    dc.era = era;
    dc.year = year;
    dc.month = month;
    dc.day = day;
    dc.hour = hour;
    dc.minute = minute;
    int secondsI = floor(seconds);
    dc.second = secondsI;
    NSTimeInterval timeInterval = [[estz->nsCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
    int eraReturn;
    int yearReturn;
    int monthReturn;
    int dayReturn;
    int hourReturn;
    int minuteReturn;
    double secondsReturn;
    ESCalendar_localComponentsFromTimeInterval(timeInterval, estz, &eraReturn, &yearReturn, &monthReturn, &dayReturn, &hourReturn, &minuteReturn, &secondsReturn);
    bool success = 
        era == eraReturn &&
        year == yearReturn &&
        month == monthReturn &&
        day == dayReturn &&
        hour == hourReturn &&
        minute == minuteReturn &&
        fabs(seconds - secondsReturn) < 0.0001;
    bool alwaysPrint = false;
    if (alwaysPrint || !success) {
        printf("\ntestDate %s --\n", alwaysPrint ? "report" : "mismatch");
        printf("...NSDate got %3s %4d/%02d/%02d %02d:%02d:%05.2f\n",
               era ? " CE" : "BCE", year, month, day, hour, minute, seconds);
        printf("...ESCal  got %3s %4d/%02d/%02d %02d:%02d:%05.2f\n",
               eraReturn ? " CE" : "BCE", yearReturn, monthReturn, dayReturn, hourReturn, minuteReturn, secondsReturn);
    }
    return testTimeInterval(false, timeInterval, estz) && success;
}

NSTimeInterval startTimeInterval;
NSTimeInterval endTimeInterval;

void ESTestCalendarAtESTZ(ESTimeZone *estz) {
    NSDateComponents *dc = [[[NSDateComponents alloc] init] autorelease];

    testDate(estz, dc, 1, 2010, 3, 14, 7, 59, 59.01);
    testDate(estz, dc, 1, 2010, 3, 14, 8, 59, 59.01);
    testDate(estz, dc, 1, 2010, 3, 14, 9, 59, 59.01);
    testDate(estz, dc, 1, 2010, 3, 14, 10, 0, 1.01);
    testDate(estz, dc, 1, 2010, 3, 14, 11, 0, 1.01);

    testDate(estz, dc, 1, 2010, 11, 7, 7, 59, 59.01);
    testDate(estz, dc, 1, 2010, 11, 7, 8, 59, 59.01);
    testDate(estz, dc, 1, 2010, 11, 7, 9, 59, 59.01);
    testDate(estz, dc, 1, 2010, 11, 7, 10, 0, 1.01);
    testDate(estz, dc, 1, 2010, 11, 7, 11, 0, 1.01);

    testTimeInterval(false, -1743692400, estz);
    testTimeInterval(false, -1743688800, estz);
    testTimeInterval(false, -63140518800, estz);

    testTimeInterval(false, -1743692399.99, estz);
    testTimeInterval(false, -1743688799.99, estz);
    testTimeInterval(false, -63140518799.99, estz);

    testTimeInterval(false, kECJulianGregorianSwitchoverTimeInterval - 0.05, estz);
    testTimeInterval(false, kECJulianGregorianSwitchoverTimeInterval + 0.05, estz);

    testDate(estz, dc, 1, 1997, 12, 31, 0, 0, 0.01);
    testDate(estz, dc, 1, 2006, 12, 31, 0, 0, 0.01);
    testDate(estz, dc, 1, 2000, 12, 31, 0, 0, 0.01);
    testDate(estz, dc, 1, 1997, 12, 31, 23, 59, 59.01);
    testDate(estz, dc, 1, 2000, 12, 31, 23, 59, 59.01);
    testDate(estz, dc, 1, 1999, 12, 31, 23, 59, 59.01);
    testDate(estz, dc, 1, 2006, 12, 31, 23, 59, 59.01);
    testDate(estz, dc, 1, 2000, 2, 28, 23, 59, 59.01);
    testDate(estz, dc, 1, 2000, 2, 29, 0, 0, 0.01);
    testDate(estz, dc, 1, 2000, 3, 1, 0, 0, 0.01);
    testDate(estz, dc, 1, 2001, 2, 28, 0, 0, 0.01);
    testDate(estz, dc, 1, 2001, 3, 1, 0, 0, 0.01);
    testDate(estz, dc, 1, 2010, 2, 28, 0, 0, 0.01);
    testDate(estz, dc, 1, 2010, 3, 1, 0, 0, 0.01);
    testTimeInterval(false, 1.01, estz);
    testTimeInterval(false, 0.01, estz);
    testTimeInterval(false, -0.99, estz);

    // Test every second around timeInterval = 0 for 24 hours in each direction
    bool fail = false;
    for (int h = -24; h < 24; h++) {
        for (int m = 0; m < 60; m++) {
            for (int s = 0; s < 60; s++) {
                if (!testTimeInterval(false, h * 3600 + m * 60 + s, estz)) {
		    fail = true;
		    break;
		}
                if (!testTimeInterval(false, h * 3600 + m * 60 + s + 0.5, estz)) {
		    fail = true;
		    break;
		}
                if (!testTimeInterval(false, h * 3600 + m * 60 + s - 0.5, estz)) {
		    fail = true;
		    break;
		}
            }
        }
    }
    if (fail) {
	printf("every-second test failed (see above)\n");
    }

    int testNumber = 0;
    int failureCount = 0;
    for (NSTimeInterval t = startTimeInterval; t <= endTimeInterval; t += 3600) {
        if (!testTimeInterval(false, t, estz)) {
	    if (++failureCount > 10) {
		break;
	    }
	}
        if (!testTimeInterval(false, t + 0.5, estz)) {
	    if (++failureCount > 10) {
		break;
	    }
	}
        if (!testTimeInterval(false, t - 0.5, estz)) {
	    if (++failureCount > 10) {
		break;
	    }
	}
        if ((testNumber++ % 1000000) == 0) {
            printf("...%s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:t] description] UTF8String]);
        }
    }
}

void ESTestCalendarWithTZWithOlsonID(const char *olsonID) {
    printf("Testing calendar with timezone with Olson id %s\n", olsonID);
    ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID(olsonID);
    assert(estz);
    ESTestCalendarAtESTZ(estz);
    ESCalendar_releaseTimeZone(estz);
}

static void *testThreadBody(void *arg) {
    const char *olsonID = (const char *)arg;
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    ESTestCalendarWithTZWithOlsonID(olsonID);
    [pool release];
    return NULL;
}

static pthread_t
startThreadTestingOlsonID(const char *olsonID) {
    pthread_t thread;
    pthread_create(&thread, NULL, testThreadBody, (char *)olsonID);
    return thread;
}

static void
waitForThreadTestCompletion(pthread_t thread) {
    void *returnValue;
    printf("waiting for thread completion...\n");
    /*int errorNumber = */ pthread_join(thread, &returnValue);
    printf("... thread is complete\n");
}

static void testAllOlsonIDs(void) {
    ECGeoNames *geoNames = [[ECGeoNames alloc] init];
    NSArray *tzNames = [[geoNames tzNames] retain];
    printf("There are %lu timezones to test\n", (unsigned long)[tzNames count]);

    int arrayIndex = 0;

#define NUM_THREADS 8
    pthread_t threads[NUM_THREADS];
    while (arrayIndex < [tzNames count]) {
	int threadsToWaitFor = 0;
	for (int i = 0; i < NUM_THREADS; i++) {
	    if (arrayIndex < [tzNames count]) {
		if (i == 0) {
		    threads[threadsToWaitFor++] = startThreadTestingOlsonID("America/Curacao");
		} else if (i == 1) {
		    threads[threadsToWaitFor++] = startThreadTestingOlsonID("America/Anguilla");
		} else {
		    threads[threadsToWaitFor++] = startThreadTestingOlsonID([[tzNames objectAtIndex:arrayIndex++] UTF8String]);
		}
	    }
	}
	for (int i = 0; i < threadsToWaitFor; i++) {
	    waitForThreadTestCompletion(threads[i]);
	}
    }

    [tzNames release];
    [geoNames release];
}

static void sampleAllOlsonIDs(void) {
    ECGeoNames *geoNames = [[ECGeoNames alloc] init];
    NSArray *tzNames = [[geoNames tzNames] retain];
    printf("There are %lu timezones to sample\n", (unsigned long)[tzNames count]);

    NSDateComponents *dc = [[NSDateComponents alloc] init];

    for (int i = 0; i < [tzNames count]; i++) {
	const char *olsonID = [[tzNames objectAtIndex:i] UTF8String];
	printf("\nSampling %s\n", olsonID);
	ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID(olsonID);
	assert(estz);

	bool doLocal = true;

	dc.era = 0;
	dc.year = 4000;
	dc.month = 1;
	dc.day = 1;
	dc.hour = 0;
	dc.minute = 0;
	double seconds = 0;
	int secondsI = 0;
	dc.second = 0;
	NSTimeInterval timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	//testTimeInterval(true, timeInterval, estz, doLocal);

	dc.era = 1;
	dc.year = 1700;
	timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	testTimeInterval(true, timeInterval, estz);

	dc.year = 1800;
	timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	testTimeInterval(true, timeInterval, estz);

	dc.year = 1900;
	timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	testTimeInterval(true, timeInterval, estz);

	dc.year = 2000;
	timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	testTimeInterval(true, timeInterval, estz);

	dc.year = 2010;
	timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	testTimeInterval(true, timeInterval, estz);

	dc.year = 2262;
	dc.month = 11;
	dc.day = 1;
	dc.hour = 7;
	seconds = 0.5;
	secondsI = 0;
	dc.second = 0;
	timeInterval = [[estz->utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate] + (seconds - secondsI);
	printOne(timeInterval, estz, doLocal);
	testTimeInterval(true, timeInterval, estz);

	ESCalendar_releaseTimeZone(estz);
    }


    [dc release];

    [tzNames release];
    [geoNames release];
}

void ESTestCalendar(void) {
    if (!printLock) {
	printLock = [[NSLock alloc] init];
    }

    NSCalendar *utcCalendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    [utcCalendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    // Test every hour from 4000 BCE to 2800 CE
    NSDateComponents *dc = [[NSDateComponents alloc] init];
    dc.era = 1; // 0;
    dc.year = 1900; // 4000;
    dc.month = 1;
    dc.day = 1;
    dc.hour = 0;
    dc.minute = 0;
    dc.second = 0;
    startTimeInterval = [[utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate];
    dc.era = 1;
    dc.year = 2800;
    dc.month = 12;
    dc.day = 31;
    dc.hour = 23;
    dc.minute = 59;
    dc.second = 59;
    endTimeInterval = [[utcCalendar dateFromComponents:dc] timeIntervalSinceReferenceDate];
    [dc release];
    dc = nil;

    printf("ECTestCalendar performance test beginning\n");
    double startTime = CACurrentMediaTime();
    int testNumber = 0;
#if 0
    if (!ESCalendar_nscalendarIsPureGregorian) {
	printf("Running calendar tests on pre-4.0 os\n");
	for (NSTimeInterval t = startTimeInterval; t <= endTimeInterval; t += 3600) {
	    int eraESCal;
	    int yearESCal;
	    int monthESCal;
	    int dayESCal;
	    int hourESCal;
	    int minuteESCal;
	    double secondsESCal;
	    ESCalendar_UTCComponentsFromTimeInterval(t + 0.01, &eraESCal, &yearESCal, &monthESCal, &dayESCal, &hourESCal, &minuteESCal, &secondsESCal);
	    if ((testNumber++ % 1000000) == 0) {
//          printf("...%s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:t] description] UTF8String]);
	    }
	}
    }
#endif
    double endTime = CACurrentMediaTime();
    printf("ECTestCalendar performance test (%d tests) end after %.4f seconds, %.3f microseconds per test\n", testNumber, endTime - startTime, 1000000.0 * (endTime - startTime)/testNumber);
    startTime = CACurrentMediaTime();
    printf("ECTestCalendar verification test start\n");
    sampleAllOlsonIDs();
    testAllOlsonIDs();
    endTime = CACurrentMediaTime();
    printf("ECTestCalendar verification test end after %.4f seconds\n", endTime - startTime);
}

@interface FooInterface : NSObject {
}
@end
@implementation FooInterface
-(NSDate *)dateByAddingTimeInterval:(NSTimeInterval)timeInterval {  // Dummy method to fake out compiler
    return nil;
}
@end

NSDate *addTimeIntervalToDate(NSDate         *date,
			      NSTimeInterval timeInterval) {
    return [(id)date dateByAddingTimeInterval:timeInterval];
}

// Doesn't look like we need this.  But if we do it needs to be rewritten using new interfaces
#if 0

NSDate *earliest;
#define MAXDAYSBACK 365.25*100
NSString *tzCompare(NSTimeZone *t1, NSTimeZone *t2)
{
    double inc = 0;		    // days
    while (inc<MAXDAYSBACK) {
	NSDate *d = addTimeIntervalToDate([NSDate date], -86400*inc);	    // inc days ago
	if (([t1 secondsFromGMTForDate:d] != [t2 secondsFromGMTForDate:d]) ||
	    (![[t1 nextDaylightSavingTimeTransitionAfterDate:d] isEqualToDate:[t2 nextDaylightSavingTimeTransitionAfterDate:d]]) ||
	    ([t1 isDaylightSavingTimeForDate:d] != [t2 isDaylightSavingTimeForDate:d])) {
	    if (inc == 0) {
		return nil;
	    } else {
		while (([t1 secondsFromGMTForDate:d] != [t2 secondsFromGMTForDate:d]) ||
		       (![[t1 nextDaylightSavingTimeTransitionAfterDate:d] isEqualToDate:[t2 nextDaylightSavingTimeTransitionAfterDate:d]]) ||
		       ([t1 isDaylightSavingTimeForDate:d] != [t2 isDaylightSavingTimeForDate:d])) {
		    d = addTimeIntervalToDate(d, 14*60);
		}
		[dateFormatter setTimeZone:t1];
		earliest = [d earlierDate:earliest];
		return [NSString stringWithFormat:@"\t\t\t\t =  %-30s since %@\n",[[t2 name] UTF8String],[dateFormatter stringFromDate:d]];
	    }
	}
	inc += 365.25/12;	    // about a month
    }
    return [NSString stringWithFormat:@"\t\t\t\t %s %@\n",[[t1 data] isEqualToData:[t2 data]] ? "==" : "= ",[t2 name]];
}

static NSString *
ESCalendar_formatTZInfo2(NSTimeZone *tz) {
    [dateFormatter setTimeZone:tz];
    [timeFormatter setTimeZone:tz];
    NSDate *now = [NSDate date];
    NSString *abbrevNow = [tz abbreviationForDate:now];
    double offsetNow = [tz secondsFromGMTForDate:now]/3600.0;
    NSDate *nextDSTTransition = ECNextDSTDateAfterDate(tz, [NSDate date]);
    if (!nextDSTTransition) {
	return [NSString stringWithFormat:@"%6s = UTC%6s %33s", [abbrevNow UTF8String], ESCalendar_formatTZOffset(offsetNow),"no DST"];
    } else {
	NSString *abbrevThen = [tz abbreviationForDate:addTimeIntervalToDate(nextDSTTransition,1)];
	double offsetThen = [tz secondsFromGMTForDate:addTimeIntervalToDate(nextDSTTransition,1)]/3600.0;
	NSString *transitionDate = [dateFormatter stringFromDate:nextDSTTransition];
	NSString *nextTransitionDate = [NSString stringWithFormat:@"%@ = UTC%@ on %@", abbrevThen, ESCalendar_formatTZOffset(offsetThen), transitionDate];
	return [NSString stringWithFormat:@"%6s = UTC%6s %33s", [abbrevNow UTF8String], ESCalendar_formatTZOffset(offsetNow), [nextTransitionDate UTF8String]];
    }
    [dateFormatter setTimeZone:currentTZ->nsTimeZone];
    [timeFormatter setTimeZone:currentTZ->nsTimeZone];
}

static NSString *
dumpTZInfo(NSTimeZone *tz) {
    [dateFormatter setTimeZone:tz];
    NSDate *dat = [NSDate dateWithTimeIntervalSinceReferenceDate:-86400*MAXDAYSBACK];
    NSString *ret = [NSString stringWithFormat:@"\t\t\t    DST transitions:\n\t\t\t\t%12s\t%6s  \t",
		     [[dateFormatter stringFromDate:dat] UTF8String],
		     [[self formatTZOffset:[tz secondsFromGMTForDate:dat]/3600.0] UTF8String]];
    NSDate *last = addTimeIntervalToDate([NSDate date], 86400*365.25);
    int cnt = 1;
    char *tabnl = "\t";
    while ([dat compare:last] == NSOrderedAscending) {
	if (!ECNextDSTDateAfterDate(tz,dat)) {
	    ret = [NSString stringWithFormat:@"%@     no DST \t%6s\n", ret, [[self formatTZOffset:[tz secondsFromGMTForDate:dat]/3600.0] UTF8String]];
	    break;
	} else {
	    if (++cnt % 6 == 0) {
		tabnl = "\n\t\t\t\t";
	    } else {
		tabnl = "\t";
	    }

	    dat = addTimeIntervalToDate(ECNextDSTDateAfterDate(tz,dat),1);
	    ret = [NSString stringWithFormat:@"%@%12s\t%6s %s%s",ret,
		   [[dateFormatter stringFromDate:dat] UTF8String],
		   [[self formatTZOffset:[tz secondsFromGMTForDate:dat]/3600.0] UTF8String],
		   [tz isDaylightSavingTimeForDate:dat] ? "D" : " ",
		   tabnl];
	}
    }
    if (tabnl == "\t") {
	ret = [ret stringByAppendingString:@"\n"];
    }
#if 0
    double daysBack = MAXDAYSBACK;
    double inc = 0.25;
    double lastoff = 99;
    ret = [ret stringByAppendingString:@"\t\t\t    UTC Offset transitions:\n"];
    while (daysBack > -366*2) {
	NSDate *d = addTimeIntervalToDate([NSDate date], -86400*daysBack);
	double off = [tz secondsFromGMTForDate:d]/3600.0;
	if (off != lastoff) {
	    if (inc < 1) {
		ret = [NSString stringWithFormat:@"%@\t\t\t\t\t%12s\t%6s %s\n",
		       ret,
		       [[dateFormatter stringFromDate:d] UTF8String],
		       [[self formatTZOffset:off] UTF8String],
		       [tz isDaylightSavingTimeForDate:d] ? "D" : "" ];
		inc = 365.25/12;
		lastoff = off;
	    } else {
		daysBack += 365.24/12;	// back up one month
		inc = 1.0/12;		// and search more finely
	    }
	}
	daysBack = daysBack - inc;
    }
#endif
    return ret;
}

+ (NSString *)TZMaxMinOffsets:(NSTimeZone *)tz {
    double daysBack = -800;
    double inc = 0.25;
    double minOff = 99999;
    double delta;
    double maxOff = -99999;
    NSDate *d2 = nil;
    while (daysBack < MAXDAYSBACK) {
	NSDate *d = addTimeIntervalToDate([NSDate date], -86400*daysBack);
	double off = [tz secondsFromGMTForDate:d]/3600.0;
	maxOff = fmax(maxOff, off);
	minOff = fmin(minOff, off);
	if (d2 == nil && ((maxOff - minOff) > 1)) {
	    d2 = d;
	}
	daysBack = daysBack + inc;
    }
    delta = maxOff - minOff;
    NSString *ret = [NSString stringWithFormat:@"min Offset = %6.2f   maxOffset = %6.2f    delta=%6.2f", minOff, maxOff, delta];
    if (d2) {
	ret = [ret stringByAppendingFormat:@"   %@", [d2 description]];
    }
    if (true || delta > 1) {
	ret = [ret stringByAppendingFormat:@"\n %@", [ECOptions dumpTZInfo:tz]];
    }
    return ret;
}
#endif

#ifndef NDEBUG
NSDate *earliest;
NSInteger tzSort(NSTimeZone *t1, NSTimeZone *t2, void *context)
{
    int v1 = [t1 secondsFromGMT];
    int v2 = [t2 secondsFromGMT];
    if (v1 < v2)
        return NSOrderedAscending;
    else if (v1 > v2)
        return NSOrderedDescending;
    else {
	NSString *tn1 = [t1 name];
	NSString *tn2 = [t2 name];
	if ([tn1 compare:@"UTC"] == NSOrderedSame && ![tn2 compare:@"UTC"] == NSOrderedSame) {
	    return NSOrderedAscending;
	} else 	if ([tn2 compare:@"UTC"] == NSOrderedSame && ![tn1 compare:@"UTC"] == NSOrderedSame) {
	    return NSOrderedDescending;
	} else 	if ([tn1 hasPrefix:@"Etc/GMT"] && ![tn2 hasPrefix:@"Etc/GMT"]) {
	    return NSOrderedAscending;
	} else 	if ([tn2 hasPrefix:@"Etc/GMT"] && ![tn1 hasPrefix:@"Etc/GMT"]) {
	    return NSOrderedDescending;
	} else {
	    return [[t1 name] compare:[t2 name]];
	}
    }
}
#endif

#if 0
void ESCalendar_printAllTimeZones() {
#ifndef NDEBUG
    NSMutableArray *tzs2 = [[NSMutableArray alloc] initWithCapacity:510];
    for (NSString *tzn in [NSTimeZone knownTimeZoneNames]) {
	[tzs2 addObject:[NSTimeZone timeZoneWithName:tzn]];
    }
    NSString **others = [ECOptionsTZRoot otherTZs];
    for (int i=0; i<NUMOTHERS; i++) {
	[tzs2 addObject:[NSTimeZone timeZoneWithName:others[i]]];
    }
    NSArray *tzs = [tzs2 sortedArrayUsingFunction:tzSort context:NULL];
    [tzs2 release];
    for (int i=0; i<[tzs count]; i++) {
	NSTimeZone *tzi = [tzs objectAtIndex:i];
	printf("* %30s : %s\n",[[tzi name] UTF8String], "Foo"/*[[ECOptions TZMaxMinOffsets:tzi] UTF8String]*/);
    }
#undef PRINTALLZONEINFO
#ifdef PRINTALLZONEINFO
    for (int i=0; i<[tzs count]; i++) {
	NSTimeZone *tzi = [tzs objectAtIndex:i];
	printf("* %30s = %s\n",[[tzi name] UTF8String], [[ECOptions formatInfoForTZ:tzi type:3] UTF8String]);
	printf("%s", [[ECOptions dumpTZInfo:tzi] UTF8String]);
	printf("\t\t\t    Equivalent zones:\n");
	for (int j=0; j<[tzs count]; j++) {
	    if (i != j) {
		NSTimeZone *tzj = [tzs objectAtIndex:j];
		NSString *dif = tzCompare(tzi,tzj);
		if ([dif compare:@""] != NSOrderedSame) {
		    printf("%s", [dif UTF8String]);
		}
	    }
	}
	printf("\n");
    }
#endif
    [ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"Earliest diff at %@; system zone: %s", [earliest description], @"Foo"/*[ECOptions formatTZInfo2:[NSTimeZone systemTimeZone]]*/]];	    // restores dateFormatter as a side effect

    NSDictionary *abd = [NSTimeZone abbreviationDictionary];
    for (id key in abd) {
	printf("%s = %s\n",[key UTF8String],[[abd objectForKey:key]UTF8String]);
    }
    printf("%s\n",[[abd description]UTF8String]);
#endif
}
#endif

#endif  // NDEBUG
