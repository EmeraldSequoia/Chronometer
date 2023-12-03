//
//  ECAstronomy.m
//  Emerald Chronometer
//
//  Created by Steve Pucci on May 11 2008
//  Copyright Emerald Sequoia 2008. All rights reserved.
//

#include <math.h>

#import "Constants.h"
#import "ECAstronomy.h"
#import "ECWatchTime.h"
#import "ECWatchEnvironment.h"
#import "ECLocationManager.h"
#import "ECGLWatchLoader.h"
#import "ECGlobals.h"
#import "ECWillmannBell.h"

#define kECDaysInEpochCentury (36525.0)
#define kEC1990Epoch (-347241600.0)  // 12/31/1989 GMT - 1/1/2001 GMT, calculated as 24 * 3600 * (365 * 8 + 366 * 3 + 1) /*1992, 1996, 2000*/ and verified with NS-Calendar
#define kECSunAngularDiameterAtR0 (0.533128*M_PI/180)
#define kECJulianDateOf1990Epoch (2447891.5)
#define kECJulianDateOf2000Epoch (2451545.0)
#define kECJulianDaysPerCentury (36525.0)
#define kECSecondsInTropicalYear (3600.0 * 24 * 365.2422) // NOTE: Average at J2000 (approx), will be less in the future, more in the past
#define kECMoonOrbitSemimajorAxis (384401) // km
#define kECMoonAngularSizeAtA (.5181*M_PI/180)
#define kECMoonParallaxAtA (0.9507*M_PI/180)
#define kECT0k1 (100.46061837 * M_PI/180) // Source: MeeusR2
#define kECT0k2 (36000.770053608 * M_PI/180)
#define kECT0k3 (1/38710000.0 * M_PI/180)
#define kECUTUnitsPerGSTUnit (1/1.00273790935)
#define kECRefractionAtHorizonX (34.0 / 60 * (M_PI / 180))  // 34 arcminutes
#define kECLunarCycleInSeconds (29.530589 * 3600 * 24)
#define kECcosMoonEquatorEclipticAngle 0.999637670406006
#define kECsinMoonEquatorEclipticAngle 0.026917056028711
#define kECSunDistanceR0 (1.495985E8 / kECAUInKilometers)  // semi-major axis
#define kECLimitingAzimuthLatitude (89.9999 * M_PI / 180)  // when the latitude exceeds this (in absolute value), limit it to provide more information about azimuth at the poles

#import "ECAstronomyCache.h"  // Needs to follow #defines above

static bool printingEnabled = false;

bool EC_nansEqual(double n1,
		  double n2) {
    if (isnan(n1) && isnan(n2)) {
	return *((long long *)(&n1)) == *((long long *)(&n2));
    } else {
	return false;  // they're not both nans
    }
}

#define kECAlwaysBelowHorizon nan("1")
#define kECAlwaysAboveHorizon nan("2")

static void
printAngle(double      angle,
	   const char *description) {
    if (!printingEnabled) {
	return;
    }
    if (isnan(angle)) {
	if (EC_nansEqual(angle, kECAlwaysAboveHorizon)) {
	    printf("            NAN (kECAlwaysAboveHorizon)                                                             %s\n",
		   description);
	} else if (EC_nansEqual(angle, kECAlwaysBelowHorizon)) {
	    printf("            NAN (kECAlwaysBelowHorizon)                                                             %s\n",
		   description);
	} else {
	    printf("            NAN (\"\")                                                                                %s\n",
		   description);
	}
	return;
    }
    int sign = angle < 0 ? -1 : 1;
    double absAngle = fabs(angle);
    int degrees = sign * (int)(((long long int)floor(absAngle * 180/M_PI)));
    int arcMinutes = (int)(((long long int)floor(absAngle * 180/M_PI * 60)) % 60);
    int arcSeconds = (int)(((long long int)floor(absAngle * 180/M_PI * 3600)) % 60);
    int arcSecondHundredths = (int)(((long long int)floor(absAngle * 180/M_PI * 360000)) % 100);
    int hours = sign * (int)(((long long int)floor(absAngle * 12/M_PI)));
    int          minutes  = (int)(((long long int)floor(absAngle * 12/M_PI * 60)) % 60);
    int minuteThousandths = (int)(((long long int)floor(absAngle * 12/M_PI * 60000)) % 1000);
    int          seconds = (int)(((long long int)floor(absAngle * 12/M_PI * 3600)) % 60);
    int secondHundredths = (int)(((long long int)floor(absAngle * 12/M_PI * 360000)) % 100);
    printf("%32.24fr %16.8fd %5do%02d'%02d.%02d\" %16.8fh %5dh%02dm%02d.%02ds %5dh%02d.%03dm  %s\n",
	   angle,
	   angle * 180 / M_PI,
	   degrees,
	   arcMinutes,
	   arcSeconds,
	   arcSecondHundredths,
	   angle * 12 / M_PI,
	   hours,
	   minutes,
	   seconds,
	   secondHundredths,
	   hours,
	   minutes,
	   minuteThousandths,
	   description);
}

void EC_printAngle(double     angle,
		   const char *description) {
    bool savePrintingEnabled = printingEnabled;
    printingEnabled = true;
    printAngle(angle, description);
    printingEnabled = savePrintingEnabled;
}

static bool
timesAreOnSameDay(NSTimeInterval dt1,
		  NSTimeInterval dt2,
		  ESTimeZone     *estz) {
    ESDateComponents cs1;
    ESCalendar_localDateComponentsFromTimeInterval(dt1, estz, &cs1);
    ESDateComponents cs2;
    ESCalendar_localDateComponentsFromTimeInterval(dt2, estz, &cs2);
    return cs1.era == cs2.era && cs1.year == cs2.year && cs1.month == cs2.month && cs1.day == cs2.day;
}

static void
printDouble(double     value,
	    const char *description) {
    if (!printingEnabled) {
	return;
    }
    printf("%16.8f        %s\n", value, description);
}

static void
printDateD(NSTimeInterval dt,
	   const char     *description) {
    if (!printingEnabled) {
	return;
    }
    ESDateComponents cs;
    ESCalendar_UTCDateComponentsFromTimeInterval(dt, &cs);
    int second = floor(cs.seconds);
    double fractionalSeconds = cs.seconds - second;
    int microseconds = round(fractionalSeconds * 1000000);
    printf("%s %04d/%02d/%02d %02d:%02d:%02d.%06d UT %s\n",
	   cs.era ? " CE" : "BCE", cs.year, cs.month, cs.day, cs.hour, cs.minute, second, microseconds,
	   description);
}

static void
printDateDWithTimeZone(NSTimeInterval dt,
		       ESTimeZone     *estz,
		       const char     *description) {
    if (!printingEnabled) {
	return;
    }
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, estz, &cs);
    int second = floor(cs.seconds);
    double fractionalSeconds = cs.seconds - second;
    int microseconds = round(fractionalSeconds * 1000000);
    printf("%s %04d/%02d/%02d %02d:%02d:%02d.%06d LT %s\n",
	   cs.era ? " CE" : "BCE", cs.year, cs.month, cs.day, cs.hour, cs.minute, second, microseconds,
	   description);
}

#undef ASTRO_DEBUG_PRINT
#ifdef ASTRO_DEBUG_PRINT
#define PRINT_DOUBLE(D) printDouble(D, #D)
#define PRINT_ANGLE(A) printAngle(A, #A)
#define PRINT_DATE(D) printDateD(D, #D)
#define PRINT_DATE_ACT_LT(D) ([self printDate:D withDescription:#D])
#define PRINT_DATE_VIRT_LT(D) printDateDWithTimeZone(D, estz, #D)
#define PRINT_STRING(S) { if (printingEnabled) printf(S); } 
#define PRINT_STRING1(S, A1) { if (printingEnabled) printf(S, A1); }
#else
#define PRINT_DOUBLE(D)
#define PRINT_ANGLE(A)
#define PRINT_DATE(D)
#define PRINT_DATE_ACT_LT(D)
#define PRINT_DATE_VIRT_LT(D)
#define PRINT_STRING(S)
#define PRINT_STRING1(S, A1)
#endif

static double deltaTTable[] = {  // From 1620 thru 2004 on alternate years (1620, 1622, 1624, etc)  From Meeus 2nd ed, p 79
    121/*1620*/, 112/*1622*/, 103/*1624*/, 95/*1626*/, 88/*1628*/,  82/*1630*/, 77/*1632*/, 72/*1634*/, 68/*1636*/, 63/*1638*/,  60/*1640*/, 56/*1642*/, 53/*1644*/, 51/*1646*/, 48/*1648*/,  46/*1650*/, 44/*1652*/, 42/*1654*/, 40/*1656*/, 38/*1658*/,
    35/*1660*/, 33/*1662*/, 31/*1664*/, 29/*1666*/, 26/*1668*/,  24/*1670*/, 22/*1672*/, 20/*1674*/, 18/*1676*/, 16/*1678*/,  14/*1680*/, 12/*1682*/, 11/*1684*/, 10/*1686*/, 9/*1688*/,  8/*1690*/, 7/*1692*/, 7/*1694*/, 7/*1696*/, 7/*1698*/,
    7/*1700*/, 7/*1702*/, 8/*1704*/, 8/*1706*/, 9/*1708*/,  9/*1710*/, 9/*1712*/, 9/*1714*/, 9/*1716*/, 10/*1718*/,  10/*1720*/, 10/*1722*/, 10/*1724*/, 10/*1726*/, 10/*1728*/,  10/*1730*/, 10/*1732*/, 11/*1734*/, 11/*1736*/, 11/*1738*/,
    11/*1740*/, 11/*1742*/, 12/*1744*/, 12/*1746*/, 12/*1748*/,  12/*1750*/, 13/*1752*/, 13/*1754*/, 13/*1756*/, 14/*1758*/,  14/*1760*/, 14/*1762*/, 14/*1764*/, 15/*1766*/, 15/*1768*/,  15/*1770*/, 15/*1772*/, 15/*1774*/, 16/*1776*/, 16/*1778*/,
    16/*1780*/, 16/*1782*/, 16/*1784*/, 16/*1786*/, 16/*1788*/,  16/*1790*/, 15/*1792*/, 15/*1794*/, 14/*1796*/, 13/*1798*/,  13.1/*1800*/, 12.5/*1802*/, 12.2/*1804*/, 12/*1806*/, 12/*1808*/,  12/*1810*/, 12/*1812*/, 12/*1814*/, 12/*1816*/, 11.9/*1818*/,
    11.6/*1820*/, 11/*1822*/, 10.2/*1824*/, 9.2/*1826*/, 8.2/*1828*/,  7.1/*1830*/, 6.2/*1832*/, 5.6/*1834*/, 5.4/*1836*/, 5.3/*1838*/,  5.4/*1840*/, 5.6/*1842*/, 5.9/*1844*/, 6.2/*1846*/, 6.5/*1848*/,  6.8/*1850*/, 7.1/*1852*/, 7.3/*1854*/, 7.5/*1856*/, 7.6/*1858*/,
    7.7/*1860*/, 7.3/*1862*/, 6.2/*1864*/, 5.2/*1866*/, 2.7/*1868*/,  1.4/*1870*/, -1.2/*1872*/, -2.8/*1874*/, -3.8/*1876*/, -4.8/*1878*/,  -5.5/*1880*/, -5.3/*1882*/, -5.6/*1884*/, -5.7/*1886*/, -5.9/*1888*/,  -6.0/*1890*/, -6.3/*1892*/, -6.5/*1894*/, -6.2/*1896*/, -4.7/*1898*/,
    -2.8/*1900*/, -0.1/*1902*/, 2.6/*1904*/, 5.3/*1906*/, 7.7/*1908*/,  10.4/*1910*/, 13.3/*1912*/, 16.0/*1914*/, 18.2/*1916*/, 20.2/*1918*/,  21.1/*1920*/, 22.4/*1922*/, 23.5/*1924*/, 23.8/*1926*/, 24.3/*1928*/,  24/*1930*/, 23.9/*1932*/, 23.9/*1934*/, 23.7/*1936*/, 24/*1938*/,
    24.3/*1940*/, 25.3/*1942*/, 26.2/*1944*/, 27.3/*1946*/, 28.2/*1948*/,  29.1/*1950*/, 30/*1952*/, 30.7/*1954*/, 31.4/*1956*/, 32.2/*1958*/,  33.1/*1960*/, 34/*1962*/, 35/*1964*/, 36.5/*1966*/, 38.3/*1968*/,  40.2/*1970*/, 42.2/*1972*/, 44.5/*1974*/, 46.5/*1976*/, 48.5/*1978*/,
    50.5/*1980*/, 52.2/*1982*/, 53.8/*1984*/, 54.9/*1986*/, 55.8/*1988*/,  56.9/*1990*/, 58.3/*1992*/, 60/*1994*/, 61.6/*1996*/, 63/*1998*/,  63.8/*2000*/, 64.3/*2002*/, 64.6/*2004*/
};

// From Meeus, p78
double ECMeeusDeltaT(double yearValue) {  // year value as in 2008.5 for July 1 (approx)
    double deltaT;
    if (yearValue < 948) {
	double t = (yearValue - 2000)/100;
	deltaT = 2177 + 497*t + 44.1*t*t;
    } else if (yearValue < 1620) {
	double t = (yearValue - 2000)/100;
	deltaT = 102 + 102*t + 25.3*t*t;
    } else if (yearValue >= 2100) {
	double t = (yearValue - 2000)/100;
	deltaT = 102 + 102*t + 25.3*t*t;
    } else if (yearValue > 2004) {
	double t = (yearValue - 2000)/100;
	deltaT = 102 + 102*t + 25.3*t*t + 0.37*(yearValue - 2100);
    } else if (yearValue == 2004) {
	deltaT = deltaTTable[(2004-1620)/2];
    } else {
	double realIndex = (yearValue-1620)/2;
	int priorIndex = floor(realIndex);
	int nextIndex = priorIndex + 1;
	double interpolation = (realIndex - priorIndex);
	deltaT = deltaTTable[priorIndex] + (deltaTTable[nextIndex] - deltaTTable[priorIndex])*interpolation;
    }
    return deltaT;
}

static double espenakDeltaT(double yearValue) {  // year value as in 2008.5 for July 1
    if (yearValue >= 2005 && yearValue <= 2050) {  // common case first
	double t = (yearValue - 2000);
	double t2 = t * t;
	return 62.92 + 0.32217*t + 0.005589*t2;
    } else if (yearValue < -500 || yearValue >= 2150) {  // really only claimed to be valid back to -1999, so our use of it prior to then is questionable
	double u = (yearValue - 1820) / 100;
	return -20 + 32 * u*u;
    } else if (yearValue < 500) {
	double u = yearValue / 100;
	double u2 = u * u;
	double u3 = u2 * u;
	double u4 = u2 * u2;
	double u5 = u3 * u2;
	double u6 = u3 * u3;
	return 10583.6 - 1014.41*u + 33.78311*u2 - 5.952053*u3
	    - 0.1798452*u4 + 0.022174192*u5 + 0.0090316521*u6;
    } else if (yearValue < 1600) {
	double u = (yearValue-1000) / 100;
	double u2 = u * u;
	double u3 = u2 * u;
	double u4 = u2 * u2;
	double u5 = u3 * u2;
	double u6 = u3 * u3;
	return 1574.2 - 556.01*u + 71.23472*u2 + 0.319781*u3
	    - 0.8503463*u4 - 0.005050998*u5 + 0.0083572073*u6;
    } else if (yearValue < 1700) {
	double t = (yearValue - 1600);
	double t2 = t * t;
	double t3 = t2 * t;
	return 120 - 0.9808*t - 0.01532*t2 + t3/7129;
    } else if (yearValue < 1800) {
	double t = (yearValue - 1700);
	double t2 = t * t;
	double t3 = t2 * t;
	double t4 = t2 * t2;
	return 8.83 + 0.1603*t - 0.0059285*t2 + 0.00013336*t3 - t4/1174000;
    } else if (yearValue < 1860) {
	double t = (yearValue - 1800);
	double t2 = t * t;
	double t3 = t2 * t;
	double t4 = t2 * t2;
	double t5 = t3 * t2;
	double t6 = t3 * t3;
	double t7 = t4 * t3;
	return 13.72 - 0.332447*t + 0.0068612*t2 + 0.0041116*t3 - 0.00037436*t4 
	    + 0.0000121272*t5 - 0.0000001699*t6 + 0.000000000875*t7;
    } else if (yearValue < 1900) {
	double t = (yearValue - 1860);
	double t2 = t * t;
	double t3 = t2 * t;
	double t4 = t2 * t2;
	double t5 = t3 * t2;
	return 7.62 + 0.5737*t - 0.251754*t2 + 0.01680668*t3
	    -0.0004473624*t4 + t5/233174;
    } else if (yearValue < 1920) {
	double t = (yearValue - 1900);
	double t2 = t * t;
	double t3 = t2 * t;
	double t4 = t2 * t2;
	return -2.79 + 1.494119*t - 0.0598939*t2 + 0.0061966*t3 - 0.000197*t4;
    } else if (yearValue < 1941) {
	double t = (yearValue - 1920);
	double t2 = t * t;
	double t3 = t2 * t;
	return 21.20 + 0.84493*t - 0.076100*t2 + 0.0020936*t3;
    } else if (yearValue < 1961) {
	double t = (yearValue - 1950);
	double t2 = t * t;
	double t3 = t2 * t;
	return 29.07 + 0.407*t - t2/233 + t3/2547;
    } else if (yearValue < 1986) {
	double t = (yearValue - 1975);
	double t2 = t * t;
	double t3 = t2 * t;
	return 45.45 + 1.067*t - t2/260 - t3/718;
    } else if (yearValue < 2005) {
	double t = (yearValue - 2000);
	double t2 = t * t;
	double t3 = t2 * t;
	double t4 = t2 * t2;
	double t5 = t3 * t2;
	return 63.86 + 0.3345*t - 0.060374*t2 + 0.0017275*t3 + 0.000651814*t4 
	    + 0.00002373599*t5;
    } else if (yearValue < 2150) {
	assert(yearValue > 2050);  // should have caught it in first case
	double t1 = (yearValue-1820)/100;
	return -20 + 32 * t1*t1 - 0.5628 * (2150 - yearValue);
#ifndef NDEBUG
    } else {
	assert(false);  // should have caught it in second case
#endif
    }
    return 0;
}

static bool useMeeusDeltaT = false;

static double convertUTtoET(double ut,
			    double yearValue) {
    if (useMeeusDeltaT) {
	return ut + ECMeeusDeltaT(yearValue);
    } else {
	return ut + espenakDeltaT(yearValue);
    }
}

#ifndef NDEBUG
static void testConversion() {
    //for (int year = 900; year < 2110; year += 2) {
    for (int year = -500; year < 2110; year += 50) {
	useMeeusDeltaT = true;
	double newValue = convertUTtoET(0, year);
	printf("\n%04d %10.3f Meeus\n", year, newValue);
	useMeeusDeltaT = false;
	newValue = convertUTtoET(0, year);
	printf("%04d %10.3f Espenak\n", year, newValue);
    }
}
#endif

double
julianDateForDate(NSTimeInterval dateInterval) {
    double secondsSince1990Epoch = dateInterval - kEC1990Epoch;
    return kECJulianDateOf1990Epoch + (secondsSince1990Epoch / (24 * 3600));
}

static NSTimeInterval
priorUTMidnightForDateRaw(NSTimeInterval dateInterval) {
    ESDateComponents cs;
    ESCalendar_UTCDateComponentsFromTimeInterval(dateInterval, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    return ESCalendar_timeIntervalFromUTCDateComponents(&cs);
}

static NSTimeInterval
priorUTMidnightForDateInterval(NSTimeInterval calculationDateInterval,
			       ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    double val;
    if (currentCache && currentCache->cacheSlotValidFlag[priorUTMidnightSlotIndex] == currentCache->currentFlag) {
	val = currentCache->cacheSlots[priorUTMidnightSlotIndex];
    } else {
	static double lastCalculatedMidnight = 0;
	if (calculationDateInterval > lastCalculatedMidnight && calculationDateInterval < lastCalculatedMidnight + 24 * 3600) {
	    val = lastCalculatedMidnight;
	} else {
	    val = priorUTMidnightForDateRaw(calculationDateInterval);
	    lastCalculatedMidnight = val;
	}
	if (currentCache) {
	    currentCache->cacheSlots[priorUTMidnightSlotIndex] = val;
	    currentCache->cacheSlotValidFlag[priorUTMidnightSlotIndex] = currentCache->currentFlag;
	}
    }
    return val;
}

static NSTimeInterval
noonUTForDateInterval(NSTimeInterval dateInterval) {
    ESDateComponents cs;
    ESCalendar_UTCDateComponentsFromTimeInterval(dateInterval, &cs);
    cs.hour = 12;
    cs.minute = 0;
    cs.seconds = 0;
    return ESCalendar_timeIntervalFromUTCDateComponents(&cs);
}

static double positionAngle(double sunRightAscension,
			    double sunDeclination,
			    double objRightAscension,
			    double objDeclination) {
    return atan2(cos(sunDeclination) * sin(sunRightAscension - objRightAscension),
		 cos(objDeclination) * sin(sunDeclination) - sin(objDeclination) * cos(sunDeclination) * cos(sunRightAscension - objRightAscension));
}

static double greatCircleCourse(double latitude1,
				double longitude1,
				double latitude2,
				double longitude2) {
    return atan2(sin(longitude1 - longitude2) * cos(latitude2),
		 cos(latitude1)*sin(latitude2)-sin(latitude1)*cos(latitude2)*cos(longitude1-longitude2));
}

static double northAngleForObject(double altitude,
				  double azimuth,
				  double observerLatitude) {
    // this is the great circle course from the object to the celestial north pole
    // expressed in lat/long coordinates for a sphere whose north is at the zenith
    // and where the celestial north pole is at latitude = observerLatitude and longitude = 0
    // and the object is at latitude=altitude and longitude=azimuth
    return greatCircleCourse(altitude, azimuth, observerLatitude, 0);
}

// Returns TDT/ET Julian Centuries since J2000.0 given a UT date
static double
julianCenturiesSince2000EpochForDateInterval(NSTimeInterval dateInterval,
					     double         *deltaT,
					     ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    double julianCenturiesSince2000Epoch;
    if (currentCache && currentCache->cacheSlotValidFlag[tdtCenturiesSlotIndex] == currentCache->currentFlag) {  // we use one slot index valid value to cover all values
	julianCenturiesSince2000Epoch = currentCache->cacheSlots[tdtCenturiesSlotIndex];
	if (deltaT) {
	    *deltaT = currentCache->cacheSlots[tdtCenturiesDeltaTSlotIndex];
	}
    } else {
	double utSeconds = dateInterval;
	NSTimeInterval firstOfThisYearInterval;
	static NSTimeInterval lastCalculatedFirstInterval = 0;
	static int lastYearValue = 0;
	if (utSeconds > lastCalculatedFirstInterval && utSeconds < lastCalculatedFirstInterval + (24 * 3600 * 330)) {
	    firstOfThisYearInterval = lastCalculatedFirstInterval;
	} else {
	    ESDateComponents cs;
	    ESCalendar_UTCDateComponentsFromTimeInterval(dateInterval, &cs);
	    cs.month = 1;
	    cs.day = 1;
	    cs.hour = 0;
	    cs.minute = 0;
	    cs.seconds = 0;
	    firstOfThisYearInterval = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	    lastCalculatedFirstInterval = firstOfThisYearInterval;
	    lastYearValue = cs.era ? cs.year : 1 - cs.year;
	}
	double yearValue = lastYearValue + (utSeconds - firstOfThisYearInterval)/(365.25 * 24 * 3600);
	PRINT_DOUBLE(yearValue);
	double etSeconds = convertUTtoET(utSeconds, yearValue);
	if (deltaT) {
	    *deltaT = etSeconds - utSeconds;
	}
	double julianDaysSince2000Epoch = julianDateForDate(etSeconds) - kECJulianDateOf2000Epoch;
	julianCenturiesSince2000Epoch = julianDaysSince2000Epoch / kECJulianDaysPerCentury;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[tdtCenturiesSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[tdtHundredCenturiesSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[tdtCenturiesSlotIndex] = julianCenturiesSince2000Epoch;
	    currentCache->cacheSlots[tdtCenturiesDeltaTSlotIndex] = etSeconds - utSeconds;
	    currentCache->cacheSlots[tdtHundredCenturiesSlotIndex] = julianCenturiesSince2000Epoch / 100;
	}
    }
    return julianCenturiesSince2000Epoch;
}

static double sunEclipticLongitudeForDate(NSTimeInterval dateInterval,
					  ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunEclipticLongitudeSlotIndex] == currentCache->currentFlag) {
	return currentCache->cacheSlots[sunEclipticLongitudeSlotIndex];
    }
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(dateInterval, NULL, currentCache);
    double eclipticLongitude = WB_sunLongitudeApparent(julianCenturiesSince2000Epoch/100, currentCache);
    //printAngle(eclipticLongitude, "EL Willmann-Bell");
    if (currentCache) {
	currentCache->cacheSlotValidFlag[sunEclipticLongitudeSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[sunEclipticLongitudeSlotIndex] = eclipticLongitude;
    }
    return eclipticLongitude;
}

static double meanObliquityOfEclipticForDate(NSTimeInterval dateInterval) {
    double julianDaysSince2000Epoch = julianDateForDate(dateInterval) - kECJulianDateOf2000Epoch;
    double julianCenturiesSince2000Epoch = julianDaysSince2000Epoch / kECJulianDaysPerCentury;
    double obliquity =
	(23.439292 - (46.815 * julianCenturiesSince2000Epoch +
		      0.0006 * (julianCenturiesSince2000Epoch * julianCenturiesSince2000Epoch) +
		      0.00181 * (julianCenturiesSince2000Epoch * julianCenturiesSince2000Epoch * julianCenturiesSince2000Epoch)) / 3600.0) * M_PI / 180.0;
    PRINT_ANGLE(obliquity);
    return obliquity;
}

// Method taking obliquity directly (for testing purposes, we break this out)
static void raAndDeclO(double eclipticLatitude,
		       double eclipticLongitude,
		       double obliquity,
		       double *rightAscensionReturn,
		       double *declinationReturn) {
    double sinDelta = sin(eclipticLatitude)*cos(obliquity) + cos(eclipticLatitude)*sin(obliquity)*sin(eclipticLongitude);
    PRINT_DOUBLE(sinDelta);
    *declinationReturn = asin(sinDelta);
    PRINT_ANGLE(*declinationReturn);
    double y = sin(eclipticLongitude)*cos(obliquity)-tan(eclipticLatitude)*sin(obliquity);
    PRINT_DOUBLE(y);
    double x = cos(eclipticLongitude);
    PRINT_DOUBLE(x);
    *rightAscensionReturn = atan2(y, x);
    PRINT_ANGLE(*rightAscensionReturn);
}

// raAndDecl with eclipticLatitude == 0
static void sunRAandDecl(NSTimeInterval dateInterval,
			 double 	*rightAscensionReturn,
			 double 	*declinationReturn,
			 ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunRASlotIndex] == currentCache->currentFlag) {  // both slotValid flags are always set at the same time
	*rightAscensionReturn = currentCache->cacheSlots[sunRASlotIndex];
	*declinationReturn = currentCache->cacheSlots[sunDeclSlotIndex];
	return;
    }
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(dateInterval, NULL, currentCache);
    double sunLongitude;
    WB_sunRAAndDecl(julianCenturiesSince2000Epoch/100, rightAscensionReturn, declinationReturn, &sunLongitude, currentCache);
    if (currentCache) {
	currentCache->cacheSlotValidFlag[sunRASlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlotValidFlag[sunDeclSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[sunRASlotIndex] = *rightAscensionReturn;
	currentCache->cacheSlots[sunDeclSlotIndex] = *declinationReturn;
    }
}

// From Meeus, chs 11 & 40
static void topocentricParallax(double ra,  // radians
				double decl,// radians
				double H,   // hour angle, radians
				double distInAU, // AU
				double observerLatitude,  // radians
				double observerAltitude,  // m
				double *Hprime,
				double *declPrime) {
    static const double bOverA = 0.99664719;
    double u = atan(bOverA * tan(observerLatitude));
    double delta = observerAltitude/6378140;
    double rhoSinPhiPrime = bOverA * sin(u) + delta * sin(observerLatitude);
    double rhoCosPhiPrime = cos(u) + delta * cos(observerLatitude);
    double sinPi = sin(8.794/3600*M_PI/180)/distInAU;  // equatorial horizontal parallax
    double A = cos(decl) * sin(H);
    double B = cos(decl) * cos(H) - rhoCosPhiPrime * sinPi;
    double C = sin(decl) - rhoSinPhiPrime * sinPi;
    double q = sqrt(A*A + B*B + C*C);
    *Hprime = atan2(A,B);
    if (*Hprime < 0) {
	*Hprime += (M_PI * 2);
    }
    *declPrime = asin(C/q);
}

static void moonRAAndDecl(NSTimeInterval dateInterval,
			  double 	 *rightAscensionReturn,
			  double 	 *declinationReturn,
			  double         *moonEclipticLongitudeReturn,
			  ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonRASlotIndex] == currentCache->currentFlag) {  // we use one slot index valid value to cover all values
	*rightAscensionReturn = currentCache->cacheSlots[moonRASlotIndex];
	*declinationReturn = currentCache->cacheSlots[moonDeclSlotIndex];
	*moonEclipticLongitudeReturn = currentCache->cacheSlots[moonEclipticLongitudeSlotIndex];
	return;
    }

    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(dateInterval, NULL, currentCache);
    //printf("Date %s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:dateInterval] description] UTF8String]);
    //printf("Julian date %.10f\n", julianDateForDate(dateInterval));

    double moonEclipticLatitude;
    WB_MoonRAAndDecl(julianCenturiesSince2000Epoch, rightAscensionReturn, declinationReturn, moonEclipticLongitudeReturn, &moonEclipticLatitude, currentCache, ECWBFullPrecision);
    //printAngle(*moonEclipticLongitudeReturn, "eclip long WB");
    //printAngle(moonEclipticLatitude, "eclip lat WB");
    //printAngle(*rightAscensionReturn, "wb moon RA");
    //printAngle(*declinationReturn, "wb moon decl");
    if (currentCache) {
	currentCache->cacheSlotValidFlag[moonRASlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[moonRASlotIndex] = *rightAscensionReturn;
	currentCache->cacheSlots[moonDeclSlotIndex] = *declinationReturn;
	currentCache->cacheSlots[moonEclipticLongitudeSlotIndex] = *moonEclipticLongitudeReturn;
    }
}

