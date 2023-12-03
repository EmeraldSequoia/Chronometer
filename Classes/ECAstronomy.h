//
//  ECAstronomy.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@class ECWatchEnvironment;
@class ECWatchTime;

typedef struct ECAstroCache ECAstroCache;
typedef struct ECAstroCachePool ECAstroCachePool;

#include "ESCalendar.h"  // For opaque ESTimeZone

@interface ECAstronomyManager : NSObject {
    // Input parameters
    ECWatchEnvironment  *environment;
    ECWatchTime         *watchTime;

    // Internal data -- temporary only while calculating
    NSTimeInterval      calculationDateInterval;
    ESTimeZone          *estz;
    double              observerLatitude;
    double              observerLongitude;
    bool                locationValid;
    ECAstroCache        *currentCache;
    ECAstroCachePool    *astroCachePool;
    ECWatchTime         *scratchWatchTime;
    bool                inActionButton;  // in the action button for *this* astro mgr
}

@property(readonly, nonatomic) double observerLatitude;

+(void)initializeStatics;
+(double)widthOfZodiacConstellation:(int)n;
+(double)centerOfZodiacConstellation:(int)n;
+(NSString *)zodiacConstellationOf:(double)elong;
-(id)initFromEnvironment:(ECWatchEnvironment *)environment watchTime:(ECWatchTime *)watchTime;
-(void)dealloc;

// Methods called by ECGLWatch prior to updating a series of parts, and after the update is complete
-(void)setupLocalEnvironmentForThreadFromActionButton:(bool)fromActionButton;
-(void)cleanupLocalEnvironmentForThreadFromActionButton:(bool)fromActionButton;

// The following calculation functions operate on the ECWatchTime virtual time
// indicated by the environment's watch time

// The sunrise for the day given by the environment's time, whether before or after that time
-(NSTimeInterval)sunriseForDay;
// The sunset for the day given by the environment's time, whether before or after that time
-(NSTimeInterval)sunsetForDay;

// The first sunrise following the time in the environment, whether on the same day or the next
// When the environment's clock is running backward, it returns the previous sunrise instead.
-(NSTimeInterval)nextSunrise;
-(NSTimeInterval)nextSunriseOrMidnight;
// The first sunset following the time in the environment, whether on the same day or the next
// When the environment's clock is running backward, it returns the previous sunset instead.
-(NSTimeInterval)nextSunset;
-(NSTimeInterval)nextSunsetOrMidnight;

// The moonrise for the day given by the environment's time, whether before or after that time
-(NSTimeInterval)moonriseForDay;
// The moonset for the day given by the environment's time, whether before or after that time
-(NSTimeInterval)moonsetForDay;

// The first moonrise following the time in the environment, whether on the same day or the next
// When the environment's clock is running backward, it returns the previous moonrise instead.
-(NSTimeInterval)nextMoonrise;
-(NSTimeInterval)nextMoonriseOrMidnight;
// The first moonset following the time in the environment, whether on the same day or the next
// When the environment's clock is running backward, it returns the previous moonset instead.
-(NSTimeInterval)nextMoonset;
-(NSTimeInterval)nextMoonsetOrMidnight;

-(NSTimeInterval)planetriseForDay:(int)planetNumber;
-(NSTimeInterval)planetsetForDay:(int)planetNumber;
-(NSTimeInterval)nextPlanetriseForPlanetNumber:(int)planetNumber;
-(NSTimeInterval)nextPlanetsetForPlanetNumber:(int)planetNumber;
-(NSTimeInterval)prevPlanetriseForPlanetNumber:(int)planetNumber;
-(NSTimeInterval)prevPlanetsetForPlanetNumber:(int)planetNumber;

-(NSTimeInterval)moontransitForDay;
-(NSTimeInterval)suntransitForDay;
-(NSTimeInterval)nextMoontransit;
-(NSTimeInterval)nextSuntransit;
    
// return true in summer half of the year
-(bool)summer;

// returns 1 if planet is above the equator and the observer is also, or both below
-(bool)planetIsSummer:(int)planetNumber;

// return the local sidereal time
-(double)localSiderealTime;

