//
//  ECDB.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 9/15/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECDB.h"


@implementation ECDB

-(ECDB *)init {
    if (self = [super init]) {
	NSString *dbPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"/locationDB.sqlite"];

	if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
	    //printf("DB open\n");
	} else {
	    // Even though the open call failed, close the database connection to release all the memory
	    sqlite3_close(database);
	    database = nil;
	}
    }
    return self;
}

-(NSString *)findNearestCityToLatitude:(double)latitude longitude:(double)longitude delta:(double)delta {
    if (delta < 0.001) delta = 1;	    // TEMP  HACK
    assert(database);
    NSString *ret = nil;
    double minDist = 999999;	// very far
    delta = delta/2;		// just the visible part of the map
    NSString *locaterSQL = [NSString stringWithFormat:@"select city, lat, long, div2, countryCode, tzId from city where lat > %g and lat < %g and long > %g and long < %g",
			    latitude - delta, latitude + delta, longitude - delta, longitude + delta];
    sqlite3_stmt *locaterSelectStmt;
    if (sqlite3_prepare_v2(database, [locaterSQL UTF8String], -1, &locaterSelectStmt, NULL) == SQLITE_OK) {
	while(sqlite3_step(locaterSelectStmt) == SQLITE_ROW) {
	    NSString *name = [NSString stringWithUTF8String:(char*)sqlite3_column_text(locaterSelectStmt, 0)];
	    double lat = sqlite3_column_double(locaterSelectStmt, 1);
	    double lng = sqlite3_column_double(locaterSelectStmt, 2);
	    double dist = sqrt((lat-latitude)*(lat-latitude) + (lng-longitude)*(lng-longitude));
	    //printf("%s %g\n", [name UTF8String], dist);
	    if (dist < minDist) {
		ret = [name stringByAppendingFormat:@", %s, %s", sqlite3_column_text(locaterSelectStmt, 3), sqlite3_column_text(locaterSelectStmt, 4)];
		minDist = dist;
	    }
	}
    } else {
	assert(false);
    }
    //printf("%s %g\n", [ret UTF8String], minDist);
    sqlite3_finalize(locaterSelectStmt);
    return ret;
}

-(NSString *)findTimeZoneForLatitude:(double)latitude longitude:(double)longitude delta:(double)delta {
    if (delta < 0.001) delta = 1;	    // TEMP  HACK
    assert(database);
    BOOL gotOne = false;
    NSString *ret = nil;
    while (!gotOne ) {
	delta = delta*2;	// use a 4x larger region
	//printf("delta %g\n", delta);
	NSString *locaterSQL = [NSString stringWithFormat:@"select timezone, lat, long from cz where lat > %g and lat < %g and long > %g and long < %g order by (lat-(%g))*(lat-(%g))+(long-(%g))*(long-(%g))",
				latitude - delta, latitude + delta, longitude - delta, longitude + delta,
				latitude, latitude, longitude, longitude];
	sqlite3_stmt *locaterSelectStmt;
	if (sqlite3_prepare_v2(database, [locaterSQL UTF8String], -1, &locaterSelectStmt, NULL) == SQLITE_OK) {
	    BOOL n = false;	    // found a city north of our target
	    BOOL s = false;	    // found a city south of our target
	    BOOL e = false;	    // found a city  east of our target
	    BOOL w = false;	    // found a city  west of our target
	    while(sqlite3_step(locaterSelectStmt) == SQLITE_ROW) {
		gotOne = true;
		NSString *tzName = [NSString stringWithUTF8String:(char*)sqlite3_column_text(locaterSelectStmt, 0)];
		//printf("%s\n", [tzName UTF8String]);
		if (ret == nil || [ret caseInsensitiveCompare:tzName] == NSOrderedSame) {
		    ret = tzName;
		} else {
		    ret = @"ambiguous";
		    break;		// it's not going to get better
		}
		double lat = sqlite3_column_double(locaterSelectStmt, 1);
		double lng = sqlite3_column_double(locaterSelectStmt, 2);
		n = n || lat > latitude;
		s = s || lat < latitude;
		w = w || lng < longitude;
		e = e || lng > longitude;
		if (n && s && w && e) {
		    break;		// we've found cities in all 4 directions from the target
		}
	    }
	} else {
	    assert(false);
	}
	sqlite3_finalize(locaterSelectStmt);
    }
    //printf("<%s>\n\n", [ret UTF8String]);
    return ret;
}

-(void) dealloc {
    if (database) {
	sqlite3_close(database);
	database = nil;
    }
    [super dealloc];
}

@end
