//
//  ECWillmannBell.m
//  Emerald Chronometer
//
//  Created by Steve Pucci in March 2009
//  Copyright Emerald Sequoia 2009. All rights reserved.
//
//  Portions derived from "Lunar Tables and Programs from 4000 B.C. to A.D. 8000",
//    by Michelle Chapront-Touze & Jean Chapront,
//    copyright 1991
//    published by Willmann-Bell, Inc.
//
//  Portions derived from "Planetary Programs and Tables from -4000 to +2800",
//    by Pierre Bretagnon & Jean-Louis Simon
//    copyright 1986
//    published by Willmann-Bell, Inc.
//

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <math.h>
#include <string.h>

#include "Lunar/ECWBLunarTable.h"
#include "Planets/ECWBPlanetsTable.h"

#include "../Classes/Constants.h"
#include "../Classes/ECAstronomy.h"
#include "../Classes/ECAstronomyCache.h"

#include "ECWillmannBell.h"

static void
printAngle(double      angle,
	   const char *description) {
//    if (!printingEnabled) {
//	return;
//    }
    int sign = angle < 0 ? -1 : 1;
    double absAngle = fabs(angle);
    int degrees = sign * (int)(((long long int)floor(absAngle * 180/M_PI)));
    int arcMinutes = (int)(((long long int)floor(absAngle * 180/M_PI * 60)) % 60);
    int arcSeconds = (int)(((long long int)floor(absAngle * 180/M_PI * 3600)) % 60);
    int arcSecondHundredths = (int)(((long long int)floor(absAngle * 180/M_PI * 360000)) % 100);
    int hours = sign * (int)(((long long int)floor(absAngle * 12/M_PI)));
    int minutes = (int)(((long long int)floor(absAngle * 12/M_PI * 60)) % 60);
    int seconds = (int)(((long long int)floor(absAngle * 12/M_PI * 3600)) % 60);
    int secondHundredths = (int)(((long long int)floor(absAngle * 12/M_PI * 360000)) % 100);
    printf("%16.8fr %16.8fd %5do%02d'%02d.%02d\" %16.8fh %5dh%02dm%02d.%02ds  %s\n",
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
	   description);
}
static void printAngle2(double     angle,
			const char *desc1,
			const char *desc2) {
    char *description = (char *)malloc(strlen(desc1) + strlen(desc2) + 3);  // ': ' + \0 = 3 extra chars
    sprintf(description, "%s: %s", desc1, desc2);
    printAngle(angle, description);
    free(description);
}

#ifndef STANDALONE
#include "ECGlobals.h"
#endif

#ifdef STANDALONE  // COPY OF CODE FROM ECAstronomy.m for testing purposes...
static double
EC_fmod(double arg1,
	double arg2)
{
    return (arg1 - floor(arg1/arg2)*arg2);
}

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
#endif

static enum {
    ETUseChapront,
    ETUseBretagnon,
    ETUseMeeus
} ETConversionMethod = ETUseMeeus;

// From MCT/JP sec 4.2 p8
static double JDForDate(int yr,   // 1986, or -2 for 3 BC
			int mo,   // 1-12
			int dy,   // 1-31
			int hr,
			int mi,
			int sc) {
    assert(mo >= 1 && mo <= 12);
    int yprime;
    int mprime;
    if (mo > 2) {
	mprime = mo;
	yprime = yr;
    } else {
	mprime = mo + 12;
	yprime = yr - 1;
    }
    double C;
    int yearSign;
    int absYprime;
    if (yprime < 0) {
	C = -0.75;
	yearSign = -1;
	absYprime = -yprime;
    } else {
	C = 0;
	yearSign = 1;
	absYprime = yprime;
    }
    //printf("C = %.2f\n", C);
    int B;
    if (yr < 1582 ||
	(yr == 1582 &&
	 (mo < 10 ||
	  (mo == 10 &&
	   dy < 5)))) {
	B = 0;
    } else {
	int A = absYprime / 100;
	//printf("A = %d (from absYprime %d)\n", A, absYprime);
	B = 2 - A + A / 4;
	B *= yearSign;
    }
    //printf("B = %d\n", B);
    double JD = 1720994.5 + (int)(365.25 * yprime + C) + (int)(30.60001*(mprime + 1)) + dy + B + hr/24.0 + mi/1440.0 + sc/86400.0;
    return JD;
}

// Return # centuries since J2000 (2000 January 1 12h)
static double TDTForTDTDate(int yr,   // 1986, or -2 for 3 BC
			    int mo,   // 1-12
			    int dy,
			    int hr,
			    int mi,
			    int sc) {
    double JD = JDForDate(yr, mo, dy, hr, mi, sc);
    return (JD - 2451545)/36525;
}

// Processed via Perl from the following table in LUNEF1.FOR:
//        DATA IDTSM/80,78,75,73,70,68,65,52,43,36,30,26,20,
//     1  16,10,6,1,-2,-3,-4,2*-3,-2,-1,0,2*1,2*3,2*5,6,8,
//     2  2*9,6*11,7*12,4*11,3*10,4*9,8*8,10*9,3*8,2*7,3*6,
//     3  2*5,2*4,10*3,5*4,6*5,9*6,2*5,2*4,3,1,2*0,-1,-2,-3,
//     4  2*-4,-5,8*-6,4*-7,-6,7*-7,-6,-5,-4,-3,-2,-1,1,2,3,
//     5  5,6,7,9,10,11,13,14,16,17,18,19,20,2*21,2*22,3*23,
//     6  15*24,2*25,2*26,2*27,2*28,2*29,3*30,3*31,2*32,2*33,
//     7  3*34,35,36,2*37,38,39,40,41,42,43,44,45,46,48,49,50,
//     8  2*51,52,53,2*54,2*55,2*56,57/
static int lunarDeltaTTable1[] = {
    80,78,75,73,70,68,65,52,43,36,30,26,20,
    16,10,6,1,-2,-3,-4,-3,-3,-2,-1,0,1,1,3,3,5,5,6,8,
    9,9,11,11
};
static int lunarDeltaTTable2[] = {
    11,11,11,11,12,12,12,12,12,12,12,11,11,11,11,10,10,10,9,9,9,9,8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9,9,9,8,8,8,7,7,6,6,6,
    5,5,4,4,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,5,5,4,4,3,1,0,0,-1,-2,-3,
    -4,-4,-5,-6,-6,-6,-6,-6,-6,-6,-6,-7,-7,-7,-7,-6,-7,-7,-7,-7,-7,-7,-7,-6,-5,-4,-3,-2,-1,1,2,3,
    5,6,7,9,10,11,13,14,16,17,18,19,20,21,21,22,22,23,23,23,
    24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,25,25,26,26,27,27,28,28,29,29,30,30,30,31,31,31,32,32,33,33,
    34,34,34,35,36,37,37,38,39,40,41,42,43,44,45,46,48,49,50,
    51,51,52,53,54,54,55,55,56,56,57
};

// Constants obtained from LUNEF1.FOR SUBROUTINE TU
static double deltaTForUT_Chapront(double t) {
    static const double T1 = -10.519658;
    static const double T2 =  -3.999932;
    static const double T3 =  -2.199959;
    static const double T4 =  -0.0900068;
    if (t < T1) {
	// formula 2, sec 4.1 p6
	return 2177 + 495 * t + 42.4 * t * t;
    } else if (t < T2) {
	// formula 1, sec 4.1 p6
	return 102 + 100 * t + 23.6 * t * t;
    } else if (t < T3) {
	int indx = (int)((t - T2)*20);
	assert(indx >= 0 && indx <= (sizeof(lunarDeltaTTable1) / sizeof(int)));
	return lunarDeltaTTable1[indx];
    } else if (t < T4) {
	int indx = (int)((t - T3)*100);
	if (indx > 0) {
	    indx--;
	}
	//printf("indx = %d\n", indx);
	assert(indx >= 0 && indx <= (sizeof(lunarDeltaTTable2) / sizeof(int)));
	return lunarDeltaTTable2[indx];
    } else {
	return 0;  // FIX: Is this right?
    }
}

extern double ECMeeusDeltaT(double yearValue);  // year value as in 2008.5 for July 1 (approx)

static double deltaTForUT_Meeus(double t) {
    double yearValue = t*100 + 2000;
    return ECMeeusDeltaT(yearValue);
}

static double deltaTForUT_Bretagnon(double UTCenturies) {
    static const double DJ1800 = (2378497.0/36525.0);

    double jd = UTCenturies * 36525 + 2451545;
    double jdCenturies = jd/36525;;
	  
    double tSince1800 = (jdCenturies - DJ1800) - 0.1;  // centuries
    double deltaTSeconds = -15 + 32.5*(tSince1800*tSince1800);
    return deltaTSeconds;
}

static double deltaTForUT(double t) {
    switch(ETConversionMethod) {
      case ETUseChapront:
	return deltaTForUT_Chapront(t);
      case ETUseBretagnon:
	return deltaTForUT_Bretagnon(t);
      case ETUseMeeus:
	// fallthru
      default:
	return deltaTForUT_Meeus(t);
    }
} 

// return in centuries since 2000 epoch
static double TDTForUTDate(int yr,   // 1986, or -2 for 3 BC
			   int mo,   // 1-12
			   int dy,
			   int hr,
			   int mi,
			   int sc) {
    double t = TDTForTDTDate(yr, mo, dy, hr, mi, sc);
    double deltaT = deltaTForUT(t);  // input: centuries; output in seconds
    return t + deltaT/(36525. * 24. * 3600.);
}

// Returns DEGREES
static double lunarLongitudeForTDT(double        t,
				   ECWBPrecision p,
				   ECAstroCache  *currentCache) {
    assert(p >= ECWBLowPrecision && p <= ECWBFullPrecision);
    assertCacheValidForTDTCenturies(currentCache, t);
    int slotIndex = WBLunarLongitudeLowSlotIndex + p;
    double V;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	V = currentCache->cacheSlots[slotIndex];
    } else {
	double SV = 0;
	//printf("Nv %d\n", Nv[p]);
	const SvDatum *end = Sv + Nv[p];
	double t2 = t*t;
	double t3 = t*t2;
	double t4 = t2*t2;
	for (const SvDatum *datum = Sv; datum < end; datum++) {
	    double sinArg =
		datum->an0 +
		datum->an1 * t +
		datum->an2 * t2 * 1E-4 +
		datum->an3 * t3 * 1E-6 +
		datum->an4 * t4 * 1E-8;
	    SV += datum->vn * sin((M_PI / 180) * sinArg);
	}
	//printf("SV %.4f\n", SV);
	double SV1 = 0;
	//printf("N1v %d\n", N1v[p]);
	const Sv1Datum *end1 = Sv1 + N1v[p];
	for (const Sv1Datum *datum = Sv1; datum < end1; datum++) {
	    //printf("datum: vn=%.2f, an0=%.2f, an1=%.2f\n", datum->vn, datum->an0, datum->an1);
	    double sinArg =
		datum->an0 +
		datum->an1 * t;
	    SV1 += datum->vn * sin((M_PI / 180) * sinArg);
	}
	//printf("SV1 %.4f\n", SV1);
	//printf("N2v %d\n", N2v[p]);
	double SV2 = 0;
	const Sv2Datum *end2 = Sv2 + N2v[p];
	for (const Sv2Datum *datum = Sv2; datum < end2; datum++) {
	    double sinArg =
		datum->an0 +
		datum->an1 * t;
	    SV2 += datum->vn * sin((M_PI / 180) * sinArg);
	}
	//printf("SV2 %.4f\n", SV2);
	//printf("N3v %d\n", N3v[p]);
	double SV3 = 0;
	const Sv3Datum *end3 = Sv3 + N3v[p];
	for (const Sv3Datum *datum = Sv3; datum < end3; datum++) {
	    double sinArg =
		datum->an0 +
		datum->an1 * t;
	    SV3 += datum->vn * sin((M_PI / 180) * sinArg);
	}
	//printf("SV3 %.4f\n", SV3);
	//printf("t %.4f\n", t);
	V = 218.31665436 +
	    481267.88134240 * t -
	    13.268E-4 * t2 +
	    1.856E-6 * t3 -
	    1.534E-8 * t4 +
	    SV +
	    (1E-3)*(SV1 + t * SV2 + t2*(1E-4)*SV3);
	//printf("V %.4f\n", V);
	V = EC_fmod(V, 360.0);
	//printf("V %.4f\n", V);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = V;
	}
    }
    return V;
}