// Separation of Sun from Moon, or Earth's shadow from Moon, scaled such that
//   1) partial eclipse starts when separation == 2
//   2) total eclipse starts when separation == 1
// Note that zero doesn't therefore represent zero separation, and that zero separation may lie above or below the total eclipse point depending on the relative diameters
-(double)eclipseSeparation;
-(double)eclipseAngularSeparation;
-(ECEclipseKind)eclipseKind;
+(bool)eclipseKindIsMoreSolarThanLunar:(ECEclipseKind)eclipseKind;

// Whether the given op has a valid date (difficult to tell otherwise now that we supply the meridian
// time on the clock)
-(bool)nextSunriseValid;
-(bool)nextSunsetValid;
-(bool)nextMoonriseValid;
-(bool)nextMoonsetValid;
-(bool)prevSunriseValid;
-(bool)prevSunsetValid;
-(bool)prevMoonriseValid;
-(bool)prevMoonsetValid;
-(bool)sunriseForDayValid;
-(bool)sunsetForDayValid;
-(bool)moonriseForDayValid;
-(bool)moonsetForDayValid;
-(bool)suntransitForDayValid;
-(bool)moontransitForDayValid;
-(bool)planetriseForDayValid:(int)planetNumber;
-(bool)planetsetForDayValid:(int)planetNumber;
-(bool)planettransitForDayValid:(int)planetNumber;
-(bool)nextPlanetriseValid:(int)planetNumber;
-(bool)nextPlanetsetValid:(int)planetNumber;

// Special op for day/night indicator leaves
-(double)dayNightLeafAngleForPlanetNumber:(int)planetNumber
			       leafNumber:(double)leafNumber
				numLeaves:(int)numLeaves
                             timeBaseKind:(ECTimeBaseKind)timeBaseKind;
// Defaults to LT (local time):
-(double)dayNightLeafAngleForPlanetNumber:(int)planetNumber
			       leafNumber:(double)leafNumber
				numLeaves:(int)numLeaves;

// Special ops for Mauna Kea & the planet equivalent
-(bool)sunriseIndicatorValid;
-(bool)sunsetIndicatorValid;
-(double)sunrise24HourIndicatorAngle;
-(bool)polarSummer;
-(bool)polarWinter;
-(double)sunset24HourIndicatorAngle;
-(double)moonrise24HourIndicatorAngle;
-(double)moonset24HourIndicatorAngle;
-(double)planetrise24HourIndicatorAngle:(int)planetNumber;
-(double)planetset24HourIndicatorAngle:(int)planetNumber;
-(double)planettransit24HourIndicatorAngle:(int)planetNumber forNumLeaves:(int)numLeaves;
-(double)planetrise24HourIndicatorAngleLST:(int)planetNumber;
-(double)planetset24HourIndicatorAngleLST:(int)planetNumber;

// Age in moon.  This routine makes one revolution of EC_2PI every 28+ days
-(double)moonAgeAngle;
-(double)realMoonAgeAngle;
-(NSTimeInterval)nextMoonPhase; // new, 1st, full, third
-(double)moonPositionAngle;  // rotation of terminator relative to earth's North (std defn)
-(double)moonRelativePositionAngle;  // rotation of terminator as it appears in the sky
-(double)moonRelativeAngle; // rotation of moon image as it appears in the sky
-(NSTimeInterval)closestNewMoon;
-(NSTimeInterval)closestFullMoon;
-(NSTimeInterval)closestFirstQuarter;
-(NSTimeInterval)closestThirdQuarter;
-(NSTimeInterval)nextNewMoon;
-(NSTimeInterval)nextFullMoon;
-(NSTimeInterval)nextFirstQuarter;
-(NSTimeInterval)nextThirdQuarter;
-(NSString *)moonPhaseString;

+(double)moonDeltaEclipticLongitudeAtDateInterval:(double)dateInterval;

// Functions for doing planetary terminator displays
-(double)planetMoonAgeAngle:(int)planetNumber;
-(double)planetRelativePositionAngle:(int)planetNumber; // rotation of terminator as it appears in the sky