// Note spucci 2017-10-29:  GAAAAAAH!!
// moonAge is just a bad concept, but it's encoded into the terminator, so we're stuck with it until/unless the terminator gets rewritten.
// When I was writing that code back in 2008, I apparently was under the impression that what was important was how the Moon went around the Earth
// with respect to the Sun (the Moon-Earth-Sun angle, if you will).  But the phase is solely dependent on the Earth-Moon-Sun angle (in fact,
// that's how astronomical calculations are defined), since that's how we see the shadow on the Moon.  I got "lucky" in that the phase and the
// "age angle" are essentially complements (they, along with the Earth-Sun-Moon angle, are the three angles of a triangle, but the Earth-Sun-Moon
// angle is very very small).  So by assuming 180-phase=age, the calculations (mostly) worked out.  This weird convention is unfortunate, since
// we're trying to do planet phases now for Android in Terra II, and there age and phase are *not* complements, so the assumptions don't work out.

// THE "phase" RETURNED HERE IS WRONG.  I have no idea where I got "phase = (1 - cos(age))/2", but that's just malarkey.  I don't think we actually
// use the phase anywhere, so it's probably ok.  It should just be 180-age.  Not changing now.
static double
moonAge(NSTimeInterval dateInterval,
	double         *phase,   // NOT REALLY PHASE, JUST BOGUS NUMBER
	ECAstroCache   *currentCache) {
    double age;
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonAgeSlotIndex] == currentCache->currentFlag) {
	age = currentCache->cacheSlots[moonAgeSlotIndex];
	*phase = currentCache->cacheSlots[moonPhaseSlotIndex];
    } else {
	double rightAscension;
	double declination;
	double moonEclipticLongitude;
	moonRAAndDecl(dateInterval, &rightAscension, &declination, &moonEclipticLongitude, currentCache);
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(dateInterval, NULL, currentCache);
	double sunEclipticLongitude = WB_sunLongitudeApparent(julianCenturiesSince2000Epoch/100, currentCache);
	age = moonEclipticLongitude - sunEclipticLongitude;
	if (age < 0) {
	    age += (M_PI * 2);
	}
	PRINT_ANGLE(age);
	*phase = (1 - cos(age))/2;  // HUH?
	PRINT_DOUBLE(*phase);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonAgeSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonAgeSlotIndex] = age;
	    currentCache->cacheSlots[moonPhaseSlotIndex] = *phase;
	}
    }
    return age;
}

static NSTimeInterval
stepRefineMoonAgeTargetForDate(NSTimeInterval dateInterval,
			       double         targetAge,
			       ECAstroCache   *currentCache) {
    double phase;
    double age = moonAge(dateInterval, &phase, currentCache);
    double deltaAge = targetAge - age;  // amount by which we must increase the calculation date to reach the target age
    if (deltaAge > M_PI) {
	deltaAge -= (M_PI * 2);
    } else if (deltaAge < -M_PI) {
	deltaAge += (M_PI * 2);
    }
    return (dateInterval + deltaAge/(M_PI * 2)*kECLunarCycleInSeconds);
}

static NSTimeInterval
refineMoonAgeTargetForDate(NSTimeInterval dateInterval,
			   double         targetAge,
			   ECAstroCachePool *cachePool) {
    NSTimeInterval tryDate = dateInterval;
    for (int i = 0; i < 5; i++) {
	ECAstroCache *priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
	NSTimeInterval newDate = stepRefineMoonAgeTargetForDate(tryDate, targetAge, cachePool->currentCache);
	popECAstroCacheToInPool(cachePool, priorCache);
	if (fabs(newDate - tryDate) < 0.1) {
	    return newDate;
	}
	tryDate = newDate;
    }
    return tryDate;
}

static double convertLSTtoGST(double lst,
			      double observerLongitude,
			      int    *dayOffset) {
    double gst = lst - observerLongitude;
    if (gst < 0) {
	gst += (M_PI * 2);
	if (dayOffset) {
	    *dayOffset = -1;
	}
    } else if (gst > (M_PI * 2)) {
	gst -= (M_PI * 2);
	if (dayOffset) {
	    *dayOffset = 1;
	}
    } else {
	if (dayOffset) {
	    *dayOffset = 0;
	}
    }
    return gst;
}

static double convertGSTtoLST(double gst,
			      double observerLongitude) {
    double lst = gst + observerLongitude;
    if (lst < 0) {
	lst += (M_PI * 2);
    } else if (lst > (M_PI * 2)) {
	lst -= (M_PI * 2);
    }
    return lst;
}

// P03; returns seconds
static double
convertUTToGSTP03x(double         centuriesSinceEpochTDT,
		   double         deltaTSeconds,
		   double         utSinceMidnightRadians,
		   NSTimeInterval priorUTMidnight) {
    double t = centuriesSinceEpochTDT;
    double tu = t - deltaTSeconds/(24*3600*kECJulianDaysPerCentury);
    double t2 = t*t;
    double t3 = t2*t;
    double t4 = t2*t2;
    double t5 = t3*t2;
    double gmst = 24110.5493771
	+ 8640184.79447825*tu
	+ 307.4771013*(t - tu)
	+ 0.092772110*t2
	- 0.0000002926*t3
	- 0.00000199708*t4
	- 0.000000002454*t5;
    // convert from seconds to radians
    gmst *= M_PI / (12.0 * 3600);
    gmst += utSinceMidnightRadians;
    gmst = EC_fmod(gmst, M_PI * 2);
    if (gmst < 0) {
	gmst += M_PI * 2;
    }
    return gmst;
}

static double
convertUTToGSTP03(double       calculationDate,
		  ECAstroCache *currentCache) {
    double deltaTSeconds;
    double centuriesSinceEpochTDT = julianCenturiesSince2000EpochForDateInterval(calculationDate, &deltaTSeconds, currentCache);
    double priorUTMidnightD = priorUTMidnightForDateInterval(calculationDate, currentCache);
    double utRadiansSinceMidnight = (calculationDate - priorUTMidnightD) * M_PI/(12 * 3600);
    return convertUTToGSTP03x(centuriesSinceEpochTDT, deltaTSeconds, utRadiansSinceMidnight, priorUTMidnightD);
}

static double
convertGSTtoUT(double         	gst,
	       NSTimeInterval 	priorUTMidnight,
	       double         	*ut2,
	       ECAstroCachePool *cachePool) {
    PRINT_ANGLE(gst);
    PRINT_DATE(priorUTMidnight);

    ECAstroCache *priorCache = pushECAstroCacheInPool(cachePool, &cachePool->midnightCache, priorUTMidnight);
    double deltaTSeconds;
    double centuriesSinceEpochTDT = julianCenturiesSince2000EpochForDateInterval(priorUTMidnight, &deltaTSeconds, cachePool->currentCache);
    double T0 = convertUTToGSTP03x(centuriesSinceEpochTDT, deltaTSeconds, 0, priorUTMidnight);
    popECAstroCacheToInPool(cachePool, priorCache);

    double ut = gst - T0;
    if (ut < 0) {
	ut += (M_PI * 2);
    } else if (ut > (M_PI * 2)) {
	ut -= (M_PI * 2);
    }
    ut *= kECUTUnitsPerGSTUnit;
    PRINT_ANGLE(ut);
    *ut2 = ut + (kECUTUnitsPerGSTUnit * (M_PI * 2));  // there might be two uts for this gst
    if (*ut2 > (M_PI * 2)) {
	*ut2 = -1;  // only one ut for this gst
    } else {
	PRINT_ANGLE(*ut2);
    }
    return ut;
}

static double
STDifferenceForDate(NSTimeInterval dateInterval,
		    ECAstroCache   *currentCache) {
    double deltaTSeconds;
    double centuriesSinceEpochTDT = julianCenturiesSince2000EpochForDateInterval(dateInterval, &deltaTSeconds, currentCache);
    double priorUTMidnightD = priorUTMidnightForDateInterval(dateInterval, currentCache);
    double utRadiansSinceMidnight = (dateInterval - priorUTMidnightD) * M_PI/(12 * 3600);
    double gst = convertUTToGSTP03x(centuriesSinceEpochTDT, deltaTSeconds, utRadiansSinceMidnight, priorUTMidnightD);
    return gst - utRadiansSinceMidnight;
}

static NSTimeInterval
convertGSTtoUTclosest(double           gst,
		      NSTimeInterval   closestToThisDate,
		      ECAstroCachePool *cachePool) {
    PRINT_DATE(closestToThisDate);
    double priorUTMidnightD = priorUTMidnightForDateInterval(closestToThisDate, cachePool->currentCache);

    // Calculate answer for this UT date
    double ut0_2;
    double ut0 = convertGSTtoUT(gst, priorUTMidnightD, &ut0_2, cachePool);
    double utSecondsSinceMidnight = ut0 * (12 * 3600)/M_PI;

    // seconds since reference date for answer
    double utD = priorUTMidnightD + utSecondsSinceMidnight;

    // If answer is less than target date - 12h, then we want the next UT date
    if (utD < closestToThisDate - 12 * 3600.0 * kECUTUnitsPerGSTUnit) {
	// First see if there is a second, later UT date for the given GST:
	if (ut0_2 > 0) {
	    PRINT_STRING("...using second UT for this GST\n");
	    ut0 = ut0_2;
	    utSecondsSinceMidnight = ut0 * (12 * 3600)/M_PI;
	    utD = priorUTMidnightD + utSecondsSinceMidnight;
	} else {
	    PRINT_STRING("...moving forward a day\n");
	    priorUTMidnightD += 24 * 3600.0;
	    ut0 = convertGSTtoUT(gst, priorUTMidnightD, &ut0_2, cachePool);
	    utSecondsSinceMidnight = ut0 * (12 * 3600)/M_PI;
	    utD = priorUTMidnightD + utSecondsSinceMidnight;
	}
    } else if (utD > closestToThisDate + 12 * 3600.0 * kECUTUnitsPerGSTUnit) {
	PRINT_STRING("...backing up a day\n");
	priorUTMidnightD -= 24 * 3600.0;
	ut0 = convertGSTtoUT(gst, priorUTMidnightD, &ut0_2, cachePool);
	if (ut0_2 > 0) { // we want the later of the two if there is one
	    PRINT_STRING("...using later of two UTs for this GST\n");
	    ut0 = ut0_2;
	}
	utSecondsSinceMidnight = ut0 * (12 * 3600)/M_PI;
	utD = priorUTMidnightD + utSecondsSinceMidnight;
    }
    return utD;
}

// From P03; includes both motion of the equator in the GCRS and the motion of the ecliptic
// in the ICRS.
static double
generalPrecessionSinceJ2000(double julianCenturiesSince2000Epoch) {
    double t = julianCenturiesSince2000Epoch;
    double t2 = t*t;
    double t3 = t*t2;
    double t4 = t2*t2;
    double t5 = t2*t3;

    double arcSeconds = 5028.796195*t + 1.1054348*t2 + 0.00007964*t3 - 0.000023857*t4 - 0.0000000383*t5;
    double radians = arcSeconds * M_PI/(3600 * 180);
//    char buf[128];
//    sprintf(buf, "%20.10f", julianCenturiesSince2000Epoch);
//    printAngle(radians, buf);
    return radians;
}

// From P03; includes both motion of the equator in the GCRS and the motion of the ecliptic
// in the ICRS.
static double
generalObliquity(double julianCenturiesSince2000Epoch) {
    double t = julianCenturiesSince2000Epoch;
    double t2 = t*t;
    double t3 = t*t2;
    double t4 = t2*t2;
    double t5 = t2*t3;
    double e0 = 84381.406;
    double eA = e0 - 46.836769*t - 0.0001831*t2 + 0.00200340*t3 - 0.000000576*t4 - 0.0000000434*t5;
    double radians = eA * M_PI/(3600 * 180);
    return radians;
}

// From P03; includes both motion of the equator in the GCRS and the motion of the ecliptic
// in the ICRS.
static void
generalPrecessionQuantities(double julianCenturiesSince2000Epoch,
			    double *pA,
			    double *eA,
			    double *chiA,
			    double *zetaA,
			    double *zA,
			    double *thetaA) {
    double t = julianCenturiesSince2000Epoch;
    double t2 = t*t;
    double t3 = t*t2;
    double t4 = t2*t2;
    double t5 = t2*t3;
    double arcSeconds = 5028.796195*t + 1.1054348*t2 + 0.00007964*t3 - 0.000023857*t4 - 0.0000000383*t5;
    *pA = arcSeconds * M_PI/(3600 * 180);
    double e0 = 84381.406;
    arcSeconds = e0 - 46.836769*t - 0.0001831*t2 + 0.00200340*t3 - 0.000000576*t4 - 0.0000000434*t5;
    *eA = arcSeconds * M_PI/(3600 * 180);
    arcSeconds = 10.556403*t - 2.3814292*t2 - 0.00121197*t3 + 0.000170663*t4 - 0.0000000560*t5;
    *chiA = arcSeconds * M_PI/(3600 * 180);
    arcSeconds = 2.650545 + 2306.083227*t + 0.2988499*t2 + 0.01801828*t3 - 0.000005971*t4 - 0.0000003173*t5;
    *zetaA = arcSeconds * M_PI/(3600 * 180);
    arcSeconds = -2.650545 + 2306.077181*t + 1.0927348*t2 + 0.01826837*t3 - 0.000028596*t4 - 0.0000002904*t5;
    *zA = arcSeconds * M_PI/(3600 * 180);
    arcSeconds = 2004.19103*t - 0.4294934*t2 - 0.04182264*t3 - 0.000007089*t4 - 0.0000001274*t5;
    *thetaA = arcSeconds * M_PI/(3600 * 180);
}

// P03; uses general precession quantities
static void
convertJ2000ToOfDate(double julianCenturiesSince2000Epoch,
		     double raJ2000,
		     double declJ2000,
		     double *raOfDate,
		     double *declOfDate) {
    double pA, eA, chiA, zetaA, zA, thetaA;
    generalPrecessionQuantities(julianCenturiesSince2000Epoch, &pA, &eA, &chiA, &zetaA, &zA, &thetaA);
    double cosDecl = cos(declJ2000);
    double sinDecl = sin(declJ2000);
    double cosTheta = cos(thetaA);
    double sinTheta = sin(thetaA);
    double term = cosDecl*cos(raJ2000 + zetaA);
    double A = cosDecl*sin(raJ2000 + zetaA);
    double B = cosTheta*term - sinTheta*sinDecl;
    double C = sinTheta*term + cosTheta*sinDecl;
    double raMinusZ = atan2(A, B);
    double ra = EC_fmod(raMinusZ + zA, M_PI * 2);
    if (ra < 0) {
	ra += M_PI * 2;
    }
    *raOfDate = ra;
    *declOfDate = asin(C);  // Meeus says: if star is close to celestial pole, use decl = acos(sqrt(A*A + B*B)) instead; but for now we're just dealing with things in the ecliptic
}

// Meeus; P03 does not have formulae for angles to convert back to J2000; see also refineConvertToJ2000FromOfDate below
static void
convertToJ2000FromOfDate(double julianCenturiesSince2000Epoch,
			 double raOfDate,
			 double declOfDate,
			 double *raJ2000,
			 double *declJ2000) {
    double T = julianCenturiesSince2000Epoch;
    double T2 = T*T;
    double t = -T;
    double t2 = t*t;
    double t3 = t2*t;
    double arcSeconds = (2306.2181 + 1.39656*T - 0.000139*T2)*t
	+ (0.30188 - 0.000344*T)*t2 + 0.017998*t3;
    double zetaA = arcSeconds * M_PI/(3600 * 180);
    arcSeconds = (2306.2181 + 1.39656*T - 0.000139*T2)*t
	+ (1.09468 + 0.000066*T)*t2 + 0.018203*t3;
    double zA = arcSeconds * M_PI/(3600 * 180);
    arcSeconds = (2004.3109 - 0.85330*T - 0.000217*T2)*t
	- (0.42665 + 0.000217*T)*t2 - 0.041833*t3;
    double thetaA = arcSeconds * M_PI/(3600 * 180);
    double cosDecl = cos(declOfDate);
    double sinDecl = sin(declOfDate);
    double cosTheta = cos(thetaA);
    double sinTheta = sin(thetaA);
    double term = cosDecl*cos(raOfDate + zetaA);
    double A = cosDecl*sin(raOfDate + zetaA);
    double B = cosTheta*term - sinTheta*sinDecl;
    double C = sinTheta*term + cosTheta*sinDecl;
    double raMinusZ = atan2(A, B);
    double ra = EC_fmod(raMinusZ + zA, M_PI * 2);
    if (ra < 0) {
	ra += M_PI * 2;
    }
    *raJ2000 = ra;
    *declJ2000 = asin(C);  // Meeus says: if star is close to celestial pole, use decl = acos(sqrt(A*A + B*B)) instead
}

// Meeus gets very close (10 arcseconds?), but this will get us as exact as we need.  Initial plus 2 refines gets us to within .01 arcsecond
static void
refineConvertToJ2000FromOfDate(double julianCenturiesSince2000Epoch,
			       double raOfDate,
			       double declOfDate,
			       double *raJ2000,
			       double *declJ2000) {
    double raTry2000, declTry2000;
    convertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDate, declOfDate, &raTry2000, &declTry2000);
    double raRoundTrip, declRoundTrip;
    convertJ2000ToOfDate(julianCenturiesSince2000Epoch, raTry2000, declTry2000, &raRoundTrip, &declRoundTrip);
    double raOfDateTweak = raOfDate + (raOfDate - raRoundTrip);
    double declOfDateTweak = declOfDate + (declOfDate - declRoundTrip);
    convertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDateTweak, declOfDateTweak, &raTry2000, &declTry2000);
    convertJ2000ToOfDate(julianCenturiesSince2000Epoch, raTry2000, declTry2000, &raRoundTrip, &declRoundTrip);
    raOfDateTweak = raOfDateTweak + (raOfDate - raRoundTrip); 
    declOfDateTweak = declOfDateTweak + (declOfDate - declRoundTrip);
    convertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDateTweak, declOfDateTweak, &raTry2000, &declTry2000);
    *raJ2000 = raTry2000;
    *declJ2000 = declTry2000;
}

static void sunRAandDeclJ2000(NSTimeInterval dateInterval,
			      double 	     *rightAscensionReturn,
			      double 	     *declinationReturn,
			      ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunRAJ2000SlotIndex] == currentCache->currentFlag) {
	*rightAscensionReturn = currentCache->cacheSlots[sunRAJ2000SlotIndex];
	*declinationReturn = currentCache->cacheSlots[sunDeclJ2000SlotIndex];
	return;
    }
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(dateInterval, NULL, currentCache);
    double raOfDate;
    double declOfDate;
    double sunLongitude;
    WB_sunRAAndDecl(julianCenturiesSince2000Epoch/100, &raOfDate, &declOfDate, &sunLongitude, currentCache);
    refineConvertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDate, declOfDate, rightAscensionReturn, declinationReturn);
    if (currentCache) {
	currentCache->cacheSlotValidFlag[sunRAJ2000SlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlotValidFlag[sunDeclJ2000SlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[sunRAJ2000SlotIndex] = *rightAscensionReturn;
	currentCache->cacheSlots[sunDeclJ2000SlotIndex] = *declinationReturn;
    }
}

static void moonRAandDeclJ2000(NSTimeInterval dateInterval,
			       double 	      *rightAscensionReturn,
			       double 	      *declinationReturn,
			       ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - dateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonRAJ2000SlotIndex] == currentCache->currentFlag) {
	*rightAscensionReturn = currentCache->cacheSlots[moonRAJ2000SlotIndex];
	*declinationReturn = currentCache->cacheSlots[moonDeclJ2000SlotIndex];
	return;
    }
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(dateInterval, NULL, currentCache);
    double raOfDate;
    double declOfDate;
    double moonEclipticLongitude;
    double moonEclipticLatitude;
    WB_MoonRAAndDecl(julianCenturiesSince2000Epoch, &raOfDate, &declOfDate, &moonEclipticLongitude, &moonEclipticLatitude, currentCache, ECWBFullPrecision);
    refineConvertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDate, declOfDate, rightAscensionReturn, declinationReturn);
    if (currentCache) {
	currentCache->cacheSlotValidFlag[moonRAJ2000SlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlotValidFlag[moonDeclJ2000SlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[moonRAJ2000SlotIndex] = *rightAscensionReturn;
	currentCache->cacheSlots[moonDeclJ2000SlotIndex] = *declinationReturn;
    }
}

static void
testConvertJ2000() {
    double julianCenturiesSince2000Epoch = -60;
    double raJ2000 = 41.054063 * M_PI / 180;
    double declJ2000 = 49.227750 * M_PI / 180;
    double raOfDate;
    double declOfDate;
    convertJ2000ToOfDate(julianCenturiesSince2000Epoch, raJ2000, declJ2000, &raOfDate, &declOfDate);
    //printAngle(raOfDate, "test convert RA");
    //printAngle(declOfDate, "test convert decl");
    double raOrig = raJ2000;
    double declOrig = declJ2000;
    refineConvertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDate, declOfDate, &raJ2000, &declJ2000);
    printf("And the results are:\n");
    printAngle(raOrig, "RA J2000 orig");
    printAngle(raJ2000, "RA J2000 round trip");
    printAngle(declOrig, "Decl J2000 orig");
    printAngle(declJ2000, "Decl J2000 round trip");
}

