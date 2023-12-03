//
//  ECDB.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 9/15/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

/*
 sqlite> .schema

 CREATE TABLE city (
     cityId integer,
     city varchar,
     lat float,
     long float,
     alt integer,
     countryCode char(2),
     div1 char(2),
     div2 char(2),
     div3 char(2),
     pop integer,
     tzId integer);
 
 CREATE TABLE country (
     countryCode char(2), 
     country varchar, 
     capital varchar, 
     area integer,
     countryPop integer);

 CREATE TABLE timezone (
     tzId integer primary key,
     timezone varchar);
 
 CREATE VIEW cz as select 
     city,
     lat,
     long,
     alt,
     countryCode,
     div1,
     div2,
     div3,
     pop,
     timezone
   from city,timezone where city.tzId=timezone.tzId;

 CREATE VIEW czc as select
     city, 
     lat,
     long,
     alt,
     country,
     cz.countryCode countryCode,
     div1,
     div2,
     div3,
     pop,
     timezone
 from cz, country where cz.countryCode=country.countryCode;

 CREATE INDEX countryCodeX on city(countryCode);
 CREATE INDEX countryX on country(countryCode);
 CREATE INDEX countrynameX on country(country);
 CREATE INDEX ctzidX on city (tzId);
 CREATE INDEX latLongX on city (lat,long);
 CREATE INDEX nameX on city (city);
 CREATE INDEX tzX on timezone (timezone);

*/

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface ECDB : NSObject {
    sqlite3 *database;
}

-(NSString *)findNearestCityToLatitude:(double)latitude longitude:(double)longitude delta:(double)delta;
-(NSString *)findTimeZoneForLatitude:(double)latitude longitude:(double)longitude delta:(double)delta;

@end