// Returns DEGREES
static double lunarLatitudeForTDT(double        t,
				  ECWBPrecision p,
				  ECAstroCache  *currentCache) {
    assert(p >= ECWBLowPrecision && p <= ECWBFullPrecision);
    assertCacheValidForTDTCenturies(currentCache, t);
    int slotIndex = WBLunarLatitudeLowSlotIndex + p;
    double U;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	U = currentCache->cacheSlots[slotIndex];
    } else {
	double SU = 0;
	//printf("Nu %d\n", Nu[p]);
	const SuDatum *end = Su + Nu[p];
	double t2 = t*t;
	double t3 = t*t2;
	double t4 = t2*t2;
	for (const SuDatum *datum = Su; datum < end; datum++) {
	    double sinArg =
		datum->bn0 +
		datum->bn1 * t +
		datum->bn2 * t2 * 1E-4 +
		datum->bn3 * t3 * 1E-6 +
		datum->bn4 * t4 * 1E-8;
	    SU += datum->un * sin((M_PI / 180) * sinArg);
	}
	//printf("SU %.4f\n", SU);
	double SU1 = 0;
	//printf("N1u %d\n", N1u[p]);
	const Su1Datum *end1 = Su1 + N1u[p];
	for (const Su1Datum *datum = Su1; datum < end1; datum++) {
	    //printf("datum: un=%.2f, bn0=%.2f, bn1=%.2f\n", datum->un, datum->bn0, datum->bn1);
	    double sinArg =
		datum->bn0 +
		datum->bn1 * t;
	    SU1 += datum->un * sin((M_PI / 180) * sinArg);
	}
	//printf("SU1 %.4f\n", SU1);
	//printf("N2u %d\n", N2u[p]);
	double SU2 = 0;
	const Su2Datum *end2 = Su2 + N2u[p];
	for (const Su2Datum *datum = Su2; datum < end2; datum++) {
	    double sinArg =
		datum->bn0 +
		datum->bn1 * t;
	    SU2 += datum->un * sin((M_PI / 180) * sinArg);
	}
	//printf("SU2 %.4f\n", SU2);
	//printf("N3u %d\n", N3u[p]);
	double SU3 = 0;
	const Su3Datum *end3 = Su3 + N3u[p];
	for (const Su3Datum *datum = Su3; datum < end3; datum++) {
	    double sinArg =
		datum->bn0 +
		datum->bn1 * t;
	    SU3 += datum->un * sin((M_PI / 180) * sinArg);
	}
	//printf("SU3 %.4f\n", SU3);
	//printf("t %.4f\n", t);
	U = SU +
	    (1E-3)*(SU1 + t * SU2 + t2*(1E-4)*SU3);
	//printf("U %.4f\n", U);
	U = EC_fmod(U, 360.0);
	if (U > 180) {
	    U -= 360;
	}
	//printf("U %.4f\n", U);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = U;
	}
    }
    return U;
}

// Returns km
static double lunarDistanceForTDT(double        t,
				  ECWBPrecision p,
				  ECAstroCache  *currentCache) {
    assert(p >= ECWBLowPrecision && p <= ECWBFullPrecision);
    assertCacheValidForTDTCenturies(currentCache, t);
    int slotIndex = WBLunarDistanceLowSlotIndex + p;
    double R;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	R = currentCache->cacheSlots[slotIndex];
    } else {
	double SR = 0;
	//printf("Nr %d\n", Nr[p]);
	const SrDatum *end = Sr + Nr[p];
	double t2 = t*t;
	double t3 = t*t2;
	double t4 = t2*t2;
	for (const SrDatum *datum = Sr; datum < end; datum++) {
	    double cosArg =
		datum->dn0 +
		datum->dn1 * t +
		datum->dn2 * t2 * 1E-4 +
		datum->dn3 * t3 * 1E-6 +
		datum->dn4 * t4 * 1E-8;
	    SR += datum->rn * cos((M_PI / 180) * cosArg);
	}
	//printf("SR %.4f\n", SR);
	double SR1 = 0;
	//printf("N1r %d\n", N1r[p]);
	const Sr1Datum *end1 = Sr1 + N1r[p];
	for (const Sr1Datum *datum = Sr1; datum < end1; datum++) {
	    //printf("datum: rn=%.2f, dn0=%.2f, dn1=%.2f\n", datum->rn, datum->dn0, datum->dn1);
	    double cosArg =
		datum->dn0 +
		datum->dn1 * t;
	    SR1 += datum->rn * cos((M_PI / 180) * cosArg);
	}
	//printf("SR1 %.4f\n", SR1);
	//printf("N2r %d\n", N2r[p]);
	double SR2 = 0;
	const Sr2Datum *end2 = Sr2 + N2r[p];
	for (const Sr2Datum *datum = Sr2; datum < end2; datum++) {
	    double cosArg =
		datum->dn0 +
		datum->dn1 * t;
	    SR2 += datum->rn * cos((M_PI / 180) * cosArg);
	}
	//printf("SR2 %.4f\n", SR2);
	//printf("N3r %d\n", N3r[p]);
	double SR3 = 0;
	const Sr3Datum *end3 = Sr3 + N3r[p];
	for (const Sr3Datum *datum = Sr3; datum < end3; datum++) {
	    double cosArg =
		datum->dn0 +
		datum->dn1 * t;
	    SR3 += datum->rn * cos((M_PI / 180) * cosArg);
	}
	//printf("SR3 %.4f\n", SR3);
	//printf("t %.4f\n", t);
	R = 385000.57 +
	    SR + SR1 + t * SR2 + t2*(1E-4)*SR3;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = R;
	}
    }
    return R;
}

// returns radians
static double meanObliquityFromTDT(double t) {
    double t2 = t*t;
    double t3 = t*t2;
    double t4 = t2*t2;
    return (M_PI/180) * (23.43928 - 0.013*t + 0.555E-6*t3 - 0.014E-8*t4);
}

// returns radians
static void nutations(double centuriesSinceEpochTDT,
		      double *longitudeNutation,
		      double *obliquityNutation) {
    double t = centuriesSinceEpochTDT;
    double longNut = 0;
    double obliqueNut = 0;
    int iterations = NNut[ECWBFullPrecision];
    double t2 = t*t;
    for (int i = 0; i < iterations; i++) {
	const NutationDatum *datum = &NutationData[i];
	double arg = (datum->mu0n + datum->mu1n * t + datum->mu2n * t2) * M_PI / 180;
	longNut += (datum->psin + datum->psi1n * t) * sin(arg);
	if (i < 4 || (i > 5 && i < 9)) {
	    obliqueNut += (datum->obn + datum->ob1n * t) * cos(arg);
	}
    }
    *longitudeNutation = longNut * M_PI / 180;
    *obliquityNutation = obliqueNut * M_PI / 180;
}

// returns radians
static void moonRightAscensionAndDeclForTDT(double V,  // radians
					    double U,  // radians
					    double centuriesSinceEpochTDT,
					    double *ra,     // radians
					    double *decl) { // radians
    //printAngle(V, "V+DV");
    //printAngle(U, "U+DU");
    double meanOb = meanObliquityFromTDT(centuriesSinceEpochTDT);
    double longitudeNutation;
    double obliquityNutation;
    nutations(centuriesSinceEpochTDT, &longitudeNutation, &obliquityNutation);
    //printAngle(meanOb, "meanObliquity");
    //printAngle(longitudeNutation, "longitudeNutation");
    //printAngle(obliquityNutation, "obliquityNutation");
    V += longitudeNutation;
    //printAngle(V, "VT");
    double trueOb = meanOb + obliquityNutation;
    //printAngle(trueOb, "trueObliquity");
    double cosV = cos(V);
    double sinV = sin(V);
    double sinU = sin(U);
    double cosU = cos(U);
    double cosTrueOb = cos(trueOb);
    double sinTrueOb = sin(trueOb);
    if (cosV == 0) {
	*ra = V;
    } else {
	*ra = atan2((cosTrueOb*sinV*cosU - sinTrueOb*sinU),
		    cosV * cosU);
	if (*ra < 0) {
	    *ra += M_PI * 2;
	}
    }
    *decl = asin(sinTrueOb*sinV*cosU + cosTrueOb*sinU);
}

static double lunarAberrationV(double t) {
    return M_PI/180*(-0.00019524 - 0.00001059*sin((225 + 477198.9*t)*M_PI/180));
}

static double lunarAberrationU(double t) {
    return M_PI/180*(-0.00001754*sin((183.3 + 483202.0*t)*M_PI/180));
}

static double lunarAberrationR(double t) {
    return M_PI/180*(0.0708*cos((225 + 477198.9*t)*M_PI/180));
}

void WB_MoonRAAndDecl(double 	    centuriesSinceEpochTDT,
		      double 	    *rightAscensionReturn,
		      double 	    *declinationReturn,
		      double 	    *longitudeReturn,
		      double 	    *latitudeReturn,
		      ECAstroCache  *currentCache,
		      ECWBPrecision p) {
    assertCacheValidForTDTCenturies(currentCache, centuriesSinceEpochTDT);
    int raSlotIndex = WBMoonRALowSlotIndex + p;
    int declSlotIndex = WBMoonDeclLowSlotIndex + p;
    int longSlotIndex = WBMoonEclipticLongitudeLowSlotIndex + p;
    int latSlotIndex = WBMoonEclipticLatitudeLowSlotIndex + p;
    if (currentCache && currentCache->cacheSlotValidFlag[raSlotIndex] == currentCache->currentFlag) {
	assert(currentCache->cacheSlotValidFlag[declSlotIndex] == currentCache->currentFlag);
	assert(currentCache->cacheSlotValidFlag[longSlotIndex] == currentCache->currentFlag);
	assert(currentCache->cacheSlotValidFlag[latSlotIndex] == currentCache->currentFlag);
	*rightAscensionReturn = currentCache->cacheSlots[raSlotIndex];
	*declinationReturn = currentCache->cacheSlots[declSlotIndex];
	*longitudeReturn = currentCache->cacheSlots[longSlotIndex];
	*latitudeReturn = currentCache->cacheSlots[latSlotIndex];
    } else {
	assert(!currentCache || currentCache->cacheSlotValidFlag[declSlotIndex] != currentCache->currentFlag);
	//printf("%d-%d-%d %d:%d:%d\n", gmtcs.year, gmtcs.month, gmtcs.day, gmtcs.hour, gmtcs.minute, gmtcs.second);
	//double t = TDTForUTDate(gmtcs.year, gmtcs.month, gmtcs.day, gmtcs.hour, gmtcs.minute, gmtcs.second);
	//printf("Calcluated t = %.10f\n", t);
	//printf("passed in  t = %.10f\n", centuriesSinceEpochTDT);
	double V = lunarLongitudeForTDT(centuriesSinceEpochTDT, p, currentCache);
	//printAngle(V*M_PI/180, "V");
	double U = lunarLatitudeForTDT(centuriesSinceEpochTDT, p, currentCache);
	//printAngle(U*M_PI/180, "U");
	*longitudeReturn = V*M_PI/180 + lunarAberrationV(centuriesSinceEpochTDT);
	*latitudeReturn = U*M_PI/180 + lunarAberrationU(centuriesSinceEpochTDT);
	moonRightAscensionAndDeclForTDT(*longitudeReturn, *latitudeReturn, centuriesSinceEpochTDT, rightAscensionReturn, declinationReturn);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[raSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[declSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[longSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[latSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[raSlotIndex] = *rightAscensionReturn;
	    currentCache->cacheSlots[declSlotIndex] = *declinationReturn;
	    currentCache->cacheSlots[longSlotIndex] = *longitudeReturn;
	    currentCache->cacheSlots[latSlotIndex] = *latitudeReturn;
	}
    }
}

double WB_MoonEclipticLongitude(double        centuriesSinceEpochTDT,
				ECAstroCache  *currentCache,
				ECWBPrecision p) {
    assertCacheValidForTDTCenturies(currentCache, centuriesSinceEpochTDT);
    int slotIndex = WBMoonEclipticLongitudeLowSlotIndex + p;
    double Vr;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	Vr = currentCache->cacheSlots[slotIndex];
    } else {
	double V = lunarLongitudeForTDT(centuriesSinceEpochTDT, p, currentCache);
	Vr = V*M_PI/180 + lunarAberrationV(centuriesSinceEpochTDT);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = Vr;
	}
    }
    return Vr;
}

double WB_MoonEclipticLatitude(double        centuriesSinceEpochTDT,
			       ECAstroCache  *currentCache,
			       ECWBPrecision p) {
    assertCacheValidForTDTCenturies(currentCache, centuriesSinceEpochTDT);
    int slotIndex = WBMoonEclipticLatitudeLowSlotIndex + p;
    double Ur;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	Ur = currentCache->cacheSlots[slotIndex];
    } else {
	double U = lunarLatitudeForTDT(centuriesSinceEpochTDT, p, currentCache);
	Ur = U*M_PI/180 + lunarAberrationU(centuriesSinceEpochTDT);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = Ur;
	}
    }
    return Ur;
}

