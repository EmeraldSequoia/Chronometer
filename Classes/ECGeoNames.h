//
//  ECGeoNames.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 9/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#include "ESCalendar.h"  // For opaque ESTimeZone

typedef struct ECCityData ECCityData;
typedef struct ECGeoSortDescriptor ECGeoSortDescriptor;
typedef struct ECRegionDesc ECRegionDesc;
typedef struct ECTimeZoneRange ECTimeZoneRange;
typedef enum ECSlotInclusionClass { //slots reason								    example
    notIncluded,		    //	    doesnt fit in this slot
    normalHasDST,		    // 1    fills the slot exactly						    Los Angeles
    normalNoDSTLeft,		    // 2    on the boundary between this slot and the one to the east		    Phoenix
    normalNoDSTRight,		    // 2    on the boundary between this slot and the one to the west		    Phoenix
    halfHasDSTLeft,		    // 2    evenly splits the boundary between this slot and the one to the east    Adelaide
    halfHasDSTRight,		    // 2    evenly splits the boundary between this slot and the one to the west    Adelaide
    halfNoDST,			    // 1    in the middle of a slot						    Mumbai
    oddHasDST,			    // 1    off center of a slot						    <none as of 2010>
    oddNoDST			    // 1    off center of slot							    Kathmandu
} ECSlotInclusionClass;

typedef struct tzData {
    short   stdOffset;		    // "minutesFromGMT" for standard time
    short   dstOffset;		    // "minutesFromGMT" in daylight time   (== stdOffset if no DST)
} tzData;

@interface ECGeoNames : NSObject {
@private
    char       *cityNames;         // String, 1 per city, delimited by NULL characters.  Each name has 1+ components separated
                                   //   by '+':  First the ascii search name, then any alternate names ("Munich"), then the display name in full UTF8 if it's different.
                                   //   Loaded from loc-names.txt
    int        *nameIndices;       // Index,  1 per city, packed, indicating position of city within cityNames.  Loaded from loc-index.dat
    ECCityData *cityData;          // Pop/lat/long, 1 per city, packed.  Loaded from loc-data.dat
    short      *cityRegions;       // Region index, 1 per city, packed.  Loaded from loc-region.dat
    ECRegionDesc *regionDescs;     // Region descriptors, one per unique region index, packed.  Loaded from loc-regionDesc.dat
    NSArray    *ccNames;           // Country names based on ECRegionDesc cc index.  Loaded from loc-cc.dat
    NSArray    *a1Names;           // Admin1 names based on ECRegionDesc a1 index.  Loaded from loc-a1.dat
    NSArray    *a2Names;           // Admin2 names based on ECRegionDesc a2 index.  Loaded from loc-a2.dat
    NSArray    *a1Codes;           // Admin1 *codes* (e.g., US.CA) based on ECRegionDesc a1 index.  Loaded from loc-a1Codes.dat
    short      *tzIndices;         // Time zone index, 1 per city.  Loaded from loc-tz.dat
    NSArray    *tzNames;           // Name of time zone, delimited by NULL, for each unique time zone index.  Loaded from loc-tzNames.dat
    unsigned int tzNamesChecksum;  // Checksum of tzNames array in use (can be used as version id)
    tzData     *tzCache;         // Center of offset of time zone in minutes, for each unique time zone index.  Calculated by instantiating time zones.
    int        numCities;          // Count of nameIndices, cityData, regionIndices, etc. arrays
    int        numRegionDescs;     // Count of regionDescs array

    int        selectedCityIndex;  // Index of city currently selected either by findClosestCityToLatitudeDegrees or selectNthTopCity

    ECGeoSortDescriptor *sortedSearchIndices;   // Sort descriptor (index + sort value) for each name matched by searchForCityNameFragment
    int                 numMatchingCities;      // Number of matching cities in sortedSearchIndices
    int			numMatchingAtLevel[3];	// Number of matching cities in sortedSearchIndices at each confidence level
}

// Call findClosest first, then you can use the access methods to return the last found city
-(void)findClosestCityToLatitudeDegrees:(float)latitudeDegrees longitudeDegrees:(float)longitudeDegrees;
-(void)findBestMatchCityToLatitudeDegrees:(float)latitudeDegrees longitudeDegrees:(float)longitudeDegrees;	// factors in population, too
-(NSString *)selectedCityName;		// returns last found city
-(NSString *)selectedCityRegionName;	// returns last found city's region info
-(NSString *)selectedCityTZName;	// returns last found city tz name
-(float)selectedCityLatitude;		// returns last found city's latitude
-(float)selectedCityLongitude;		// returns last found city's longitude
-(unsigned long)selectedCityPopulation;	// returns last found city's population
-(bool)selectedCityValidForSlotAtOffsetHour:(int)offsetHours;   // returns true iff last found city can fit in slot for (offsetHours:offsetHours+1)
-(ECSlotInclusionClass)selectedCityInclusionClassForSlotAtOffsetHour:(int)offsetHours;	    // returns a code indicating why city is or isn't in this slot
    
// Sort top N cities first, then retrieve each one's name
-(void)searchForCityNameFragment:(NSString *)cityNameFragment appropriateForNominalTZSlot:(int)offsetHours;
-(void)searchForCityNameFragment:(NSString *)cityNameFragment withProximity:(bool)proximity;
-(int)searchForCity:(NSString *)cityName state:(NSString *)state country:(NSString *)country code:(NSString *)code;
-(NSString *)topCityNameAtIndex:(int)index;	// after search
-(void)selectNthTopCity:(int)index;		// after search; then after calling this you can use *selected* methods above
-(int)numMatches;				// after search; number of matching city entries
-(int)numMatchesAtLevel:(int)level;		// after qualified search; number of matching city entries with confidence level

// revert to pre-search state
-(void)clearSelection;

// Use this to clear storage when exiting location picker
-(void)clearStorage;

#ifndef NDEBUG
-(NSArray *)tzNames;
#endif
+(bool)validTZ:(ESTimeZone *)tz forSlot:(int)offsetHours;

@end