static double planetRadiiInAU[ECNumPlanets] = {
    695500  / kECAUInKilometers,  // ECPlanetSun       = 0
    1737.10 / kECAUInKilometers,  // ECPlanetMoon      = 1
    2439.7  / kECAUInKilometers,  // ECPlanetMercury   = 2
    6051.8  / kECAUInKilometers,  // ECPlanetVenus     = 3
    6371.0  / kECAUInKilometers,  // ECPlanetEarth     = 4,
    3389.5  / kECAUInKilometers,  // ECPlanetMars      = 5,
    69911   / kECAUInKilometers,  // ECPlanetJupiter   = 6,
    58232   / kECAUInKilometers,  // ECPlanetSaturn    = 7,
    25362   / kECAUInKilometers,  // ECPlanetUranus    = 8,
    24622   / kECAUInKilometers,  // ECPlanetNeptune   = 9,
    1195    / kECAUInKilometers   // ECPlanetPluto     = 10,
};

static double planetMassInKG[ECNumPlanets] = {
    11.9891e30,	// Sun
    7.3477e22,	// Moon
    0.330104* 1e24,	// Mercury
    4.86732 * 1e24,	// Venus
    5.97219 * 1e24,	// Earth
    0.641693* 1e24,	// Mars
    1898.13 * 1e24,	// Jupiter
    568.319 * 1e24,	// Saturn
    86.8103 * 1e24,	// Uranus
    102.410 * 1e24,	// Neptune
    0.01309 * 1e24	// Pluto
};

static double planetOrbitalPeriodInYears[ECNumPlanets] = {
    0,	// Sun
    27.321582 / 365.256366,	// Moon
    0.2408467,	// Mercury
    0.61519726,	// Venus
    1.0000174,	// Earth
    1.8808476,	// Mars
    11.862615,	// Jupiter
    29.447498,	// Saturn
    84.016846,	// Uranus
    164.79132,	// Neptune
    247.92065	// Pluto
};

static void
planetSizeAndParallax(int    planetNumber,
		      double distanceInAU,
		      double *angularSizeReturn,
		      double *parallaxReturn) {
    assert(planetNumber >= 0 && planetNumber < ECNumPlanets);
    double radiusInAU = planetRadiiInAU[planetNumber];
    *angularSizeReturn = 2 * atan(radiusInAU / distanceInAU);
    *parallaxReturn = asin(sin(8.794/3600*M_PI/180) / distanceInAU);
}

static double
planetAltAz(int            planetNumber,
	    NSTimeInterval calculationDateInterval,
	    double         observerLatitude,
	    double         observerLongitude,
	    bool           correctForParallax,
	    bool           altNotAz,
	    ECAstroCache   *currentCache) {
    double angle;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    int slotBase = altNotAz ? planetAltitudeSlotIndex : planetAzimuthSlotIndex;
    if (currentCache && currentCache->cacheSlotValidFlag[slotBase+planetNumber] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[slotBase+planetNumber];
    } else {
	// At the north pole, the azimuth of *everything* is south.  But that's not useful, so use the limiting value of azimuth as the latitude approaches zero
	if (observerLatitude > kECLimitingAzimuthLatitude) {
	    observerLatitude = kECLimitingAzimuthLatitude;
	} else if (observerLatitude < - kECLimitingAzimuthLatitude) {
	    observerLatitude = - kECLimitingAzimuthLatitude;
	}
	double planetRightAscension;
	double planetDeclination;
	double planetGeocentricDistance;
	if (currentCache && currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] == currentCache->currentFlag) {
	    assert(currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] == currentCache->currentFlag);
	    planetRightAscension = currentCache->cacheSlots[planetRASlotIndex+planetNumber];
	    planetDeclination = currentCache->cacheSlots[planetDeclSlotIndex+planetNumber];
	    planetGeocentricDistance = currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber];
	} else {
	    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	    double planetEclipticLongitude;
	    double latitude;
	    WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &latitude, &planetGeocentricDistance, &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
	}
	double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
	double lst = convertGSTtoLST(gst, observerLongitude);
	double planetHourAngle = lst - planetRightAscension;
	if (correctForParallax) {
	    double planetTopoHourAngle;
	    double planetTopoDecl;
	    topocentricParallax(planetRightAscension, planetDeclination, planetHourAngle, planetGeocentricDistance, observerLatitude, 0, &planetTopoHourAngle, &planetTopoDecl);
	    //printAngle(planetDeclination, [[NSString stringWithFormat:@"%@ Decl", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	    //printAngle(planetTopoDecl, [[NSString stringWithFormat:@"%@ Topo Decl", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	    planetDeclination = planetTopoDecl;
	    planetHourAngle = planetTopoHourAngle;
	}
	double sinAlt = sin(planetDeclination)*sin(observerLatitude) + cos(planetDeclination)*cos(observerLatitude)*cos(planetHourAngle);
	//printAngle(observerLatitude, [[NSString stringWithFormat:@"%@ observerLatitude", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	//printAngle(cos(observerLatitude), [[NSString stringWithFormat:@"%@ cos(observerLatitude)", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	//double numerator = -cos(planetDeclination)*cos(observerLatitude)*sin(planetHourAngle);
	//printAngle(numerator, [[NSString stringWithFormat:@"%@ numerator", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	//double denominator = sin(planetDeclination) - sin(observerLatitude)*sinAlt;
	//printAngle(denominator, [[NSString stringWithFormat:@"%@ denominator", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	double planetAzimuth = atan2(-cos(planetDeclination)*cos(observerLatitude)*sin(planetHourAngle), sin(planetDeclination) - sin(observerLatitude)*sinAlt);
	//printAngle(planetAzimuth, [[NSString stringWithFormat:@"%@ Azimuth", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	double planetAltitude = asin(sinAlt);
	//printAngle(planetAltitude, [[NSString stringWithFormat:@"%@ Altitude", nameOfPlanetWithNumber(planetNumber)] UTF8String]);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetAltitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetAzimuthSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetAltitudeSlotIndex+planetNumber] = planetAltitude;
	    currentCache->cacheSlots[planetAzimuthSlotIndex+planetNumber] = planetAzimuth;
	}
	angle = altNotAz ? planetAltitude : planetAzimuth;
    }
    return angle;
}

static double
distanceOfPlanetInAU(int    	   planetNumber,
		     double 	   julianCenturiesSince2000Epoch,
		     ECAstroCache  *currentCache,
		     ECWBPrecision moonPrecision) {
    assert(planetNumber >= 0 && planetNumber < ECNumLegalPlanets);
    switch(planetNumber) {
      case ECPlanetSun:
	return WB_sunRadius(julianCenturiesSince2000Epoch/100, currentCache);
      case ECPlanetMoon:
	return WB_MoonDistance(julianCenturiesSince2000Epoch, currentCache, moonPrecision) / kECAUInKilometers;
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	{
	    double geocentricApparentLongitude;
	    double geocentricApparentLatitude;
	    double geocentricDistance;
	    double apparentRightAscension;
	    double apparentDeclination;
	    WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100,
				      &geocentricApparentLongitude, &geocentricApparentLatitude,
				      &geocentricDistance, &apparentRightAscension, &apparentDeclination, currentCache, ECWBFullPrecision);
	    return geocentricDistance;
	}
      case ECPlanetEarth:
      default:
	assert(false);
	return 0;
    }
}

static void angularSizeAndParallaxForPlanet(double         julianCenturiesSince2000Epoch,
					    int            planetNumber,
					    double         *angularSize,
					    double         *parallax,
					    ECAstroCache   *currentCache,
					    ECWBPrecision  moonPrecision) {
    double planetDistance = distanceOfPlanetInAU(planetNumber, julianCenturiesSince2000Epoch, currentCache, moonPrecision);
    planetSizeAndParallax(planetNumber, planetDistance, angularSize, parallax);
}

// Meeus calls this h0
static double
altitudeAtRiseSet(double       	julianCenturiesSince2000Epoch,
		  int          	planetNumber,
		  bool         	wantGeocentricAltitude,
		  ECAstroCache 	*currentCache,
		  ECWBPrecision moonPrecision) {
    double angularDiameter;
    double parallax;
    angularSizeAndParallaxForPlanet(julianCenturiesSince2000Epoch, planetNumber, &angularDiameter, &parallax, currentCache, moonPrecision);
    return (wantGeocentricAltitude ? parallax : 0) - kECRefractionAtHorizonX - angularDiameter/2.0;
//    if (wantGeocentricAltitude) {  // I think this is right, but it makes almost no difference...
//	double alt = parallax - kECRefractionAtHorizonX - angularDiameter/2.0;
//	return asin(sin(parallax)*cos(alt)) - kECRefractionAtHorizonX - angularDiameter/2.0;
//    } else {
//	return -kECRefractionAtHorizonX - angularDiameter/2.0;
//    }
}

// Note: does not incorporate delta-m correction from Meeus here, but otherwise follows pp 102-103
static NSTimeInterval
riseSetTime(bool             riseNotSet,
	    double 	     rightAscension,
	    double 	     declination,
	    double 	     observerLatitude,
	    double 	     observerLongitude,
	    double           altAtRiseSet,
	    NSTimeInterval   calculationDateInterval,
	    ECAstroCachePool *cachePool) {
    double cosH = (sin(altAtRiseSet) - sin(observerLatitude)*sin(declination)) / (cos(observerLatitude)*cos(declination));
    PRINT_DOUBLE(cosH);
    if (cosH < -1.0) {
	PRINT_STRING1("No rise/set: cosh negative (%g)\n", cosH);
	return kECAlwaysAboveHorizon;    // always above the horizon (obsLat > 0 == decl > 0)
    } else if (cosH > 1.0) {
	PRINT_STRING1("No rise/set: cosh positive (%g)\n", cosH);
	return kECAlwaysBelowHorizon;    // always below the horizon (obsLat > 0 != decl > 0)
    }
    double H = acos(cosH);
    PRINT_ANGLE(H);
    double LST_rs = rightAscension + (riseNotSet ? (M_PI * 2) - H : H);
    PRINT_ANGLE(LST_rs);
    if (LST_rs > (M_PI * 2)) {
	LST_rs -= (M_PI * 2);
    }
    PRINT_ANGLE(LST_rs);
    int riseSetDayOffset;
    double GST_rs = convertLSTtoGST(LST_rs, observerLongitude, &riseSetDayOffset);
    PRINT_ANGLE(GST_rs);
    PRINT_STRING1("     ...day offset: %d\n", riseSetDayOffset);
    NSTimeInterval riseSetDate = convertGSTtoUTclosest(GST_rs, calculationDateInterval, cachePool);
    return riseSetDate;
}
		    
static NSTimeInterval
transitTime(NSTimeInterval dateInterval,
	    bool           wantHighTransit,
	    double         observerLongitude,
	    double         rightAscension,
	    ECAstroCache   *currentCache) {
    double gst = convertUTToGSTP03(dateInterval, currentCache);
    if (!wantHighTransit) {
	rightAscension += M_PI;
    }
    double hourAngle = EC_fmod(gst + observerLongitude - rightAscension, (M_PI * 2));
    if (hourAngle > M_PI) {
	hourAngle -= (M_PI * 2);
    } else if (hourAngle < -M_PI) {
	hourAngle += (M_PI * 2);
    }
    double transit = dateInterval - hourAngle*(12*3600)/M_PI;
    return transit;
}

static double linearFit(double X1,
			double Y1,
			double X2,
			double Y2) {
    // Offset to reduce roundoff error:
    double offset = X1;
    X1 = 0;
    Y1 -= offset;
    X2 -= offset;
    Y2 -= offset;
    double denom = X2 - X1 - Y2 + Y1;
    if (denom == 0) {
	return Y2 + offset;  // Best we can do
    }
    //printDateD(X1+offset, "X1 lin");
    //printDateD(Y1+offset, "Y1 lin");
    //printDateD(X2+offset, "X2 lin");
    //printDateD(Y2+offset, "Y2 lin");
    double root = (Y1*(X2 - X1) - X1*(Y2 - Y1)) / denom;
    //printDateD(offset + root, "Y root");
    if (fabs(root - Y2) > 12 * 3600) {  // bogus
	return Y2 + offset;
    }
    return offset + root;
}

// This function presumes that we are trying to find x such that f(x) = x,
// for the function whose prior values are y1 = f(x1), y2 = f(x2), etc, and
// such that the latest values in the array are presumed to be most accurate.
// If there is only one point, then the only reasonable value is to choose y1.
// For two points, we draw a line through P1 and P2 and see where it intersects
// y == x.  For three or more points, we take the most recent three points,
// draw a parabola through it (a quadratic equation), and see where (if anywhere)
// that parabola intersects y == x.  If there are no roots, we revert to linear;
// if there are two roots, we take the closest root to yN.
static double extrapolateToYEqualX(const double x[],
				   const double y[],
				   int    numValues) {
    assert(numValues > 0);
    if (numValues == 1) {
	return y[0];
    }
    
    if (numValues > 2) {

	// To greatly increase the resolution of the numbers we're working from, offset every number from X1
	double offset = x[numValues - 3];
	double X1 = 0;
	double Y1 = y[numValues - 3] - offset;
	double X2 = x[numValues - 2] - offset;
	double Y2 = y[numValues - 2] - offset;
	double X3 = x[numValues - 1] - offset;
	double Y3 = y[numValues - 1] - offset;

	// Expanding Lagrange's formula for a parabola through 3 points:

	if (X1 != X2 && X1 != X3 && X2 != X3) {

	    double k1 = Y1/((X1 - X2)*(X1 - X3));
	    double k2 = Y2/((X2 - X1)*(X2 - X3));
	    double k3 = Y3/((X3 - X1)*(X3 - X2));

	    // Following, then, are coefficients of quadratic equation through p1,p2,p3, for y = C2*x*x - C1*x + C0
	    double C2 = k1 + k2 + k3;
	    double C1 = k1*(X2 + X3) + k2*(X1 + X3) + k3*(X1 + X2);
	    double C0 = k1*X2*X3 + k2*X1*X3 + k3*X1*X2;

	    // If y == x, then it becomes C2*x*x + (-C1 - 1)*x + C0 = 0, or in std quadratic form A = C2, B = -C1-1, C = C0, then dividing by A to get p and q we get
	    if (C2 != 0) {
		double p = (-C1 - 1)/C2;
		double q = C0 / C2;
		double D = p*p/4 - q;
		if (D >= 0) {
		    double sqrtTerm = sqrt(D);
		    double root1 = -p/2 + sqrtTerm;
		    double root2 = -p/2 - sqrtTerm;
		    if (fabs(root1 - Y3) < fabs(root2 - Y3)) {
			if (fabs(root1 - Y3) < 24 * 3600) { // reject totally bogus values and revert to linear
			    //printDateD(X1+offset, "X1");
			    //printDateD(Y1+offset, "Y1");
			    //printDateD(X2+offset, "X2");
			    //printDateD(Y2+offset, "Y2");
			    //printDateD(X3+offset, "X3");
			    //printDateD(Y3+offset, "Y3");
			    //printDateD(root1+offset, "root1");
			    return root1+offset;
			}
			if (printingEnabled) printf("Totally bogus\n");
		    } else {
			if (fabs(root2 - Y3) < 24 * 3600) { // reject totally bogus values and revert to linear
			    //printDateD(X1+offset, "X1");
			    //printDateD(Y1+offset, "Y1");
			    //printDateD(X2+offset, "X2");
			    //printDateD(Y2+offset, "Y2");
			    //printDateD(X3+offset, "X3");
			    //printDateD(Y3+offset, "Y3");
			    //printDateD(root2+offset, "root2");
			    return root2+offset;
			}
			if (printingEnabled) printf("Totally bogus\n");
		    }
		}
	    }
	}
    }
    return linearFit(x[numValues - 2], y[numValues -2], x[numValues - 1], y[numValues - 1]);
}

static NSTimeInterval
planettransitTimeRefined(NSTimeInterval   	     calculationDateInterval,
			 double 	  	     observerLatitude,
			 double 	  	     observerLongitude,
			 bool                        wantHighTransit,
			 int                         planetNumber,
			 double                      *riseSetOrTransit,  // useless parameter here
			 ECAstroCachePool            *cachePool)
{
    assert(planetNumber >= 0 && planetNumber <= ECLastLegalPlanet);
    NSTimeInterval tryDate = calculationDateInterval;
    ECWBPrecision precision = planetNumber == ECPlanetMoon ? ECWBLowPrecision : ECWBFullPrecision;  // Start out moon at low precision
    const int numIterations = 7;
    double tryDates[numIterations];
    double results[numIterations];
    int fitTries = 0;
    for(int i = 0; i < numIterations; i++) {
	if (planetNumber == ECPlanetMoon && i == numIterations - 1 && precision != ECWBFullPrecision) {
	    precision = ECWBFullPrecision;
	    i --;  // Give us two more shots at it with full precision
	    fitTries = 0;  // And ignore any low-precision prior values
	}
	double rightAscension;
	double declination;
	ECAstroCache *priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(tryDate, NULL, cachePool->currentCache);
	double longitude;
	double latitude;
	double distance;
	WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &longitude, &latitude, &distance, &rightAscension, &declination, cachePool->currentCache, precision);
//	printAngle(rightAscension, "rightAscension");
//	printAngle(declination, "declination");
	double newDate = transitTime(tryDate, wantHighTransit, observerLongitude, rightAscension, cachePool->currentCache);
	assert(!isnan(newDate));  // there's always a transit time
	popECAstroCacheToInPool(cachePool, priorCache);
#ifndef NDEBUG
	//printf("Planet %s transit %d (%s) Iteration %d: %s\n", wantHighTransit ? "high" : "low", planetNumber, [nameOfPlanetWithNumber(planetNumber) UTF8String], i, [[[NSDate dateWithTimeIntervalSinceReferenceDate:tryDate] description] UTF8String]);
#else
	//printf("Planet %s %d Iteration %d: %s\n", wantHighTransit ? "high" : "low", planetNumber, i, [[[NSDate dateWithTimeIntervalSinceReferenceDate:tryDate] description] UTF8String]);
#endif
	if (fabs(newDate - tryDate) < 0.1) {  // values within 0.1 second are deemed close enough
	    if (planetNumber == ECPlanetMoon && precision != ECWBFullPrecision) {
		precision = ECWBFullPrecision;
	    } else {
		*riseSetOrTransit = newDate;
		return newDate;
	    }
	}
	tryDates[fitTries] = tryDate;
	results [fitTries++] = newDate;
	tryDate = extrapolateToYEqualX(tryDates, results, fitTries);
    }
#ifndef NDEBUG
    // printf("Planet transit %d (%s): %s\n", planetNumber, [nameOfPlanetWithNumber(planetNumber) UTF8String], [[[NSDate dateWithTimeIntervalSinceReferenceDate:tryDate] description] UTF8String]);
#else
    // printf("Planet %d: %s\n", planetNumber, [[[NSDate dateWithTimeIntervalSinceReferenceDate:tryDate] description] UTF8String]);
#endif
    *riseSetOrTransit = tryDate;
    return tryDate;
}

// Return the rise time closest to the given calculation date, by iterative refinement
static NSTimeInterval
planetaryRiseSetTimeRefined(NSTimeInterval   	     calculationDateInterval,
			    double 	  	     observerLatitude,
			    double 	  	     observerLongitude,
			    bool                     riseNotSet,
			    int                      planetNumber,
			    double                   *riseSetOrTransit,
			    ECAstroCachePool         *cachePool) {
    assert(planetNumber >= 0 && planetNumber <= ECLastLegalPlanet);
    NSTimeInterval tryDate = calculationDateInterval;
    assert(!isnan(tryDate));
    NSTimeInterval lastValidResultDate = nan("");
    NSTimeInterval lastValidTryDate = nan("");
    bool convergedToInvalid = false;
    bool polarSpecial = fabs(observerLatitude) > M_PI / 180 * 89;
    //if (printingEnabled) printf("polarSpecial %s\n", polarSpecial ? "true" : "false");
    ECWBPrecision precision = planetNumber == ECPlanetMoon ? ECWBLowPrecision : ECWBFullPrecision;  // Start out moon at low precision
    if (polarSpecial) {
	precision = ECWBFullPrecision;  // We need all the help we can get at polar latitudes
    }
    const int numIterations = 20;
    const int numPolarTries = 10;  // Number of binary-search tries to find a place that has a valid rise/set -- should get us down to less than a minute
    double tryDates[numIterations + numPolarTries + 1];  // +1 because I'm too lazy to see if I really need it
    double results[numIterations + numPolarTries + 1];
    int fitTries = 0;
    double lastDelta = 0;
    double firstNan = nan("");
    double firstTransit = tryDate;
    for(int i = 0; i < numIterations; i++) {
	if (planetNumber == ECPlanetMoon && i == numIterations - 1 && precision != ECWBFullPrecision) {
	    precision = ECWBFullPrecision;
	    i --;  // Give us two more shots at it with full precision
	    fitTries = 0;  // And ignore any low-precision prior values
	}
	double rightAscension;
	double declination;
	ECAstroCache *priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(tryDate, NULL, cachePool->currentCache);
	double longitude;
	double latitude;
	double distance;
	WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &longitude, &latitude, &distance, &rightAscension, &declination, cachePool->currentCache, precision);
	double newDate = riseSetTime(riseNotSet, rightAscension, declination,
				     observerLatitude, observerLongitude,
				     altitudeAtRiseSet(julianCenturiesSince2000Epoch, planetNumber, true/*wantGeocentricAltitude*/, cachePool->currentCache, precision),
				     tryDate, cachePool);
	popECAstroCacheToInPool(cachePool, priorCache);
	if (isnan(newDate)) {
	    // Mostly this means there is no rise/set this day.  But near the first rise/set of the season, the decl may reach a "legal"
	    // spot closer to the actual rise time during the same day.  To detect this case, we first calculate the transit time which is most likely to cross
	    // the horizon, and see if we're legal there.
	    if (!convergedToInvalid) { // If we haven't already done this
		convergedToInvalid = true;
		bool wantHighTransit = EC_nansEqual(newDate, kECAlwaysBelowHorizon);  // if the object is below, we want high transit, to see if the highest point is any better
		priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
		double tt;
		double transitT = planettransitTimeRefined(tryDate, observerLatitude, observerLongitude, wantHighTransit, planetNumber, &tt, cachePool);
		popECAstroCacheToInPool(cachePool, priorCache);
		firstTransit = transitT;
		firstNan = newDate;
		priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, transitT, 0);
		julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(transitT, NULL, cachePool->currentCache);
		WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &longitude, &latitude, &distance, &rightAscension, &declination, cachePool->currentCache, precision);
		newDate = riseSetTime(riseNotSet, rightAscension, declination,
				      observerLatitude, observerLongitude,
				      altitudeAtRiseSet(julianCenturiesSince2000Epoch, planetNumber, true/*wantGeocentricAltitude*/, cachePool->currentCache, precision),
				      transitT, cachePool);
		popECAstroCacheToInPool(cachePool, priorCache);
		if (isnan(newDate)) {
		    if (polarSpecial) {
			// In this case the effect due to the Earth's rotation is small compared to the change due to the Sun's motion in Decl
			// Go back and forth 13 hours and see if the sun transitioned between up and down; if so binary search to see when it happened
		    
			// Check -13 hrs
			// If nan same as ours, skip and check other side (+13 hrs)
			// If nan different than ours or isn't nan, setup lastPolarUp and lastPolarDown, average them, and iterate
		    
			NSTimeInterval priorPolar = transitT - 13 * 3600;
			priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, priorPolar, 0);
			julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(priorPolar, NULL, cachePool->currentCache);
			WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &longitude, &latitude, &distance, &rightAscension, &declination, cachePool->currentCache, precision);
			NSTimeInterval priorPolarEvent = riseSetTime(riseNotSet, rightAscension, declination,
								     observerLatitude, observerLongitude,
								     altitudeAtRiseSet(julianCenturiesSince2000Epoch, planetNumber, true/*wantGeocentricAltitude*/, cachePool->currentCache, precision),
								     priorPolar, cachePool);
			popECAstroCacheToInPool(cachePool, priorCache);
			NSTimeInterval binaryLow = nan("");
			NSTimeInterval binaryHigh = nan("");
			NSTimeInterval binaryLowEvent = nan("");
			NSTimeInterval binaryHighEvent = nan("");
			if (isnan(priorPolarEvent)) {
			    if (!EC_nansEqual(priorPolarEvent, newDate)) {
				binaryLow = priorPolar;
				binaryLowEvent = priorPolarEvent;
				binaryHigh = transitT;
				binaryHighEvent = newDate;
			    }
			    NSTimeInterval nextPolar = tryDate + 13 * 3600;
			    priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, nextPolar, 0);
			    julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(nextPolar, NULL, cachePool->currentCache);
			    WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &longitude, &latitude, &distance, &rightAscension, &declination, cachePool->currentCache, precision);
			    NSTimeInterval nextPolarEvent = riseSetTime(riseNotSet, rightAscension, declination,
									observerLatitude, observerLongitude,
									altitudeAtRiseSet(julianCenturiesSince2000Epoch, planetNumber, true/*wantGeocentricAltitude*/, cachePool->currentCache, precision),
									nextPolar, cachePool);
			    popECAstroCacheToInPool(cachePool, priorCache);
			    if (isnan(nextPolarEvent)) {
				if (!EC_nansEqual(nextPolarEvent, newDate)) {
				    binaryLow = transitT;
				    binaryLowEvent = newDate;
				    binaryHigh = nextPolar;
				    binaryHighEvent = nextPolarEvent;
				} else if (isnan(binaryLow)) {
				    *riseSetOrTransit = transitT;
				    assert(!isnan(*riseSetOrTransit));
				    return newDate;
				}
			    } else {
				if (nextPolarEvent > tryDate + 24 * 3600) {
				    *riseSetOrTransit = transitT;
				    assert(!isnan(*riseSetOrTransit));
				    return newDate;
				}
				tryDate = nextPolar;
				assert(!isnan(tryDate));
				newDate = nextPolarEvent;
			    }
			} else {
			    if (priorPolarEvent < tryDate - 24 * 3600) {  // Too long ago, doesn't count
				*riseSetOrTransit = transitT;
				assert(!isnan(*riseSetOrTransit));
				return newDate;
			    }
			    tryDate = priorPolar;
			    assert(!isnan(tryDate));
			    newDate = priorPolarEvent;
			}
			if (!isnan(binaryLow)) {
			    //printDateD(binaryLow, "binary search between here");
			    //printDateD(binaryHigh, ".. and here");
			    int polarTries = numPolarTries;
			    while (polarTries--) {
				NSTimeInterval split = (binaryLow + binaryHigh) / 2;
				priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, split, 0);
				julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(split, NULL, cachePool->currentCache);
				WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &longitude, &latitude, &distance, &rightAscension, &declination, cachePool->currentCache, precision);
				NSTimeInterval splitEvent = riseSetTime(riseNotSet, rightAscension, declination,
									observerLatitude, observerLongitude,
									altitudeAtRiseSet(julianCenturiesSince2000Epoch, planetNumber, true/*wantGeocentricAltitude*/, cachePool->currentCache, precision),
									split, cachePool);
				popECAstroCacheToInPool(cachePool, priorCache);
				if (!isnan(splitEvent)) {
				    transitT = split;  // pseudo "transit" for polarSpecial
				    newDate = splitEvent;
				    break;
				}
				if (EC_nansEqual(splitEvent, binaryLowEvent)) {
				    binaryLow = split;
				    binaryLowEvent = splitEvent;
				} else {
				    assert(EC_nansEqual(splitEvent, binaryHighEvent));
				    binaryHigh = split;
				    binaryHighEvent = splitEvent;
				}
			    }
			    if (isnan(newDate)) {
				*riseSetOrTransit = transitT;
				assert(!isnan(*riseSetOrTransit));
				return newDate;
			    }
			    //printDateD(transitT, "...binary search found that asking here");
			    //printDateD(newDate, "...got this result");
			}
		    } else {  // else not polar special
			//printDateD(tryDate, "no riseSet here, first time through, failed");
			//printDateD(transitT, "... (transit time was here)");
			//printAngle(newDate, "...returning newDate");
			*riseSetOrTransit = transitT;
			assert(!isnan(*riseSetOrTransit));
			return newDate;
		    }
		} // end if isnan(newDate) for transit
		//printDateD(transitT, "no riseSet at requestTime, but transitTime here works");
		//if (printingEnabled) printf("nan at calculationDate but transit is better\n");
		assert(!isnan(newDate));
		lastValidTryDate = transitT;
		assert(!isnan(transitT));
		lastValidResultDate = newDate;
		tryDates[fitTries] = transitT;
		results [fitTries++] = newDate;
		tryDate = extrapolateToYEqualX(tryDates, results, fitTries);  // The point (transitT, newDate) is perfectly acceptable as a fit point
		assert(!isnan(tryDate));
		//tryDate = newDate;
	    } else { // already did !convergedToInvalid case
		//printDateD(tryDate, "no riseSet here, been here before");
		// If we've been here before, we know that lastValidTryDate resulted in a legal rise/set.  Let's halve
		// the distance between that and our tryDate here.
		assert(!isnan(lastValidTryDate));
		assert(!isnan(tryDate));
		tryDate = (tryDate + lastValidTryDate) / 2;
		assert(!isnan(tryDate));
		// We have no info about the curve, since it isn't valid here.  So we ignore this in the fitTries arrays
	    }
	} else {
	    //if (printingEnabled) printDateD(tryDate, "riseSet valid here");
	    //if (printingEnabled) printDateD(newDate, "...with result here");
	    lastValidTryDate = tryDate;
	    lastValidResultDate = newDate;
	    tryDates[fitTries] = tryDate;
	    results [fitTries++] = newDate;
	    tryDate = extrapolateToYEqualX(tryDates, results, fitTries);
	    assert(!isnan(tryDate));
	    //printDateD(tryDate, "...extrapolating to here");
	}
	//if (printingEnabled) printf("Iterate %d Planet %d (%s %s): %s\n", i, planetNumber, [nameOfPlanetWithNumber(planetNumber) UTF8String],
	//			    riseNotSet ? "rise" : "set",
	//			    [[[NSDate dateWithTimeIntervalSinceReferenceDate:lastValidResultDate] description] UTF8String]);
	lastDelta = lastValidResultDate - lastValidTryDate;
	if (fabs(lastDelta) < 0.1) {
	    if (planetNumber == ECPlanetMoon && precision != ECWBFullPrecision) {
		precision = ECWBFullPrecision;
		continue;
	    }
#ifndef NDEBUG
	    //if (printingEnabled) printf("Converged Planet %d (%s %s): %s\n", planetNumber, [nameOfPlanetWithNumber(planetNumber) UTF8String],
	    //riseNotSet ? "rise" : "set",
	    //[[[NSDate dateWithTimeIntervalSinceReferenceDate:lastValidResultDate] description] UTF8String]);
#else
	    //printf("Planet %d converged on iteration %d: %s\n", planetNumber, i, [[[NSDate dateWithTimeIntervalSinceReferenceDate:lastValidResultDate] description] UTF8String]);
#endif
	    *riseSetOrTransit = lastValidResultDate;
	    assert(!isnan(*riseSetOrTransit));
	    return lastValidResultDate;
	//} else if (printingEnabled && i == numIterations - 1) {
	//    if (printingEnabled) printf("Last delta %.2f seconds off\n", lastDelta);
	}
    }