double WB_MoonDistance(double        centuriesSinceEpochTDT,
		       ECAstroCache  *currentCache,
		       ECWBPrecision p) {
    assertCacheValidForTDTCenturies(currentCache, centuriesSinceEpochTDT);
    int slotIndex = WBMoonDistanceLowSlotIndex + p;
    double R;
    if (currentCache && currentCache->cacheSlotValidFlag[slotIndex] == currentCache->currentFlag) {
	R = currentCache->cacheSlots[slotIndex];
	assert(R > 0);
    } else {
	R = lunarDistanceForTDT(centuriesSinceEpochTDT, p, currentCache);
	assert(R > 0);
	R += lunarAberrationR(centuriesSinceEpochTDT);
	assert(R > 0);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[slotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[slotIndex] = R;
	}
    }
    return R;
}

// radians
static double ascendingNodeLongitude(double        centuriesSinceEpochTDT,
				     ECWBPrecision p,
				     ECAstroCache  *currentCache) {
    assertCacheValidForTDTCenturies(currentCache, centuriesSinceEpochTDT);
    double L;
    if (currentCache && currentCache->cacheSlotValidFlag[WBAscendingNodeLongitudeSlotIndex] == currentCache->currentFlag) {
	L = currentCache->cacheSlots[WBAscendingNodeLongitudeSlotIndex];
    } else {
	double t = centuriesSinceEpochTDT;
	double Vdot;
	{
	    //printf("Nv %d\n", Nv[p]);
	    double SVdot = 0;
	    const SvDatum *end = Sv + Nv[p];
	    double t2 = t*t;
	    double t3 = t*t2;
	    double t4 = t2*t2;
	    for (const SvDatum *datum = Sv; datum < end; datum++) {
		double cosArg =
		    datum->an0 +
		    datum->an1 * t +
		    datum->an2 * t2 * 1E-4 +
		    datum->an3 * t3 * 1E-6 +
		    datum->an4 * t4 * 1E-8;
		double derivativeArg =
		    datum->an1 +
		    2 * datum->an2 * t  * 1E-4 +
		    3 * datum->an3 * t2 * 1E-6 +
		    4 * datum->an4 * t3 * 1E-8;
		SVdot += datum->vn * derivativeArg * cos((M_PI / 180) * cosArg);
	    }
	    SVdot *= (M_PI / 180);
	    //printf("SVdot %.4f\n", SVdot);
	    double SV1dot = 0;
	    //printf("N1v %d\n", N1v[p]);
	    const Sv1Datum *end1 = Sv1 + N1v[p];
	    for (const Sv1Datum *datum = Sv1; datum < end1; datum++) {
		//printf("datum: vn=%.2f, an0=%.2f, an1=%.2f\n", datum->vn, datum->an0, datum->an1);
		double cosArg =
		    datum->an0 +
		    datum->an1 * t;
		SV1dot += datum->vn * datum->an1 * cos((M_PI / 180) * cosArg);
	    }
	    SV1dot *= (M_PI / 180);
	    //printf("SV1dot %.4f\n", SV1dot);
	    //printf("N2v %d\n", N2v[p]);
	    double SV2dot = 0;
	    const Sv2Datum *end2 = Sv2 + N2v[p];
	    for (const Sv2Datum *datum = Sv2; datum < end2; datum++) {
		double cosArg =
		    datum->an0 +
		    datum->an1 * t;
		SV2dot += datum->vn * datum->an1 * cos((M_PI / 180) * cosArg);
	    }
	    SV2dot *= (M_PI / 180);
	    //printf("SV2dot %.4f\n", SV2dot);
	    //printf("N3v %d\n", N3v[p]);
	    double SV3dot = 0;
	    const Sv3Datum *end3 = Sv3 + N3v[p];
	    for (const Sv3Datum *datum = Sv3; datum < end3; datum++) {
		double cosArg =
		    datum->an0 +
		    datum->an1 * t;
		SV3dot += datum->vn * datum->an1 * cos((M_PI / 180) * cosArg);
	    }
	    SV3dot *= (M_PI / 180);
	    //printf("SV3dot %.4f\n", SV3dot);
	    //printf("t %.4f\n", t);
	    Vdot = 481267.881 - 0.0026536 * t + 0.05568E-4 * t2 - 0.06136E-6 * t3
		+ SVdot + 1E-3 * (SV1dot + t * SV2dot + t2 * SV3dot * 1E-4);
	}
	//printf("Vdot %.4f\n", Vdot);
	double Udot;
	{
	    double SUdot = 0;
	    const SuDatum *end = Su + Nu[p];
	    double t2 = t*t;
	    double t3 = t*t2;
	    double t4 = t2*t2;
	    for (const SuDatum *datum = Su; datum < end; datum++) {
		double cosArg =
		    datum->bn0 +
		    datum->bn1 * t +
		    datum->bn2 * t2 * 1E-4 +
		    datum->bn3 * t3 * 1E-6 +
		    datum->bn4 * t4 * 1E-8;
		double derivativeArg =
		    datum->bn1 +
		    2 * datum->bn2 * t  * 1E-4 +
		    3 * datum->bn3 * t2 * 1E-6 +
		    4 * datum->bn4 * t3 * 1E-8;
		SUdot += datum->un * derivativeArg * cos((M_PI / 180) * cosArg);
	    }
	    SUdot *= (M_PI / 180);
	    //printf("SUdot %.4f\n", SUdot);
	    double SU1dot = 0;
	    //printf("N1u %d\n", N1u[p]);
	    const Su1Datum *end1 = Su1 + N1u[p];
	    for (const Su1Datum *datum = Su1; datum < end1; datum++) {
		//printf("datum: un=%.2f, an0=%.2f, an1=%.2f\n", datum->un, datum->an0, datum->an1);
		double cosArg =
		    datum->bn0 +
		    datum->bn1 * t;
		SU1dot += datum->un * datum->bn1 * cos((M_PI / 180) * cosArg);
	    }
	    SU1dot *= (M_PI / 180);
	    //printf("SU1dot %.4f\n", SU1dot);
	    //printf("N2u %d\n", N2u[p]);
	    double SU2dot = 0;
	    const Su2Datum *end2 = Su2 + N2u[p];
	    for (const Su2Datum *datum = Su2; datum < end2; datum++) {
		double cosArg =
		    datum->bn0 +
		    datum->bn1 * t;
		SU2dot += datum->un * datum->bn1 * cos((M_PI / 180) * cosArg);
	    }
	    SU2dot *= (M_PI / 180);
	    //printf("SU2dot %.4f\n", SU2dot);
	    //printf("N3u %d\n", N3u[p]);
	    double SU3dot = 0;
	    const Su3Datum *end3 = Su3 + N3u[p];
	    for (const Su3Datum *datum = Su3; datum < end3; datum++) {
		double cosArg =
		    datum->bn0 +
		    datum->bn1 * t;
		SU3dot += datum->un * datum->bn1 * cos((M_PI / 180) * cosArg);
	    }
	    SU3dot *= (M_PI / 180);
	    //printf("SU3dot %.4f\n", SU3dot);
	    Udot = SUdot + 1E-3 * (SU1dot + t * SU2dot + 1E-4 * t2 * SU3dot);
	}
	//printf("Udot %.4f\n", Udot);
#if 0 // not needed for Omega
	double SRdot = 0;
	//printf("Nr %d\n", Nr[p]);
	const SrDatum *end = Sr + Nr[p];
	double t2 = t*t;
	double t3 = t*t2;
	double t4 = t2*t2;
	for (const SrDatum *datum = Sr; datum < end; datum++) {
	    double sinArg =
		datum->dn0 +
		datum->dn1 * t +
		datum->dn2 * t2 * 1E-4 +
		datum->dn3 * t3 * 1E-6 +
		datum->dn4 * t4 * 1E-8;
	    double derivativeArg =
		datum->dn1 +
		2 * datum->dn2 * t  * 1E-4 +
		3 * datum->dn3 * t2 * 1E-6 +
		4 * datum->dn4 * t3 * 1E-8;
	    SRdot += datum->rn * derivativeArg * sin((M_PI / 180) * sinArg);
	}
	SRdot = - M_PI/180 * SRdot;
	//printf("SRdot %.4f\n", SRdot);
	double SR1dot = 0;
	//printf("N1r %d\n", N1r[p]);
	const Sr1Datum *end1 = Sr1 + N1r[p];
	for (const Sr1Datum *datum = Sr1; datum < end1; datum++) {
	    //printf("datum: rn=%.2f, dn0=%.2f, dn1=%.2f\n", datum->rn, datum->dn0, datum->dn1);
	    double sinArg =
		datum->dn0 +
		datum->dn1 * t;
	    SR1dot += datum->rn * datum->dn1 * sin((M_PI / 180) * sinArg);
	}
	SR1dot = - M_PI/180 * SR1dot;
	//printf("SR1dot %.4f\n", SR1dot);
	//printf("N2r %d\n", N2r[p]);
	double SR2dot = 0;
	const Sr2Datum *end2 = Sr2 + N2r[p];
	for (const Sr2Datum *datum = Sr2; datum < end2; datum++) {
	    double sinArg =
		datum->dn0 +
		datum->dn1 * t;
	    SR2dot += datum->rn * datum->dn1 * sin((M_PI / 180) * sinArg);
	}
	SR2dot = - M_PI/180 * SR2dot;
	//printf("SR2dot %.4f\n", SR2dot);
	//printf("N3r %d\n", N3r[p]);
	double SR3dot = 0;
	const Sr3Datum *end3 = Sr3 + N3r[p];
	for (const Sr3Datum *datum = Sr3; datum < end3; datum++) {
	    double sinArg =
		datum->dn0 +
		datum->dn1 * t;
	    SR3dot += datum->rn * datum->dn1 * sin((M_PI / 180) * sinArg);
	}
	SR3dot = - M_PI/180 * SR3dot;
	//printf("SR3dot %.4f\n", SR3dot);
	double Rdot = SRdot + SR1dot + t * SR2dot + 1E-4 * t2 * SR3dot;
	//printf("Rdot %.4f\n", Rdot);
#endif
	double V = lunarLongitudeForTDT(centuriesSinceEpochTDT, p, currentCache); // DO WE NEED ABERRATION?
	//printf("V %.4f\n", V);
	double U = lunarLatitudeForTDT(centuriesSinceEpochTDT, p, currentCache);
	//printf("U %.4f\n", U);
#if 0 // not needed for Omega
	double R = lunarDistanceForTDT(centuriesSinceEpochTDT, p, currentCache);
	//printf("R %.4f\n", R);
#endif
	double cosU = cos(M_PI/180*U);
	double sinU = sin(M_PI/180*U);
	double cosV = cos(M_PI/180*V);
	double sinV = sin(M_PI/180*V);
#if 0 // not needed for Omega
	double X = Vdot * cosU * cosU;
	//printf("X %.4f\n", X);
#endif
	double Y = Udot * sinV - Vdot * sinU*cosU*cosV;
	//printf("Y %.4f\n", Y);
	double Z = Udot * cosV + Vdot * sinU*cosU*sinV;
	//printf("Z %.4f\n", Z);
#if 0 // not needed for Omega
	double W = sqrt(X*X + Y*Y + Z*Z);
	//printf("W %.4f\n", W);
#endif
	double Omega = atan2(Y, Z);
	L = EC_fmod(Omega, 2*M_PI);
	if (L < 0) {
	    L += 2 * M_PI;
	}
	//printAngle(L, "Omega");
    }
    return L; // radians
}

double WB_MoonAscendingNodeLongitude(double       centuriesSinceEpochTDT,
				     ECAstroCache *currentCache) {
    return ascendingNodeLongitude(centuriesSinceEpochTDT, ECWBFullPrecision, currentCache);
}

// *************  SUN AND PLANETS  ***************

// Without aberration, nutation
double WB_sunLongitudeRaw(double       hundredCenturiesSinceEpochTDT,
			  ECAstroCache *currentCache) {
    assertCacheValidForTDTHundredCenturies(currentCache, hundredCenturiesSinceEpochTDT);
    double U = hundredCenturiesSinceEpochTDT;
    double longitude;
    if (currentCache && currentCache->cacheSlotValidFlag[WBSunLongitudeSlotIndex] == currentCache->currentFlag) {
	longitude = currentCache->cacheSlots[WBSunLongitudeSlotIndex];
    } else {
	longitude = 0;
	for (int i = 0; i < numSunData; i++) {
	    const SunDatum *datum = &sunData[i];
	    double term = datum->ali + datum->bli*U;
	    longitude += datum->li * sin(term);
	}
	longitude = 1E-7 * longitude +  4.9353929 + 62833.1961680 * U;
	longitude = EC_fmod(longitude, M_PI * 2);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[WBSunLongitudeSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[WBSunLongitudeSlotIndex] = longitude;
	}
    }
    return longitude;
}

double WB_sunRadius(double       hundredCenturiesSinceEpochTDT,
		    ECAstroCache *currentCache) {
    assertCacheValidForTDTHundredCenturies(currentCache, hundredCenturiesSinceEpochTDT);
    double U = hundredCenturiesSinceEpochTDT;
    double radius;
    if (currentCache && currentCache->cacheSlotValidFlag[WBSunRadiusSlotIndex] == currentCache->currentFlag) {
	radius = currentCache->cacheSlots[WBSunRadiusSlotIndex];
    } else {
	radius = 0;
	for (int i = 0; i < numSunData; i++) {
	    const SunDatum *datum = &sunData[i];
	    double term = datum->ali + datum->bli*U;
	    radius += datum->ri * cos(term);
	}
	radius = 1E-7 * radius + 1.0001026;
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[WBSunRadiusSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[WBSunRadiusSlotIndex] = radius;
	}
    }
    return radius;
}

