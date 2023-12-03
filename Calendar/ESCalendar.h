//
//  ESCalendar.h
//  Emerald Sequoia LLC
//
//  Created by Steve Pucci 5/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#ifndef ESCALENDAR_H
#define ESCALENDAR_H

#define ESCALENDAR_NS  // Special interface available only when using NS-TimeZone and NS-Calendar as the implementation

// Opaque reference to time zone structure
typedef struct _ESTimeZone ESTimeZone;

// Mimic (kind of) the NS-DateComponents object, but this one is a plain struct owned by the caller (and presumably almost always stack storage)
typedef struct _ESDateComponents {
    int era;
    int year;
    int month;
    int day;
    int hour;
    int minute;
    double seconds;  // plural to remind that it's a double here
} ESDateComponents;

// Static initialization -- call this once before calling anything else
extern void
ESCalendar_init(void);

//********** Time Zone **********

// Allocate and init ("new") a time zone, return with refCount == 1
extern ESTimeZone *
ESCalendar_initTimeZoneFromOlsonID(const char *olsonID);

// Allocate and init ("new") a time zone with shared calendars suitable for use in a single thread only; only one at a time my exist; return with refCount == 1
extern ESTimeZone *
ESCalendar_initSingleTimeZoneFromOlsonID(const char *olsonID);

// Increment refCount
extern ESTimeZone *
ESCalendar_retainTimeZone(ESTimeZone *estz);

// Decrement refCount and free if refCount == 0
extern void
ESCalendar_releaseTimeZone(ESTimeZone *estz);
extern void
ESCalendar_releaseSingleTimeZone(ESTimeZone *estz);

// Number of seconds ahead of UTC at the given time in the given time zone
extern double
ESCalendar_tzOffsetForTimeInterval(ESTimeZone     *estz,
				   NSTimeInterval timeInterval);

extern NSTimeInterval
ESCalendar_nextDSTChangeAfterTimeInterval(ESTimeZone     *estz,
					  NSTimeInterval timeInterval);

extern bool
ESCalendar_isDSTAtTimeInterval(ESTimeZone     *estz,
			       NSTimeInterval timeInterval);

extern const char *
ESCalendar_localTimeZoneName(void);

extern ESTimeZone *
ESCalendar_localTimeZone(void);

extern void
ESCalendar_localTimeZoneChanged(void);

// Is this a valid time zone name?
extern bool
ESCalendar_validOlsonID(const char *olsonID);

#ifdef ESCALENDAR_NS
extern NSTimeZone *
ESCalendar_nsTimeZone(ESTimeZone *estz);
#endif

//********** Conversions between NSTimeInterval and ESDateComponents **************

// Return calendar components from an NSTimeInterval (UTC)
extern void
ESCalendar_UTCDateComponentsFromTimeInterval(NSTimeInterval   timeInterval,
					     ESDateComponents *dateComponents);

// Return an NSTimeInterval from calendar components (UTC)
extern NSTimeInterval
ESCalendar_timeIntervalFromUTCDateComponents(ESDateComponents *dateComponents);

// Return calendar components in the given time zone from an NSTimeInterval
extern void
ESCalendar_localDateComponentsFromTimeInterval(NSTimeInterval   timeInterval,
					       ESTimeZone       *timeZone,
					       ESDateComponents *dateComponents);

// Return an NSTimeInterval from the calendar components in the given time zone
extern NSTimeInterval
ESCalendar_timeIntervalFromLocalDateComponents(ESTimeZone       *timeZone,
					       ESDateComponents *dateComponents);

// Return the weekday from an ESTimeInterval (UTC)
extern int
ESCalendar_UTCWeekdayFromTimeInterval(NSTimeInterval);

// Return the weekday in the given timezone from an ESTimeInterval
extern int
ESCalendar_localWeekdayFromTimeInterval(NSTimeInterval,
                                        ESTimeZone *);

//********** Adding ESDateComponents to NSTimeInterval **************

extern NSTimeInterval
ESCalendar_addDaysToTimeInterval(NSTimeInterval timeInterval,
				 ESTimeZone     *estz,
				 int            days);

extern NSTimeInterval
ESCalendar_addMonthsToTimeInterval(NSTimeInterval timeInterval,
				   ESTimeZone     *estz,
				   int            months);

extern NSTimeInterval
ESCalendar_addYearsToTimeInterval(NSTimeInterval timeInterval,
				  ESTimeZone     *estz,
				  int            years);

extern void
ESCalendar_localDateComponentsFromDeltaTimeInterval(ESTimeZone       *estz,
						    NSTimeInterval   time1,
						    NSTimeInterval   time2,
						    ESDateComponents *cs);

extern int
ESCalendar_daysInYear(ESTimeZone     *estz,
		      NSTimeInterval forTime);

//*********** Printing and formatting ******************

const char *
ESCalendar_dateIntervalDescription(NSTimeInterval dt);

extern const char *
ESCalendar_timeZoneName(ESTimeZone *estz);

const char *
ESCalendar_formatInfoForTZ(ESTimeZone *estz,
			   int typ);

const char *
ESCalendar_formatTZOffset(float off);

const char *
ESCalendar_formatTime(void);

const char *
ESCalendar_version(void);

const char *
ESCalendar_formatTimeInterval(NSTimeInterval timeInterval,
			      ESTimeZone     *estz,
			      const char     *formatString);

//*********** Testing ************

#ifndef NDEBUG
extern void ESTestCalendar(void);
#endif

#endif  // ESCALENDAR_H