#ifndef NDEBUG
    //if (printingEnabled) printf("Didn't converge Planet %d (%s): %s\n", planetNumber, [nameOfPlanetWithNumber(planetNumber) UTF8String], [[[NSDate dateWithTimeIntervalSinceReferenceDate:lastValidResultDate] description] UTF8String]);
#else
    //if (printingEnabled) printf("Planet %d didn't converge: %s\n", planetNumber, [[[NSDate dateWithTimeIntervalSinceReferenceDate:lastValidResultDate] description] UTF8String]);
#endif
    if (isnan(lastValidResultDate)) {
	*riseSetOrTransit = tryDate;
	assert(!isnan(*riseSetOrTransit));
    } else if (fabs(lastDelta) > 60) { // Still futzing around
	*riseSetOrTransit = firstTransit;
	lastValidResultDate = firstNan;
	assert(!isnan(*riseSetOrTransit));
    } else {
	*riseSetOrTransit = lastValidResultDate;
	assert(!isnan(*riseSetOrTransit));
    }
    assert(!isnan(*riseSetOrTransit)); 
    return lastValidResultDate;
}

static double EOT(NSTimeInterval   dateInterval,
                  ECAstroCachePool *cachePool) {
    // Find the longitude at which the mean Sun crosses the meridian at this time.
    // That's the longitude whose offset from Greenwich is exactly the fraction of
    // a day from UT noon.
    NSTimeInterval noonD = noonUTForDateInterval(dateInterval);
    NSTimeInterval secondsFromNoon = dateInterval - noonD;
    double longitudeOfMeanSun = - secondsFromNoon * M_PI / (12 * 3600);  // Sign change:  if it's one hour after UT noon, the longitude of the Sun is one hour west
    double rightAscension;
    double declination;
    // Get the Sun's RA.   This is the local actual sidereal time for the given latitude.
    sunRAandDecl(dateInterval, &rightAscension, &declination, cachePool->currentCache);
    // The actual sidereal time at Greenwich can be obtained by subtracting the longitude
    double gast = rightAscension - longitudeOfMeanSun;
    NSTimeInterval utDate = convertGSTtoUTclosest(gast, dateInterval, cachePool);

    NSTimeInterval eotAsSeconds = dateInterval - utDate;
    double eot = (eotAsSeconds) * M_PI/(12 * 3600);
    //printf("EOT as seconds = %.4f, utDate =%s\n",
    //  eotAsSeconds, [[[NSDate dateWithTimeIntervalSinceReferenceDate:utDate] description] UTF8String]);
    PRINT_ANGLE(eot);
    return eot;
}

@implementation ECAstronomyManager

@synthesize observerLatitude;

-(void)printDateD:(NSTimeInterval)dt withDescription:(const char *)description {
    if (!printingEnabled) {
	return;
    }
    double fractionalSeconds = dt - floor(dt);
    int microseconds = round(fractionalSeconds * 1000000);

    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, estz, &ltcs);
    int ltSecond = floor(ltcs.seconds);

    ESDateComponents utcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, estz, &utcs);
    int utSecond = floor(utcs.seconds);

    printf("%s %04d/%02d/%02d %02d:%02d:%02d.%06d LT, %s %04d/%02d/%02d %02d:%02d:%02d.%06d UT %s\n",
	   ltcs.era ? " CE" : "BCE", ltcs.year, ltcs.month, ltcs.day, ltcs.hour, ltcs.minute, ltSecond, microseconds,
	   utcs.era ? " CE" : "BCE", utcs.year, utcs.month, utcs.day, utcs.hour, utcs.minute, utSecond, microseconds,
	   description);
}

-(id)init {
    assert(false);
    return nil;
}

-(void)dealloc {
    [[environment locationManager] removeLocationChangeObserver:self];
    [environment release];
    [super dealloc];
}

+(void)initializeStatics {  // Tried naming this just "+initialize" but it never got called...
    initializeAstroCache();
#ifndef NDEBUG
    //WB_printMemoryUsage();
#endif
}

+(double)moonDeltaEclipticLongitudeAtDateInterval:(double)dateInterval
{
    double unused_phase;
    return moonAge(dateInterval, &unused_phase, NULL/*currentCache*/);
}

static double zodiacCenters[12] = {	    // ecliptic longitudes of constellation centers
     11,    // Psc
     42,    // Ari
     72,    // Tau
    104,    // Gem
    128,    // Can
    156,    // Leo
    196,    // Vir
    230,    // Lib
    254,    // Sco
    283,    // Sgr
    314,    // Cap
    340	    // Aqr
};
static double zodiacEdges[13] = {	// ecliptic longitudes of constellation western edges
     -8,   //  0 Psc
     29,   //  1 Ari
     54,   //  2 Tau
     90,   //  3 Gem
    118,   //  4 Can
    138,   //  5 Leo
    174,   //  6 Vir
    218,   //  7 Lib
    242,   //  8 Sco, incl Oph
    266,   //  9 Sgr
    300,   // 10 Cap
    327,   // 11 Aqr
    352    // 12 Psc
};

+(double)centerOfZodiacConstellation:(int)n {
    return zodiacCenters[(int)n]/360*2*M_PI;
}

+(double)widthOfZodiacConstellation:(int)n {
    return fabs(zodiacEdges[(int)n]-zodiacEdges[(int)n+1])*2.0*M_PI/360.0;
}

+(NSString *)zodiacConstellationOf:(double)elong {
    for (int i=1; i<13; i++) {
	if ((zodiacEdges[i] * M_PI/180) > elong) {
	    switch (i-1) {
		case  0: return @"Pisces";
		case  1: return @"Aries";
		case  2: return @"Taurus";
		case  3: return @"Gemini";
		case  4: return @"Cancer";
		case  5: return @"Leo";
		case  6: return @"Virgo";
		case  7: return @"Libra";
		case  8: return @"Scorpius";
		case  9: return @"Sagittarius";
		case 10: return @"Capricornus";
		case 11: return @"Aquarius";
		default: assert(false); return nil;
	    }
	}
    }
    return @"Pisces";
}

#ifndef NDEBUG
-(void)testPolarEdge {
    ESDateComponents cs;
    cs.year = 2009;
    cs.month = 3;
    cs.day = 27;
    cs.hour = 12;
    cs.minute = 0;
    cs.seconds = 0;
    ESTimeZone *estzTest = ESCalendar_initTimeZoneFromOlsonID("US/Pacific");
    NSTimeInterval calculationDate = ESCalendar_timeIntervalFromLocalDateComponents(estzTest, &cs);
    double riseSetOrTransit;
    NSTimeInterval riseTime = planetaryRiseSetTimeRefined(calculationDate,
							    70 * M_PI / 180, // latitude
							  -122 * M_PI / 180, // longitude
							  true, // riseNotSet
							  ECPlanetVenus,
							  &riseSetOrTransit,
							  astroCachePool);
    printingEnabled = true;
    printDateDWithTimeZone(riseTime, estzTest, "polarEdge Venusrise");
    ESCalendar_releaseTimeZone(estzTest);
    printingEnabled = false;
}
#endif

-(void)runTests {
#ifndef NDEBUG
    double ra;
    double decl;
    double moonEclipticLongitude;
    double age;
    double moonPhase;
    double angularSize;
    double parallax;
    ESDateComponents cs;
    cs.era = 1;
    static bool testsRun = false;
    if (testsRun) {
	return;
    }
    testsRun = true;

    printf("\nSection 51\n");
    cs.year = 1980;
    cs.month = 7;
    cs.day = 27;
    cs.hour = 12;
    cs.minute = 0;
    cs.seconds = 0;
    EOT(ESCalendar_timeIntervalFromUTCDateComponents(&cs), astroCachePool);

    printf("\nSection 65\n");
    cs.year = 1979;
    cs.month = 2;
    cs.day = 26;
    cs.hour = 16;
    cs.minute = 0;
    cs.seconds = 0;
    moonRAAndDecl(ESCalendar_timeIntervalFromUTCDateComponents(&cs), &ra, &decl, &moonEclipticLongitude, currentCache);

    printf("\nSection 66\n");
    cs.year = 1979;
    cs.month = 2;
    cs.day = 26;
    cs.hour = 17;
    cs.minute = 0;
    cs.seconds = 0;
    moonRAAndDecl(ESCalendar_timeIntervalFromUTCDateComponents(&cs), &ra, &decl, &moonEclipticLongitude, currentCache);

    printf("\nSection 67\n");
    cs.year = 1979;
    cs.month = 2;
    cs.day = 26;
    cs.hour = 16;
    cs.minute = 0;
    cs.seconds = 0;
    age = moonAge(ESCalendar_timeIntervalFromUTCDateComponents(&cs), &moonPhase, currentCache);

    printf("\nSection 69\n");
    cs.year = 1979;
    cs.month = 9;
    cs.day = 6;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    double t = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(t, NULL, currentCache);
    double distance = WB_MoonDistance(julianCenturiesSince2000Epoch, currentCache, ECWBFullPrecision);
    moonRAAndDecl(t, &ra, &decl, &moonEclipticLongitude, currentCache);
    planetSizeAndParallax(ECPlanetMoon, distance/kECAUInKilometers, &angularSize, &parallax);

    printf("\nSection 27\n");
    double elong = (139 + 41/60.0 + 10/3600.0) * M_PI / 180.0;
    PRINT_ANGLE(elong);
    double elat = (4 + 52/60.0 + 31/3600.0) * M_PI / 180.0;
    PRINT_ANGLE(elat);
    double obli = 23.441884 * M_PI / 180.0;
    PRINT_ANGLE(obli);

    raAndDeclO(elat, elong, obli, &ra, &decl);
    printAngle(ra, "ra");
    printAngle(decl, "decl");
    
    printf("\nSection 47\n");
    cs.year = 1988;
    cs.month = 7;
    cs.day = 27;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    sunRAandDecl(ESCalendar_timeIntervalFromUTCDateComponents(&cs), &ra, &decl, currentCache);
    printAngle(ra, "ra");
    printAngle(decl, "decl");

    printf("\nSection 15\n");
    double lst = (0 + 24/60.0 + 5.23/3600.0) * M_PI / 12.0;
    PRINT_ANGLE(lst);
    double olong = - 64 * M_PI / 180.0;
    PRINT_ANGLE(olong);
    int dayO;
    double gst = convertLSTtoGST(lst, olong, &dayO);
    printAngle(gst, "gst");
    PRINT_STRING1("     ...day offset: %d\n", dayO);

    printf("\nSection 13\n");
    gst = (4 + 40/60.0 + 5.23/3600.0) * M_PI / 12.0;
    PRINT_ANGLE(gst);
    cs.year = 1980;
    cs.month = 4;
    cs.day = 22;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    double ut0_2;
    double ut0 = convertGSTtoUT(gst, ESCalendar_timeIntervalFromUTCDateComponents(&cs), &ut0_2, astroCachePool);
    printAngle(ut0, "ut");

    printf("\nMeeus Example 12.a (in reverse)\n");
    gst = (13 + 10/60.0 + 46.3668/3600.0) * M_PI / 12.0;
    PRINT_ANGLE(gst);
    cs.year = 1987;
    cs.month = 4;
    cs.day = 10;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    ut0 = convertGSTtoUT(gst, ESCalendar_timeIntervalFromUTCDateComponents(&cs), &ut0_2, astroCachePool);
    printAngle(ut0, "ut");

    printf("\nSection 4\n");
    cs.year = 1985;
    cs.month = 2;
    cs.day = 17;
    cs.hour = 6;
    cs.minute = 0;
    cs.seconds = 0;
    double jd = julianDateForDate(ESCalendar_timeIntervalFromUTCDateComponents(&cs));
    printDouble(jd, "jd");

    printf("\nSection 49\n");
    cs.era = 1;
    cs.year = 2009;
    cs.month = 3;
    cs.day = 27;
    cs.hour = 12;
    cs.minute = 0;
    cs.seconds = 0;
    ESTimeZone *estzTest = ESCalendar_initTimeZoneFromOlsonID("America/New_York");
    /*NSTimeInterval calculationDate = */ ESCalendar_timeIntervalFromLocalDateComponents(estzTest, &cs);
    estzTest = NULL;
    cs.year = 1986;
    cs.month = 3;
    cs.day = 10;
    cs.hour = 6;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval tryDateD = ESCalendar_timeIntervalFromLocalDateComponents(estzTest, &cs);
    double olat = 42.37 * M_PI/180;
    olong = -71.05 * M_PI/180;
    double riseSetOrTransit;
    NSTimeInterval riseD = planetaryRiseSetTimeRefined(tryDateD, olat, olong, true, ECPlanetSun, &riseSetOrTransit, astroCachePool);
    [self printDateD:riseD withDescription:"sunrise"];
    cs.hour = 18;
    tryDateD = ESCalendar_timeIntervalFromLocalDateComponents(estzTest, &cs);
    ESCalendar_releaseTimeZone(estzTest);
    NSTimeInterval setD = planetaryRiseSetTimeRefined(tryDateD, olat, olong, false, ECPlanetSun, &riseSetOrTransit, astroCachePool);
    [self printDateD:setD withDescription:"sunset"];

    printf("\nSection 70\n");
    cs.year = 1986;
    cs.month = 3;
    cs.day = 6;
    cs.hour = 17;  // noon Boston
    cs.minute = 0;
    cs.seconds = 0;
    olat = (42.0 + 22/60.0) * M_PI/180;
    olong = -(71 + 3/60.0) * M_PI/180;
    riseD = planetaryRiseSetTimeRefined(ESCalendar_timeIntervalFromUTCDateComponents(&cs), olat, olong, true, ECPlanetMoon, &riseSetOrTransit, astroCachePool);
    setD = planetaryRiseSetTimeRefined(ESCalendar_timeIntervalFromUTCDateComponents(&cs), olat, olong, false, ECPlanetMoon, &riseSetOrTransit, astroCachePool);
    
    printf("\nBug 1\n");
    cs.year = 2008;
    cs.month = 6;
    cs.day = 27;
    cs.hour = 23;  // 16:35 PDT
    cs.minute = 35;
    cs.seconds = 0;
    riseD = planetaryRiseSetTimeRefined(ESCalendar_timeIntervalFromUTCDateComponents(&cs), 37.32 * M_PI/180, -122.03 * M_PI/180, true, ECPlanetSun, &riseSetOrTransit, astroCachePool);
    
    printf("\nBug 2\n");
    cs.year = 2008;
    cs.month = 8;
    cs.day = 27;
    cs.hour = 3;  // 20:00 PDT
    cs.minute = 0;
    cs.seconds = 0;
    riseD = planetaryRiseSetTimeRefined(ESCalendar_timeIntervalFromUTCDateComponents(&cs), 70 * M_PI/180, -122.03 * M_PI/180, true, ECPlanetSun, &riseSetOrTransit, astroCachePool);
    
    printf("\nSection 68\n");
    cs.year = 1979;
    cs.month = 5;
    cs.day = 19;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    sunRAandDecl(ESCalendar_timeIntervalFromUTCDateComponents(&cs), &ra, &decl, currentCache);
    //printAngle(ra, "sun ra");
    //printAngle(decl, "sun decl");
    double moonRA;
    double moonDecl;
    moonRAAndDecl(ESCalendar_timeIntervalFromUTCDateComponents(&cs), &moonRA, &moonDecl, &moonEclipticLongitude, currentCache);
    printAngle(moonRA, "moon ra");
    printAngle(moonDecl, "moon decl");
    double pa = positionAngle(ra, decl, moonRA, moonDecl);
    printAngle(pa, "position angle");

    printf("\n\n");
    printingEnabled = false;
#endif
}

-(void)setupLocalEnvironmentForThreadFromActionButton:(bool)fromActionButton {
    ECAstroCachePool *poolForThisThread = getCachePoolForThisThread();
    //if (astroCachePool) {
    //printf("  ");
    //}
    //printf("astro setupLocalEnvironment, fromActionButton=%s, poolForThisThread=0x%08x, astroCachePool=0x%08x, inActionButton=%s, currentCache=0x%08x\n",
    //fromActionButton ? "true" : "false",
    //(unsigned int)poolForThisThread,
    //(unsigned int)astroCachePool,
    //inActionButton ? "true" : "false",
    //(unsigned int)currentCache);
    if (astroCachePool) {
	assert(!fromActionButton);
	assert(inActionButton);
	assert(astroCachePool->inActionButton);
	assert(astroCachePool == poolForThisThread);
	assert(estz);
	assert(currentCache);
	assert([watchTime currentTime] == calculationDateInterval);
	if (fabs(currentCache->dateInterval - calculationDateInterval) > ASTRO_SLOP) {
	    pushECAstroCacheInPool(astroCachePool, &astroCachePool->finalCache, calculationDateInterval);
	}
	assert(fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
	//printf("...exiting early\n");
	return;
    }
    astroCachePool = poolForThisThread;
#ifndef NDEBUG
    if (inActionButton) {
	assert(poolForThisThread->inActionButton);
    }
    assert(!estz);
    assert(!currentCache);
    assert(observerLatitude == 0);
    assert(observerLongitude == 0);
#endif

    calculationDateInterval = [watchTime currentTime];

    estz = ESCalendar_retainTimeZone([environment estz]);

    observerLatitude = [[environment locationManager] lastLatitudeRadians];
    //PRINT_ANGLE(observerLatitude);

    observerLongitude = [[environment locationManager] lastLongitudeRadians];
    //PRINT_ANGLE(observerLongitude);

    locationValid = [[environment locationManager] valid];

    initializeCachePool(poolForThisThread,
			calculationDateInterval,
			observerLatitude,
			observerLongitude,
			[watchTime runningBackward],
			[watchTime tzOffsetUsingEnv:environment]);

    currentCache = astroCachePool->currentCache;
    assert(currentCache);
    assert(fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);

    scratchWatchTime = [[ECWatchTime alloc] init];

    if (fromActionButton) {
	assert(!inActionButton);
	assert(!poolForThisThread->inActionButton);
	inActionButton = true;
	poolForThisThread->inActionButton = true;
    }
}

-(void)cleanupLocalEnvironmentForThreadFromActionButton:(bool)fromActionButton {
    assert(astroCachePool);
    assert(astroCachePool == getCachePoolForThisThread());
    assert(currentCache);
    //if (inActionButton && !fromActionButton) {
    //printf("  ");
    //}
    //printf("astro cleanupLocalEnvironment, fromActionButton=%s, poolForThisThread=0x%08x, astroCachePool=0x%08x, inActionButton=%s, currentCache=0x%08x\n",
    //fromActionButton ? "true" : "false",
    //(unsigned int)(getCachePoolForThisThread()),
    //(unsigned int)astroCachePool,
    //inActionButton ? "true" : "false",
    //(unsigned int)currentCache);
    if (fromActionButton) {
	assert(inActionButton);
	assert(astroCachePool->inActionButton);
	inActionButton = false;
	astroCachePool->inActionButton = false;
	releaseCachePoolForThisThread(astroCachePool);
    } else {
	if (inActionButton) {
	    assert(astroCachePool->inActionButton);
	    return;
	}
	if (!astroCachePool->inActionButton) {
	    releaseCachePoolForThisThread(astroCachePool);
	}
    }
    astroCachePool = nil;
    currentCache = nil;
    locationValid = false;
    observerLatitude = 0;
    observerLongitude = 0;
    locationValid = false;
    calculationDateInterval = 0;
    assert(estz);
    ESCalendar_releaseTimeZone(estz);
    estz = nil;
    [scratchWatchTime release];
    scratchWatchTime = nil;
}

/* In seconds */
static double
localSiderealTime(double       calculationDateInterval,
                  double       observerLongitude,
                  ECAstroCache *currentCache) {
    double ret;
    if (currentCache && currentCache->cacheSlotValidFlag[lstSlotIndex] == currentCache->currentFlag) {
	ret = calculationDateInterval - currentCache->cacheSlots[lstSlotIndex];
    } else {
	double deltaTSeconds;
	double centuriesSinceEpochTDT = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, &deltaTSeconds, currentCache);
	double priorUTMidnightD = priorUTMidnightForDateInterval(calculationDateInterval, currentCache);
	double utRadiansSinceMidnight = (calculationDateInterval - priorUTMidnightD) * M_PI/(12 * 3600);
	double gst = convertUTToGSTP03x(centuriesSinceEpochTDT, deltaTSeconds, utRadiansSinceMidnight, priorUTMidnightD);
	ret = convertGSTtoLST(gst, observerLongitude) * (12 * 3600)/M_PI + priorUTMidnightD;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[lstSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[lstSlotIndex] = calculationDateInterval - ret;
	}
    }
    return ret;
}

/* In seconds */
-(double)localSiderealTime {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    return localSiderealTime(calculationDateInterval, observerLongitude, currentCache);
}

static bool isSummer(NSTimeInterval calculationDateInterval,
		     double         observerLatitude,
		     ECAstroCache   *currentCache) {
    double rightAscension;
    double declination;
    sunRAandDecl(calculationDateInterval, &rightAscension, &declination, currentCache);	
    return (declination >= 0 && observerLatitude >= 0 ||
	    declination <  0 && observerLatitude < 0);
}