// Doesn't include aberration or nutation
void WB_sunLongitudeRadiusRaw(double 	   hundredCenturiesSinceEpochTDT,
			      double 	   *longitudeReturn,
			      double 	   *radiusReturn,
			      ECAstroCache *currentCache) {
    assertCacheValidForTDTHundredCenturies(currentCache, hundredCenturiesSinceEpochTDT);
    double U = hundredCenturiesSinceEpochTDT;
    double longitude;
    double radius;
    if (currentCache && currentCache->cacheSlotValidFlag[WBSunRadiusSlotIndex] == currentCache->currentFlag) {
	radius = currentCache->cacheSlots[WBSunRadiusSlotIndex];
	if (currentCache->cacheSlotValidFlag[WBSunLongitudeSlotIndex] == currentCache->currentFlag) {
	    longitude = currentCache->cacheSlots[WBSunLongitudeSlotIndex];
	} else {
	    longitude = WB_sunLongitudeRaw(hundredCenturiesSinceEpochTDT, currentCache);
	}
    } else if (currentCache && currentCache->cacheSlotValidFlag[WBSunLongitudeSlotIndex] == currentCache->currentFlag) {
	longitude = currentCache->cacheSlots[WBSunLongitudeSlotIndex];
	radius = WB_sunRadius(hundredCenturiesSinceEpochTDT, currentCache);
    } else {
	longitude = 0;
	radius = 0;
	for (int i = 0; i < numSunData; i++) {  // Do both at the same time for memory locality purposes
	    const SunDatum *datum = &sunData[i];
	    double term = datum->ali + datum->bli*U;
	    longitude += datum->li * sin(term);
	    radius += datum->ri * cos(term);
	}
	longitude = 1E-7 * longitude +  4.9353929 + 62833.1961680 * U;
	radius = 1E-7 * radius + 1.0001026;
	longitude = EC_fmod(longitude, M_PI * 2);
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[WBSunRadiusSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlotValidFlag[WBSunLongitudeSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[WBSunRadiusSlotIndex] = radius;
	    currentCache->cacheSlots[WBSunLongitudeSlotIndex] = longitude;
	}
    }
    *longitudeReturn = longitude;
    *radiusReturn = radius;
}

double WB_sunLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    return 1E-7*(-993 + 17*cos(3.10 + 62830.14*U));
}

void WB_nutationObliquity(double       hundredCenturiesSinceEpochTDT,
			  double       *nutationReturn,
			  double       *obliquityReturn,
			  ECAstroCache *currentCache) {
    assertCacheValidForTDTHundredCenturies(currentCache, hundredCenturiesSinceEpochTDT);
    if (currentCache && currentCache->cacheSlotValidFlag[WBNutationSlotIndex] == currentCache->currentFlag) {
	*nutationReturn = currentCache->cacheSlots[WBNutationSlotIndex];
	*obliquityReturn = currentCache->cacheSlots[WBObliquitySlotIndex];
    } else {
	double U = hundredCenturiesSinceEpochTDT;
	double U_2 = U * U;
	double A1 = 2.18 - 3375.70*U + 0.36 * U_2;
	double A2 = 3.51 + 125666.39*U + 0.10 * U_2;
	*nutationReturn = 1E-7 * (-834*sin(A1) - 64*sin(A2));
	double U_3 = U * U_2;
	double U_4 = U_2 * U_2;
	double U_5 = U * U_4;
	*obliquityReturn = 0.4090928 + 1E-7 * (-226938*U - 75*U_2 + 96926*U_3 - 2491*U_4 - 12104*U_5 + 446*cos(A1) + 28*cos(A2));
	if (currentCache) {
	    currentCache->cacheSlotValidFlag[WBNutationSlotIndex] = currentCache->currentFlag;
	    currentCache->cacheSlots[WBNutationSlotIndex] = *nutationReturn;
	    currentCache->cacheSlots[WBObliquitySlotIndex] = *obliquityReturn;
	}
    }
}

void WB_sunRAAndDecl(double 	  hundredCenturiesSinceEpochTDT,
		     double 	  *rightAscensionReturn,
		     double 	  *declinationReturn,
		     double 	  *apparentLongitudeReturn,
		     ECAstroCache *currentCache) {
    double longitude = WB_sunLongitudeRaw(hundredCenturiesSinceEpochTDT, currentCache);
    double aberration = WB_sunLongitudeAberration(hundredCenturiesSinceEpochTDT);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    double apparentLongitude = longitude + aberration + nutation;
    apparentLongitude = EC_fmod(apparentLongitude, M_PI * 2);
    if (apparentLongitude < 0) {
	apparentLongitude += M_PI * 2;
    }
    *declinationReturn = asin(sin(obliquity) * sin(apparentLongitude));
    *rightAscensionReturn = atan2(cos(obliquity) * sin(apparentLongitude), cos(apparentLongitude));
    if (*rightAscensionReturn < 0) {
	*rightAscensionReturn += M_PI * 2;
    }
    *apparentLongitudeReturn = apparentLongitude;
}

double WB_sunLongitudeApparent(double       hundredCenturiesSinceEpochTDT,
			       ECAstroCache *currentCache) {
    assertCacheValidForTDTHundredCenturies(currentCache, hundredCenturiesSinceEpochTDT);
    if (currentCache && currentCache->cacheSlotValidFlag[WBSunLongitudeApparentSlotIndex] == currentCache->currentFlag) {
	return currentCache->cacheSlots[WBSunLongitudeApparentSlotIndex];
    }
    double longitude = WB_sunLongitudeRaw(hundredCenturiesSinceEpochTDT, currentCache);
    double aberration = WB_sunLongitudeAberration(hundredCenturiesSinceEpochTDT);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    double apparentLongitude = longitude + aberration + nutation;
    apparentLongitude = EC_fmod(apparentLongitude, M_PI * 2);
    if (apparentLongitude < 0) {
	apparentLongitude += M_PI * 2;
    }
    if (currentCache) {
	currentCache->cacheSlotValidFlag[WBSunLongitudeApparentSlotIndex] = currentCache->currentFlag;
	currentCache->cacheSlots[WBSunLongitudeApparentSlotIndex] = apparentLongitude;
    }
    return apparentLongitude;
}

static void WB_convertGeocentric(double hundredCenturiesSinceEpochTDT,
				 double planetHeliocentricLongitude,
				 double planetHeliocentricLatitude,
				 double planetHeliocentricRadius,
				 double sunMeanLongitude,
				 double sunMeanRadius,
				 double planetaryLongitudeAberration,
				 double planetaryLatitudeAberration,
				 double obliquity,
				 double nutation,
				 double *geocentricApparentLongitude,
				 double *geocentricApparentLatitude,
				 double *geocentricDistance,
				 double *apparentRightAscension,
				 double *apparentDeclination) {
    double xSunGeo = sunMeanRadius * cos(sunMeanLongitude);
    double ySunGeo = sunMeanRadius * sin(sunMeanLongitude);
    const double zSunGeo = 0;

    double xPlanetHelio = planetHeliocentricRadius * cos(planetHeliocentricLatitude) * cos(planetHeliocentricLongitude);
    double yPlanetHelio = planetHeliocentricRadius * cos(planetHeliocentricLatitude) * sin(planetHeliocentricLongitude);
    double zPlanetHelio = planetHeliocentricRadius * sin(planetHeliocentricLatitude);

    double xPlanetGeo = xSunGeo + xPlanetHelio;
    double yPlanetGeo = ySunGeo + yPlanetHelio;
    double zPlanetGeo = zSunGeo + zPlanetHelio;

    *geocentricDistance = sqrt(xPlanetGeo*xPlanetGeo + yPlanetGeo*yPlanetGeo + zPlanetGeo*zPlanetGeo);

    double planetMeanGeoLongitude = atan2(yPlanetGeo, xPlanetGeo);
    double planetMeanGeoLatitude = atan2(zPlanetGeo, sqrt(xPlanetGeo*xPlanetGeo + yPlanetGeo * yPlanetGeo));

    *geocentricApparentLongitude = planetMeanGeoLongitude + planetaryLongitudeAberration + nutation;
    if (*geocentricApparentLongitude < 0) {
	*geocentricApparentLongitude += M_PI * 2;
    } else if (*geocentricApparentLongitude > M_PI * 2) {
	*geocentricApparentLongitude -= M_PI * 2;
    }
    *geocentricApparentLatitude = planetMeanGeoLatitude + planetaryLatitudeAberration;

    if (apparentDeclination && apparentRightAscension) {
	double cosObliquity = cos(obliquity);
	double sinObliquity = sin(obliquity);
	double sinLatitude = sin(*geocentricApparentLatitude);
	double cosLatitude = cos(*geocentricApparentLatitude);
	double sinLongitude = sin(*geocentricApparentLongitude);
	double sinDecl = cosObliquity*sinLatitude + sinObliquity*cosLatitude*sinLongitude;
	*apparentDeclination = asin(sinDecl);
	double y = cosObliquity*cosLatitude*sinLongitude - sinObliquity*sinLatitude;
	double x = cosLatitude*cos(*geocentricApparentLongitude);
	*apparentRightAscension = EC_fmod(atan2(y, x), M_PI * 2);
	if (*apparentRightAscension < 0) {
	    *apparentRightAscension += M_PI * 2;
	}
    } else {
	assert(!(apparentDeclination || apparentRightAscension));
    }
}

/********* MERCURY *********/

double WB_mercuryHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;
    double U_5 = U * U_4;
    
    double L = 0;
    for (int i = 0; i < numMercuryLongData; i++) {
	const InnerPlanetDatum *datum = &mercuryLongitudeData[i];
	L += datum->vi*sin(datum->ai + U*datum->bi);
    }
    L = L * 1E-7 + 4.4429839 + 260881.4701279*U +
	1E-6 * (409894.2 + 2435*U - 1408*U_2 + 114*U_3 + 233*U_4 - 88*U_5)
	*sin(3.053817 + 260878.756773*U - 0.001093*U_2 - 0.00093*U_3 + 0.00043*U_4 + 0.00014*U_5);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_mercuryHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double L = 0;
    for (int i = 0; i < numMercuryLatData; i++) {
	const InnerPlanetDatum *datum = &mercuryLatitudeData[i];
	L += datum->vi*sin(datum->ai + U*datum->bi);
    }
    return L * 1E-7;
}

double WB_mercuryRadius(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double R = 0;
    for (int i = 0; i < numMercuryRadData; i++) {
	const InnerPlanetDatum *datum = &mercuryRadiusData[i];
	R += datum->vi*cos(datum->ai + U*datum->bi);
    }
    return 0.3952020 + 1E-7*R;
}

double WB_mercuryLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    return 1E-7 * (-1261 + 1485*cos(2.649 + 198048.273*U)
		    + 305*cos(5.71 + 458927.03*U)
		    + 230*cos(5.30 + 396096.55*U));
}

double WB_mercuryLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    return 190E-7 * cos(0.42 + 260879.41*U);
}

void WB_mercuryApparentPosition(double 	     hundredCenturiesSinceEpochTDT,
				double 	     *geocentricApparentLongitude,
				double 	     *geocentricApparentLatitude,
				double 	     *geocentricDistance,
				double 	     *apparentRightAscension,
				double 	     *apparentDeclination,
				ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_mercuryHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_mercuryHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_mercuryRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_mercuryLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_mercuryLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

/********* VENUS *********/

double WB_venusHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;
    double U_5 = U * U_4;
    double U_6 = U_3 * U_3;
    
    double L = 0;
    for (int i = 0; i < numVenusLongData; i++) {
	const InnerPlanetDatum *datum = &venusLongitudeData[i];
	L += datum->vi*sin(datum->ai + U*datum->bi);
    }

    L = L*1E-7 + 3.2184413 + 102135.2937764*U
        + 1E-6*(13539.7 - 9570.0*U + 1987*U_2 + 927*U_3 + 230*U_4 - 51*U_5 + 10*U_6)
	      *sin(0.88074 + 102132.84648*U + 0.24082*U_2 + 0.1004*U_3 + 0.0355*U_4 - 0.0017*U_5 - 0.0151*U_6)
        + 1E-6*(898.9 + 112.4*U - 170*U_2 + 113*U_3 + 34*U_4 - 79*U_5 + 56*U_6)
	      *sin(0.5941 + 204267.3130*U + 0.014*U_2 + 0.123*U_3 - 0.146*U_4 + 0.052*U_5);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_venusHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;

    double L = 0;
    for (int i = 0; i < numVenusLatData; i++) {
	const InnerPlanetDatum *datum = &venusLatitudeData[i];
	L += datum->vi*sin(datum->ai + U*datum->bi);
    }
    L = L*1E-7
	+ 1E-7*(4011-2713*U + 490*U_2 + 290*U_3 + 90*U_4)
	       *sin(2.7182 + 204266.568*U + 0.225*U_2 + 0.102*U_3 + 0.035*U_4)
        + 1E-7*(101 + 26*U - 64*U_2)
	       *sin(2.66 + 306400.49*U + 0.45*U_2);
    return L;
}

