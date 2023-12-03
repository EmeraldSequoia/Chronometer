#! /bin/csh -f

# the raw data was downloaded from http://www.geonames.org/export/
# and imported by makeDB.csh
set sqlFile = foo.sqlite

### rudimentary parameter checking

if ($# == 0) then
    echo fixing bugs in $sqlFile
else if ($# == 1) then
    set sqlFile = $1
    echo fixing bugs in $sqlFile
else
    echo usage: $0 fixDB '[databseFile]'
    exit
endif

sqlite3 -column -header $sqlFile << EOF
.width 30 4 4 4 40
select city,coCode,a1Code,a2Code,timezone from city where tzcode='126' and a1code!='KY';
create table fixed as select city,coCode,a1Code,a2Code from city where tzcode='126' and a1code!='KY';
EOF

### fix bugs

sqlite3 -column -header $sqlFile << EOF

update country set area = NULL where area > 100000000;

insert into a1 values('RO','00','Romania general');
insert into a1 values('SI','00','Slovenia general');
insert into a1 values('NZ','00','New Zealand general');
insert into a1 values('RU','CI','Chechnya');
insert into a1 values('ID','07','Central Java');

-- dup a2code GB.ENG.F2 is harmless
update a2 set a2Name='' where cocode='GB' and a1Code='ENG' and a2Code='00';

update city set pop = 0 where city='Juan Dolio' and coCode='DO';

update city set a1Code='01' where cocode='TR' and a1Code='81';
update city set a1Code=''   where coCode='CL' and city='Hanga Roa';
update city set a1Code='06' where city='Arkhangelsk';
update city set a1Code='00' where coCode='CH' and a1Code='';
update city set a1Code='04' where coCode='AR' and city='Comodoro Rivadavia';

delete from city where city="Khazar" and coCode='RU';

update city set tzCode='165', timezone='America/Rio_Branco'             where coCode='BR' and city='Sena Madureira';
update city set tzCode='130', timezone='America/Maceio'                 where coCode='BR' and city='Colonia Leopoldina';
update city set tzCode='169', timezone='America/Sao_Paulo'              where coCode='BR' and city='Conceicao da Barra';
update city set tzCode='132', timezone='America/Manaus'                 where coCode='BR' and city='Nhamunda';
update city set tzCode='100', timezone='America/Fortaleza'              where coCode='BR' and city='Porto Franco';

update city set tzCode='229',  timezone='Asia/Jakarta'                  where coCode='ID' and city='Meulaboh';

update city set tzCode='57',  timezone='America/Argentina/Buenos_Aires' where coCode='AR' and city='Buenos Aires';
update city set tzCode='64',  timezone='America/Argentina/Salta'        where coCode='AR' and city='Viedma';

update city set tzCode='297', timezone='Australia/Sydney'               where coCode='AU' and city='Sawtell';
update city set tzCode='297', timezone='Australia/Sydney'               where coCode='AU' and city='Coffs Harbour';

update city set tzCode='86',  timezone='America/Chicago'  where coCode='US' and a1Code='TX' and city='South Padre Island';
update city set tzCode='86',  timezone='America/Chicago'  where coCode='US' and a1Code='TX' and city='Laguna Vista';
update city set tzCode='146', timezone='America/New_York' where coCode='US' and a1Code='FL' and city='Fort Walton Beach';
update city set tzCode='146', timezone='America/New_York' where coCode='US' and a1Code='FL' and city='Laguna Beach';
update city set tzCode='146', timezone='America/New_York' where coCode='US' and a1Code='FL' and city='Mary Esther';
update city set tzCode='146', timezone='America/New_York' where coCode='US' and a1Code='FL' and city='Parker';
update city set tzCode='146', timezone='America/New_York' where tzcode='126' and a1code!='KY';

EOF


### for Steve

sqlite3 $sqlFile << EOF
.mode csv
select city,coCode,a1Code,a2Code,city.timezone from city natural join fixed;
select city,coCode,a1Code,a2Code,timezone from city where city in (
'Sena Madureira',
'Colonia Leopoldina',
'Conceicao da Barra',
'Nhamunda',
'Porto Franco',
'Meulaboh',
'Buenos Aires',
'Viedma',
'Sawtell',
'Coffs Harbour',
'South Padre Island',
'Laguna Vista',
'Fort Walton Beach',
'Laguna Beach',
'Mary Esther',
'Parker');
EOF