// Sun and Moon equatorial positions
-(double)sunRA;
-(double)sunDecl;
-(double)moonRA;
-(double)moonDecl;

// Sun and Moon alt/az positions
-(double)sunAltitude;
-(double)sunAzimuth;
-(double)moonAltitude;
-(double)moonAzimuth;
-(double)planetAltitude:(int)planetNumber;
-(double)planetAzimuth:(int)planetNumber;
-(double)planetAzimuth:(int)planetNumber atDateInterval:(NSTimeInterval)dateInterval;
-(bool)planetIsUp:(int)planetNumber;
-(double)planetRA:(int)planetNumber correctForParallax:(bool)correctForParallax;
-(double)planetDecl:(int)planetNumber correctForParallax:(bool)correctForParallax;
-(double)planetEclipticLongitude:(int)planetNumber;
-(double)planetEclipticLatitude:(int)planetNumber;
-(double)planetGeocentricDistance:(int)planetNumber;
-(double)planetRadius:(int)n;
-(double)planetApparentDiameter:(int)n;
-(double)planetMass:(int)n;
-(double)planetOribitalPeriod:(int)n;
    
// Moon ascending node
-(double)moonAscendingNodeLongitude;
-(double)moonAscendingNodeRA;
-(double)moonAscendingNodeRAJ2000;

// Precession of the equinoxes
-(double)precession;

// Calendar error for Julian calendar
-(double)calendarErrorVsTropicalYear;

// 0 => long==0, 1 => long==PI/2, etc
-(NSTimeInterval)refineTimeOfClosestSunEclipticLongitude:(int)longitudeQuarter;
-(double)closestSunEclipticLongitudeQuarter366IndicatorAngle:(int)longitudeQuarter;

-(NSTimeInterval)planettransitForDay:(int)planetNumber;
-(NSTimeInterval)nextPlanettransit:(int)planetNumber;

-(double)planetHeliocentricLongitude:(int)planetNumber;
-(double)planetHeliocentricLatitude:(int)planetNumber;
-(double)planetHeliocentricRadius:(int)planetNumber;

// Azimuth and ecliptic longitude of where the ecliptic has its highest altitude at the present time
-(double)azimuthOfHighestEclipticAltitude;
-(double)longitudeOfHighestEclipticAltitude;

// Angle ecliptic makes with the horizon
-(double)eclipticAltitude;

// Ecliptic longitude at azimuth==0
-(double)longitudeAtNorthMeridian;

// Amount the sidereal time coordinate system has rotated around since the autumnal equinox
-(double)vernalEquinoxAngle;

// Equation of Time for today expressed as an angle
-(double)EOT;

// These convenience methods return a temporary watch, from which standard
// ECWatchTime methods can be used to extract the proper hour angle, etc.
// They are based on the calculation methods above and represent the same times as those methods.
-(ECWatchTime *)watchTimeWithSunriseForDay;
-(ECWatchTime *)watchTimeWithSunsetForDay;
-(ECWatchTime *)watchTimeWithSuntransitForDay;
-(ECWatchTime *)watchTimeWithNextSunrise;
-(ECWatchTime *)watchTimeWithNextSunset;
-(ECWatchTime *)watchTimeWithMoonriseForDay;
-(ECWatchTime *)watchTimeWithMoonsetForDay;
-(ECWatchTime *)watchTimeWithMoontransitForDay;
-(ECWatchTime *)watchTimeWithNextMoonrise;
-(ECWatchTime *)watchTimeWithNextMoonset;
-(ECWatchTime *)watchTimeWithClosestNewMoon;
-(ECWatchTime *)watchTimeWithClosestFullMoon;
-(ECWatchTime *)watchTimeWithClosestFirstQuarter;
-(ECWatchTime *)watchTimeWithClosestThirdQuarter;
-(ECWatchTime *)watchTimeWithPlanetriseForDay:(int)planetNumber;
-(ECWatchTime *)watchTimeWithPlanetsetForDay:(int)planetNumber;
-(ECWatchTime *)watchTimeWithPlanettransitForDay:(int)planetNumber;

@end