double WB_venusRadius(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;
    double U_5 = U_2 * U_3;
    double U_6 = U_3 * U_3;
    double R = 0;
    for (int i = 0; i < numVenusRadData; i++) {
	const InnerPlanetDatum *datum = &venusRadiusData[i];
	R += datum->vi*cos(datum->ai + U*datum->bi);
    }
    R = R*1E-7 + 0.7235481
        + 1E-7*(48982-34549*U + 7096*U_2 + 3360*U_3 + 890*U_4-210*U_5)
	      *cos(4.02152 + 102132.84695*U + 0.2420*U_2 + 0.0994*U_3 + 0.0351*U_4 - 0.0013*U_5 - 0.015*U_6)
        + 1E-7*(166-234*U + 131*U_2)
	      *cos(4.90 + 204265.69*U + 0.48*U_2 + 0.20*U_3);
    return R;
}

double WB_venusLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;

    return 1E-7 * (-1304+1016*cos(1.423+39302.097*U)
		   +224*cos(2.85+78604.19*U)
		   +98*cos(4.27+117906.29*U));
}

double WB_venusLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    return 0;
}

void WB_venusApparentPosition(double 	   hundredCenturiesSinceEpochTDT,
			      double 	   *geocentricApparentLongitude,
			      double 	   *geocentricApparentLatitude,
			      double 	   *geocentricDistance,
			      double 	   *apparentRightAscension,
			      double 	   *apparentDeclination,
			      ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_venusHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_venusHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_venusRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_venusLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_venusLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

/********* MARS *********/

double WB_marsHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;
    double U_5 = U * U_4;
    double U_6 = U_3 * U_3;
    
    double L = 0;
    for (int i = 0; i < numMarsLongData; i++) {
	const InnerPlanetDatum *datum = &marsLongitudeData[i];
	L += datum->vi*sin(datum->ai + U*datum->bi);
    }

    L = L * 1E-7 + 6.2458611 + 33408.5620646*U
	+ 1E-6 * (186563.7 + 18135.0*U - 1332*U_2 - 704*U_3 - 65*U_4 - 89*U_5 + 9*U_6)
	       * sin(0.337967 + 33405.348759*U + 0.031676*U_2 - 0.007354*U_3 + 0.001143*U_4 - 0.00029*U_5 - 0.00010*U_6);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_marsHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;
    double U_5 = U_2 * U_3;
    double U_6 = U_3 * U_3;
    double U_7 = U_3 * U_4;

    double L = 0;
    for (int i = 0; i < numMarsLatData; i++) {
	const InnerPlanetDatum *datum = &marsLatitudeData[i];
	L += datum->vi*sin(datum->ai + U*datum->bi);
    }

    L = L * 1E-7
	+ 1E-7*(319714 - 10277*U + 24272*U_2 - 2420*U_3 - 10850*U_4 + 3880*U_5 + 5310*U_6 - 1050*U_7)
 	      *sin(5.339102 + 33407.21879*U + 0.04800*U_2 - 0.04831*U_3 + 0.01402*U_4 + 0.0290*U_5 - 0.0073*U_6 - 0.0112*U_7)
	+ 1E-7*(29803 + 1904*U + 1865*U_2 - 60*U_3 - 950*U_4 + 220*U_5 + 270*U_6)
	      *sin(5.67694 + 66812.5668*U + 0.0803*U_2 - 0.0536*U_3 + 0.0147*U_4 + 0.028*U_5)
	+ 1E-7*(3137 + 472*U + 111*U_2 + 70*U_3)
	      *sin(6.0173 + 100217.928*U + 0.093*U_2 - 0.086*U_3 + 0.037*U_4);
    return L;
}

double WB_marsRadius(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;
    double U_2 = U * U;
    double U_3 = U * U_2;
    double U_4 = U_2 * U_2;
    double U_5 = U_2 * U_3;
    double U_6 = U_3 * U_3;
    double R = 0;
    for (int i = 0; i < numMarsRadData; i++) {
	const InnerPlanetDatum *datum = &marsRadiusData[i];
	R += datum->vi*cos(datum->ai + U*datum->bi);
    }
    R = R*1E-7 + 1.529856
	+ 1E-6*(141849.5 + 13651.8*U - 1230*U_2 - 378*U_3 + 187*U_4 - 153*U_5 - 73*U_6)
	      *cos(3.479698 + 33405.349560*U + 0.030669*U_2 - 0.00909*U_3 + 0.00223*U_4 + 0.00083*U_5 - 0.00048*U_6)
        + 1E-6*(6607.8 + 1272.8*U - 53*U_2 - 46*U_3 + 14*U_4 - 12*U_5 + 99*U_6)
	      *cos(3.81781 + 66810.6991*U + 0.0613*U_2 - 0.0182*U_3 + 0.0044*U_4 + 0.0012*U_5 + 0.002*U_6);
    return R;
}

double WB_marsLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;

    return 1E-7 * (-1052 + 877*cos(1.834 + 29424.634*U)
		   + 187*cos(3.67 + 58849.27*U)
		   + 84*cos(3.49 + 33405.34*U));
}

double WB_marsLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    return 0;
}

void WB_marsApparentPosition(double 	  hundredCenturiesSinceEpochTDT,
			     double 	  *geocentricApparentLongitude,
			     double 	  *geocentricApparentLatitude,
			     double 	  *geocentricDistance,
			     double 	  *apparentRightAscension,
			     double 	  *apparentDeclination,
			     ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_marsHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_marsHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_marsRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_marsLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_marsLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

static double
calcOuterValue(const double Vs[],
	       const double coeffs[]) {
    return coeffs[0]
	+  coeffs[1] * Vs[1]
	+  coeffs[2] * Vs[2]
	+  coeffs[3] * Vs[3]
	+  coeffs[4] * Vs[4]
	+  coeffs[5] * Vs[5]
	+  coeffs[6] * Vs[6];
}

static void
makeVsTable(double V,
	    double Vs[]) {
    Vs[0] = 1;  // never used
    Vs[1] = V;
    Vs[2] = V * V;
    Vs[3] = Vs[2] * V;
    Vs[4] = Vs[2] * Vs[2];
    Vs[5] = Vs[3] * Vs[2];
    Vs[6] = Vs[3] * Vs[3];
}

static const OuterPlanetDatum *
findOuterPlanetDatum(double                      hundredCenturiesSinceEpochTDT,
		     const OuterPlanetDescriptor *descriptor,
		     double                      *V) {
    const OuterPlanetJDRange *jdRanges = descriptor->jdRange;
    double jd = hundredCenturiesSinceEpochTDT * 3652500 + 2451545;
    double firstJD = jdRanges[0].startJD;
    double lastJD = jdRanges[descriptor->numEntries - 1].endJD;
    if (jd < firstJD || jd > lastJD) {
	*V = nan("");
	return NULL;
    }
    // First, guess by dividing.  The last year's range extends beyond the year boundary by 4 days.
    double fract = (jd - firstJD)/(lastJD - 4 - firstJD);
    // If three entries, 0 - 0.33 is 0, .33 - .67 is 1, .67 to 1 is 2
    int indx = fract * descriptor->numEntries;  // truncating is right
    // Now check.  Presume could be index on either side if close (and note nonsense in 1582 means it doesn't have to be close)
    if (indx < 0) {
	indx = 0;
    } else if (indx > descriptor->numEntries - 1) {
	indx = descriptor->numEntries - 1;
    }
    const OuterPlanetJDRange *tryRange = &jdRanges[indx];
    if (jd < tryRange->startJD) {
	assert(indx > 0);  // Otherwise initial range check should have caught it
	indx--;
	tryRange = &jdRanges[indx];
    } else {
	if (indx < descriptor->numEntries - 1) {  // there's a next entry
	    if (jd >= jdRanges[indx + 1].startJD) {
		indx++;
		tryRange = &jdRanges[indx];
	    }
	}
    }
    assert(jd <= tryRange->endJD);
    assert(jd >= tryRange->startJD);
    *V = (jd - tryRange->startJD) / 2000;
    return &descriptor->data[indx];
}

/********* JUPITER *********/

double WB_jupiterHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &jupiterDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLong);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_jupiterHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &jupiterDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLat);
    return L;
}

double WB_jupiterRadius(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &jupiterDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double R = calcOuterValue(Vs, datum->aRad);
    return R;
}

double WB_jupiterLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;

    return 1E-7 * (-527 + 978*cos(1.154 + 57533.849*U)
                   + 89*cos(2.30 + 115067.70*U)
                   + 46*cos(4.64 + 62830.76*U)
                   + 45*cos(0.76 + 52236.94*U));
}

double WB_jupiterLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    return 0;
}

void WB_jupiterApparentPosition(double 	     hundredCenturiesSinceEpochTDT,
				double 	     *geocentricApparentLongitude,
				double 	     *geocentricApparentLatitude,
				double 	     *geocentricDistance,
				double 	     *apparentRightAscension,
				double 	     *apparentDeclination,
				ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_jupiterHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_jupiterHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_jupiterRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_jupiterLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_jupiterLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

/********* SATURN *********/

double WB_saturnHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &saturnDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLong);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_saturnHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &saturnDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLat);
    return L;
}

double WB_saturnRadius(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &saturnDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double R = calcOuterValue(Vs, datum->aRad);
    return R;
}

double WB_saturnLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;

    return 1E-7*(-373 + 986*cos(0.880 + 60697.768*U)
		 + 54*cos(3.31 + 62830.76*U)
		 + 52*cos(1.59 + 58564.78*U)
		 + 51*cos(1.76 + 121395.54*U));
}

double WB_saturnLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    return 0;
}

void WB_saturnApparentPosition(double 	    hundredCenturiesSinceEpochTDT,
			       double 	    *geocentricApparentLongitude,
			       double 	    *geocentricApparentLatitude,
			       double 	    *geocentricDistance,
			       double 	    *apparentRightAscension,
			       double 	    *apparentDeclination,
			       ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_saturnHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_saturnHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_saturnRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_saturnLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_saturnLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

/********* URANUS *********/

double WB_uranusHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &uranusDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLong);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_uranusHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &uranusDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLat);
    return L;
}

double WB_uranusRadius(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &uranusDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double R = calcOuterValue(Vs, datum->aRad);
    return R;
}

double WB_uranusLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;

    return 1E-7*(-252 + 990*cos(2.555 + 62082.943*U)
		 + 46*cos(1.88 + 62830.76*U)
		 + 45*cos(0.11 + 61335.13*U));
}

double WB_uranusLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    return 0;
}

void WB_uranusApparentPosition(double 	    hundredCenturiesSinceEpochTDT,
			       double 	    *geocentricApparentLongitude,
			       double 	    *geocentricApparentLatitude,
			       double 	    *geocentricDistance,
			       double 	    *apparentRightAscension,
			       double 	    *apparentDeclination,
			       ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_uranusHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_uranusHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_uranusRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_uranusLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_uranusLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

/********* NEPTUNE *********/

double WB_neptuneHeliocentricLongitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &neptuneDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLong);
    L = EC_fmod(L, M_PI * 2);
    if (L < 0) {
	L += M_PI * 2;
    }
    return L;
}

double WB_neptuneHeliocentricLatitude(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &neptuneDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double L = calcOuterValue(Vs, datum->aLat);
    return L;
}

double WB_neptuneRadius(double hundredCenturiesSinceEpochTDT) {
    double V;
    const OuterPlanetDatum *datum = findOuterPlanetDatum(hundredCenturiesSinceEpochTDT, &neptuneDescriptor, &V);
    if (!datum) {
	return 0;
    }
    double Vs[7];
    makeVsTable(V, Vs);
    double R = calcOuterValue(Vs, datum->aRad);
    return R;
}

double WB_neptuneLongitudeAberration(double hundredCenturiesSinceEpochTDT) {
    double U = hundredCenturiesSinceEpochTDT;

    return 1E-7*(-198 + 993*cos(2.725 + 62449.428*U));
}

double WB_neptuneLatitudeAberration(double hundredCenturiesSinceEpochTDT) {
    return 0;
}

