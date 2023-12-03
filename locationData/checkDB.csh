#! /bin/csh -f

# the raw data was downloaded from http://www.geonames.org/export/
# and imported by makeDB.csh
set sqlFile = foo.sqlite

### rudimentary parameter checking

if ($# == 0) then
    echo checking $sqlFile
else if ($# == 1) then
    set sqlFile = $1
    echo checking $sqlFile
else
    echo usage: $0 checkDB '[databseFile]'
    exit
endif

echo 'Database schema:'
echo

sqlite3 -column -header $sqlFile << EOF
.tables
.schema
EOF

echo
echo 'Countries with more than 1 timezone:'
echo

sqlite3 -column -header $sqlFile 'select count() cnt,country,cocode from (select count(),country,timezone,cocode,tzcode from base group by cocode,tzcode) group by cocode having cnt > 1 order by cnt;'

echo
echo 'US states with more than 1 timezone:'
echo

sqlite3 -column -header $sqlFile 'select count() cnt,country,cocode,a1name,a1code from ( select count(),country,timezone,cocode,tzcode,a1name,a1code from base where cocode="US" group by a1code,tzcode) group by a1code having cnt >1 order by a1Name;'
### Done


echo
echo 'a1Names with more than 1 timezone:'
echo

sqlite3 -column -header $sqlFile <<EOF

select cnt,y.country,y.cocode,x.a1name from
  country y, 
  (select count() cnt,country,cocode,a1name,a1code,timezone from 
    (select count(),country,timezone,cocode,tzcode,a1name,a1code from base group by a1code,tzcode) 
  group by a1code having cnt >1) x 
where x.cocode=y.cocode order by y.country,a1name;

EOF

sqlite3 -column -header $sqlFile <<EOF

drop table if exists zoneCounts;
drop table if exists a1ZoneCounts;
drop table if exists emptyCountries;
drop table if exists emptyZones;
drop table if exists singleZoneCountries;
drop table if exists multiZoneCountries;
drop table if exists singleZoneStates;
drop table if exists multiZoneStates;
drop table if exists x;

create table emptyZones as select * from timezone natural join (select timezone from timezone except select timezone from base group by timezone);

create table zoneCounts as select count() cityCnt, country, timezone, coCode from base group by country,timezone;
create table multiZoneCountries as select count() zoneCnt, coCode, country from zoneCounts group by country having zoneCnt>1 order by zoneCnt;
create table singleZoneCountries as select coCode, country, timezone from zoneCounts group by country having count()=1;
create table emptyCountries as select * from country natural join (select country from country except select country from singlezonecountries except select country from multizonecountries);

create table a1ZoneCounts as select count() cityCnt, cocode, a1code, country, a1Name, timezone  from multiZoneCountries natural join  base group by country,a1Name,timezone order by country,a1name,timezone;
create table multiZoneStates as select count() zoneCnt, coCode, a1code, country,a1Name from a1ZoneCounts group by country,a1Name having zoneCnt>1 order by country,a1name,zonecnt;
create table singleZoneStates as select  coCode, a1code, country,a1Name from a1ZoneCounts group by country,a1Name having count()=1 order by country,a1name;

create table x as select coCode, a1Code,tzCode, country,a1name,a2name,city,timezone from base natural join (select cocode,a1code from multiZoneStates) order by country,a1name,a2name,timezone;
EOF

echo
echo 'Empty timezones:'

sqlite3 -column -header $sqlFile <<EOF
.mode line
select count() from emptyZones;
.mode column
.width 4 40
select * from emptyZones;
EOF

echo
echo 'Country types:'

sqlite3 -column -header $sqlFile <<EOF
select empty,single,multi,countries,empty+single+multi sum from (select count() countries from country),(select count() empty from emptycountries),(select count() single from singlezonecountries),(select count() multi from multizonecountries);

EOF

echo
echo 'Empty countries:'

sqlite3 -column -header $sqlFile <<EOF
.mode line
select count() from emptyCountries;
.mode column
.width 4 40 30 10 10
select * from emptyCountries;
EOF

echo
echo 'Single zone countries:'

sqlite3 -column -header $sqlFile <<EOF
.mode line
select count() from singleZoneCountries;
.mode column
.width 4 40 30 10 10
select * from singleZoneCountries;
EOF

echo
echo 'Single zone states:'

sqlite3 -column -header $sqlFile <<EOF
.mode line
select count() from singleZoneStates;
.mode column
.width 4 4 32 40
select * from singleZoneStates;
EOF

echo
echo 'Removing known OK combinations'

sqlite3 -column -header $sqlFile <<EOF
delete  from x where timeZone="America/Chicago"  and a1Code in ("TN", "FL", "KY");
delete  from x where timeZone="America/New_York" and a1Code in ("TN", "FL", "KY");
delete  from x where timeZone="America/Phoenix" and a1Code = "AZ";
delete  from x where timeZone="America/Detroit" and a1Code = "MI";
delete  from x where timeZone in ("America/Los_Angeles", "America/Boise") and a1Code in ("OR","ID");
delete  from x where timeZone in ("America/Chicago", "America/Denver") and a1Code in ("NE","KS","ND","SD","TX");
delete  from x where timeZone in ("America/Indiana/Indianapolis", "America/New_York", "America/Chicago") and a1Code = "IN";
delete  from x where coCode='BR' and a1Code='17';
delete  from x where coCode='CA';

delete  from x where timeZone in ("Australia/Sydney") and coCode="AU" and a1Code = "02";
delete  from x where timeZone in ("Australia/Melbourne") and coCode="AU" and a1Code = "07";
EOF

echo
echo 'Cities in remaining multi zone states:'

sqlite3 -column -header $sqlFile <<EOF
.mode line
select count() from x;
.mode column
.width 3 3 3 20 20 30 30 40
EOF