static bool moonIsSummer(NSTimeInterval calculationDateInterval,
			 double         observerLatitude,
			 ECAstroCache   *currentCache) {
    double rightAscension;
    double declination;
    double moonEclipticLongitude;
    moonRAAndDecl(calculationDateInterval, &rightAscension, &declination, &moonEclipticLongitude, currentCache);
    return (declination >= 0 && observerLatitude >= 0 ||
	    declination <  0 && observerLatitude < 0);
}

static bool planetIsSummer(NSTimeInterval calculationDateInterval,
			   double         observerLatitude,
			   int            planetNumber,
			   ECAstroCache   *currentCache) {
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
    double planetRightAscension;
    double planetDeclination;
    double planetEclipticLongitude;
    double planetEclipticLatitude;
    double planetGeocentricDistance;
    WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &planetEclipticLatitude, &planetGeocentricDistance, &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
    return (planetDeclination >= 0 && observerLatitude >= 0 ||
	    planetDeclination <  0 && observerLatitude < 0);
}

// returns 1 in summer half of the year, 0 otherwise; (the equator is considered northern)
-(bool)summer {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    bool ret = isSummer(calculationDateInterval, observerLatitude, currentCache);
    return ret;
}

// returns 1 if planet is above the equator and the observer is also, or both below
-(bool)planetIsSummer:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    bool ret = planetIsSummer(calculationDateInterval, observerLatitude, planetNumber, currentCache);
    return ret;
}

-(double)EOT {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double eot;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[eotSlotIndex] == currentCache->currentFlag) {
	eot = currentCache->cacheSlots[eotSlotIndex];
    } else {
	eot = EOT(calculationDateInterval, astroCachePool);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[eotSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[eotSlotIndex] = eot;
	}
    }
    return eot;
}

static double fudgeFactorSeconds = 5;  // enough so refined closest is behind us

// compiler work around:
static NSTimeInterval (*ECsaveCalculationMethod)(NSTimeInterval calculationDate, double observerLatitude, double observerLongitude, bool riseNotSet, int planetNumber, double *riseSetOrTransit, ECAstroCachePool *cachePool) = NULL;

-(NSTimeInterval)nextPrevRiseSetInternalWithFudgeInterval:(double)fudgeSeconds
					calculationMethod:(NSTimeInterval (*)(NSTimeInterval calculationDate,
									      double 	     observerLatitude,
									      double 	     observerLongitude,
									      bool 	     riseNotSet,
									      int            planetNumber,
									      NSTimeInterval *riseSetOrTransit,
									      ECAstroCachePool *cachePool)) calculationMethod
					     planetNumber:(int)planetNumber
					       riseNotSet:(bool)riseNotSet
						   isNext:(bool)isNext
						lookahead:(NSTimeInterval)lookahead
					 riseSetOrTransit:(NSTimeInterval *)riseSetOrTransit
{
    // work around apparent compiler bug
    ECsaveCalculationMethod = calculationMethod;

    // strategy: Pick closest time.  If it's ahead of us, we're done.
    //    otherwise look ahead and pick closest.
    if (!isNext) {
	fudgeSeconds = -fudgeSeconds;
	lookahead = -lookahead;
    }
    //[self printDateD:calculationDateInterval withDescription:(isNext ? "NEXT starting with date here" : "PREV starting with date here")];
    NSTimeInterval fudgeDate = calculationDateInterval + fudgeSeconds;
    //[self printDateD:fudgeDate withDescription:"fudging to here"];
    NSTimeInterval returnDate = (*calculationMethod)(fudgeDate, observerLatitude, observerLongitude, riseNotSet, planetNumber, riseSetOrTransit, astroCachePool);
    assert(!isnan(*riseSetOrTransit));
    if (isNext
	? *riseSetOrTransit >= fudgeDate
	: *riseSetOrTransit < fudgeDate) {
	//if (isnan(returnDate)) {
	//    printAngle(returnDate, "nextPrev initial success same day");
	//} else {
	//    [self printDateD:returnDate withDescription:"nextPrev initial success same day"];
	//}
	return returnDate;
    }
    //[self printDateD:returnDate withDescription:"nextPrev initial failure different day"];

    NSTimeInterval tryDate = fudgeDate + lookahead;
    //[self printDateD:tryDate withDescription:"...so looking ahead from here"];
    calculationMethod = ECsaveCalculationMethod;  // work around apparent compiler bug
    returnDate = (*calculationMethod)(tryDate, observerLatitude, observerLongitude, riseNotSet, planetNumber, riseSetOrTransit, astroCachePool);
    //if (isnan(returnDate)) {
    //	printAngle(returnDate, "...... to get here");
    //} else {
    //	[self printDateD:returnDate withDescription:"...... to get here"];
    //}
    return returnDate;
}

-(NSTimeInterval)nextPrevPlanetRiseSetForPlanet:(int)planetNumber
				     riseNotSet:(bool)riseNotSet
				    nextNotPrev:(bool)nextNotPrev {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval returnDate;
    if (!locationValid) {
	returnDate = nan("");
    } else {
	assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
	int slotIndexBase;
	if (riseNotSet) {
	    if (nextNotPrev) {
		slotIndexBase = nextPlanetriseSlotIndex;
	    } else {
		slotIndexBase = prevPlanetriseSlotIndex;
	    }
	} else {
	    if (nextNotPrev) {
		slotIndexBase = nextPlanetsetSlotIndex;
	    } else {
		slotIndexBase = prevPlanetsetSlotIndex;
	    }
	}
	if (currentCache && currentCache->cacheSlotValidFlag[slotIndexBase+planetNumber] == currentCache->currentFlag) {
	    returnDate = currentCache->cacheSlots[slotIndexBase+planetNumber];
	} else {
	    double riseSetOrTransit;
	    returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:fudgeFactorSeconds
						      calculationMethod:planetaryRiseSetTimeRefined
							   planetNumber:planetNumber
							     riseNotSet:riseNotSet
								 isNext:([environment runningBackward] ^ nextNotPrev)
							      lookahead:(3600 * 13.2)
						       riseSetOrTransit:&riseSetOrTransit];
	    PRINT_DATE_VIRT_LT(returnDate);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[slotIndexBase+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[slotIndexBase+planetNumber] = returnDate;
	    }
	}
    }
    return returnDate;
}

-(NSTimeInterval)nextSunrise {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetSun riseNotSet:true nextNotPrev:true];
}

-(NSTimeInterval)nextSunset {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetSun riseNotSet:false nextNotPrev:true];
}

-(NSTimeInterval)prevSunrise {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetSun riseNotSet:true nextNotPrev:false];
}

-(NSTimeInterval)prevSunset {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetSun riseNotSet:false nextNotPrev:false];
}

-(NSTimeInterval)nextMoonrise {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetMoon riseNotSet:true nextNotPrev:true];
}

-(NSTimeInterval)nextMoonset {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetMoon riseNotSet:false nextNotPrev:true];
}

-(NSTimeInterval)prevMoonrise {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetMoon riseNotSet:true nextNotPrev:false];
}

-(NSTimeInterval)prevMoonset {
    return [self nextPrevPlanetRiseSetForPlanet:ECPlanetMoon riseNotSet:false nextNotPrev:false];
}

-(NSTimeInterval)nextPlanetriseForPlanetNumber:(int)planetNumber {
    return [self nextPrevPlanetRiseSetForPlanet:planetNumber riseNotSet:true nextNotPrev:true];
}

-(NSTimeInterval)nextPlanetsetForPlanetNumber:(int)planetNumber {
    return [self nextPrevPlanetRiseSetForPlanet:planetNumber riseNotSet:false nextNotPrev:true];
}

-(NSTimeInterval)prevPlanetriseForPlanetNumber:(int)planetNumber {
    return [self nextPrevPlanetRiseSetForPlanet:planetNumber riseNotSet:true nextNotPrev:false];
}

-(NSTimeInterval)prevPlanetsetForPlanetNumber:(int)planetNumber {
    return [self nextPrevPlanetRiseSetForPlanet:planetNumber riseNotSet:false nextNotPrev:false];
}

-(NSTimeInterval)nextOrMidnightForDateInterval:(NSTimeInterval)opDate {
    ESTimeZone *estzHere = [environment estz];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([watchTime currentTime], estzHere, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval nextMidnightD = ESCalendar_timeIntervalFromLocalDateComponents(estzHere, &cs);
    if ([environment runningBackward]) {
	if (opDate < nextMidnightD) {
	    return nextMidnightD;
	}
    } else {
	nextMidnightD = ESCalendar_addDaysToTimeInterval(nextMidnightD, estzHere, 1);
	if (opDate > nextMidnightD) {
	    return nextMidnightD;
	}
    }
    return opDate;
}

// Note:  Returns internal storage
-(ECWatchTime *)watchTimeForInterval:(NSTimeInterval)dateInterval {
    assert(scratchWatchTime);
    [scratchWatchTime setToFrozenDateInterval:dateInterval];
    return scratchWatchTime;
}

-(NSTimeInterval)planetRiseSetForDay:(int)planetNumber riseNotSet:(bool)riseNotSet {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval returnDate;
    if (!locationValid) {
	return nan("");
    }
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    int slotIndexBase = riseNotSet ? planetriseForDaySlotIndex : planetsetForDaySlotIndex;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndexBase+planetNumber] == currentCache->currentFlag) {
	returnDate = currentCache->cacheSlots[slotIndexBase+planetNumber];
    } else {
	NSTimeInterval riseSetOrTransit;
	returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:-fudgeFactorSeconds
						  calculationMethod:planetaryRiseSetTimeRefined
						       planetNumber:planetNumber
							 riseNotSet:riseNotSet
							     isNext:true
							  lookahead:(3600*13.2)
						   riseSetOrTransit:&riseSetOrTransit];
	if (!timesAreOnSameDay(riseSetOrTransit, calculationDateInterval, estz)) {
	    returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:-fudgeFactorSeconds
						      calculationMethod:planetaryRiseSetTimeRefined
							   planetNumber:planetNumber
							     riseNotSet:riseNotSet
								 isNext:false
							      lookahead:(3600*13.2)
						       riseSetOrTransit:&riseSetOrTransit];
	    if (!isnan(returnDate) && !timesAreOnSameDay(returnDate, calculationDateInterval, estz)) {
		returnDate = nan("");
	    }
	}
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndexBase+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndexBase+planetNumber] = returnDate;
	}
    }
    PRINT_DATE_VIRT_LT(returnDate);
#if 0    
    if (false && planetNumber == ECPlanetMoon && !riseNotSet && !isnan(returnDate)) {
	printf("\nMoonset at %s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:returnDate] description] UTF8String]);
	ECWatchTime *saveTime = [[ECWatchTime alloc] initWithFrozenDateInterval:[watchTime currentTime] andCalendar:ltCalendar];
	[saveTime makeTimeIdenticalToOtherTimer:watchTime];
	bool savePrintingEnabled = printingEnabled;
	printingEnabled = true;
	for (int i = -20; i <= 20; i += 1) {
	    double t = returnDate + i;
	    [self cleanupLocalEnvironmentForThreadFromActionButton:false];
	    [watchTime unlatchTime];
	    [watchTime setToFrozenDateInterval:t];
	    [watchTime latchTimeForBeatsPerSecond:0];
	    [self setupLocalEnvironmentForThreadFromActionButton:false];
	    bool isUp = [self planetIsUp:planetNumber];
	    printf("  %4d: %s %s\n", i, isUp ? "up" : "not up", [[[NSDate dateWithTimeIntervalSinceReferenceDate:calculationDateInterval] description] UTF8String]);
	}
	printingEnabled = savePrintingEnabled;
	[self cleanupLocalEnvironmentForThreadFromActionButton:false];
	[watchTime unlatchTime];
	[watchTime makeTimeIdenticalToOtherTimer:saveTime];
	[watchTime latchTimeForBeatsPerSecond:0];
	[self setupLocalEnvironmentForThreadFromActionButton:false];
	[saveTime release];
    }
#endif
    return returnDate;
}

-(NSTimeInterval)sunriseForDay {
    double t = [self planetRiseSetForDay:ECPlanetSun riseNotSet:true];
    return t;
}

-(NSTimeInterval)sunsetForDay {
    return [self planetRiseSetForDay:ECPlanetSun riseNotSet:false];
}

-(NSTimeInterval)moonriseForDay {
    return [self planetRiseSetForDay:ECPlanetMoon riseNotSet:true];
}

-(NSTimeInterval)moonsetForDay {
    return [self planetRiseSetForDay:ECPlanetMoon riseNotSet:false];
}

-(NSTimeInterval)planetriseForDay:(int)planetNumber {
    return [self planetRiseSetForDay:planetNumber riseNotSet:true];
}
 
-(NSTimeInterval)planetsetForDay:(int)planetNumber {
    return [self planetRiseSetForDay:planetNumber riseNotSet:false];
}
 
-(NSTimeInterval)planettransitForDay:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval returnDate;
    if (!locationValid) {
	PRINT_STRING("planettransitForDay returns nil\n");
	//printf("planettransitForDay returns nil\n");
	returnDate = nan("");
    } else {
	assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
	if (currentCache && currentCache->cacheSlotValidFlag[planettransitForDaySlotIndex+planetNumber] == currentCache->currentFlag) {
	    returnDate = currentCache->cacheSlots[planettransitForDaySlotIndex+planetNumber];
	} else {
	    NSTimeInterval riseSetOrTransit;
	    returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:-fudgeFactorSeconds
						      calculationMethod:planettransitTimeRefined
							   planetNumber:planetNumber
							     riseNotSet:true // Means return high transit
								 isNext:true
							      lookahead:(3600*13.2)
						       riseSetOrTransit:&riseSetOrTransit];
	    assert(!isnan(returnDate));
	    assert(riseSetOrTransit == returnDate);
	    if (!timesAreOnSameDay(returnDate, calculationDateInterval, estz)) {
		returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:-fudgeFactorSeconds
							  calculationMethod:planettransitTimeRefined
							       planetNumber:planetNumber
								 riseNotSet:true // Means return high transit
								     isNext:false
								  lookahead:(3600*13.2)
							   riseSetOrTransit:&riseSetOrTransit];
		assert(!isnan(returnDate));
		assert(riseSetOrTransit == returnDate);
		if (!timesAreOnSameDay(returnDate, calculationDateInterval, estz)) {
		    returnDate = nan("");
		}
	    }
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[planettransitForDaySlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[planettransitForDaySlotIndex+planetNumber] = returnDate;
	    }
	}
    }
    PRINT_DATE_VIRT_LT(returnDate);
    //printf("planettransit for day: %s\n", [[returnDate description] UTF8String]);
    return returnDate;
}

-(NSTimeInterval)suntransitForDay {
    return [self planettransitForDay:ECPlanetSun];
}

-(NSTimeInterval)moontransitForDay {
    return [self planettransitForDay:ECPlanetMoon];
}

-(NSTimeInterval)nextPrevPlanettransit:(int)planetNumber nextNotPrev:(bool)nextNotPrev {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval returnDate;
    if (!locationValid) {
	PRINT_STRING("nextPlanettransit returns nil\n");
	returnDate = nan("");
    } else {
	assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
	int slotIndex = (nextNotPrev ? nextPlanettransitSlotIndex : prevPlanettransitSlotIndex) + planetNumber;
	if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	    returnDate = currentCache->cacheSlots[slotIndex];
	} else {
	    NSTimeInterval riseSetOrTransit;
	    if ([environment runningBackward]) {
		returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:fudgeFactorSeconds
							  calculationMethod:planettransitTimeRefined
							       planetNumber:planetNumber
								 riseNotSet:true  // Means return high transit
								     isNext:!nextNotPrev
								  lookahead:(3600 * 13.2)
							   riseSetOrTransit:&riseSetOrTransit];
	    } else {
		returnDate = [self nextPrevRiseSetInternalWithFudgeInterval:fudgeFactorSeconds
							  calculationMethod:planettransitTimeRefined
							       planetNumber:planetNumber
								 riseNotSet:true  // Means return high transit
								     isNext:nextNotPrev
								  lookahead:(3600 * 13.2)
							   riseSetOrTransit:&riseSetOrTransit];
	    }	
	    assert(returnDate == riseSetOrTransit);
	    PRINT_DATE_VIRT_LT(returnDate);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
		currentCache->cacheSlots[slotIndex] = returnDate;
	    }
	}
    }
    return returnDate;
}

-(NSTimeInterval)nextSuntransit {
    return [self nextPrevPlanettransit:ECPlanetSun nextNotPrev:true];
}

-(NSTimeInterval)nextMoontransit {
    return [self nextPrevPlanettransit:ECPlanetMoon nextNotPrev:true];
}

-(NSTimeInterval)nextPlanettransit:(int)planetNumber {
    return [self nextPrevPlanettransit:planetNumber nextNotPrev:true];
}

-(NSTimeInterval)prevPlanettransit:(int)planetNumber {
    return [self nextPrevPlanettransit:planetNumber nextNotPrev:true];
}

-(NSTimeInterval)nextSunriseOrMidnight {
    return [self nextOrMidnightForDateInterval:[self nextSunrise]];
}

-(NSTimeInterval)nextSunsetOrMidnight {
    return [self nextOrMidnightForDateInterval:[self nextSunset]];
}

-(NSTimeInterval)nextMoonriseOrMidnight {
    return [self nextOrMidnightForDateInterval:[self nextMoonrise]];
}

-(NSTimeInterval)nextMoonsetOrMidnight {
    return [self nextOrMidnightForDateInterval:[self nextMoonset]];
}

-(double)planetHeliocentricLongitude:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    if (planetNumber < ECFirstActualPlanet || planetNumber > ECLastLegalPlanet) {
	return nan("");
    } else if (!locationValid) {
	return nan("");
    }
    double longitude;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetHeliocentricLongitudeSlotIndex+planetNumber] == currentCache->currentFlag) {
	longitude = currentCache->cacheSlots[planetHeliocentricLongitudeSlotIndex+planetNumber];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	longitude = WB_planetHeliocentricLongitude(planetNumber, julianCenturiesSince2000Epoch/100, currentCache);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetHeliocentricLongitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetHeliocentricLongitudeSlotIndex+planetNumber] = longitude;
	}
    }
    return longitude;
}

-(double)planetHeliocentricLatitude:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    if (planetNumber < ECFirstActualPlanet || planetNumber > ECLastLegalPlanet) {
	return nan("");
    } else if (!locationValid) {
	return nan("");
    }
    double latitude;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetHeliocentricLatitudeSlotIndex+planetNumber] == currentCache->currentFlag) {
	latitude = currentCache->cacheSlots[planetHeliocentricLatitudeSlotIndex+planetNumber];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	latitude = WB_planetHeliocentricLatitude(planetNumber, julianCenturiesSince2000Epoch/100, currentCache);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetHeliocentricLatitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetHeliocentricLatitudeSlotIndex+planetNumber] = latitude;
	}
    }
    return latitude;
}

-(double)planetHeliocentricRadius:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    if (planetNumber < ECFirstActualPlanet || planetNumber > ECLastLegalPlanet) {
	return nan("");
    } else if (!locationValid) {
	return nan("");
    }
    double radius;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetHeliocentricRadiusSlotIndex+planetNumber] == currentCache->currentFlag) {
	radius = currentCache->cacheSlots[planetHeliocentricRadiusSlotIndex+planetNumber];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	radius = WB_planetHeliocentricRadius(planetNumber, julianCenturiesSince2000Epoch/100, currentCache);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetHeliocentricRadiusSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetHeliocentricRadiusSlotIndex+planetNumber] = radius;
	}
    }
    return radius;
}

-(NSString *)moonPhaseString {
    double age;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double phase;
    age = moonAge(calculationDateInterval, &phase, currentCache) * 180/M_PI;
    if (age >= 359 || age <= 1) {
	return @"New";
    } else if (age < 89) {
	return @"Waxing Crescent";
    } else if (age <= 91) {
	return @"1st Quarter";
    } else if (age < 179) {
	return @"Waxing Gibbous";
    } else if (age <= 181) {
	return @"Full";
    } else if (age < 269) {
	return @"Waning Gibbous";
    } else if (age <= 271) {
	return @"3rd Quarter";
    } else {
	return @"Waning Crescent";
    }
}

-(double)moonAgeAngle {
    double age;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double phase;
    age = moonAge(calculationDateInterval, &phase, currentCache);
    return age;
}

-(double)planetMoonAgeAngle:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double phase;
    double moonAge;
    [self planetAge:planetNumber planetMoonAgeReturn:&moonAge phaseReturn:&phase];  // Ignore return 'age'
    return moonAge;
}

-(NSTimeInterval)nextMoonPhase {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[nextMoonPhaseSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[nextMoonPhaseSlotIndex];
    } else {
	double phase;
	double age = moonAge(calculationDateInterval, &phase, currentCache);
	bool runningBackward = [environment runningBackward];
	double fudgeFactor = runningBackward ? -0.01 : 0.01;
	double ageSinceQuarter = EC_fmod(age + fudgeFactor, M_PI/2);  // now age is age angle since nearest exact phase (new, 1st quarter, full, 3rd quarter)
	double ageAtLastQuarter = age + fudgeFactor - ageSinceQuarter;
	double targetAge = runningBackward ? ageAtLastQuarter : ageAtLastQuarter + M_PI/2;
	if (targetAge > 15.0/8 * M_PI) {
	    targetAge -= (M_PI * 2);
	}
	nextOne = refineMoonAgeTargetForDate(calculationDateInterval, targetAge, astroCachePool);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[nextMoonPhaseSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[nextMoonPhaseSlotIndex] = nextOne;
	}
    }
//    printf("next moon phase: %s (%.2f)\n\n", [[nextOne description] UTF8String], targetAge / (M_PI * 2));
    return nextOne;
}

-(double)realMoonAgeAngle {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double ageAngle;
    NSTimeInterval newMoonDate;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[realMoonAgeAngleSlotIndex] == currentCache->currentFlag) {
	ageAngle = currentCache->cacheSlots[realMoonAgeAngleSlotIndex];
    } else {
	double phase;
	ageAngle = moonAge(calculationDateInterval, &phase, currentCache);
	if (ageAngle > (M_PI * 2)-0.0001) {
	    ageAngle = 0;
	}
	NSTimeInterval guessDate = calculationDateInterval - kECLunarCycleInSeconds * ageAngle/(M_PI * 2);
	newMoonDate = refineMoonAgeTargetForDate(guessDate, 0, astroCachePool);
	ageAngle = (calculationDateInterval - newMoonDate)/86400;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[realMoonAgeAngleSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[realMoonAgeAngleSlotIndex] = ageAngle;
	}
    }
    // printf("%8.2f since new at %s\n", ageAngle, [[[NSDate dateWithTimeIntervalSinceReferenceDate:newMoonDate] description] UTF8String]);
    return ageAngle;
}

-(NSTimeInterval)closestQuarterAngle:(double)quarterAngle {
    double phase;
    double age = moonAge(calculationDateInterval, &phase, currentCache);
    double ageSinceQuarter = EC_fmod(age - quarterAngle, (M_PI * 2));
    bool closestIsBack =
    [environment runningBackward]
    ? ageSinceQuarter < M_PI + 0.01
    : ageSinceQuarter < M_PI - 0.01;
    NSTimeInterval guessDate =
    closestIsBack
    ? calculationDateInterval - kECLunarCycleInSeconds * ageSinceQuarter/(M_PI * 2)
    : calculationDateInterval + kECLunarCycleInSeconds * ((M_PI * 2) - ageSinceQuarter)/(M_PI * 2);
    return refineMoonAgeTargetForDate(guessDate, quarterAngle, astroCachePool);
}