void WB_neptuneApparentPosition(double 	     hundredCenturiesSinceEpochTDT,
				double 	     *geocentricApparentLongitude,
				double 	     *geocentricApparentLatitude,
				double 	     *geocentricDistance,
				double 	     *apparentRightAscension,
				double 	     *apparentDeclination,
				ECAstroCache *currentCache) {
    double sunMeanLongitude;
    double sunMeanRadius;
    WB_sunLongitudeRadiusRaw(hundredCenturiesSinceEpochTDT,
			     &sunMeanLongitude,
			     &sunMeanRadius, currentCache);
    double nutation;
    double obliquity;
    WB_nutationObliquity(hundredCenturiesSinceEpochTDT, &nutation, &obliquity, currentCache);
    WB_convertGeocentric(hundredCenturiesSinceEpochTDT,
			 WB_neptuneHeliocentricLongitude(hundredCenturiesSinceEpochTDT),
			 WB_neptuneHeliocentricLatitude(hundredCenturiesSinceEpochTDT),
			 WB_neptuneRadius(hundredCenturiesSinceEpochTDT),
			 sunMeanLongitude,
			 sunMeanRadius,
			 WB_neptuneLongitudeAberration(hundredCenturiesSinceEpochTDT),
			 WB_neptuneLatitudeAberration(hundredCenturiesSinceEpochTDT),
			 obliquity,
			 nutation,
			 geocentricApparentLongitude,
			 geocentricApparentLatitude,
			 geocentricDistance,
			 apparentRightAscension,
			 apparentDeclination);
}

// ***** Generic routines *****

void WB_planetApparentPosition(int    	     planetNumber,
			       double 	     hundredCenturiesSinceEpochTDT,
			       double 	     *geocentricApparentLongitude,
			       double 	     *geocentricApparentLatitude,
			       double 	     *geocentricDistance, // In AU
			       double 	     *apparentRightAscension,
			       double 	     *apparentDeclination,
			       ECAstroCache  *currentCache,
			       ECWBPrecision moonPrecision) {
    switch(planetNumber) {
      case ECPlanetSun:
	WB_sunRAAndDecl(hundredCenturiesSinceEpochTDT, apparentRightAscension, apparentDeclination, geocentricApparentLongitude, currentCache);
	*geocentricApparentLatitude = 0;
	*geocentricDistance = WB_sunRadius(hundredCenturiesSinceEpochTDT, currentCache);
	return;
      case ECPlanetMoon:
	WB_MoonRAAndDecl(hundredCenturiesSinceEpochTDT*100, apparentRightAscension, apparentDeclination, geocentricApparentLongitude, geocentricApparentLatitude, currentCache, moonPrecision);
	*geocentricDistance = WB_MoonDistance(hundredCenturiesSinceEpochTDT*100, currentCache, moonPrecision) / kECAUInKilometers;
	return;
      case ECPlanetMercury:
	WB_mercuryApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetVenus:
	WB_venusApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetMars:
	WB_marsApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetJupiter:
	WB_jupiterApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetSaturn:
	WB_saturnApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetUranus:
	WB_uranusApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetNeptune:
	WB_neptuneApparentPosition(hundredCenturiesSinceEpochTDT, geocentricApparentLongitude, geocentricApparentLatitude, geocentricDistance, apparentRightAscension, apparentDeclination, currentCache);
	return;
      case ECPlanetPluto:
	assert(0);
	break;
      case ECPlanetEarth:
	assert(0);
	break;
      default:
	assert(0);
    }
    *geocentricApparentLongitude = nan("");
    *geocentricApparentLatitude = nan("");
    *apparentRightAscension = nan("");
    *apparentDeclination = nan("");
}

double WB_planetHeliocentricLongitude(int    	   planetNumber,
				      double 	   hundredCenturiesSinceEpochTDT,
				      ECAstroCache *currentCache) {
    switch(planetNumber) {
      case ECPlanetEarth:
	{
	    double sunMeanLongitude = WB_sunLongitudeRaw(hundredCenturiesSinceEpochTDT, currentCache);
	    double helioLong = EC_fmod(M_PI + sunMeanLongitude, 2 * M_PI);
	    if (helioLong < 0) {
		helioLong += 2 * M_PI;
	    }
	    return helioLong;
	}
      case ECPlanetMercury:
	return WB_mercuryHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetVenus:
	return WB_venusHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetMars:
	return WB_marsHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetJupiter:
	return WB_jupiterHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetSaturn:
	return WB_saturnHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetUranus:
	return WB_uranusHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetNeptune:
	return WB_neptuneHeliocentricLongitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetSun:
      case ECPlanetMoon:
      case ECPlanetPluto:
	assert(0);
	break;
      default:
	assert(0);
    }
    return nan("");
}

double WB_planetHeliocentricLatitude(int    	  planetNumber,
				     double 	  hundredCenturiesSinceEpochTDT,
				     ECAstroCache *currentCache) {
    switch(planetNumber) {
      case ECPlanetEarth:
	return 0;
      case ECPlanetMercury:
	return WB_mercuryHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetVenus:
	return WB_venusHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetMars:
	return WB_marsHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetJupiter:
	return WB_jupiterHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetSaturn:
	return WB_saturnHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetUranus:
	return WB_uranusHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetNeptune:
	return WB_neptuneHeliocentricLatitude(hundredCenturiesSinceEpochTDT);
      case ECPlanetSun:
      case ECPlanetMoon:
      case ECPlanetPluto:
	assert(0);
	break;
      default:
	assert(0);
    }
    return nan("");
}

double WB_planetHeliocentricRadius(int    	planetNumber,
				   double 	hundredCenturiesSinceEpochTDT,
				   ECAstroCache *currentCache) {
    switch(planetNumber) {
      case ECPlanetEarth:
	return WB_sunRadius(hundredCenturiesSinceEpochTDT, currentCache);
      case ECPlanetMercury:
	return WB_mercuryRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetVenus:
	return WB_venusRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetMars:
	return WB_marsRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetJupiter:
	return WB_jupiterRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetSaturn:
	return WB_saturnRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetUranus:
	return WB_uranusRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetNeptune:
	return WB_neptuneRadius(hundredCenturiesSinceEpochTDT);
      case ECPlanetSun:
      case ECPlanetMoon:
      case ECPlanetPluto:
	assert(0);
	break;
      default:
	assert(0);
    }
    return nan("");
}

void someFunctionToUseAllThosePlanetDescriptorsToShutUpTheCompiler(void) {
    printf("0x%016lx\n", (long)&mercuryDescriptor);
    printf("0x%016lx\n", (long)&venusDescriptor);
    printf("0x%016lx\n", (long)&marsDescriptor);
    printf("0x%016lx\n", (long)&jupiterDescriptor);
    printf("0x%016lx\n", (long)&saturnDescriptor);
    printf("0x%016lx\n", (long)&uranusDescriptor);
    printf("0x%016lx\n", (long)&neptuneDescriptor);
}

#ifndef NDEBUG

#ifndef STANDALONE
static NSNumberFormatter *sizeFormatter;

static void initializeSizeFormatter(void) {
    sizeFormatter = [[NSNumberFormatter alloc] init];
#if 0 // TARGET_IPHONE_SIMULATOR
    [sizeFormatter setFormat:@"#,##0"];
#endif
    [sizeFormatter setUsesGroupingSeparator:YES];
}

static NSString *formattedSize(size_t size) {
    if (!sizeFormatter) {
	initializeSizeFormatter();
    }
    if (size % (1024 * 1024) == 0) {
	return [NSString stringWithFormat:@"%ld  MB  ", size / (1024 * 1024)];
    }
    NSNumber *number = [NSNumber numberWithUnsignedLong:size];
    assert(number);
    NSString *numberString = [sizeFormatter stringFromNumber:number];
    assert(numberString);
    return numberString;
}

static void printMemoryLine(size_t size, NSString *description) {
    NSString *formattedString = formattedSize(size);
    printf("%12s : %s\n", [formattedString UTF8String], [description UTF8String]);
}

static void printInnerPlanet(const InnerPlanetDescriptor *descriptor,
			     const char                  *planetName,
			     size_t                      *totalMemory) {
    size_t longitudeSize = descriptor->numLongData * sizeof(InnerPlanetDatum);
    printMemoryLine(longitudeSize, [NSString stringWithFormat:@"%7s long: %3d %2ld-byte datum elements", planetName, descriptor->numLongData, sizeof(InnerPlanetDatum)]);
    *totalMemory += longitudeSize;
    size_t latitudeSize = descriptor->numLatData * sizeof(InnerPlanetDatum);
    printMemoryLine(latitudeSize, [NSString stringWithFormat:@"%7s lat:  %3d %2ld-byte datum elements", planetName, descriptor->numLatData, sizeof(InnerPlanetDatum)]);
    *totalMemory += latitudeSize;
    size_t radiusSize = descriptor->numRadData * sizeof(InnerPlanetDatum);
    printMemoryLine(latitudeSize, [NSString stringWithFormat:@"%7s rad:  %3d %2ld-byte datum elements", planetName, descriptor->numRadData, sizeof(InnerPlanetDatum)]);
    *totalMemory += radiusSize;
}

static void printOuterPlanet(const OuterPlanetDescriptor *descriptor,
			     const char                  *planetName,
			     size_t                      *totalMemory) {
    size_t sz = descriptor->numEntries * sizeof(OuterPlanetDatum);
    printMemoryLine(sz, [NSString stringWithFormat:@"%7s    :  %3d %2ld-byte half-decade entries", planetName, descriptor->numEntries, sizeof(OuterPlanetDatum)]);
    *totalMemory += sz;		    

    sz = descriptor->numEntries * sizeof(OuterPlanetJDRange);
    printMemoryLine(sz, [NSString stringWithFormat:@"%7s    :  %3d %2ld-byte half-decade jd range elements", planetName, descriptor->numEntries, sizeof(OuterPlanetJDRange)]);
    *totalMemory += sz;		    
}

