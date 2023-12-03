//
//  ECWillmannBell.h
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


typedef enum { ECWBLowPrecision  = 0,
	       ECWBMidPrecision  = 1,
	       ECWBFullPrecision = 2
} ECWBPrecision;

extern void WB_MoonRAAndDecl(double centuriesSinceEpochTDT,
			     double *rightAscensionReturn,
			     double *declinationReturn,
			     double *longitudeReturn,
			     double *latitudeReturn,
			     ECAstroCache *currentCache,
			     ECWBPrecision p);

extern double WB_MoonEclipticLongitude(double centuriesSinceEpochTDT,
				       ECAstroCache *currentCache,
				       ECWBPrecision p);
extern double WB_MoonEclipticLatitude(double centuriesSinceEpochTDT,
				      ECAstroCache *currentCache,
				      ECWBPrecision p);
extern double WB_MoonDistance(double centuriesSinceEpochTDT,
			      ECAstroCache *currentCache,
			      ECWBPrecision p);
extern double WB_MoonAscendingNodeLongitude(double centuriesSinceEpochTDT,
					    ECAstroCache *currentCache);

extern double WB_sunLongitudeRaw(double hundredCenturiesSinceEpochTDT,
				 ECAstroCache *currentCache);
extern double WB_sunLongitudeApparent(double hundredCenturiesSinceEpochTDT,
				      ECAstroCache *currentCache);
extern double WB_sunRadius(double hundredCenturiesSinceEpochTDT,
			   ECAstroCache *currentCache);
extern void WB_sunLongitudeRadiusRaw(double hundredCenturiesSinceEpochTDT,
				     double *longitudeReturn,
				     double *radiusReturn,
				     ECAstroCache *currentCache);

void WB_sunRAAndDecl(double hundredCenturiesSinceEpochTDT,
		     double *rightAscensionReturn,
		     double *declinationReturn,
		     double *apparentLongitudeReturn,
		     ECAstroCache *currentCache);

void WB_nutationObliquity(double hundredCenturiesSinceEpochTDT,
			  double *nutationReturn,
			  double *obliquityReturn,
			  ECAstroCache *currentCache);

void WB_planetApparentPosition(int planetNumber,
			       double hundredCenturiesSinceEpochTDT,
			       double *geocentricApparentLongitude,
			       double *geocentricApparentLatitude,
			       double *geocentricDistance,
			       double *apparentRightAscension,
			       double *apparentDeclination,
			       ECAstroCache *currentCache,
			       ECWBPrecision moonPrecision);

double WB_planetHeliocentricLongitude(int planetNumber,
				      double hundredCenturiesSinceEpochTDT,
				      ECAstroCache *currentCache);
double WB_planetHeliocentricLatitude(int planetNumber,
				     double hundredCenturiesSinceEpochTDT,
				     ECAstroCache *currentCache);
double WB_planetHeliocentricRadius(int planetNumber,
				   double hundredCenturiesSinceEpochTDT,
				   ECAstroCache *currentCache);

void setECWBPrecision(ECWBPrecision newPrecision);
ECWBPrecision getECWBPrecision(void);

#ifndef NDEBUG
extern void WB_printMemoryUsage(void);
#endif