-(NSTimeInterval)closestNewMoon {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[closestNewMoonSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[closestNewMoonSlotIndex];
    } else {
	nextOne = [self closestQuarterAngle:0];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[closestNewMoonSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[closestNewMoonSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)closestFullMoon {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[closestFullMoonSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[closestFullMoonSlotIndex];
    } else {
	nextOne = [self closestQuarterAngle:M_PI];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[closestFullMoonSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[closestFullMoonSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)closestFirstQuarter {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[closestFirstQuarterSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[closestFirstQuarterSlotIndex];
    } else {
	nextOne = [self closestQuarterAngle:(M_PI/2)];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[closestFirstQuarterSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[closestFirstQuarterSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)closestThirdQuarter {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[closestThirdQuarterSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[closestThirdQuarterSlotIndex];
    } else {
	nextOne = [self closestQuarterAngle:(3*M_PI/2)];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[closestThirdQuarterSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[closestThirdQuarterSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)nextQuarterAngle:(double)quarterAngle {
    double phase;
    double age = moonAge(calculationDateInterval, &phase, currentCache);
    if ([environment runningBackward]) {
	age -= 0.01;  // in case we're right on the same quarter
    } else {
	age += 0.01;
    }
    double ageSinceQuarter = EC_fmod(age - quarterAngle, (M_PI * 2));
    NSTimeInterval guessDate;
    if ([environment runningBackward]) {
	guessDate = calculationDateInterval - kECLunarCycleInSeconds * ageSinceQuarter/(M_PI * 2);
    } else {
	guessDate = calculationDateInterval + kECLunarCycleInSeconds * ((M_PI * 2) - ageSinceQuarter)/(M_PI * 2);
    }
    return refineMoonAgeTargetForDate(guessDate, quarterAngle, astroCachePool);
}

-(NSTimeInterval)nextNewMoon {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[nextNewMoonSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[nextNewMoonSlotIndex];
    } else {
	nextOne = [self nextQuarterAngle:0];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[nextNewMoonSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[nextNewMoonSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)nextFullMoon {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[nextFullMoonSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[nextFullMoonSlotIndex];
    } else {
	nextOne = [self nextQuarterAngle:M_PI];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[nextFullMoonSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[nextFullMoonSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)nextFirstQuarter {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[nextFirstQuarterSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[nextFirstQuarterSlotIndex];
    } else {
	nextOne = [self nextQuarterAngle:(M_PI/2)];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[nextFirstQuarterSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[nextFirstQuarterSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(NSTimeInterval)nextThirdQuarter {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval nextOne;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[nextThirdQuarterSlotIndex] == currentCache->currentFlag) {
	nextOne = currentCache->cacheSlots[nextThirdQuarterSlotIndex];
    } else {
	nextOne = [self nextQuarterAngle:(3*M_PI/2)];
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[nextThirdQuarterSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[nextThirdQuarterSlotIndex] = nextOne;
	}
    }
    return nextOne;
}

-(double)planetAge:(int)planetNumber planetMoonAgeReturn:(double *)moonAge phaseReturn:(double *)phase {
    // The phase of a planet is the angle  Sun -> object -> Earth.
    double planet_r = [self planetHeliocentricRadius:planetNumber];  // Distance from Sun to planet
    double planet_delta = [self planetGeocentricDistance:planetNumber];  // Distance from Earth to planet
    double planet_R = [self planetHeliocentricRadius:ECPlanetEarth];  // Distance from Earth to Sun
    // Solving for an angle in a triangle where we know the lengths of the three sides:
    double cos_i = ((planet_r*planet_r) + (planet_delta*planet_delta) - (planet_R*planet_R)) / (2 * planet_r * planet_delta);
    *phase = acos(cos_i);

    // Here be hacks galore.

    // First, we shouldn't be using 'age' at all in our terminator, but we are.  The terminator is strictly based on
    // the phase, not the age.  (The "phase" is the angle Sun-Moon-Earth, and the "age" is delta ecliptic longitude of
    // the Sun and the Moon, which is roughly the angle Sun-Earth-Moon.  The phase controls the shadow, and the only
    // reason the age could be a proxy for the phase is that the age is essentially the complement of the phase in this
    // triangle, since the Moon-Sun-Earth angle is nearly zero).  So even though we've correctly calculated the phase
    // above, we can't use it in the terminator, because the terminator (improperly) wants the age, assuming the age works
    // as with the Moon.

    // So we figure out what Moon age would generate the phase we calcualte above, and then return that.  That's simply the
    // complement, as I said above, subject to sign variations (since we only have the absolute phase value).

    *moonAge = M_PI - *phase;  // The complement of the phase.
    // EC_printAngle(*moonAge, "moonAge");

    // NOTE: Sometimes we actually want the "age" of the object itself, via the delta ecliptic longitudes, or just
    // figure out the appropriate angle in the same triangle (Sun-Earth-Moon):
    cos_i = ((planet_R*planet_R) + (planet_delta*planet_delta) - (planet_r*planet_r)) / (2 * planet_delta * planet_R);
    double age = acos(cos_i);

    // EC_printAngle(age, "age");

    // But age can be negative rather than positive, and the way we calculate it, we only have the absolute value
    // (since it's based on only the sizes of the sides of a triangle).  To distinguish the two cases (+ and -) we need
    // to analyze the relative heliocentric longitudes:
    double deltaHeliocentricLongitude = [self planetHeliocentricLongitude:planetNumber] - [self planetHeliocentricLongitude:ECPlanetEarth];
    if (deltaHeliocentricLongitude < 0) {
        deltaHeliocentricLongitude += 2 * M_PI;
    }
    // EC_printAngle(deltaHeliocentricLongitude, "deltaHeliocentricLongitude");
    if (deltaHeliocentricLongitude > M_PI) {
        age = 2 * M_PI - age;
        *moonAge = 2 * M_PI - *moonAge;
    }
    // EC_printAngle(age, "age with sign");
    // EC_printAngle(*moonAge, "moonAge with sign");
    return age;
}

-(double)planetPositionAngle:(int)planetNumber {  // rotation of terminator relative to North (std defn)
    double sunRightAscension;
    double sunDeclination;
    sunRAandDecl(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
    double planetRightAscension = [self planetRA:planetNumber correctForParallax:false];
    double planetDeclination = [self planetDecl:planetNumber correctForParallax:false];
    return positionAngle(sunRightAscension, sunDeclination, planetRightAscension, planetDeclination);
}

-(double)planetRelativePositionAngle:(int)planetNumber {  // rotation of terminator as it appears in the sky
    double angle;
    double sunRightAscension;
    double sunDeclination;
    sunRAandDecl(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
    double planetRightAscension = [self planetRA:planetNumber correctForParallax:false];
    double planetDeclination = [self planetDecl:planetNumber correctForParallax:false];
    double posAngle = positionAngle(sunRightAscension, sunDeclination, planetRightAscension, planetDeclination);
    double phase;
    double moonAge;
    [self planetAge:planetNumber planetMoonAgeReturn:&moonAge phaseReturn:&phase];
    if (moonAge > M_PI) { // bright limb on the left, sense of posAngle is reversed by 180
        if (posAngle > M_PI) {
            posAngle -= M_PI;
        } else {
            posAngle += M_PI;
        }
    }
    double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
    double lst = convertGSTtoLST(gst, observerLongitude);
    double planetHourAngle = lst - planetRightAscension;
    double sinAlt = sin(planetDeclination)*sin(observerLatitude) + cos(planetDeclination)*cos(observerLatitude)*cos(planetHourAngle);
    double planetAzimuth = atan2(-cos(planetDeclination)*cos(observerLatitude)*sin(planetHourAngle), sin(planetDeclination) - sin(observerLatitude)*sinAlt);
    double planetAltitude = asin(sinAlt);
    double northAngle = northAngleForObject(planetAltitude, planetAzimuth, observerLatitude);
    angle = -northAngle - posAngle - M_PI/2;
    if (angle < 0) {
        angle += (M_PI * 2);
    } else if (angle > (M_PI * 2)) {
        angle -= (M_PI * 2);
    }
    return angle;
}

-(double)moonPositionAngle {  // rotation of terminator relative to North (std defn)
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonPositionAngleSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonPositionAngleSlotIndex];
    } else {
	double sunRightAscension;
	double sunDeclination;
	sunRAandDecl(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
	double moonRightAscension;
	double moonDeclination;
	double moonEclipticLongitude;
	moonRAAndDecl(calculationDateInterval, &moonRightAscension, &moonDeclination, &moonEclipticLongitude, currentCache);
	angle = positionAngle(sunRightAscension, sunDeclination, moonRightAscension, moonDeclination);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonPositionAngleSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonPositionAngleSlotIndex] = angle;
	}
    }
    return angle;
}

-(double)moonRelativePositionAngle {  // rotation of terminator as it appears in the sky
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonRelativePositionAngleSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonRelativePositionAngleSlotIndex];
    } else {
	double sunRightAscension;
	double sunDeclination;
	sunRAandDecl(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
	double moonRightAscension;
	double moonDeclination;
	double moonEclipticLongitude;
	moonRAAndDecl(calculationDateInterval, &moonRightAscension, &moonDeclination, &moonEclipticLongitude, currentCache);
	double posAngle = positionAngle(sunRightAscension, sunDeclination, moonRightAscension, moonDeclination);
	double phase;
	double moonAgeAngle = moonAge(calculationDateInterval, &phase, currentCache);
	if (moonAgeAngle > M_PI) { // bright limb on the left, sense of posAngle is reversed by 180
	    if (posAngle > M_PI) {
		posAngle -= M_PI;
	    } else {
		posAngle += M_PI;
	    }
	}
	double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
	double lst = convertGSTtoLST(gst, observerLongitude);
	double moonHourAngle = lst - moonRightAscension;
	double sinAlt = sin(moonDeclination)*sin(observerLatitude) + cos(moonDeclination)*cos(observerLatitude)*cos(moonHourAngle);
	double moonAzimuth = atan2(-cos(moonDeclination)*cos(observerLatitude)*sin(moonHourAngle), sin(moonDeclination) - sin(observerLatitude)*sinAlt);
	double moonAltitude = asin(sinAlt);
	double northAngle = northAngleForObject(moonAltitude, moonAzimuth, observerLatitude);
	angle = -northAngle - posAngle - M_PI/2;
	if (angle < 0) {
	    angle += (M_PI * 2);
	} else if (angle > (M_PI * 2)) {
	    angle -= (M_PI * 2);
	}
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonRelativePositionAngleSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonRelativePositionAngleSlotIndex] = angle;
	}
    }
    return angle;
}

- (double)moonRelativeAngle { // rotation of moon image as it appears in the sky
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonRelativeAngleSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonRelativeAngleSlotIndex];
    } else {
	double moonRightAscension;
	double moonDeclination;
	double moonEclipticLongitude;
	moonRAAndDecl(calculationDateInterval, &moonRightAscension, &moonDeclination, &moonEclipticLongitude, currentCache);
	double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
	double lst = convertGSTtoLST(gst, observerLongitude);
	double moonHourAngle = lst - moonRightAscension;
	double sinAlt = sin(moonDeclination)*sin(observerLatitude) + cos(moonDeclination)*cos(observerLatitude)*cos(moonHourAngle);
	double moonAzimuth = atan2(-cos(moonDeclination)*cos(observerLatitude)*sin(moonHourAngle), sin(moonDeclination) - sin(observerLatitude)*sinAlt);
	double moonAltitude = asin(sinAlt);
	double northAngle = northAngleForObject(moonAltitude, moonAzimuth, observerLatitude);

	// Approximate:
	double apparentGeocentricLongitude = moonRightAscension - gst;
	double apparentGeocentricLatitude = moonDeclination;

	// Meeus p373, "Position Angle of Axis"
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	double eclipticTrueObliquity = generalObliquity(julianCenturiesSince2000Epoch);
	double longitudeOfAscendingNode = WB_MoonAscendingNodeLongitude(julianCenturiesSince2000Epoch, currentCache);  // FIX: Add cache, although WB already caches it
	double W = apparentGeocentricLongitude - longitudeOfAscendingNode;
	double b = asin(-sin(W)*cos(apparentGeocentricLatitude)*kECsinMoonEquatorEclipticAngle - sin(apparentGeocentricLatitude) * kECcosMoonEquatorEclipticAngle);
	// Ignore physical librarions, for now (Meeus p 373, rho and sigma)
	double V = longitudeOfAscendingNode;
	double X = kECsinMoonEquatorEclipticAngle * sin(V);
	double Y = kECsinMoonEquatorEclipticAngle * cos(V) * cos(eclipticTrueObliquity) - kECcosMoonEquatorEclipticAngle * sin(eclipticTrueObliquity);
	double omega = atan2(X, Y);
	double sinP = sqrt(X * X + Y * Y) * cos(moonRightAscension - omega) / cos(b);
	double posAngle = asin(sinP);
#if 0
	printingEnabled = true;
	printAngle(posAngle, "posAngle");
	printingEnabled = false;
#endif
	angle = -northAngle - posAngle/* - M_PI/2*/;
	if (angle < 0) {
	    angle += (M_PI * 2);
	} else if (angle > (M_PI * 2)) {
	    angle -= (M_PI * 2);
	}
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonRelativeAngleSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonRelativeAngleSlotIndex] = angle;
	}
    }
    return angle;
}

-(double)sunRA {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunRASlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[sunRASlotIndex];
    } else {
	double sunRightAscension;
	double sunDeclination;
	sunRAandDecl(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
	angle = sunRightAscension;
    }
    return angle;
}
-(double)sunRAJ2000 {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunRAJ2000SlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[sunRAJ2000SlotIndex];
    } else {
	double sunRightAscension;
	double sunDeclination;
	sunRAandDeclJ2000(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
	angle = sunRightAscension;
    }
    return angle;
}
-(double)sunDecl {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunDeclSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[sunDeclSlotIndex];
    } else {
	double sunRightAscension;
	double sunDeclination;
	sunRAandDecl(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
	angle = sunDeclination;
    }
    return angle;
}
-(double)sunDeclJ2000 {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[sunDeclSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[sunDeclSlotIndex];
    } else {
	double sunRightAscension;
	double sunDeclination;
	sunRAandDeclJ2000(calculationDateInterval, &sunRightAscension, &sunDeclination, currentCache);
	angle = sunDeclination;
    }
    return angle;
}
-(double)moonRA {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonRASlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonRASlotIndex];
    } else {
	double moonRightAscension;
	double moonDeclination;
	double moonEclipticLongitude;
	moonRAAndDecl(calculationDateInterval, &moonRightAscension, &moonDeclination, &moonEclipticLongitude, currentCache);
 	angle = moonRightAscension;
    }
    return angle;
}
-(double)moonRAJ2000 {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonRASlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonRASlotIndex];
    } else {
	double moonRightAscension;
	double moonDeclination;
	moonRAandDeclJ2000(calculationDateInterval, &moonRightAscension, &moonDeclination, currentCache);
 	angle = moonRightAscension;
    }
    return angle;
}
-(double)moonDecl {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonDeclSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonDeclSlotIndex];
    } else {
	double moonRightAscension;
	double moonDeclination;
	double moonEclipticLongitude;
	moonRAAndDecl(calculationDateInterval, &moonRightAscension, &moonDeclination, &moonEclipticLongitude, currentCache);
 	angle = moonDeclination;
    }
    return angle;
}
-(double)moonDeclJ2000 {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonDeclSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[moonDeclSlotIndex];
    } else {
	double moonRightAscension;
	double moonDeclination;
	moonRAandDeclJ2000(calculationDateInterval, &moonRightAscension, &moonDeclination, currentCache);
 	angle = moonDeclination;
    }
    return angle;
}

// Note: planetAzimuth and planetAltitude correct for topocentric parallax.  For inner planets it improves the error in azimuth by a factor of 3 or so, by removing the topocentric error of approx half an arcsecond
-(double)planetAltitude:(int)planetNumber {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double angle = planetAltAz(planetNumber, calculationDateInterval, observerLatitude, observerLongitude, true/*correctForParallax*/, true/*altNotAz*/, currentCache);
    return angle;
}
-(double)planetAzimuth:(int)planetNumber {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double angle = planetAltAz(planetNumber, calculationDateInterval, observerLatitude, observerLongitude, true/*correctForParallax*/, false/*!altNotAz*/, currentCache);
    return angle;
}
-(double)planetAzimuth:(int)planetNumber atDateInterval:(NSTimeInterval)dateInterval {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double angle = planetAltAz(planetNumber, dateInterval, observerLatitude, observerLongitude, true/*correctForParallax*/, false/*!altNotAz*/, currentCache);
    return angle;
}

// By "up" here, we mean past the calculated rise and before the calculated set
- (bool)planetIsUp:(int)planetNumber {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    bool isUp;
    if (!locationValid) {
	PRINT_STRING("planetIsUp returns nil\n");
	//printf("planetIsUp returns nil\n");
	isUp = false;
    } else {
	assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
	if (currentCache && currentCache->cacheSlotValidFlag[planetIsUpSlotIndex+planetNumber] == currentCache->currentFlag) {
	    isUp = (int) currentCache->cacheSlots[planetIsUpSlotIndex+planetNumber];
	} else {
	    double altitude = planetAltAz(planetNumber, calculationDateInterval, observerLatitude, observerLongitude,
					  true/*correctForParallax*/, true/*altNotAz*/, currentCache);  // already incorporates topocentric parallax
	    //printAngle(altitude, "planetIsUp altitude");
	    double altAtRiseSet = altitudeAtRiseSet(julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache),
						    planetNumber, false/*!wantGeocentricAltitude*/, currentCache, ECWBFullPrecision);
	    //printAngle(altAtRiseSet, "...altAtRiseSet");
	    isUp = altitude > altAtRiseSet;
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[planetIsUpSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[planetIsUpSlotIndex+planetNumber] = (double) (isUp);
	    }
	}
    }
    return isUp;
}

-(double)moonAzimuth {
    return [self planetAzimuth:ECPlanetMoon];
}

-(double)moonAltitude {
    return [self planetAltitude:ECPlanetMoon];
}

-(double)sunAzimuth {
    return [self planetAzimuth:ECPlanetSun];
}

-(double)sunAltitude {
    return [self planetAltitude:ECPlanetSun];
}

-(double)planetRA:(int)planetNumber correctForParallax:(bool)correctForParallax {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    int slotIndexBase = correctForParallax ? planetRATopoSlotIndex : planetRASlotIndex;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndexBase+planetNumber] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[slotIndexBase+planetNumber];
    } else {
	double planetRightAscension;
	double planetDeclination;
	double planetGeocentricDistance;
	if (correctForParallax && currentCache &&
	    currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] == currentCache->currentFlag &&
	    currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] == currentCache->currentFlag &&
	    currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] == currentCache->currentFlag) {
	    planetDeclination = currentCache->cacheSlots[planetDeclSlotIndex+planetNumber];
	    planetRightAscension = currentCache->cacheSlots[planetRASlotIndex+planetNumber];
	    planetGeocentricDistance = currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber];
	} else {
	    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	    double planetEclipticLongitude;
	    double planetEclipticLatitude;
	    WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &planetEclipticLatitude, &planetGeocentricDistance,
				      &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[planetEclipticLongitudeSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetEclipticLatitudeSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[planetEclipticLongitudeSlotIndex+planetNumber] = planetEclipticLongitude;
		currentCache->cacheSlots[planetEclipticLatitudeSlotIndex+planetNumber] = planetEclipticLatitude;
		currentCache->cacheSlots[planetDeclSlotIndex+planetNumber] = planetDeclination;
		currentCache->cacheSlots[planetRASlotIndex+planetNumber] = planetRightAscension;
		currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber] = planetGeocentricDistance;;
	    }
	}
	if (correctForParallax) {
	    assert(!currentCache || currentCache->cacheSlotValidFlag[planetRATopoSlotIndex+planetNumber] != currentCache->currentFlag);  // Otherwise very first cache check should succeed
	    double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
	    double lst = convertGSTtoLST(gst, observerLongitude);
	    double planetHourAngle = lst - planetRightAscension;
	    double planetTopoRightAscension;
	    double planetTopoDeclination;
	    double planetTopoHourAngle;
	    topocentricParallax(planetRightAscension, planetDeclination, planetHourAngle, planetGeocentricDistance, observerLatitude, 0/*observerAltitude*/,
				&planetTopoHourAngle, &planetTopoDeclination);
	    planetTopoRightAscension = lst - planetTopoHourAngle;
	    if (planetTopoRightAscension < 0) {
		planetTopoRightAscension += M_PI * 2;
	    }
	    //EC_printAngle(planetRightAscension, "planetRightAscension");
	    //EC_printAngle(planetTopoRightAscension, "planetTopoRightAscension");
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[planetDeclTopoSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetRATopoSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[planetDeclTopoSlotIndex+planetNumber] = planetTopoDeclination;
		currentCache->cacheSlots[planetRATopoSlotIndex+planetNumber] = planetTopoRightAscension;
	    }
	    angle = planetTopoRightAscension;
	} else {
	    angle = planetRightAscension;
	}
    }
    return angle;
}

-(double)planetDecl:(int)planetNumber correctForParallax:(bool)correctForParallax {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    int slotIndexBase = correctForParallax ? planetDeclTopoSlotIndex : planetDeclSlotIndex;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndexBase+planetNumber] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[slotIndexBase+planetNumber];
    } else {
	double planetRightAscension;
	double planetDeclination;
	double planetGeocentricDistance;
	if (correctForParallax && currentCache &&
	    currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] == currentCache->currentFlag &&
	    currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] == currentCache->currentFlag &&
	    currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] == currentCache->currentFlag) {
	    planetDeclination = currentCache->cacheSlots[planetDeclSlotIndex+planetNumber];
	    planetRightAscension = currentCache->cacheSlots[planetRASlotIndex+planetNumber];
	    planetGeocentricDistance = currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber];
	} else {
	    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	    double planetEclipticLongitude;
	    double planetEclipticLatitude;
	    WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &planetEclipticLatitude, &planetGeocentricDistance, &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[planetEclipticLongitudeSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetEclipticLatitudeSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[planetEclipticLongitudeSlotIndex+planetNumber] = planetEclipticLongitude;
		currentCache->cacheSlots[planetEclipticLatitudeSlotIndex+planetNumber] = planetEclipticLatitude;
		currentCache->cacheSlots[planetDeclSlotIndex+planetNumber] = planetDeclination;
		currentCache->cacheSlots[planetRASlotIndex+planetNumber] = planetRightAscension;
		currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber] = planetGeocentricDistance;;
	    }
	}
	if (correctForParallax) {
	    assert(!currentCache || currentCache->cacheSlotValidFlag[planetDeclTopoSlotIndex+planetNumber] != currentCache->currentFlag);  // Otherwise very first cache check should succeed
	    double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
	    double lst = convertGSTtoLST(gst, observerLongitude);
	    double planetHourAngle = lst - planetRightAscension;
	    double planetTopoRightAscension;
	    double planetTopoDeclination;
	    topocentricParallax(planetRightAscension, planetDeclination, planetHourAngle, planetGeocentricDistance, observerLatitude, 0/*observerAltitude*/,
				&planetTopoRightAscension, &planetTopoDeclination);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[planetDeclTopoSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlotValidFlag[planetRATopoSlotIndex+planetNumber] = currentCache->currentFlag;
		currentCache->cacheSlots[planetDeclTopoSlotIndex+planetNumber] = planetTopoDeclination;
		currentCache->cacheSlots[planetRATopoSlotIndex+planetNumber] = planetTopoRightAscension;
	    }
	    angle = planetTopoDeclination;
	} else {
	    angle = planetDeclination;
	}
    }
    return angle;
}

-(double)planetEclipticLongitude:(int)planetNumber {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetEclipticLongitudeSlotIndex+planetNumber] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[planetEclipticLongitudeSlotIndex+planetNumber];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	double planetRightAscension;
	double planetDeclination;
	double planetEclipticLongitude;
	double planetEclipticLatitude;
	double planetGeocentricDistance;
	WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &planetEclipticLatitude, &planetGeocentricDistance, &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetEclipticLongitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetEclipticLatitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetEclipticLongitudeSlotIndex+planetNumber] = planetEclipticLongitude;
	    currentCache->cacheSlots[planetEclipticLatitudeSlotIndex+planetNumber] = planetEclipticLatitude;
	    currentCache->cacheSlots[planetDeclSlotIndex+planetNumber] = planetDeclination;
	    currentCache->cacheSlots[planetRASlotIndex+planetNumber] = planetRightAscension;
	    currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber] = planetGeocentricDistance;;
	}
	angle = planetEclipticLongitude;
    }
    return angle;
}

-(double)planetEclipticLatitude:(int)planetNumber {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetEclipticLatitudeSlotIndex+planetNumber] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[planetEclipticLatitudeSlotIndex+planetNumber];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	double planetRightAscension;
	double planetDeclination;
	double planetEclipticLongitude;
	double planetEclipticLatitude;
	double planetGeocentricDistance;
	WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &planetEclipticLatitude, &planetGeocentricDistance, &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetEclipticLongitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetEclipticLatitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetEclipticLongitudeSlotIndex+planetNumber] = planetEclipticLongitude;
	    currentCache->cacheSlots[planetEclipticLatitudeSlotIndex+planetNumber] = planetEclipticLatitude;
	    currentCache->cacheSlots[planetDeclSlotIndex+planetNumber] = planetDeclination;
	    currentCache->cacheSlots[planetRASlotIndex+planetNumber] = planetRightAscension;
	    currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber] = planetGeocentricDistance;;
	}
	angle = planetEclipticLatitude;
    }
    return angle;
}

-(double)planetGeocentricDistance:(int)planetNumber {
    if (planetNumber < 0 || planetNumber > ECLastLegalPlanet || planetNumber == ECPlanetEarth) {
	return nan("");
    }
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double distance;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] == currentCache->currentFlag) {
	distance = currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	double planetRightAscension;
	double planetDeclination;
	double planetEclipticLongitude;
	double planetEclipticLatitude;
	double planetGeocentricDistance;
	WB_planetApparentPosition(planetNumber, julianCenturiesSince2000Epoch/100, &planetEclipticLongitude, &planetEclipticLatitude, &planetGeocentricDistance, &planetRightAscension, &planetDeclination, currentCache, ECWBFullPrecision);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetEclipticLongitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetEclipticLatitudeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetDeclSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetRASlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[planetGeocentricDistanceSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetEclipticLongitudeSlotIndex+planetNumber] = planetEclipticLongitude;
	    currentCache->cacheSlots[planetEclipticLatitudeSlotIndex+planetNumber] = planetEclipticLatitude;
	    currentCache->cacheSlots[planetDeclSlotIndex+planetNumber] = planetDeclination;
	    currentCache->cacheSlots[planetRASlotIndex+planetNumber] = planetRightAscension;
	    currentCache->cacheSlots[planetGeocentricDistanceSlotIndex+planetNumber] = planetGeocentricDistance;;
	}
	distance = planetGeocentricDistance;
    }
    return distance;
}

-(double)planetMass:(int)n {
    return planetMassInKG[n];			// kilograms
}

-(double)planetOribitalPeriod:(int)n {
    return planetOrbitalPeriodInYears[n];	// years
}

-(double)planetRadius:(int)n {
    return planetRadiiInAU[n] * kECAUInKilometers;				// kilometers
}

-(double)planetApparentDiameter:(int)n {
    return atan((planetRadiiInAU[n])/[self planetGeocentricDistance:n])*2;	// radians
}