void WB_printMemoryUsage(void) {
    printf("\nMemory usage for Willmann-Bell data tables:\n");
    size_t totalMemory = 0;
    size_t sunDatumSize = sizeof(SunDatum);
    size_t sunDataSize = sunDatumSize * numSunData;
    assert(sunDataSize == sizeof(sunData));
    printMemoryLine(sunDataSize, [NSString stringWithFormat:@"    Sun:  %3d %2zd-byte datum elements", numSunData, sunDatumSize]);
    totalMemory += sunDataSize;

    size_t thisSize = 218 * sizeof(SvDatum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sv:  %3d %2ld-byte datum elements", 218, sizeof(SvDatum)]);
    totalMemory += thisSize;

    thisSize = 244 * sizeof(Sv1Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sv1: %3d %2ld-byte datum elements", 244, sizeof(Sv1Datum)]);
    totalMemory += thisSize;

    thisSize = 154 * sizeof(Sv2Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sv2: %3d %2ld-byte datum elements", 154, sizeof(Sv2Datum)]);
    totalMemory += thisSize;

    thisSize = 25 * sizeof(Sv3Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sv3: %3d %2ld-byte datum elements",  25, sizeof(Sv3Datum)]);
    totalMemory += thisSize;

    thisSize = 188 * sizeof(SuDatum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Su:  %3d %2ld-byte datum elements", 188, sizeof(SuDatum)]);
    totalMemory += thisSize;

    thisSize =  64 * sizeof(Su1Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Su1: %3d %2ld-byte datum elements", 64, sizeof(Su1Datum)]);
    totalMemory += thisSize;

    thisSize =  64 * sizeof(Su2Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Su2: %3d %2ld-byte datum elements", 64, sizeof(Su2Datum)]);
    totalMemory += thisSize;

    thisSize = 12 * sizeof(Su3Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Su3: %3d %2ld-byte datum elements", 12, sizeof(Su3Datum)]);
    totalMemory += thisSize;

    thisSize = 154 * sizeof(SrDatum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sr:  %3d %2ld-byte datum elements", 154, sizeof(SrDatum)]);
    totalMemory += thisSize;

    thisSize = 114 * sizeof(Sr1Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sr1: %3d %2ld-byte datum elements", 114, sizeof(Sr1Datum)]);
    totalMemory += thisSize;

    thisSize =  68 * sizeof(Sr2Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sr2: %3d %2ld-byte datum elements", 68, sizeof(Sr2Datum)]);
    totalMemory += thisSize;

    thisSize = 19 * sizeof(Sr3Datum);
    printMemoryLine(thisSize,    [NSString stringWithFormat:@"Moon Sr3: %3d %2ld-byte datum elements", 19, sizeof(Sr3Datum)]);
    totalMemory += thisSize;

    printInnerPlanet(&mercuryDescriptor, "mercury", &totalMemory);
    printInnerPlanet(&venusDescriptor, "venus", &totalMemory);
    printInnerPlanet(&marsDescriptor, "mars", &totalMemory);

    printOuterPlanet(&jupiterDescriptor, "jupiter", &totalMemory);
    printOuterPlanet(&saturnDescriptor, "saturn", &totalMemory);
    printOuterPlanet(&uranusDescriptor, "uranus", &totalMemory);
    printOuterPlanet(&neptuneDescriptor, "neptune", &totalMemory);

    printMemoryLine(totalMemory, @"Total WB data table size");
    printf("\n");
}

#endif

static void checkExample(const char *exampleName,
			 double     calculatedValue,
			 double     expectedValue,
			 double     allowedError) {
    double delta = fabs(expectedValue - calculatedValue);
    printf("%20.11f  %20.11f  %20.11f  %s\n",
	   delta, expectedValue, calculatedValue, exampleName);
    if (delta > allowedError) {
	printf("*************** TEST FAILED ****************\n");
	printf("%20.11f was maximum allowed error\n", allowedError);
	printf("*************** TEST FAILED ****************\n");
	exit(1);
    }
}

static void EXAMPLE1(void) {
    // Compute t on 1563 B.C. February 10 at 16h5m ET
    double JD = JDForDate(-1562, 2, 10, 16, 5, 0);
    checkExample("EXAMPLE1:JD", JD, 1150578.170139, 0.0000005);
    double t = TDTForTDTDate(-1562, 2, 10, 16, 5, 0);
    checkExample("EXAMPLE1:t", t, -35.6185305917, 0.0000000001);
}

static void EXAMPLE2(void) {
    // Compute t on 251 B.C. April 10 at 18h12m UT
    double JD = JDForDate(-250, 4, 10, 18, 12, 0);
    checkExample("EXAMPLE2:JD", JD, 1629845.258333, 0.0000005);
    double deltaT = deltaTForUT(TDTForTDTDate(-250, 4, 10, 18, 12, 0));
    checkExample("EXAMPLE2:deltaT", deltaT, 12500.1, 0.1);
    double t = TDTForUTDate(-250, 4, 10, 18, 12, 0);
    checkExample("EXAMPLE2:t", t, -22.4969088840, 0.0000000001);
}

static void EXAMPLE3(void) {
    // Compute t on 1590 January 15 at 2h25m30s UT
    double JD = JDForDate(1590, 1, 15, 2, 25, 30);
    checkExample("EXAMPLE3:JD", JD, 2301809.601042, 0.0000005);
    double deltaT = deltaTForUT(TDTForTDTDate(1590, 1, 15, 2, 25, 30));
    checkExample("EXAMPLE3:deltaT", deltaT, 88.7, 0.1);
    double t = TDTForUTDate(1590, 1, 15, 2, 25, 30);
    checkExample("EXAMPLE3:t", t, -4.0995317709, 0.0000000001);
}

static void EXAMPLE4(void) {
    // Compute t on 1986 August 7 at 22h 15m 12s UT
    double JD = JDForDate(1986, 8, 7, 22, 15, 12);
    checkExample("EXAMPLE4:JD", JD, 2446650.4272222, 0.00000005);
    double deltaT = deltaTForUT(TDTForTDTDate(1986, 8, 7, 22, 15, 12));
    checkExample("EXAMPLE4:deltaT", deltaT, 55, 0.5);
    double t = TDTForUTDate(1986, 8, 7, 22, 15, 12);
    checkExample("EXAMPLE4:t", t, -0.13400608189, 0.00000000001);
}

static void EXAMPLE4A(void) {
    // MY EXAMPLE, NOT IN BOOK
    // Compute deltaT on 1986 August 7 at 22h 15m 12s UT
    double deltaT = deltaTForUT(TDTForTDTDate(1986, 8, 7, 22, 15, 12));
    checkExample("EXAMPLE4A1:deltaT", deltaT, 55, 0.01);
    // Compute deltaT on 1675 August 7 at 22h 15m 12s UT
    deltaT = deltaTForUT(TDTForTDTDate(1675, 8, 7, 22, 15, 12));
    checkExample("EXAMPLE4A2:deltaT", deltaT, 6, 0.01);
    // Compute deltaT on 1780 August 7 at 22h 15m 12s UT
    deltaT = deltaTForUT(TDTForTDTDate(1780, 8, 7, 22, 15, 12));
    checkExample("EXAMPLE4A3:deltaT", deltaT, 11, 0.01);
    // Compute deltaT on 1781 August 7 at 22h 15m 12s UT
    deltaT = deltaTForUT(TDTForTDTDate(1781, 8, 7, 22, 15, 12));
    checkExample("EXAMPLE4A4:deltaT", deltaT, 11, 0.01);
    // Compute deltaT on 1889 August 7 at 22h 15m 12s UT
    deltaT = deltaTForUT(TDTForTDTDate(1889, 8, 7, 22, 15, 12));
    checkExample("EXAMPLE4A5:deltaT", deltaT, -6, 0.01);
}

// Example from table 5 on p14, and table 11 on p21
static void EXAMPLE5(void) {
    double t;
    double U, V, R;
    double rightAscension;
    double declination;
    double longitude;
    double latitude;
    double aberr;
    ECAstroCache *currentCache = NULL;
    t = TDTForTDTDate(-1562, 2, 10, 16, 5, 0);
    checkExample("EXAMPLE5A:t", t, -35.6185305917, .0000000001);
    V = lunarLongitudeForTDT(t, ECWBLowPrecision, currentCache);
    checkExample("EXAMPLE5A:V", V, 285.5572, .0002);
    U = lunarLatitudeForTDT(t, ECWBLowPrecision, currentCache);
    checkExample("EXAMPLE5A:U", U, 2.2214, .0002);
    R = lunarDistanceForTDT(t, ECWBLowPrecision, currentCache);
    checkExample("EXAMPLE5A:R", R, 375342, 1);
    WB_MoonRAAndDecl(t, &rightAscension, &declination, &longitude, &latitude, currentCache, ECWBFullPrecision);
    checkExample("EXAMPLE5A:long", longitude * 180 / M_PI, 285.5617, .001);
    checkExample("EXAMPLE5A:lat", latitude * 180 / M_PI, 2.216, .001);
    checkExample("EXAMPLE5A:RA", rightAscension * 12 / M_PI, 19.11097, .0001);
    checkExample("EXAMPLE5A:decl", declination * 180 / M_PI, -20.7487, .0001);

    t = TDTForUTDate(1590, 1, 15, 2, 25, 30);
    checkExample("EXAMPLE5B:t", t, -4.0995317709, .0000000001);
    V = lunarLongitudeForTDT(t, ECWBMidPrecision, currentCache);
    checkExample("EXAMPLE5B:V", V, 51.96876, .00001);
    U = lunarLatitudeForTDT(t, ECWBMidPrecision, currentCache);
    checkExample("EXAMPLE5B:U", U, -5.20601, .00001);
    R = lunarDistanceForTDT(t, ECWBMidPrecision, currentCache);
    checkExample("EXAMPLE5B:R", R, 388236.5, .1);
    WB_MoonRAAndDecl(t, &rightAscension, &declination, &V, &U, currentCache, ECWBFullPrecision);
    checkExample("EXAMPLE5B:RA", rightAscension * 12/M_PI, 3.394627, .0002);
    checkExample("EXAMPLE5B:decl", declination * 180/M_PI, 13.26411, .0002);

    t = TDTForUTDate(1986, 8, 7, 22, 15, 12);
    checkExample("EXAMPLE5C:t", t, -0.13400608189, .00000000001);
    V = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    checkExample("EXAMPLE5C:V", V, 160.466436, .000005);
    aberr = lunarAberrationV(t) * 180/M_PI;
    checkExample("EXAMPLE5C:DV", aberr, -0.000195, .000001);
    V += aberr;
    checkExample("EXAMPLE5C:Vapp", V, 160.466436 - 0.000195, .000005);
    U = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    checkExample("EXAMPLE5C:U", U, 3.422415, .000005);
    aberr = lunarAberrationU(t) * 180/M_PI;
    checkExample("EXAMPLE5C:DU", aberr, 0.000014, .000001);
    U += aberr;
    checkExample("EXAMPLE5C:Uapp", U, 3.422415+0.000014, .000001);
    R = lunarDistanceForTDT(t, ECWBFullPrecision, currentCache);
    checkExample("EXAMPLE5C:R", R, 388150.634, .001);
    WB_MoonRAAndDecl(t, &rightAscension, &declination, &V, &U, currentCache, ECWBFullPrecision);
    checkExample("EXAMPLE5C:RA", rightAscension * 12 / M_PI, 10.8857436, .0000003);
    checkExample("EXAMPLE5C:decl", declination * 180 / M_PI, 10.810752, .000002);
}

// Example from table 12 on p25
static void EXAMPLE12(void) {
    ECAstroCache *currentCache = NULL;

    double t = TDTForTDTDate(-497, 4, 1, 2, 6, 0);
    checkExample("EXAMPLE12A:t", t, -24.9671844627, .0000000001);
    double Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBLowPrecision, currentCache);
    checkExample("EXAMPLE12A:Omega", Omega, 176.4, .1);

    t = TDTForTDTDate(1420, 9, 22, 12, 10, 20);
    checkExample("EXAMPLE12B:t", t, -5.7923885783, .0000000001);
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBMidPrecision, currentCache);
    checkExample("EXAMPLE12B:Omega", Omega, 169.51, .01);

    t = TDTForTDTDate(1990, 9, 20, 22, 50, 43);
    checkExample("EXAMPLE12C:t", t, -.09280076970, .0000000001);
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBFullPrecision, currentCache);
    checkExample("EXAMPLE12C:Omega", Omega, 306.010, .001);

    ETConversionMethod = ETUseMeeus;

    t = TDTForUTDate(2010, 7, 11, 19, 33, 33);
    t += 0.6/(36525. * 24. * 3600.);
    double RA;
    double decl;
    double along;
    WB_sunRAAndDecl(t/100, &RA, &decl, &along, currentCache);
    printAngle(RA, "EXAMPLE12D sun apparent RA");
    printAngle(decl, "EXAMPLE12D sun apparent decl");
    double alat;
    WB_MoonRAAndDecl(t, &RA, &decl, &along, &alat, currentCache, ECWBFullPrecision);
    printAngle(RA, "EXAMPLE12D moon apparent RA");
    printAngle(decl, "EXAMPLE12D moon apparent decl");
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBFullPrecision, currentCache);
    double rawLong = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLong*M_PI/180, "EXAMPLE12D moon geometric long");
    double appLong = WB_MoonEclipticLongitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLong, "EXAMPLE12D moon apparent long");
    double rawSunLong = WB_sunLongitudeRaw(t/100, currentCache);
    printAngle(rawSunLong, "EXAMPLE12D sun geometric long");
    double appSunLong = WB_sunLongitudeApparent(t/100, currentCache);
    printAngle(appSunLong, "EXAMPLE12D sun apparent long");
    double rawLat = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLat*M_PI/180, "EXAMPLE12D moon geometric lat");
    double appLat = WB_MoonEclipticLatitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLat, "EXAMPLE12D moon apparent lat");
    printAngle((Omega-180)*M_PI/180, "EXAMPLE12D Omega-pi");
//    checkExample("EXAMPLE12D:Omega", Omega, 289.35, 1.5);

    t = TDTForUTDate(2010, 7, 11, 07, 31, 53);
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBFullPrecision, currentCache);
    rawLat = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLat*M_PI/180, "EXAMPLE12E moon geometric lat");
    rawLong = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLong*M_PI/180, "EXAMPLE12E moon geometric long");
    rawSunLong = WB_sunLongitudeRaw(t/100, currentCache);
    printAngle(rawSunLong, "EXAMPLE12E sun geometric long");
    appSunLong = WB_sunLongitudeApparent(t/100, currentCache);
    printAngle(appSunLong, "EXAMPLE12E sun apparent long");
    appLat = WB_MoonEclipticLatitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLat, "EXAMPLE12E moon apparent lat");
    appLong = WB_MoonEclipticLongitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLong, "EXAMPLE12E moon apparent long");
    printAngle((Omega-180)*M_PI/180, "EXAMPLE12E Omega-pi");

    t = TDTForUTDate(2008, 2, 21, 3, 26, 00);
    WB_sunRAAndDecl(t/100, &RA, &decl, &along, currentCache);
    printAngle(RA, "EXAMPLE12F sun apparent RA");
    printAngle(decl, "EXAMPLE12F sun apparent decl");
    WB_MoonRAAndDecl(t, &RA, &decl, &along, &alat, currentCache, ECWBFullPrecision);
    printAngle(RA, "EXAMPLE12F moon apparent RA");
    printAngle(decl, "EXAMPLE12F moon apparent decl");
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBFullPrecision, currentCache);
    rawLat = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLat*M_PI/180, "EXAMPLE12F moon geometric lat");
    rawLong = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLong*M_PI/180, "EXAMPLE12F moon geometric long");
    rawSunLong = WB_sunLongitudeRaw(t/100, currentCache);
    printAngle(rawSunLong, "EXAMPLE12F sun geometric long");
    appSunLong = WB_sunLongitudeApparent(t/100, currentCache);
    printAngle(appSunLong, "EXAMPLE12F sun apparent long");
    appLat = WB_MoonEclipticLatitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLat, "EXAMPLE12F moon apparent lat");
    appLong = WB_MoonEclipticLongitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLong, "EXAMPLE12F moon apparent long");
    printAngle((Omega-180)*M_PI/180, "EXAMPLE12F Omega-pi");

    t = TDTForUTDate(2009, 7, 22, 2, 35, 21);
    t += 0.1/(36525. * 24. * 3600.);
    WB_sunRAAndDecl(t/100, &RA, &decl, &along, currentCache);
    printAngle(RA, "EXAMPLE12G sun apparent RA");
    printAngle(decl, "EXAMPLE12G sun apparent decl");
    WB_MoonRAAndDecl(t, &RA, &decl, &along, &alat, currentCache, ECWBFullPrecision);
    printAngle(RA, "EXAMPLE12G moon apparent RA");
    printAngle(decl, "EXAMPLE12G moon apparent decl");
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBFullPrecision, currentCache);
    rawLong = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLong*M_PI/180, "EXAMPLE12G moon geometric long");
    appLong = WB_MoonEclipticLongitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLong, "EXAMPLE12G moon apparent long");
    rawSunLong = WB_sunLongitudeRaw(t/100, currentCache);
    printAngle(rawSunLong, "EXAMPLE12G sun geometric long");
    appSunLong = WB_sunLongitudeApparent(t/100, currentCache);
    printAngle(appSunLong, "EXAMPLE12G sun apparent long");
    rawLat = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLat*M_PI/180, "EXAMPLE12G moon geometric lat");
    appLat = WB_MoonEclipticLatitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLat, "EXAMPLE12G moon apparent lat");
    printAngle((Omega-180)*M_PI/180, "EXAMPLE12G Omega-pi");
