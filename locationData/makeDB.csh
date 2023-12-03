#! /bin/csh -f

# the raw data was downloaded from http://www.geonames.org/export/
set cityData = cities1000.txt
set admin1Data = admin1Codes.txt
set admin2Data = admin2Codes.txt
set countryData = countryData.txt

### rudimentary parameter checking

if ($# == 1) then
    echo OK
else if ($# == 2) then
    set cityData = $2
    echo input from $cityData
else
    echo usage: $0 newDB '[inputFile]'
    exit
endif

# generate from printAllTimeZones in EC
set tzData = tzNames.txt

if (! -e $cityData) then
    echo can't find $cityData
    exit
endif
if (! -e $tzData) then
    echo can't find $tzData
    exit
endif
if (! -e $countryData) then
    echo can't find $countryData
    exit
endif

### create the database
echo creating $1

rm -f $1
sqlite3 $1 << EOF
create table citytmp (cityId integer primary key, dcity varchar, city varchar,  acity varchar, lat float, long float, featureClass char(1), featureCode varchar, coCode char(2), cc2 char(2), a1Code char(2), a2Code char(2), a3Code char(2), pop integer, alt integer, timezone varchar);
EOF


### prepare input files
echo inserting city data

# grab just the columns we want (matching the above table)
# translate non-ascii chars
# blast quotes
# change tabs to @s
# insert the sql verbage and tilde at the beginning and end
# change both tildes to quotes
# change all @s to quote comma quote
(echo "Begin transaction;"; cut -f 1,2,3,4,5,6,7,8,9,10,11-13,15,17,18 $cityData | tr '”ầờ' '"ao' | sed -e"s/\'//g"  |  tr '\t' '@' | sed -e's/^/INSERT INTO "citytmp" VALUES(~/'  | sed -e's/$/~) ; /' | sed -e"s/~/\'/g"  | sed -e"s/@/\',\'/g"; echo "End transaction;") | sqlite3 $1


### add the timezone data
echo adding timezone table

sqlite3 $1 << EOF
create table timezone (
  tzCode integer primary key,
  timezone varchar
);
EOF

# stick a unique number on the front
cat -n $tzData > /tmp/tzn;
# tab to comma
tr '\t' ',' < /tmp/tzn > /tmp/two
# quote strings
sed -e"s/,/,\'/" /tmp/two | sed -e's/$/@/' | tr "@" "'" > /tmp/three
# insert the sql verbage and tilde at the beginning and end
sed -e's/^/INSERT INTO "timezone" VALUES(/' < /tmp/three | sed -e's/$/) ;/' > /tmp/tzinsert
# insert the timezone data
echo inserting `wc -l /tmp/tzinsert | cut -f 1 -d '/'` rows
sqlite3 $1 < /tmp/tzinsert


### clean up
rm /tmp/{tzn,two,three,tzinsert}


### add country data
echo adding country data

cut -f 1,5,6,7,8 $countryData | ./tr.csh | tr '\t' '|' > /tmp/cc

sqlite3 $1 << EOF
create table country (
  coCode char(2), 
  country varchar, 
  capital varchar, 
  area integer,
  countryPop integer
);
create unique index countryX on country(coCode);
.import /tmp/cc country
EOF

rm /tmp/cc

### add the admin1 codes
echo adding admin1 codes

echo "create table a1 (coCode char(2), a1Code char(2), a1name varChar);create unique index xa1 on a1(coCode,a1Code);" | sqlite3 $1

(echo "Begin transaction;"; sed -e's/\./\*/' $admin1Data | tr '*' '\t' | sed -e"s/\'//g"  |  tr '\t' '@' | sed -e's/^/INSERT INTO "a1" VALUES(~/'  | sed -e's/$/~) ; /' | sed -e"s/~/\'/g"  | sed -e"s/@/\',\'/g"; echo "End transaction;") | sqlite3 $1


### add the admin2 codes
echo adding admin2 codes

echo "create table a2 (coCode char(2), a1Code char(2), a2Code char(2), a2name varChar);create unique index xa2 on a2(coCode,a1Code,a2Code);" | sqlite3 $1

(echo "Begin transaction;"; cut -f 1,3 $admin2Data | sed -e's/\./\*/' | sed -e's/\./\*/' | tr '*' '\t' | sed -e"s/\'//g"  |  tr '\t' '@' | sed -e's/^/INSERT INTO "a2" VALUES(~/'  | sed -e's/$/~) ; /' | sed -e"s/~/\'/g"  | sed -e"s/@/\',\'/g"; echo "End transaction;") | sqlite3 $1


### optimize the database

# create indices
echo creating tmp and timezone indices
sqlite3 $1 << EOF
create unique index tzCodeX on timezone(tzCode);
create unique index timezoneX on timezone (timezone);
EOF

# now replace the timezone string in each city record with a ref to the timezone table
echo doing city/timezone join

sqlite3 $1 << EOF
create table city as select cityId, dcity, city, acity, lat, long, alt, featureClass, featureCode, coCode, cc2, a1Code, a2Code, a3Code, pop, timezone.timezone timezone, tzCode from citytmp,timezone where citytmp.timezone == timezone.timezone;
drop table citytmp;
EOF


# add indices, views, analyze and recover free space

echo creating city name index
echo "create index nameX on city (city);" | sqlite3 $1

echo creating city latitude,longitude index
echo "create index latLongX on city (lat,long);" | sqlite3 $1

echo creating city timezone index
echo "create index ctzCodeX on city (tzCode);" | sqlite3 $1

echo creating city countryCode indices
echo "create index citycountryCodeX on city(coCode);" | sqlite3 $1

echo creating country indices
sqlite3 $1 << EOF
create index countrynameX on country(country);
EOF

echo creating views
sqlite3 $1 << EOF
create view czc as select
  city, 
  lat,
  long,
  alt,
  country,
  city.coCode coCode,
  a1Code,
  a2Code,
  a3Code,
  pop,
  timezone
    from city, country where city.coCode=country.coCode;
EOF


### fix some errors

./fixDB.csh $1


### create the big tables and finish up

echo creating big table and base view
sqlite3 $1 << EOF
create table big as select * from (select * from (select * from city natural left join a1) natural left join a2) natural left join country;
create view base as select city, country, coCode, a1Name, a1Code, a2Name, a2Code, a3Code, tzCode, timezone, cc2, lat, long, pop from big;
EOF

echo creating big table indices
sqlite3 $1 << EOF
create index bigX  on big(city,coCode,a1Code,a2Code);
create index bigX1 on big(city,coCode,a1Code);
create index bigX2 on big(city,coCode);
create index bigX3 on big(city);
create index bigX4 on big(timezone);
create index bigX5 on big(tzCode);
create index bigX6 on big(lat,long);
EOF

echo vacuuming and analyzing
sqlite3 $1 << EOF
analyze;
vacuum;
EOF