-(void)calculateHighestEcliptic {
    double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(julianCenturiesSince2000Epoch/100, &nutation, &obliquity, currentCache);
    double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
    double lst = convertGSTtoLST(gst, observerLongitude);
    double sinObliquity = sin(obliquity);
    double cosObliquity = cos(obliquity);
    double sinLst = sin(lst);
    double cosObsLat = cos(observerLatitude);
    double sinObsLat = sin(observerLatitude);
    double eclipticLongitude = atan2(-cos(lst), sinObliquity*tan(observerLatitude) + cosObliquity*sinLst);  // longitude at horizon
    eclipticLongitude += M_PI/2;  // guess + rather than -
    double sinEclipLong = sin(eclipticLongitude);
    double declination = asin(sinObliquity * sinEclipLong);
    double rightAscension = atan2(cosObliquity * sinEclipLong, cos(eclipticLongitude));
    double hourAngle = lst - rightAscension;
    double sinAlt = sin(declination)*sinObsLat + cos(declination)*cosObsLat*cos(hourAngle);

    double azimuth = atan2(-cos(declination)*cosObsLat*sin(hourAngle), sin(declination) - sinObsLat*sinAlt);

    // Check if we guessed right by checking altitude: If +, we got it right
    if (sinAlt < 0) { // guessed wrong
	azimuth = EC_fmod(azimuth + M_PI, (M_PI * 2));
	eclipticLongitude = EC_fmod(eclipticLongitude + M_PI, (M_PI * 2));
    } else { // guessed right
	azimuth = EC_fmod(azimuth, (M_PI * 2));
	eclipticLongitude = EC_fmod(eclipticLongitude, (M_PI * 2));
    }
    if (azimuth < 0) {
	azimuth += (M_PI * 2);
    }
    if (eclipticLongitude < 0) {
	eclipticLongitude += (M_PI * 2);
    }

    // Now calculate ecliptic longitude of north meridian, which is the location for which the azimuth is 0 and the ecliptic latitude is 0
    // Note cos(azimuth) = 1, sin(azimuth) = 0
    // The hourAngle is 0 or 180, depending on .... sign of sinAlt - sinObsLat*sinDecl?  but we only care about tan(HA) which ignores the +180
    // Call it zero, so RA = lst - HA = lst
    double meridianRA = lst;
    double longitudeOfEclipticMeridian = atan(tan(meridianRA) / cosObliquity);
    // This is the longitude of the meridian that intersects the half of the ecliptic with positive altitude.  But we want the north one, which might be the other one
    // Also, we must follow the quadrant of the meridianRA
    bool flipBecauseOfRA = (cos(meridianRA) > 0);
    bool flipBecauseOfAzimuth = observerLatitude > 0
	? (cos(azimuth) > 0) && observerLatitude < M_PI / 4
	: (cos(azimuth) > 0) || observerLatitude < -M_PI / 4;
	
    if (flipBecauseOfRA != flipBecauseOfAzimuth) { // either is on but not both where they cancel each other out
	longitudeOfEclipticMeridian -= M_PI;
    }
    if (longitudeOfEclipticMeridian < 0) {
	longitudeOfEclipticMeridian += (M_PI * 2);
    }
    double eclipticAltitude = acos(cosObliquity*sinObsLat - sinObliquity*cosObsLat*sinLst);
    //printAngle(eclipticLongitude, "longitude of highest ecliptic");
    //printAngle(azimuth, "azimuth of highest ecliptic");
    //printAngle(eclipticAltitude, "altitude of ecliptic");
    //printAngle(longitudeOfEclipticMeridian, "longitudeOfEclipticMeridian");
    if (currentCache) {
	currentCache->cacheSlotValidFlag[azimuthOfHighestEclipticSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlotValidFlag[longitudeOfHighestEclipticSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlotValidFlag[eclipticAltitudeSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlotValidFlag[longitudeOfEclipticMeridianSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[azimuthOfHighestEclipticSlotIndex] = azimuth;
	currentCache->cacheSlots[longitudeOfHighestEclipticSlotIndex] = eclipticLongitude;
	currentCache->cacheSlots[eclipticAltitudeSlotIndex] = eclipticAltitude;
	currentCache->cacheSlots[longitudeOfEclipticMeridianSlotIndex] = longitudeOfEclipticMeridian;
    }
}

-(double)azimuthOfHighestEclipticAltitude {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(currentCache);
    double angle;
    assert(fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache->cacheSlotValidFlag[azimuthOfHighestEclipticSlotIndex] != currentCache->currentFlag) {
	[self calculateHighestEcliptic];
    }
    angle = currentCache->cacheSlots[azimuthOfHighestEclipticSlotIndex];
    return angle;
}

-(double)longitudeOfHighestEclipticAltitude {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(currentCache);
    double angle;
    assert(fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache->cacheSlotValidFlag[longitudeOfHighestEclipticSlotIndex] != currentCache->currentFlag) {
	[self calculateHighestEcliptic];
    }
    angle = currentCache->cacheSlots[longitudeOfHighestEclipticSlotIndex];
    return angle;
}

-(double)longitudeAtNorthMeridian {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(currentCache);
    double angle;
    assert(fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache->cacheSlotValidFlag[longitudeOfEclipticMeridianSlotIndex] != currentCache->currentFlag) {
	[self calculateHighestEcliptic];
    }
    angle = currentCache->cacheSlots[longitudeOfEclipticMeridianSlotIndex];
    return angle;
}

-(double)eclipticAltitude {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(currentCache);
    double angle;
    assert(fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache->cacheSlotValidFlag[eclipticAltitudeSlotIndex] != currentCache->currentFlag) {
	[self calculateHighestEcliptic];
    }
    angle = currentCache->cacheSlots[eclipticAltitudeSlotIndex];
    return angle;
}

// Amount the sidereal time coordinate system has rotated around since the autumnal equinox
-(double)vernalEquinoxAngle {
    double angle;
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[vernalEquinoxSlotIndex] == currentCache->currentFlag) {
	angle = currentCache->cacheSlots[vernalEquinoxSlotIndex];
    } else {
	angle = STDifferenceForDate(calculationDateInterval, currentCache);
	//printDateD(calculationDateInterval, "vernalEquinoxAngle date");
	//printAngle(angle, "vernalEquinoxAngle");
	//double eclipLong = sunEclipticLongitudeForDate(calculationDateInterval, currentCache);
	//printAngle(eclipLong, "sunEclipticLong");
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[vernalEquinoxSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[vernalEquinoxSlotIndex] = angle;
	}
    }
    return angle;
}

static double
timeOfClosestSunEclipticLongitude(double       targetSunLong,
				  double       tryDate,
				  ECAstroCache *currentCache) {

    double sunLongitudeForTryDate = sunEclipticLongitudeForDate(tryDate, currentCache);
    double howFarAway = targetSunLong - sunLongitudeForTryDate;
    double deltaAngleToTarget;
    if (howFarAway >= 0) {
	if (howFarAway >= M_PI) {
	    deltaAngleToTarget = howFarAway - (M_PI * 2);
	} else {
	    deltaAngleToTarget = howFarAway;
	}
    } else if (howFarAway >= - M_PI) {
	deltaAngleToTarget = howFarAway;
    } else {
	deltaAngleToTarget = howFarAway + (M_PI * 2);
    }
    double returnDate = tryDate + deltaAngleToTarget * kECSecondsInTropicalYear / (M_PI * 2);
    return returnDate;
}

static NSTimeInterval refineClosestEclipticLongitude(int              longitudeQuarter,
						     NSTimeInterval   dateInterval,
						     ECAstroCachePool *cachePool) {
    double targetSunLongitude = longitudeQuarter * M_PI / 2;
    double tryDate = timeOfClosestSunEclipticLongitude(targetSunLongitude, dateInterval, cachePool->currentCache);
    ECAstroCache *priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
    tryDate = timeOfClosestSunEclipticLongitude(targetSunLongitude, tryDate, cachePool->currentCache);
    popECAstroCacheToInPool(cachePool, priorCache);
    priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
    tryDate = timeOfClosestSunEclipticLongitude(targetSunLongitude, tryDate, cachePool->currentCache);
    popECAstroCacheToInPool(cachePool, priorCache);
    priorCache = pushECAstroCacheWithSlopInPool(cachePool, &cachePool->refinementCache, tryDate, 0);
    NSTimeInterval closestTime = timeOfClosestSunEclipticLongitude(targetSunLongitude, tryDate, cachePool->currentCache);
    popECAstroCacheToInPool(cachePool, priorCache);
    return closestTime;
}

-(NSTimeInterval)refineTimeOfClosestSunEclipticLongitude:(int)longitudeQuarter {  // 0 => long==0, 1 => long==PI/2, etc
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval closestTime;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    assert(longitudeQuarter >= 0 && longitudeQuarter <= 3);
    int slotIndex = closestSunEclipticLongitudeSlotIndex + longitudeQuarter;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	closestTime = currentCache->cacheSlots[slotIndex];
    } else {
	closestTime = refineClosestEclipticLongitude(longitudeQuarter, calculationDateInterval, astroCachePool);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = closestTime;
	}
    }
    return closestTime;
}

-(double)closestSunEclipticLongitudeQuarter366IndicatorAngle:(int)longitudeQuarter {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double indicatorAngle;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    assert(longitudeQuarter >= 0 && longitudeQuarter <= 3);
    int slotIndex = closestSunEclipticLongIndicatorAngleSlotIndex + longitudeQuarter;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	indicatorAngle = currentCache->cacheSlots[slotIndex];
    } else {
	double targetTime = refineClosestEclipticLongitude(longitudeQuarter, calculationDateInterval, astroCachePool);
	ECWatchTime *targetTimer = [self watchTimeForInterval:targetTime];
	indicatorAngle = [targetTimer year366IndicatorFractionUsingEnv:environment] * (M_PI * 2);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = indicatorAngle;
	}
    }
    return indicatorAngle;
}

-(NSTimeInterval)meridianTimeForSeason {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval meridianTime;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[meridianTimeSlotIndex] == currentCache->currentFlag) {
	meridianTime = currentCache->cacheSlots[meridianTimeSlotIndex];
    } else {
	// Get date for midnight on this day
	ESDateComponents cs;
	ESCalendar_localDateComponentsFromTimeInterval(calculationDateInterval, estz, &cs);
	cs.hour = 0;
	cs.minute = 0;
	cs.seconds = 0;
	NSTimeInterval midnightD = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	// calculate meridian time in seconds from local noon
	double eot = EOT(calculationDateInterval, astroCachePool) * 3600 * 12 / M_PI;
	double tzOffset = [watchTime tzOffsetUsingEnv:environment];
	double longitudeOffset = observerLongitude * 3600 * 12 / M_PI;
	double meridianOffset = tzOffset - longitudeOffset - eot;
	// If summer, interesting time is midnight; if winter, it's noon
	if (isSummer(calculationDateInterval, observerLatitude, currentCache)) {
	    if (meridianOffset < 0) {
		meridianOffset += 24 * 3600;
	    }
	} else {
	    meridianOffset += 12 * 3600;
	}
	// Apply meridianOffset to midnight
	meridianTime = midnightD + meridianOffset;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[meridianTimeSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[meridianTimeSlotIndex] = meridianTime;
	}
    }
    return meridianTime;
}

-(NSTimeInterval)moonMeridianTimeForSeason {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval meridianTime;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonMeridianTimeSlotIndex] == currentCache->currentFlag) {
	meridianTime = currentCache->cacheSlots[moonMeridianTimeSlotIndex];
    } else {
	// Get date for midnight on this day
	ESDateComponents cs;
	ESCalendar_UTCDateComponentsFromTimeInterval(calculationDateInterval, &cs);
	cs.hour = 0;
	cs.minute = 0;
	cs.seconds = 0;
	NSTimeInterval midnightD = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	double meridianOffset = 0;
	if (moonIsSummer(calculationDateInterval, observerLatitude, currentCache)) {
	    meridianOffset = 12 * 3600;
	}
	meridianTime = midnightD + meridianOffset;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonMeridianTimeSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonMeridianTimeSlotIndex] = meridianTime;
	}
    }
    return meridianTime;
}

-(double)planetMeridianTimeForSeason:(int)planetNumber {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    NSTimeInterval meridianTime;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[planetMeridianTimeSlotIndex+planetNumber] == currentCache->currentFlag) {
	meridianTime = currentCache->cacheSlots[planetMeridianTimeSlotIndex+planetNumber];
    } else {
	// Get date for midnight on this day
	ESDateComponents cs;
	ESCalendar_UTCDateComponentsFromTimeInterval(calculationDateInterval, &cs);
	cs.hour = 0;
	cs.minute = 0;
	cs.seconds = 0;
	NSTimeInterval midnightD = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	double meridianOffset = 0;
	if (planetIsSummer(calculationDateInterval, observerLatitude, planetNumber, currentCache)) {
	    meridianOffset = 12 * 3600;
	}
	meridianTime = midnightD + meridianOffset;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[planetMeridianTimeSlotIndex+planetNumber] = currentCache->currentFlag;
	    currentCache->cacheSlots[planetMeridianTimeSlotIndex+planetNumber] = meridianTime;
	}
    }
    return meridianTime;
}

-(double)moonAscendingNodeLongitude {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double longitude;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonAscendingNodeLongitudeSlotIndex] == currentCache->currentFlag) {
	longitude = currentCache->cacheSlots[moonAscendingNodeLongitudeSlotIndex];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	longitude = WB_MoonAscendingNodeLongitude(julianCenturiesSince2000Epoch, currentCache);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonAscendingNodeLongitudeSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonAscendingNodeLongitudeSlotIndex] = longitude;
	}
    }
    return longitude;
}

-(double)moonAscendingNodeRA {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double RA;
    double longitude;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonAscendingNodeRASlotIndex] == currentCache->currentFlag) {
	RA = currentCache->cacheSlots[moonAscendingNodeRASlotIndex];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	if (currentCache && currentCache->cacheSlotValidFlag[moonAscendingNodeLongitudeSlotIndex] == currentCache->currentFlag) {
	    longitude = currentCache->cacheSlots[moonAscendingNodeLongitudeSlotIndex];
	} else {
	    longitude = WB_MoonAscendingNodeLongitude(julianCenturiesSince2000Epoch, currentCache);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[moonAscendingNodeLongitudeSlotIndex] = currentCache->currentFlag;
		currentCache->cacheSlots[moonAscendingNodeLongitudeSlotIndex] = longitude;
	    }
	}
	double obliquity;
	double nutation;
	WB_nutationObliquity(julianCenturiesSince2000Epoch/100,
			     &nutation,
			     &obliquity, currentCache);
	double decl;
	raAndDeclO(0 /*eclipticLatitude*/, longitude, obliquity, &RA, &decl);
	if (RA < 0) {
	    RA += 2 * M_PI;
	}
	//printAngle(longitude, "ascending node longitude");
	//printAngle(RA, "ascending node RA");
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonAscendingNodeRASlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonAscendingNodeRASlotIndex] = RA;
	    currentCache->cacheSlotValidFlag[moonAscendingNodeDeclSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonAscendingNodeDeclSlotIndex] = decl;
	}
    }
    return RA;
}

-(double)moonAscendingNodeRAJ2000 {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double RA;
    double longitude;
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache && currentCache->cacheSlotValidFlag[moonAscendingNodeRAJ2000SlotIndex] == currentCache->currentFlag) {
	RA = currentCache->cacheSlots[moonAscendingNodeRAJ2000SlotIndex];
    } else {
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	if (currentCache && currentCache->cacheSlotValidFlag[moonAscendingNodeLongitudeSlotIndex] == currentCache->currentFlag) {
	    longitude = currentCache->cacheSlots[moonAscendingNodeLongitudeSlotIndex];
	} else {
	    longitude = WB_MoonAscendingNodeLongitude(julianCenturiesSince2000Epoch, currentCache);
	    if (currentCache) {
		currentCache->cacheSlotValidFlag[moonAscendingNodeLongitudeSlotIndex] = currentCache->currentFlag;
		currentCache->cacheSlots[moonAscendingNodeLongitudeSlotIndex] = longitude;
	    }
	}
	double obliquity;
	double nutation;
	WB_nutationObliquity(julianCenturiesSince2000Epoch/100,
			     &nutation,
			     &obliquity, currentCache);
	double declOfDate;
	double raOfDate;
	raAndDeclO(0 /*eclipticLatitude*/, longitude, obliquity, &raOfDate, &declOfDate);
	if (raOfDate < 0) {
	    raOfDate += 2 * M_PI;
	}
	double decl;
	refineConvertToJ2000FromOfDate(julianCenturiesSince2000Epoch, raOfDate, declOfDate, &RA, &decl);
	//printAngle(longitude, "ascending node longitude");
	//printAngle(RA, "ascending node RA");
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[moonAscendingNodeRAJ2000SlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonAscendingNodeRAJ2000SlotIndex] = RA;
	    currentCache->cacheSlotValidFlag[moonAscendingNodeDeclJ2000SlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[moonAscendingNodeDeclJ2000SlotIndex] = decl;
	}
    }
    return RA;
}

#if 0 // THIS FUNCTION IS VERY BROKEN, DON'T HAVE TIME TO FIX IT
// Note: shadow diameter goes negative past the tip of the shadow cone
static double
shadowDiameter(double lightSourceDiameter,
	       double castingObjectDiameter,
	       double distanceFromLightSourceToCastingObject,
	       double distanceFromCastingObjectToShadow) {
    double lengthOfShadowCone = castingObjectDiameter * distanceFromLightSourceToCastingObject/(lightSourceDiameter - castingObjectDiameter);
    double halfConeAngle = asin(castingObjectDiameter/distanceFromLightSourceToCastingObject);
    double shadowDiam = castingObjectDiameter * (lengthOfShadowCone - distanceFromCastingObjectToShadow) / (lengthOfShadowCone * cos(halfConeAngle));
    return shadowDiam;
}
#endif

static double
umbralAngularRadius(double moonParallax,
		    double sunAngularRadius,
		    double sunParallax) {
    return 1.01 * moonParallax - sunAngularRadius + sunParallax;
}

// This formula works well for small separation values, unlike ones that end with acos
static double
angularSeparation(double rightAscension1,
		  double declination1,
		  double rightAscension2,
		  double declination2) {
    double sinDecl1 = sin(declination1);
    double cosDecl1 = cos(declination1);
    double sinDecl2 = sin(declination2);
    double cosDecl2 = cos(declination2);
    double sinRADelta = sin(rightAscension2 - rightAscension1);
    double cosRADelta = cos(rightAscension2 - rightAscension1);
    double x = cosDecl1 * sinDecl2 - sinDecl1 * cosDecl2 * cosRADelta;
    double y = cosDecl2 * sinRADelta;
    double z = sinDecl1 * sinDecl2 + cosDecl1 * cosDecl2 * cosRADelta;
    return atan2(sqrt(x*x + y*y), z);
}

#ifndef NDEBUG
static char *nameOfEclipseKind(ECEclipseKind kind) {
    switch (kind) {
      case ECEclipseNoneSolar:
	return "ECEclipseNoneSolar";
      case ECEclipseNoneLunar:
	return "ECEclipseNoneLunar";
      case ECEclipseSolarNotUp:
	return "ECEclipseSolarNotUp";
      case ECEclipsePartialSolar:
	return "ECEclipsePartialSolar";
      case ECEclipseAnnularSolar:
	return "ECEclipseAnnularSolar";
      case ECEclipseTotalSolar:
	return "ECEclipseTotalSolar";
      case ECEclipseLunarNotUp:
	return "ECEclipseLunarNotUp";
      case ECEclipsePartialLunar:
	return "ECEclipsePartialLunar";
      case ECEclipseTotalLunar:
	return "ECEclipseTotalLunar";
      default:
	return "Bogus EclipseKind";
    }
}
#endif

static void
calculateEclipse(NSTimeInterval calculationDateInterval,
		 double         observerLatitude,
		 double         observerLongitude,
		 double         *abstractSeparation,
                 double         *angularSep,
		 ECEclipseKind  *eclipseKind,
		 ECAstroCache   *currentCache) {
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    if (currentCache
	&& currentCache->cacheSlotValidFlag[eclipseSeparationSlotIndex] == currentCache->currentFlag
	&& currentCache->cacheSlotValidFlag[eclipseKindSlotIndex] == currentCache->currentFlag) {
	*abstractSeparation = currentCache->cacheSlots[eclipseSeparationSlotIndex];
        *angularSep = currentCache->cacheSlots[eclipseAngularSeparationSlotIndex];
	*eclipseKind = currentCache->cacheSlots[eclipseKindSlotIndex];
    } else {
	double gst = convertUTToGSTP03(calculationDateInterval, currentCache);
	double lst = convertGSTtoLST(gst, observerLongitude);
	double julianCenturiesSince2000Epoch = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	double sunRightAscension;
	double sunDeclination;
	double sunEclipticLongitude;
	double sunEclipticLatitude;
	double sunGeocentricDistance;
	WB_planetApparentPosition(ECPlanetSun, julianCenturiesSince2000Epoch/100, &sunEclipticLongitude, &sunEclipticLatitude, &sunGeocentricDistance, &sunRightAscension, &sunDeclination, currentCache, ECWBFullPrecision);
	double sunAngularSize;
	double sunParallax;
	planetSizeAndParallax(ECPlanetSun, sunGeocentricDistance, &sunAngularSize, &sunParallax);
	double moonRightAscension;
	double moonDeclination;
	double moonEclipticLongitude;
	double moonEclipticLatitude;
	double moonGeocentricDistance;
	WB_planetApparentPosition(ECPlanetMoon, julianCenturiesSince2000Epoch/100, &moonEclipticLongitude, &moonEclipticLatitude, &moonGeocentricDistance, &moonRightAscension, &moonDeclination, currentCache, ECWBFullPrecision);
	double moonAngularSize;
	double moonParallax;
	planetSizeAndParallax(ECPlanetMoon, moonGeocentricDistance, &moonAngularSize, &moonParallax);
	// Quick check:
	double raDelta = EC_fmod(fabs(moonRightAscension - sunRightAscension), M_PI * 2);
	double physicalSeparation;
	double separationAtPartialEclipse;
	double separationAtTotalEclipse;
        bool solarNotLunar;
	if (raDelta < M_PI / 2) { // might be solar
	    double sunHourAngle = lst - sunRightAscension;
	    double sunTopoHourAngle;
	    double sunTopoDecl;
	    topocentricParallax(sunRightAscension, sunDeclination, sunHourAngle, sunGeocentricDistance, observerLatitude, 0/*observerAltitude*/, &sunTopoHourAngle, &sunTopoDecl);
	    double sunTopoRA = lst - sunTopoHourAngle;
	    
	    double moonHourAngle = lst - moonRightAscension;
	    double moonTopoHourAngle;
	    double moonTopoDecl;
	    topocentricParallax(moonRightAscension, moonDeclination, moonHourAngle, moonGeocentricDistance, observerLatitude, 0/*observerAltitude*/, &moonTopoHourAngle, &moonTopoDecl);
	    double moonTopoRA = lst - moonTopoHourAngle;
	    
	    physicalSeparation = angularSeparation(sunTopoRA, sunTopoDecl, moonTopoRA, moonTopoDecl);
	    separationAtPartialEclipse        =  sunAngularSize / 2 + moonAngularSize / 2;
	    separationAtTotalEclipse          = moonAngularSize / 2 - sunAngularSize / 2;  // might be negative (no total)
	    double separationAtAnnularEclipse =  sunAngularSize / 2 - moonAngularSize / 2;  // might be negative (no annular)
	    
	    double altitude = planetAltAz(ECPlanetSun, calculationDateInterval, observerLatitude, observerLongitude,
					  true/*correctForParallax*/, true/*altNotAz*/, currentCache);  // already incorporates topocentric parallax
	    //printAngle(altitude, "planetIsUp altitude");
	    double altAtRiseSet = altitudeAtRiseSet(julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache),
						    ECPlanetSun, false/*!wantGeocentricAltitude*/, currentCache, ECWBFullPrecision);
	    //printAngle(altAtRiseSet, "...altAtRiseSet");
	    if (altitude < altAtRiseSet) {
		*eclipseKind = ECEclipseSolarNotUp;
	    } else if (physicalSeparation > separationAtPartialEclipse) {
		*eclipseKind = ECEclipseNoneSolar;
	    } else if (physicalSeparation < separationAtAnnularEclipse) {
		*eclipseKind = ECEclipseAnnularSolar;
	    } else if (physicalSeparation > separationAtTotalEclipse) {
		*eclipseKind = ECEclipsePartialSolar;
	    } else {
		*eclipseKind = ECEclipseTotalSolar;
	    }
            solarNotLunar = true;
	} else {  // might be lunar
	    double shadowAngularSize = 2 * umbralAngularRadius(moonParallax, sunAngularSize/2, sunParallax);
	    //printAngle(shadowAngularSize/2, "corrected shadow angular radius");
	    double shadowRA = sunRightAscension + M_PI;
	    if (shadowRA > 2 * M_PI) {
		shadowRA -= 2 * M_PI;
	    }
	    double shadowDecl = -sunDeclination;
	    
	    physicalSeparation = angularSeparation(shadowRA, shadowDecl, moonRightAscension, moonDeclination);
	    separationAtPartialEclipse = moonAngularSize / 2 + shadowAngularSize / 2;
	    separationAtTotalEclipse = shadowAngularSize / 2 - moonAngularSize / 2;
	    
	    double altitude = planetAltAz(ECPlanetMoon, calculationDateInterval, observerLatitude, observerLongitude,
					  true/*correctForParallax*/, true/*altNotAz*/, currentCache);  // already incorporates topocentric parallax
	    //printAngle(altitude, "planetIsUp altitude");
	    double altAtRiseSet = altitudeAtRiseSet(julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache),
						    ECPlanetMoon, false/*!wantGeocentricAltitude*/, currentCache, ECWBFullPrecision);
	    //printAngle(altAtRiseSet, "...altAtRiseSet");
	    if (altitude < altAtRiseSet) {
		*eclipseKind = ECEclipseLunarNotUp;
	    } else if (physicalSeparation > separationAtPartialEclipse) {
		*eclipseKind = ECEclipseNoneLunar;
	    } else if (physicalSeparation > separationAtTotalEclipse) {
		*eclipseKind = ECEclipsePartialLunar;
	    } else {
		*eclipseKind = ECEclipseTotalLunar;
	    }
            solarNotLunar = false;
	}
	//printingEnabled = true;
	//printAngle(physicalSeparation, "physicalSeparation");
	//printAngle(separationAtPartialEclipse, "separationAtPartialEclipse");
	//printAngle(separationAtTotalEclipse, "separationAtTotalEclipse");
	//printingEnabled = false;
	
	// Fit y=mx+b to (separationAtTotalEclipse, 1), (separationAtPartialEclipse, 2)
	// y = y1 + (x - x1)*(y2 - y1)/(x2 - x1), and note y2 - y1 == 1
        *angularSep = physicalSeparation;
	*abstractSeparation = 1 + (physicalSeparation - separationAtTotalEclipse) / (separationAtPartialEclipse - separationAtTotalEclipse);
	//printf("raw separation %.2f\n", separation);
	if (*abstractSeparation < 0) {
	    *abstractSeparation = 0;
	} else if (*abstractSeparation > 3) {
	    *abstractSeparation = 3;
	    *eclipseKind = solarNotLunar ? ECEclipseNoneSolar : ECEclipseNoneLunar;  // override possible not-up if needle is pegged
	}
	//printf("separation %.2f\n", separation);
	//printf("%s\n", nameOfEclipseKind(*eclipseKind));
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[eclipseSeparationSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[eclipseKindSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[eclipseAngularSeparationSlotIndex] = physicalSeparation;
	    currentCache->cacheSlots[eclipseSeparationSlotIndex] = *abstractSeparation;
	    currentCache->cacheSlots[eclipseKindSlotIndex] = *eclipseKind;
	}
    }
}