//    checkExample("EXAMPLE12G:Omega", Omega, 289.35, 1.5);

    ETConversionMethod = ETUseMeeus;

    t = TDTForUTDate(2010, 7, 11, 19, 33, 33);
    t += 0.6/(36525. * 24. * 3600.);
    WB_sunRAAndDecl(t/100, &RA, &decl, &along, currentCache);
    printAngle(RA, "EXAMPLE12D sun apparent RA");
    printAngle(decl, "EXAMPLE12D sun apparent decl");
    WB_MoonRAAndDecl(t, &RA, &decl, &along, &alat, currentCache, ECWBFullPrecision);
    printAngle(RA, "EXAMPLE12D moon apparent RA");
    printAngle(decl, "EXAMPLE12D moon apparent decl");
    Omega = 180.0/M_PI * ascendingNodeLongitude(t, ECWBFullPrecision, currentCache);
    rawLong = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLong*M_PI/180, "EXAMPLE12D moon geometric long");
    appLong = WB_MoonEclipticLongitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLong, "EXAMPLE12D moon apparent long");
    rawSunLong = WB_sunLongitudeRaw(t/100, currentCache);
    printAngle(rawSunLong, "EXAMPLE12D sun geometric long");
    appSunLong = WB_sunLongitudeApparent(t/100, currentCache);
    printAngle(appSunLong, "EXAMPLE12D sun apparent long");
    rawLat = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(rawLat*M_PI/180, "EXAMPLE12D moon geometric lat");
    appLat = WB_MoonEclipticLatitude(t, currentCache, ECWBFullPrecision);
    printAngle(appLat, "EXAMPLE12D moon apparent lat");
    printAngle((Omega-180)*M_PI/180, "EXAMPLE12D Omega-pi");
//    checkExample("EXAMPLE12D:Omega", Omega, 289.35, 1.5);

}

static void EXAMPLEX(void) {
    ECAstroCache *currentCache = NULL;

    double t = TDTForTDTDate(1979, 2, 26, 16, 0, 0);
    double V = lunarLongitudeForTDT(t, ECWBFullPrecision, currentCache);
    double U = lunarLatitudeForTDT(t, ECWBFullPrecision, currentCache);
    double R = lunarDistanceForTDT(t, ECWBFullPrecision, currentCache);
    printAngle(R, "EXAMPLEX:R");
    double Vr = V*M_PI/180 + lunarAberrationV(t);
    printAngle(Vr, "EXAMPLEX:Vr");
    double Ur = U*M_PI/180 + lunarAberrationU(t);
    printAngle(Ur, "EXAMPLEX:Ur");
    double ra;
    double decl;
    moonRightAscensionAndDeclForTDT(Vr, Ur, t, &ra, &decl);
    printAngle(ra, "EXAMPLEX:ra");
    printAngle(decl, "EXAMPLEX:decl");

    ETConversionMethod = ETUseBretagnon;
    double sunLong;
    double sunRad;
    printf("U for 7/14/-4000: %.10f\n", TDTForUTDate(-4000,7,14,0,0,0)/100);
    U = -.5999428421;
    printf("U sez they:       %.10f\n", U);
    WB_sunLongitudeRadiusRaw(U, &sunLong, &sunRad, currentCache);
    printAngle(sunLong, "EXAMPLEX:sunLong");
    double aberration = WB_sunLongitudeAberration(U);
    printAngle(aberration, "EXAMPLEX:aberration");
    double nutation;
    double obliquity;
    WB_nutationObliquity(U, &nutation, &obliquity, currentCache);
    printAngle(nutation, "EXAMPLEX:nutation");
    printAngle(obliquity, "EXAMPLEX:obliquity");
    sunLong += aberration + nutation;
    printAngle(sunLong, "EXAMPLEX:sun apparent long");
    double sunLong2;
    WB_sunRAAndDecl(U, &ra, &decl, &sunLong2, currentCache);
    printAngle(sunLong2, "EXAMPLEX:sun apparent long 2");
    printAngle(ra, "EXAMPLEX:sun RA");
    printAngle(decl, "EXAMPLEX:sun decl");
}

static void EXAMPLEPx(double     tdt,
		      const char *desc) {
    printf("\n\n");
    ECAstroCache *currentCache = NULL;

    double hundredCenturiesSinceEpochTDT = tdt / 100;
    double sunLong = WB_sunLongitudeRaw(hundredCenturiesSinceEpochTDT, currentCache);
    double sunLongAb = WB_sunLongitudeAberration(hundredCenturiesSinceEpochTDT);
    printAngle2(sunLong, desc, "sun meanLong");
    printAngle2(sunLongAb, desc, "sun longAb");
    double apparentRightAscension;
    double apparentDeclination;
    double sunLong2;
    WB_sunRAAndDecl(hundredCenturiesSinceEpochTDT, &apparentRightAscension, &apparentDeclination, &sunLong2, currentCache);
    printAngle2(sunLong2, desc, "sun apparentLong 2");
    printAngle2(apparentRightAscension, desc, "sun RA");
    printAngle2(apparentDeclination, desc, "sun decl");

    double geocentricApparentLongitude;
    double geocentricApparentLatitude;
    double geocentricDistance;
    WB_mercuryApparentPosition(hundredCenturiesSinceEpochTDT,
			       &geocentricApparentLongitude,
			       &geocentricApparentLatitude,
			       &geocentricDistance,
			       &apparentRightAscension,
			       &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "mercury geoLong");
    printAngle2(geocentricApparentLatitude, desc, "mercury geoLat");
    printAngle2(apparentRightAscension, desc, "mercury RA");
    printAngle2(apparentDeclination, desc, "mercury decl");

    WB_venusApparentPosition(hundredCenturiesSinceEpochTDT,
			     &geocentricApparentLongitude,
			     &geocentricApparentLatitude,
			     &geocentricDistance,
			     &apparentRightAscension,
			     &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "venus geoLong");
    printAngle2(geocentricApparentLatitude, desc, "venus geoLat");
    printAngle2(apparentRightAscension, desc, "venus RA");
    printAngle2(apparentDeclination, desc, "venus decl");

    WB_marsApparentPosition(hundredCenturiesSinceEpochTDT,
			    &geocentricApparentLongitude,
			    &geocentricApparentLatitude,
			    &geocentricDistance,
			    &apparentRightAscension,
			    &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "mars geoLong");
    printAngle2(geocentricApparentLatitude, desc, "mars geoLat");
    printAngle2(apparentRightAscension, desc, "mars RA");
    printAngle2(apparentDeclination, desc, "mars decl");

    WB_jupiterApparentPosition(hundredCenturiesSinceEpochTDT,
			       &geocentricApparentLongitude,
			       &geocentricApparentLatitude,
			       &geocentricDistance,
			       &apparentRightAscension,
			       &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "jupiter geoLong");
    printAngle2(geocentricApparentLatitude, desc, "jupiter geoLat");
    printAngle2(apparentRightAscension, desc, "jupiter RA");
    printAngle2(apparentDeclination, desc, "jupiter decl");

    WB_saturnApparentPosition(hundredCenturiesSinceEpochTDT,
			       &geocentricApparentLongitude,
			       &geocentricApparentLatitude,
			      &geocentricDistance,
			       &apparentRightAscension,
			      &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "saturn geoLong");
    printAngle2(geocentricApparentLatitude, desc, "saturn geoLat");
    printAngle2(apparentRightAscension, desc, "saturn RA");
    printAngle2(apparentDeclination, desc, "saturn decl");

    WB_uranusApparentPosition(hundredCenturiesSinceEpochTDT,
			      &geocentricApparentLongitude,
			      &geocentricApparentLatitude,
			      &geocentricDistance,
			      &apparentRightAscension,
			      &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "uranus geoLong");
    printAngle2(geocentricApparentLatitude, desc, "uranus geoLat");
    printAngle2(apparentRightAscension, desc, "uranus RA");
    printAngle2(apparentDeclination, desc, "uranus decl");

    WB_neptuneApparentPosition(hundredCenturiesSinceEpochTDT,
			       &geocentricApparentLongitude,
			       &geocentricApparentLatitude,
			       &geocentricDistance,
			       &apparentRightAscension,
			       &apparentDeclination, currentCache);
    printAngle2(geocentricApparentLongitude, desc, "neptune geoLong");
    printAngle2(geocentricApparentLatitude, desc, "neptune geoLat");
    printAngle2(apparentRightAscension, desc, "neptune RA");
    printAngle2(apparentDeclination, desc, "neptune decl");
}

static void EXAMPLEP(void) {
    ECAstroCache *currentCache = NULL;

    // Detailed example Bretagnon p9-10
    double t = TDTForUTDate(-4000, 7, 14, 0, 0, 0);
    double hundredCenturiesSinceEpochTDT = t / 100;
    double geocentricApparentLongitude;
    double geocentricApparentLatitude;
    double geocentricDistance;
    double apparentRightAscension;
    double apparentDeclination;
    WB_marsApparentPosition(hundredCenturiesSinceEpochTDT,
			    &geocentricApparentLongitude,
			    &geocentricApparentLatitude,
			    &geocentricDistance,
			    &apparentRightAscension,
			    &apparentDeclination, currentCache);
    printAngle(geocentricApparentLongitude, "EXAMPLEP:mars(-4000) geoLong");
    printAngle(geocentricApparentLatitude, "EXAMPLEP:mars(-4000) geoLat");
    printAngle(apparentRightAscension, "EXAMPLEP:mars(-4000) RA");
    printAngle(apparentDeclination, "EXAMPLEP:mars(-4000) decl");

    // Bretagnon p16 all planets on 5 dates: date 1, -1789 July 14 0h UT
    EXAMPLEPx(TDTForUTDate(-1789, 7, 14, 0, 0, 0), "EXAMPLEP -1789");
    // Bretagnon p16 all planets on 5 dates: date 2, 0 April 1 0h UT
    EXAMPLEPx(TDTForUTDate(0, 4, 1, 0, 0, 0), "EXAMPLEP 0");
    // Bretagnon p16 all planets on 5 dates: date 3, 1582 October 15 0h UT
    EXAMPLEPx(TDTForUTDate(1582, 10, 15, 0, 0, 0), "EXAMPLEP 1582");
    // Bretagnon p16 all planets on 5 dates: date 4, 1612 December 28 0h UT
    EXAMPLEPx(TDTForUTDate(1612, 12, 28, 0, 0, 0), "EXAMPLEP 1612");
    // Bretagnon p16 all planets on 5 dates: date 5, 1986 December 13 0h UT
    EXAMPLEPx(TDTForUTDate(1986, 12, 13, 0, 0, 0), "EXAMPLEP 1986");

    // Today
    ETConversionMethod = ETUseMeeus;
    printf("date: %.10f\n", TDTForUTDate(2009, 5, 3, 20, 0, 0));
    EXAMPLEPx(TDTForUTDate(2009, 5, 3, 20, 0, 0), "EXAMPLEP NOW");
}

#ifdef STANDALONE
int main() {
    ETConversionMethod = ETUseChapront;  // Use for testing only
#if 0
    EXAMPLE1();
    EXAMPLE2();
    EXAMPLE3();
    EXAMPLE4();
    EXAMPLE4A();
#endif
    EXAMPLE5();
    EXAMPLE12();
    ETConversionMethod = ETUseBretagnon;
    EXAMPLEP();
    ETConversionMethod = ETUseMeeus;
    EXAMPLEX();
    ETConversionMethod = ETUseMeeus;
}
#endif
#endif