// Separation of Sun from Moon, or Earth's shadow from Moon, scaled such that
//   1) partial eclipse starts when separation == 2
//   2) total eclipse starts when separation == 1
//   3) Limited to range 0 < sep < 3
// Note that zero doesn't therefore represent zero separation, and that zero separation may lie above or below the total eclipse point depending on the relative diameters
-(double)eclipseSeparation {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double separation;
    double angularSeparation;
    ECEclipseKind eclipseKind;
    calculateEclipse(calculationDateInterval, observerLatitude, observerLongitude, &separation, &angularSeparation, &eclipseKind, currentCache);
    return separation;
}

-(double)eclipseAngularSeparation {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double separation;
    double angularSeparation;
    ECEclipseKind eclipseKind;
    calculateEclipse(calculationDateInterval, observerLatitude, observerLongitude, &separation, &angularSeparation, &eclipseKind, currentCache);
    return angularSeparation;
}

-(ECEclipseKind)eclipseKind {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    double separation;
    double angularSeparation;
    ECEclipseKind eclipseKind;
    calculateEclipse(calculationDateInterval, observerLatitude, observerLongitude, &separation, &angularSeparation, &eclipseKind, currentCache);
    return eclipseKind;
}

+(bool)eclipseKindIsMoreSolarThanLunar:(ECEclipseKind)eclipseKind {
    switch (eclipseKind) {
      case ECEclipseNoneSolar:
        return true;
      case ECEclipseNoneLunar:
        return false;
      case ECEclipseSolarNotUp:
        return true;
      case ECEclipsePartialSolar:
        return true;
      case ECEclipseAnnularSolar:
        return true;
      case ECEclipseTotalSolar:
        return true;
      case ECEclipseLunarNotUp:
        return false;
      case ECEclipsePartialLunar:
        return false;
      case ECEclipseTotalLunar:
        return false;
      default:
        assert(false);
        return false;
    }
}

// How much the vernal equinox has moved with respect to the ideal tropical year, defined as the
// exact ecliptic longitude of the Sun in the year 2000 CE.
-(double)calendarErrorVsTropicalYear {
   assert(astroCachePool);
   assert(currentCache == astroCachePool->currentCache);
   assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
   double errorAngle;
   if (currentCache && currentCache->cacheSlotValidFlag[calendarErrorSlotIndex] == currentCache->currentFlag) {
       errorAngle = currentCache->cacheSlots[calendarErrorSlotIndex];
   } else {
       double todaysLongitude = sunEclipticLongitudeForDate(calculationDateInterval, currentCache);

       ESDateComponents cs;
       ESCalendar_UTCDateComponentsFromTimeInterval(calculationDateInterval, &cs);
       cs.era = 1;    // CE
       cs.year = 2001;
       NSTimeInterval thisDay2000 = ESCalendar_timeIntervalFromUTCDateComponents(&cs);

       ECAstroCache *priorCache = pushECAstroCacheInPool(astroCachePool, &astroCachePool->year2000Cache, thisDay2000);
       double year2000Longitude = sunEclipticLongitudeForDate(thisDay2000, astroCachePool->currentCache);
       popECAstroCacheToInPool(astroCachePool, priorCache);

       errorAngle = year2000Longitude - todaysLongitude;
       if (currentCache) {
	   currentCache->cacheSlotValidFlag[calendarErrorSlotIndex] = currentCache->currentFlag;
	   currentCache->cacheSlots[calendarErrorSlotIndex] = errorAngle;
       }
   }
   return errorAngle;
}

-(double)precession {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    double precession;
    if (currentCache && currentCache->cacheSlotValidFlag[precessionSlotIndex] == currentCache->currentFlag) {
	precession = currentCache->cacheSlots[precessionSlotIndex];
    } else {
	double centuriesSinceEpochTDT = julianCenturiesSince2000EpochForDateInterval(calculationDateInterval, NULL, currentCache);
	precession = generalPrecessionSinceJ2000(centuriesSinceEpochTDT);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[precessionSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[precessionSlotIndex] = precession;
	}
    }
    return precession;
}

-(bool)nextSunriseValid {
    return !isnan([self nextSunrise]);
}

-(bool)nextSunsetValid {
    return !isnan([self nextSunset]);
}

-(bool)nextMoonriseValid {
    return !isnan([self nextMoonrise]);
}

-(bool)nextMoonsetValid {
    return !isnan([self nextMoonset]);
}

-(bool)prevSunriseValid {
    return !isnan([self prevSunrise]);
}

-(bool)prevSunsetValid {
    return !isnan([self prevSunset]);
}

-(bool)prevMoonriseValid {
    return !isnan([self prevMoonrise]);
}

-(bool)prevMoonsetValid {
    return !isnan([self prevMoonset]);
}

-(bool)nextPlanetriseValid:(int)planetNumber {
    return !isnan([self nextPlanetriseForPlanetNumber:planetNumber]);
}

-(bool)nextPlanetsetValid:(int)planetNumber {
    return !isnan([self nextPlanetsetForPlanetNumber:planetNumber]);
}

-(bool)sunriseForDayValid {
    return !isnan([self sunriseForDay]);
}

-(bool)sunsetForDayValid {
    return !isnan([self sunsetForDay]);
}

-(bool)suntransitForDayValid {
    return !isnan([self suntransitForDay]);
}

-(bool)moonriseForDayValid {
    return !isnan([self moonriseForDay]);
}

-(bool)moonsetForDayValid {
    return !isnan([self moonsetForDay]);
}

-(bool)moontransitForDayValid {
    return !isnan([self moontransitForDay]);
}

-(bool)planetriseForDayValid:(int)planetNumber {
    return !isnan([self planetriseForDay:planetNumber]);
}

-(bool)planetsetForDayValid:(int)planetNumber {
    return !isnan([self planetsetForDay:planetNumber]);
}

-(bool)planettransitForDayValid:(int)planetNumber {
    return !isnan([self planettransitForDay:planetNumber]);
}

-(double)angle24HourForDateInterval:(NSTimeInterval)dateInterval timeBaseKind:(ECTimeBaseKind)timeBaseKind {
    if (isnan(dateInterval)) {
	return dateInterval;
    }
    [scratchWatchTime setToFrozenDateInterval:dateInterval];
    switch(timeBaseKind) {
      case ECTimeBaseKindLT:
        return [scratchWatchTime hour24ValueUsingEnv:environment] * M_PI / 12;
      case ECTimeBaseKindUT:
      {
	ESDateComponents cs;
	ESCalendar_UTCDateComponentsFromTimeInterval(dateInterval, &cs);
        return (cs.hour + cs.minute / 60.0 + cs.seconds / 3600.0) * M_PI / 12;
      }
      case ECTimeBaseKindLST:
      {
        ECAstroCache *priorCache = pushECAstroCacheWithSlopInPool(astroCachePool, &astroCachePool->refinementCache, dateInterval, 0);
        double lst = localSiderealTime(dateInterval, observerLongitude, astroCachePool->currentCache);
	popECAstroCacheToInPool(astroCachePool, priorCache);
        return lst * M_PI / (12 * 3600);
      }
      default:
        assert(false);
        return nan("");
    }
}

// Special op for day/night indicator leaves.  Returns 24-hour angle
// numLeaves == 0 means special cases by leafNumber:
//    0: rise24HourIndicatorAngle
//    1:  set24HourIndicatorAngle
//    2: polar summer mask angle
//    3: polar winter mask angle
// numLeaves < 0 special case for Dawn/dusk indicators
// planetNumber == 9 means return angles for nighttime leaves 
-(double)dayNightLeafAngleForPlanetNumber:(int)planetNumber
			       leafNumber:(double)leafNumber
				numLeaves:(int)numLeaves
                             timeBaseKind:(ECTimeBaseKind)timeBaseKind {
    assert(astroCachePool);
    assert(currentCache == astroCachePool->currentCache);
    assert(!currentCache || fabs(currentCache->dateInterval - calculationDateInterval) <= ASTRO_SLOP);
    bool nightTime = planetNumber == ECPlanetMidnightSun;
    if (nightTime) {
	planetNumber = ECPlanetSun;
    }
    assert(timeBaseKind == ECTimeBaseKindLT || timeBaseKind == ECTimeBaseKindLST);  // Else we need another set of slots...
    int possibleLSTOffset = timeBaseKind == ECTimeBaseKindLT ? 0 : (dayNightMasterRiseAngleLSTSlotIndex - dayNightMasterRiseAngleSlotIndex);
    int masterRiseSlotIndex = dayNightMasterRiseAngleSlotIndex + planetNumber + possibleLSTOffset;
    int masterSetSlotIndex  = dayNightMasterSetAngleSlotIndex + planetNumber + possibleLSTOffset;
    int masterRTransitSlotIndex = dayNightMasterRTransitAngleSlotIndex + planetNumber + possibleLSTOffset;
    int masterSTransitSlotIndex  = dayNightMasterSTransitAngleSlotIndex + planetNumber + possibleLSTOffset;
    double riseTimeAngle;
    double setTimeAngle;
    double rTransitAngle;
    double sTransitAngle;
    if (currentCache && currentCache->cacheSlotValidFlag[masterRiseSlotIndex] == currentCache->currentFlag) {
	assert(currentCache->cacheSlotValidFlag[masterSetSlotIndex] == currentCache->currentFlag);
	assert(currentCache->cacheSlotValidFlag[masterRTransitSlotIndex] == currentCache->currentFlag);
	assert(currentCache->cacheSlotValidFlag[masterSTransitSlotIndex] == currentCache->currentFlag);
	riseTimeAngle = currentCache->cacheSlots[masterRiseSlotIndex];
	setTimeAngle = currentCache->cacheSlots[masterSetSlotIndex];
	rTransitAngle = currentCache->cacheSlots[masterRTransitSlotIndex];
	sTransitAngle = currentCache->cacheSlots[masterSTransitSlotIndex];
    } else {
	// Get rise, set, transit
	bool planetIsUp = [self planetIsUp:planetNumber];
	double rTransit;
	double sTransit;
	//if (planetNumber == ECPlanetMercury && leafNumber == 0) {
	//    printingEnabled = true;
	//    printf("\nPlanet is %sup\nRISE:\n", planetIsUp ? "" : "NOT ");
	//}
	double riseTime = [self nextPrevRiseSetInternalWithFudgeInterval:-fudgeFactorSeconds
						       calculationMethod:planetaryRiseSetTimeRefined
							    planetNumber:planetNumber
							      riseNotSet:true
								  isNext:!planetIsUp
							       lookahead:(3600 * 13.2)
							riseSetOrTransit:&rTransit];
	//if (planetNumber == ECPlanetMercury && leafNumber == 0) printf("SET:\n");
	double setTime  = [self nextPrevRiseSetInternalWithFudgeInterval:-fudgeFactorSeconds
						       calculationMethod:planetaryRiseSetTimeRefined
							    planetNumber:planetNumber
							      riseNotSet:false
								  isNext:planetIsUp
							       lookahead:(3600 * 13.2)
							riseSetOrTransit:&sTransit];
	//printingEnabled = false;
	assert(!isnan(rTransit));
	assert(!isnan(sTransit));
	riseTimeAngle = [self angle24HourForDateInterval:riseTime timeBaseKind:timeBaseKind];
	setTimeAngle = [self angle24HourForDateInterval:setTime timeBaseKind:timeBaseKind];
	rTransitAngle = [self angle24HourForDateInterval:rTransit timeBaseKind:timeBaseKind];
	if (isnan(riseTimeAngle)) {
	    if (EC_nansEqual(riseTimeAngle, kECAlwaysAboveHorizon)) {
		// In this case, the transit time will be for the low transit.  We want the high transit always, so add 180
		rTransitAngle = EC_fmod(rTransitAngle + M_PI, 2 * M_PI);
	    }
	}
	sTransitAngle = [self angle24HourForDateInterval:sTransit timeBaseKind:timeBaseKind];
	if (isnan(setTimeAngle)) {
	    if (EC_nansEqual(setTimeAngle, kECAlwaysAboveHorizon)) {
		// In this case, the transit time will be for the low transit.  We want the high transit always, so add 180
		sTransitAngle = EC_fmod(sTransitAngle + M_PI, 2 * M_PI);
	    }
	}
	//if (planetNumber == ECPlanetSun && leafNumber == 0) {
	//    printingEnabled = true;
	//    printf("\nTimezone of current calendar is %s\n", [[[ltCalendar timeZone] name] UTF8String]);
	//    printAngle(observerLongitude, "observerLongitude");
	//    printAngle(observerLatitude, "observerLatitude");
	//    printAngle(riseTimeAngle, "riseTimeAngle");
	//    printAngle(setTimeAngle, "setTimeAngle");
	//    printAngle(rTransitAngle, "rTransitAngle");
	//    printAngle(sTransitAngle, "sTransitAngle");
	//    printingEnabled = false;
	//}
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[masterRiseSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[masterSetSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[masterRTransitSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[masterSTransitSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[masterRiseSlotIndex] = riseTimeAngle;
	    currentCache->cacheSlots[masterSetSlotIndex] = setTimeAngle;
	    currentCache->cacheSlots[masterRTransitSlotIndex] = rTransitAngle;
	    currentCache->cacheSlots[masterSTransitSlotIndex] = sTransitAngle;
	}
    }	
    bool isSpecial = false;
    if (numLeaves == 0) { // Special case 24-hour indicator angle
	if (leafNumber == 0) {  // rise
	    if (isnan(riseTimeAngle)) {
		assert(!isnan(rTransitAngle));
		return rTransitAngle;
	    } else {
		return riseTimeAngle;
	    }
	} else if (leafNumber == 1) { // set
	    if (isnan(setTimeAngle)) {
		assert(!isnan(sTransitAngle));
		return sTransitAngle;
	    } else {
		return setTimeAngle;
	    }
	} else {
	    isSpecial = true;    //handled below
	}
    } else if (numLeaves < 0) {  // Dawn/dusk indicators; abs(numLeaves) is amount to move backward when 
	numLeaves = -numLeaves;
    }
    double leafWidth = M_PI * 2 / numLeaves;
    bool polarSummer = false;
    bool polarWinter = false;
    if (isnan(riseTimeAngle)) {
	if (isnan(setTimeAngle)) {
	    // Can't tell: Use average transit of rise & set
	    if (sTransitAngle > rTransitAngle + M_PI) {
		sTransitAngle -= (2 * M_PI);
	    } else if (sTransitAngle < rTransitAngle - M_PI) {
		sTransitAngle -= (2 * M_PI);
	    }
	    double avgTransitAngle = (rTransitAngle + sTransitAngle) / 2;
	    if (EC_nansEqual(riseTimeAngle, kECAlwaysAboveHorizon)) {
		riseTimeAngle = avgTransitAngle - M_PI;
		setTimeAngle = avgTransitAngle + M_PI;
		polarSummer = true;
	    } else {
		riseTimeAngle = avgTransitAngle - leafWidth / 2 - .00001;  // Make them a tad bigger so we don't lose the info later  // [stevep 11/14/09]: ??? what info? should this have been on the summer case?
		setTimeAngle = avgTransitAngle + leafWidth / 2 + .00001;
		polarWinter = true;
	    }
	} else {  // rise invalid, set valid
	    if (EC_nansEqual(riseTimeAngle, kECAlwaysAboveHorizon)) {
		riseTimeAngle = setTimeAngle - (2 * M_PI);
		polarSummer = true;
	    } else {
		riseTimeAngle = setTimeAngle - leafWidth;
		polarWinter = true;
	    }
	}
    } else {
	if (isnan(setTimeAngle)) {
	    if (EC_nansEqual(setTimeAngle, kECAlwaysAboveHorizon)) {
		setTimeAngle = riseTimeAngle + (2 * M_PI);
		polarSummer = true;
	    } else {
		setTimeAngle = riseTimeAngle + leafWidth;
		polarWinter = true;
	    }
	}
    }
    if (isSpecial) {
	if (leafNumber == 2) {
	    return polarSummer;
	} else if (leafNumber == 3) {
	    return polarWinter;
	} else {
	    assert(false);
	}
    }
    assert(!isnan(riseTimeAngle));
    assert(!isnan(setTimeAngle));
    riseTimeAngle = EC_fmod(riseTimeAngle, 2 * M_PI);
    setTimeAngle = EC_fmod(setTimeAngle, 2 * M_PI);
    if (setTimeAngle <= riseTimeAngle + 0.0001) {
	setTimeAngle += 2 * M_PI;
    }
    if (nightTime) {
	setTimeAngle += leafWidth/2;
	riseTimeAngle -= leafWidth/2;
    } else {
	setTimeAngle -= leafWidth/2;
	riseTimeAngle += leafWidth/2;
    }

    if (setTimeAngle < riseTimeAngle) {
	riseTimeAngle = setTimeAngle = (riseTimeAngle + setTimeAngle) / 2;
    }
    double leafCenterAngle;
    if (nightTime) {
	leafCenterAngle = setTimeAngle + (2*M_PI - setTimeAngle + riseTimeAngle) / (numLeaves - 1) * leafNumber;
    } else {
	leafCenterAngle = riseTimeAngle + (setTimeAngle - riseTimeAngle) / (numLeaves - 1) * leafNumber;
    }

    if (leafCenterAngle > 2 * M_PI) {
	leafCenterAngle -= 2 * M_PI;
    }
    assert(!isnan(leafCenterAngle));
    return leafCenterAngle;
}

-(double)dayNightLeafAngleForPlanetNumber:(int)planetNumber
			       leafNumber:(double)leafNumber
				numLeaves:(int)numLeaves {
    return [self dayNightLeafAngleForPlanetNumber:planetNumber
                                       leafNumber:leafNumber
                                        numLeaves:numLeaves
                                     timeBaseKind:ECTimeBaseKindLT];
}

-(ECWatchTime *)watchTimeWithSunriseForDay {
    NSTimeInterval date = [self sunriseForDay];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithSunsetForDay {
    NSTimeInterval date = [self sunsetForDay];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithSuntransitForDay {
    NSTimeInterval date = [self suntransitForDay];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithNextSunrise {
    NSTimeInterval date = [self nextSunrise];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPrevSunrise {
    NSTimeInterval date = [self prevSunrise];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithNextSunset {
    NSTimeInterval date = [self nextSunset];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPrevSunset {
    NSTimeInterval date = [self prevSunset];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithMoonriseForDay {
    NSTimeInterval date = [self moonriseForDay];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithMoonsetForDay {
    NSTimeInterval date = [self moonsetForDay];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithMoontransitForDay {
    NSTimeInterval date = [self moontransitForDay];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithNextMoonrise {
    NSTimeInterval date = [self nextMoonrise];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPrevMoonrise {
    NSTimeInterval date = [self prevMoonrise];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithNextMoonset {
    NSTimeInterval date = [self nextMoonset];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPrevMoonset {
    NSTimeInterval date = [self prevMoonset];
    if (isnan(date)) {
	date = [self moonMeridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithNextPlanetrise:(int)planetNumber {
    NSTimeInterval date = [self nextPlanetriseForPlanetNumber:planetNumber];
    if (isnan(date)) {
	date = [self nextPlanettransit:planetNumber];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPrevPlanetrise:(int)planetNumber {
    NSTimeInterval date = [self prevPlanetriseForPlanetNumber:planetNumber];
    if (isnan(date)) {
	date = [self prevPlanettransit:planetNumber];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithNextPlanetset:(int)planetNumber {
    NSTimeInterval date = [self nextPlanetsetForPlanetNumber:planetNumber];
    if (isnan(date)) {
	date = [self nextPlanettransit:planetNumber];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPrevPlanetset:(int)planetNumber {
    NSTimeInterval date = [self prevPlanetsetForPlanetNumber:planetNumber];
    if (isnan(date)) {
	date = [self prevPlanettransit:planetNumber];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPlanetriseForDay:(int)planetNumber {
    NSTimeInterval date = [self planetriseForDay:planetNumber];
    if (isnan(date)) {
	date = [self planettransitForDay:planetNumber];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPlanetsetForDay:(int)planetNumber {
    NSTimeInterval date = [self planetsetForDay:planetNumber];
    if (isnan(date)) {
	date = [self planettransitForDay:planetNumber];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithPlanettransitForDay:(int)planetNumber {
    NSTimeInterval date = [self planettransitForDay:planetNumber];
    if (isnan(date)) {
	date = [self meridianTimeForSeason];
    }
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithClosestNewMoon {
    NSTimeInterval date = [self closestNewMoon];
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithClosestFullMoon {
    NSTimeInterval date = [self closestFullMoon];
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithClosestFirstQuarter {
    NSTimeInterval date = [self closestFirstQuarter];
    return [self watchTimeForInterval:date];
}

-(ECWatchTime *)watchTimeWithClosestThirdQuarter {
    NSTimeInterval date = [self closestThirdQuarter];
    return [self watchTimeForInterval:date];
}

// special ops for Mauna Kea
-(bool)sunriseIndicatorValid {
    if ([environment runningBackward]) {
	return ([self planetIsUp:ECPlanetSun] ? [self nextSunriseValid] : [self prevSunriseValid]);
    } else {
	return ([self planetIsUp:ECPlanetSun] ? [self prevSunriseValid] : [self nextSunriseValid]);
    }
}
-(bool)sunsetIndicatorValid {
    if ([environment runningBackward]) {
	return ([self planetIsUp:ECPlanetSun] ? [self prevSunsetValid] : [self nextSunsetValid]);
    } else {
	return ([self planetIsUp:ECPlanetSun] ? [self nextSunsetValid] : [self prevSunsetValid]);
    }
}

-(double)sunrise24HourIndicatorAngle {
    return [self dayNightLeafAngleForPlanetNumber:ECPlanetSun leafNumber:0 numLeaves:0];
}

-(double)sunset24HourIndicatorAngle {
    return [self dayNightLeafAngleForPlanetNumber:ECPlanetSun leafNumber:1 numLeaves:0];
}

-(bool)polarSummer {
    return [self dayNightLeafAngleForPlanetNumber:ECPlanetSun leafNumber:2 numLeaves:0];
}

-(bool)polarWinter {
    return [self dayNightLeafAngleForPlanetNumber:ECPlanetSun leafNumber:3 numLeaves:0];
}

-(double)moonrise24HourIndicatorAngle {
    return [self dayNightLeafAngleForPlanetNumber:ECPlanetMoon leafNumber:0 numLeaves:0];
}

-(double)moonset24HourIndicatorAngle {
    return [self dayNightLeafAngleForPlanetNumber:ECPlanetMoon leafNumber:1 numLeaves:0];
}

-(double)planetrise24HourIndicatorAngle:(int)planetNumber {
    return [self dayNightLeafAngleForPlanetNumber:planetNumber leafNumber:0 numLeaves:0];
}

-(double)planetset24HourIndicatorAngle:(int)planetNumber {
    return [self dayNightLeafAngleForPlanetNumber:planetNumber leafNumber:1 numLeaves:0];
}

-(double)planettransit24HourIndicatorAngle:(int)planetNumber forNumLeaves:(int)numLeaves {
    return [self dayNightLeafAngleForPlanetNumber:planetNumber leafNumber:(numLeaves/2.0) numLeaves:numLeaves];
}

-(double)planetrise24HourIndicatorAngleLST:(int)planetNumber {
    return [self dayNightLeafAngleForPlanetNumber:planetNumber leafNumber:0 numLeaves:0 timeBaseKind:ECTimeBaseKindLST];
}

-(double)planetset24HourIndicatorAngleLST:(int)planetNumber {
    return [self dayNightLeafAngleForPlanetNumber:planetNumber leafNumber:1 numLeaves:0 timeBaseKind:ECTimeBaseKindLST];
}

#if 0 // save to record WB precession formula
static void testRAPrecessionForDate(double centuriesSinceEpochTDT) {
    double T = centuriesSinceEpochTDT / 10;
    double T2 = T*T;
    double T3 = T2*T;
    double T4 = T2*T2;
    double T5 = T3*T2;
    double T6 = T3*T3;
    double T7 = T4*T3;
    double pa03 = generalPrecessionSinceJ2000(centuriesSinceEpochTDT);
    double pawb = 50290.966*T + 111.1971*T2 + 0.07732*T3 - 0.235316*T4 - 0.0018055*T5 + 0.00017451*T6 + 0.000013095*T7;
    pawb = pawb * M_PI/(3600 * 180);
    printf("\nprecession for %15.10f centuries since J2000\n", centuriesSinceEpochTDT);
    printAngle(pa03, "pa03");
    printAngle(pawb, "pawb");
    
}
#endif

-(id)initFromEnvironment:(ECWatchEnvironment *)envir watchTime:(ECWatchTime *)aWatchTime {
    [super init];
    environment = envir; // no retain; we are the ownee, not the owner
    watchTime = aWatchTime;
    estz = nil;
    calculationDateInterval = 0;
    observerLatitude = 0;
    observerLongitude = 0;
    inActionButton = 0;

#ifndef NDEBUG
    //[self testPolarEdge];
    //exit(0);
    //testConversion();
    //[self runTests];  // DEBUG: REMOVE
    //[self testReligion];	// DEBUG
//    static bool tested = false;
//    if (!tested) {
//	testConvertJ2000();
//	testRAPrecessionForDate(-1);
//	for(int i = -3; i < 27; i++) {
//	    testRAPrecessionForDate(-i * 10);
//	}
//	for(int i = 210; i < 220; i++) {
//	    testRAPrecessionForDate(-i);
//	}
//	for(int i = 0; i < 27; i++) {
//	    generalPrecessionSinceJ2000(-i * 10);
//	}
//	tested = true;
//    }
#endif

    return self;
}

@end
