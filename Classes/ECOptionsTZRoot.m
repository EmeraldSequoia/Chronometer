//
//  ECOptionsTZRoot.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/7/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsTZRoot.h"
#import "ECOptionsTZ.h"
#import "ECOptions.h"
#import "Constants.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ChronometerAppDelegate.h"
#import "ECGlobals.h"


typedef struct continentDataType {
    NSString	*name;
    int		numZones;
    NSString	**zones;
} continentDataType;
static continentDataType continentData [NUMCONTINENTS];

static NSString *FrequentlyUsedZones[] = {
    @"UTC",
    @"America/New_York",
    @"America/Chicago",
    @"America/Denver",
    @"America/Los_Angeles",
    @"America/Toronto",
    @"America/Vancouver",
    @"Europe/London",
    @"Europe/Berlin",
    @"Europe/Paris",
    @"Europe/Zurich",
    @"Europe/Rome",
    @"Europe/Madrid",
    @"Australia/Sydney",
    @"Australia/Melbourne",
    @"Australia/Brisbane",
    @"Australia/Perth",
    @"Asia/Tokyo"
};
static NSString *NorthAmericaZones[] = {
    @"America/Adak",
    @"America/Anchorage",
    @"America/Atikokan",
    @"America/Bahia_Banderas",
    @"America/Blanc-Sablon",
    @"America/Boise",
    @"America/Cambridge_Bay",
    @"America/Cancun",
    @"America/Chicago",
    @"America/Chihuahua",
    @"America/Danmarkshavn",
    @"America/Dawson",
    @"America/Dawson_Creek",
    @"America/Denver",
    @"America/Detroit",
    @"America/Edmonton",
    @"America/Glace_Bay",
    @"America/Godthab",
    @"America/Goose_Bay",
    @"America/Halifax",
    @"America/Hermosillo",
    @"America/Indiana/Indianapolis",
    @"America/Indiana/Knox",
    @"America/Indiana/Marengo",
    @"America/Indiana/Petersburg",
    @"America/Indiana/Tell_City",
    @"America/Indiana/Vevay",
    @"America/Indiana/Vincennes",
    @"America/Indiana/Winamac",
    @"America/Inuvik",
    @"America/Iqaluit",
    @"America/Juneau",
    @"America/Kentucky/Louisville",
    @"America/Kentucky/Monticello",
    @"America/Los_Angeles",
    @"America/Matamoros",
    @"America/Mazatlan",
    @"America/Menominee",
    @"America/Merida",
    @"America/Mexico_City",
    @"America/Miquelon",
    @"America/Moncton",
    @"America/Monterrey",
    @"America/Montreal",
    @"America/New_York",
    @"America/Nipigon",
    @"America/Nome",
    @"America/North_Dakota/Center",
    @"America/North_Dakota/New_Salem",
    @"America/Ojinaga",
    @"America/Pangnirtung",
    @"America/Phoenix",
    @"America/Rainy_River",
    @"America/Rankin_Inlet",
    @"America/Regina",
    @"America/Resolute",
    @"America/Santa_Isabel",
    @"America/Scoresbysund",
    @"America/Shiprock",
    @"America/Swift_Current",
    @"America/Thule",
    @"America/Thunder_Bay",
    @"America/Tijuana",
    @"America/Toronto",
    @"America/Vancouver",
    @"America/Whitehorse",
    @"America/Winnipeg",
    @"America/Yakutat",
    @"America/Yellowknife"
};
static NSString *SouthAmericaZones[] = {
    @"America/Araguaina",
    @"America/Argentina/Buenos_Aires",
    @"America/Argentina/Catamarca",
    @"America/Argentina/Cordoba",
    @"America/Argentina/Jujuy",
    @"America/Argentina/La_Rioja",
    @"America/Argentina/Mendoza",
    @"America/Argentina/Rio_Gallegos",
    @"America/Argentina/Salta",
    @"America/Argentina/San_Juan",
    @"America/Argentina/San_Luis",
    @"America/Argentina/Tucuman",
    @"America/Argentina/Ushuaia",
    @"America/Asuncion",
    @"America/Bahia",
    @"America/Belem",
    @"America/Boa_Vista",
    @"America/Bogota",
    @"America/Campo_Grande",
    @"America/Caracas",
    @"America/Cayenne",
    @"America/Cuiaba",
    @"America/Eirunepe",
    @"America/Fortaleza",
    @"America/Guayaquil",
    @"America/Guyana",
    @"America/Havana",
    @"America/La_Paz",
    @"America/Lima",
    @"America/Maceio",
    @"America/Manaus",
    @"America/Montevideo",
    @"America/Noronha",
    @"America/Paramaribo",
    @"America/Porto_Velho",
    @"America/Recife",
    @"America/Rio_Branco",
    @"America/Santarem",
    @"America/Santiago",
    @"America/Sao_Paulo"
};
static NSString *CentralAmericaZones[] = {
    @"America/Anguilla",
    @"America/Antigua",
    @"America/Aruba",
    @"America/Barbados",
    @"America/Belize",
    @"America/Cayman",
    @"America/Costa_Rica",
    @"America/Curacao",
    @"America/Dominica",
    @"America/El_Salvador",
    @"America/Grand_Turk",
    @"America/Grenada",
    @"America/Guadeloupe",
    @"America/Guatemala",
    @"America/Jamaica",
    @"America/Managua",
    @"America/Marigot",
    @"America/Martinique",
    @"America/Montserrat",
    @"America/Nassau",
    @"America/Panama",
    @"America/Port-au-Prince",
    @"America/Port_of_Spain",
    @"America/Puerto_Rico",
    @"America/Santo_Domingo",
    @"America/St_Barthelemy",
    @"America/St_Johns",
    @"America/St_Kitts",
    @"America/St_Lucia",
    @"America/St_Thomas",
    @"America/St_Vincent",
    @"America/Tegucigalpa",
    @"America/Tortola"
};
static NSString *EuropeZones[] = {
    @"Europe/Amsterdam",
    @"Europe/Andorra",
    @"Europe/Athens",
    @"Europe/Belgrade",
    @"Europe/Berlin",
    @"Europe/Bratislava",
    @"Europe/Brussels",
    @"Europe/Bucharest",
    @"Europe/Budapest",
    @"Europe/Chisinau",
    @"Europe/Copenhagen",
    @"Europe/Dublin",
    @"Europe/Gibraltar",
    @"GMT",
    @"Europe/Guernsey",
    @"Europe/Helsinki",
    @"Europe/Isle_of_Man",
    @"Europe/Istanbul",
    @"Europe/Jersey",
    @"Europe/Kaliningrad",
    @"Europe/Kiev",
    @"Europe/Lisbon",
    @"Europe/Ljubljana",
    @"Europe/London",
    @"Europe/Luxembourg",
    @"Europe/Madrid",
    @"Europe/Malta",
    @"Europe/Mariehamn",
    @"Europe/Minsk",
    @"Europe/Monaco",
    @"Europe/Moscow",
    @"Europe/Oslo",
    @"Europe/Paris",
    @"Europe/Podgorica",
    @"Europe/Prague",
    @"Europe/Riga",
    @"Europe/Rome",
    @"Europe/Samara",
    @"Europe/San_Marino",
    @"Europe/Sarajevo",
    @"Europe/Simferopol",
    @"Europe/Skopje",
    @"Europe/Sofia",
    @"Europe/Stockholm",
    @"Europe/Tallinn",
    @"Europe/Tirane",
    @"Europe/Uzhgorod",
    @"Europe/Vaduz",
    @"Europe/Vatican",
    @"Europe/Vienna",
    @"Europe/Vilnius",
    @"Europe/Volgograd",
    @"Europe/Warsaw",
    @"Europe/Zagreb",
    @"Europe/Zaporozhye",
    @"Europe/Zurich"
};
static NSString *AustraliaZones[] = {
    @"Australia/Adelaide",
    @"Australia/Brisbane",
    @"Australia/Broken_Hill",
    @"Australia/Currie",
    @"Australia/Darwin",
    @"Australia/Eucla",
    @"Australia/Hobart",
    @"Australia/Lindeman",
    @"Australia/Lord_Howe",
    @"Australia/Melbourne",
    @"Australia/Perth",
    @"Australia/Sydney"
};
static NSString *AsiaZones[] = {
    @"Asia/Aden",
    @"Asia/Almaty",
    @"Asia/Amman",
    @"Asia/Anadyr",
    @"Asia/Aqtau",
    @"Asia/Aqtobe",
    @"Asia/Ashgabat",
    @"Asia/Baghdad",
    @"Asia/Bahrain",
    @"Asia/Baku",
    @"Asia/Bangkok",
    @"Asia/Beirut",
    @"Asia/Bishkek",
    @"Asia/Brunei",
    @"Asia/Choibalsan",
    @"Asia/Chongqing",
    @"Asia/Colombo",
    @"Asia/Damascus",
    @"Asia/Dhaka",
    @"Asia/Dili",
    @"Asia/Dubai",
    @"Asia/Dushanbe",
    @"Asia/Gaza",
    @"Asia/Harbin",
    @"Asia/Ho_Chi_Minh",
    @"Asia/Hong_Kong",
    @"Asia/Hovd",
    @"Asia/Irkutsk",
    @"Asia/Jakarta",
    @"Asia/Jayapura",
    @"Asia/Jerusalem",
    @"Asia/Kabul",
    @"Asia/Kamchatka",
    @"Asia/Karachi",
    @"Asia/Kashgar",
    @"Asia/Kathmandu",
    @"Asia/Katmandu",
    @"Asia/Kolkata",
    @"Asia/Krasnoyarsk",
    @"Asia/Kuala_Lumpur",
    @"Asia/Kuching",
    @"Asia/Kuwait",
    @"Asia/Macau",
    @"Asia/Magadan",
    @"Asia/Makassar",
    @"Asia/Manila",
    @"Asia/Muscat",
    @"Asia/Nicosia",
    @"Asia/Novokuznetsk",
    @"Asia/Novosibirsk",
    @"Asia/Omsk",
    @"Asia/Oral",
    @"Asia/Phnom_Penh",
    @"Asia/Pontianak",
    @"Asia/Pyongyang",
    @"Asia/Qatar",
    @"Asia/Qyzylorda",
    @"Asia/Rangoon",
    @"Asia/Riyadh",
    @"Asia/Sakhalin",
    @"Asia/Samarkand",
    @"Asia/Seoul",
    @"Asia/Shanghai",
    @"Asia/Singapore",
    @"Asia/Taipei",
    @"Asia/Tashkent",
    @"Asia/Tbilisi",
    @"Asia/Tehran",
    @"Asia/Thimphu",
    @"Asia/Tokyo",
    @"Asia/Ulaanbaatar",
    @"Asia/Urumqi",
    @"Asia/Vientiane",
    @"Asia/Vladivostok",
    @"Asia/Yakutsk",
    @"Asia/Yekaterinburg",
    @"Asia/Yerevan"
};
static NSString *AfricaZones[] = {
    @"Africa/Abidjan",
    @"Africa/Accra",
    @"Africa/Addis_Ababa",
    @"Africa/Algiers",
    @"Africa/Asmara",
    @"Africa/Bamako",
    @"Africa/Bangui",
    @"Africa/Banjul",
    @"Africa/Bissau",
    @"Africa/Blantyre",
    @"Africa/Brazzaville",
    @"Africa/Bujumbura",
    @"Africa/Cairo",
    @"Africa/Casablanca",
    @"Africa/Ceuta",
    @"Africa/Conakry",
    @"Africa/Dakar",
    @"Africa/Dar_es_Salaam",
    @"Africa/Djibouti",
    @"Africa/Douala",
    @"Africa/El_Aaiun",
    @"Africa/Freetown",
    @"Africa/Gaborone",
    @"Africa/Harare",
    @"Africa/Johannesburg",
    @"Africa/Kampala",
    @"Africa/Khartoum",
    @"Africa/Kigali",
    @"Africa/Kinshasa",
    @"Africa/Lagos",
    @"Africa/Libreville",
    @"Africa/Lome",
    @"Africa/Luanda",
    @"Africa/Lubumbashi",
    @"Africa/Lusaka",
    @"Africa/Malabo",
    @"Africa/Maputo",
    @"Africa/Maseru",
    @"Africa/Mbabane",
    @"Africa/Mogadishu",
    @"Africa/Monrovia",
    @"Africa/Nairobi",
    @"Africa/Ndjamena",
    @"Africa/Niamey",
    @"Africa/Nouakchott",
    @"Africa/Ouagadougou",
    @"Africa/Porto-Novo",
    @"Africa/Sao_Tome",
    @"Africa/Tripoli",
    @"Africa/Tunis",
    @"Africa/Windhoek"
};
static NSString *PacificZones[] = {
    @"Pacific/Apia",
    @"Pacific/Auckland",
    @"Pacific/Chatham",
    @"Pacific/Chuuk",
    @"Pacific/Easter",
    @"Pacific/Efate",
    @"Pacific/Enderbury",
    @"Pacific/Fakaofo",
    @"Pacific/Fiji",
    @"Pacific/Funafuti",
    @"Pacific/Galapagos",
    @"Pacific/Gambier",
    @"Pacific/Guadalcanal",
    @"Pacific/Guam",
    @"Pacific/Honolulu",
    @"Pacific/Johnston",
    @"Pacific/Kiritimati",
    @"Pacific/Kosrae",
    @"Pacific/Kwajalein",
    @"Pacific/Majuro",
    @"Pacific/Marquesas",
    @"Pacific/Midway",
    @"Pacific/Nauru",
    @"Pacific/Niue",
    @"Pacific/Norfolk",
    @"Pacific/Noumea",
    @"Pacific/Pago_Pago",
    @"Pacific/Palau",
    @"Pacific/Pitcairn",
    @"Pacific/Pohnpei",
    @"Pacific/Ponape",
    @"Pacific/Port_Moresby",
    @"Pacific/Rarotonga",
    @"Pacific/Saipan",
    @"Pacific/Tahiti",
    @"Pacific/Tarawa",
    @"Pacific/Tongatapu",
    @"Pacific/Truk",
    @"Pacific/Wake",
    @"Pacific/Wallis"
};
static NSString *AtlanticZones[] = {
    @"Atlantic/Azores",
    @"Atlantic/Bermuda",
    @"Atlantic/Canary",
    @"Atlantic/Cape_Verde",
    @"Atlantic/Faroe",
    @"Atlantic/Madeira",
    @"Atlantic/Reykjavik",
    @"Atlantic/South_Georgia",
    @"Atlantic/St_Helena",
    @"Atlantic/Stanley"
};
static NSString *IndianZones[] = {
    @"Indian/Antananarivo",
    @"Indian/Chagos",
    @"Indian/Christmas",
    @"Indian/Cocos",
    @"Indian/Comoro",
    @"Indian/Kerguelen",
    @"Indian/Mahe",
    @"Indian/Maldives",
    @"Indian/Mauritius",
    @"Indian/Mayotte",
    @"Indian/Reunion"
};
static NSString *AntarcticaZones[] = {
    @"Antarctica/Casey",
    @"Antarctica/Davis",
    @"Antarctica/DumontDUrville",
    @"Antarctica/Macquarie",
    @"Antarctica/Mawson",
    @"Antarctica/McMurdo",
    @"Antarctica/Palmer",
    @"Antarctica/Rothera",
    @"Antarctica/South_Pole",
    @"Antarctica/Syowa",
    @"Antarctica/Vostok",
};
static NSString *ArcticZones[] = {
    @"Arctic/Longyearbyen"
};
static NSString *OtherZones[] = {
    @"Brazil/Acre",
    @"Brazil/DeNoronha",
    @"Brazil/East",
    @"Brazil/West",
    @"Canada/Atlantic",
    @"Canada/Central",
    @"Canada/East-Saskatchewan",
    @"Canada/Eastern",
    @"Canada/Mountain",
    @"Canada/Newfoundland",
    @"Canada/Pacific",
    @"Canada/Saskatchewan",
    @"Canada/Yukon",
    @"CET",
    @"Chile/Continental",
    @"Chile/EasterIsland",
    @"CST6CDT",
    @"Cuba",
    @"EET",
    @"Egypt",
    @"Eire",
    @"EST",
    @"EST5EDT",
    @"Etc/GMT",
    @"Etc/GMT+0",
    @"Etc/GMT+1",
    @"Etc/GMT+10",
    @"Etc/GMT+11",
    @"Etc/GMT+12",
    @"Etc/GMT+2",
    @"Etc/GMT+3",
    @"Etc/GMT+4",
    @"Etc/GMT+5",
    @"Etc/GMT+6",
    @"Etc/GMT+7",
    @"Etc/GMT+8",
    @"Etc/GMT+9",
    @"Etc/GMT-0",
    @"Etc/GMT-1",
    @"Etc/GMT-10",
    @"Etc/GMT-11",
    @"Etc/GMT-12",
    @"Etc/GMT-13",
    @"Etc/GMT-14",
    @"Etc/GMT-2",
    @"Etc/GMT-3",
    @"Etc/GMT-4",
    @"Etc/GMT-5",
    @"Etc/GMT-6",
    @"Etc/GMT-7",
    @"Etc/GMT-8",
    @"Etc/GMT-9",
    @"Etc/GMT0",
    @"Etc/Greenwich",
    @"Etc/UCT",
    @"Etc/Universal",
    @"Etc/UTC",
    @"Etc/Zulu",
    // @"Factory",		    // not a real zone
    @"GB",
    @"GB-Eire",
    @"GMT+0",
    @"GMT-0",
    @"GMT0",
    @"Greenwich",
    @"Hongkong",
    @"HST",
    @"Iceland",
    @"Iran",
    @"Israel",
    @"Jamaica",
    @"Japan",
    @"Kwajalein",
    @"Libya",
    @"MET",
    @"Mexico/BajaNorte",
    @"Mexico/BajaSur",
    @"Mexico/General",
    // @"Mideast/Riyadh87",
    // @"Mideast/Riyadh88",
    // @"Mideast/Riyadh89",
    @"MST",
    @"MST7MDT",
    @"Navajo",
    @"NZ",
    @"NZ-CHAT",
    @"Poland",
    @"Portugal",
    @"PRC",
    @"PST8PDT",
    @"ROC",
    @"ROK",
    @"Singapore",
    @"Turkey",
    @"UCT",
    @"Universal",
    @"US/Alaska",
    @"US/Aleutian",
    @"US/Arizona",
    @"US/Central",
    @"US/East-Indiana",
    @"US/Eastern",
    @"US/Hawaii",
    @"US/Indiana-Starke",
    @"US/Michigan",
    @"US/Mountain",
    @"US/Pacific",
    // @"US/Pacific-New",
    @"US/Samoa",
    @"UTC",
    @"W-SU",
    @"WET",
    @"Zulu"
};

@implementation ECOptionsTZRoot

#ifndef NDEBUG
+ (NSString **)otherTZs {
    return OtherZones;
}
#endif

+ (void)initialize {
    assert(NUMOTHERS == sizeof(OtherZones)/sizeof(char*));
    continentData[ 0].name = NSLocalizedString(@"Frequently Used", @"zones of most EC customers");
    continentData[ 1].name = NSLocalizedString(@"North America", @"continent name");
    continentData[ 2].name = NSLocalizedString(@"South America", @"continent name");
    continentData[ 3].name = NSLocalizedString(@"Central America", @"Central America and Caribbean");
    continentData[ 4].name = NSLocalizedString(@"Europe", @"continent name");
    continentData[ 5].name = NSLocalizedString(@"Australia", @"continent name");
    continentData[ 6].name = NSLocalizedString(@"Asia", @"continent name");
    continentData[ 7].name = NSLocalizedString(@"Africa", @"continent name");
    continentData[ 8].name = NSLocalizedString(@"Pacific", @"continent name");
    continentData[ 9].name = NSLocalizedString(@"Atlantic", @"continent name");
    continentData[10].name = NSLocalizedString(@"Indian", @"continent name");
    continentData[11].name = NSLocalizedString(@"Antarctica", @"continent name");
    continentData[12].name = NSLocalizedString(@"Arctic", @"continent name");
    continentData[13].name = NSLocalizedString(@"Other", @"deprecated zones");
    continentData[ 0].zones = FrequentlyUsedZones;
    continentData[ 1].zones = NorthAmericaZones;
    continentData[ 2].zones = SouthAmericaZones;
    continentData[ 3].zones = CentralAmericaZones;
    continentData[ 4].zones = EuropeZones;
    continentData[ 5].zones = AustraliaZones;
    continentData[ 6].zones = AsiaZones;
    continentData[ 7].zones = AfricaZones;
    continentData[ 8].zones = PacificZones;
    continentData[ 9].zones = AtlanticZones;
    continentData[10].zones = IndianZones;
    continentData[11].zones = AntarcticaZones;
    continentData[12].zones = ArcticZones;
    continentData[13].zones = OtherZones;
    continentData[ 0].numZones = (int)(sizeof(FrequentlyUsedZones)/sizeof(char*));
    continentData[ 1].numZones = (int)(sizeof(NorthAmericaZones)/sizeof(char*));
    continentData[ 2].numZones = (int)(sizeof(SouthAmericaZones)/sizeof(char*));
    continentData[ 3].numZones = (int)(sizeof(CentralAmericaZones)/sizeof(char*));
    continentData[ 4].numZones = (int)(sizeof(EuropeZones)/sizeof(char*));
    continentData[ 5].numZones = (int)(sizeof(AustraliaZones)/sizeof(char*));
    continentData[ 6].numZones = (int)(sizeof(AsiaZones)/sizeof(char*));
    continentData[ 7].numZones = (int)(sizeof(AfricaZones)/sizeof(char*));
    continentData[ 8].numZones = (int)(sizeof(PacificZones)/sizeof(char*));
    continentData[ 9].numZones = (int)(sizeof(AtlanticZones)/sizeof(char*));
    continentData[10].numZones = (int)(sizeof(IndianZones)/sizeof(char*));
    continentData[11].numZones = (int)(sizeof(AntarcticaZones)/sizeof(char*));
    continentData[12].numZones = (int)(sizeof(ArcticZones)/sizeof(char*));
    continentData[13].numZones = (int)(sizeof(OtherZones)/sizeof(char*));
}


#ifndef NDEBUG
static bool testedZones = false;
#endif

- (void)viewDidLoad {
    traceEnter("ECOptionsTZRoot::viewDidLoad");
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Timezone", @"Timezone option label");
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];

    // get the state of the auto/manual switch
    autoMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"];

#ifndef NDEBUG
    if (!testedZones && [ChronometerAppDelegate firstRun]) {
        // make sure all our zones are recognized by iOS
        for (int i=1; i<NUMCONTINENTS; i++) {	    // don't bother with the "Frequently Used" zone
	    //printf("%s %d:\n", [continentData[i].name UTF8String], continentData[i].numZones);
	    for (int j=0; j<continentData[i].numZones; j++) {
		NSTimeZone *tz = [NSTimeZone timeZoneWithName:continentData[i].zones[j]];
		if (tz) {
                    //printf("OK: %s (UTC%+d)\n", [continentData[i].zones[j] UTF8String], [tz secondsFromGMT]/3600);
                } else {
                    printf("Unrecognized tz: %s\n", [continentData[i].zones[j] UTF8String]);
                }
	    }
	}
        
        // make sure all of iOS's zones are in our list
        for (NSString *tzName in [NSTimeZone knownTimeZoneNames]) {
            bool found = false;
            for (int i=1; i<NUMCONTINENTS-1; i++) {
                for (int j=0; j<continentData[i].numZones; j++) {
                    if ([tzName caseInsensitiveCompare:continentData[i].zones[j]] == NSOrderedSame) {
                        found = true;
                        break;
                    }
                }
                if (found) {
                    break;
                }
            }
            if (!found) {
                NSTimeZone *tzi = [NSTimeZone timeZoneWithName:tzName];
                printf("tz not found: %s\n",[[tzi name] UTF8String]);
            }
        }

	testedZones = true;
    }
#endif

    traceExit("ECOptionsTZRoot::viewDidLoad");
}

- (void)viewWillAppear:(BOOL)animated {
    traceEnter("ECOptionsTZRoot::viewWillAppear");
    [self.tableView reloadData];
    [super viewWillAppear:animated];
    traceExit("ECOptionsTZRoot::viewWillAppear");
}

- (void)setAutoAction:(UISwitch *)sender {
    [ECOptions setAutoTZ:sender.on];
    autoMode = sender.on;
    [self.tableView reloadData];
}

// when the user taps the Done button, exit
- (IBAction) doneAction: (id) sender {
    [ChronometerAppDelegate optionDone];
}

// tableview delegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return autoMode ? 1 : 2;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
	return 1;
    }
    assert(!autoMode);
    return NUMCONTINENTS;
}

// Customize the appearance of table view cells.
#define ROW_HEIGHT 50.0
#define MAIN_FONT_SIZE 16
#define LABEL_OFFSET 10
#define LABEL_WIDTH 175
#define LABEL_WIDER 250
#define SWITCH_OFFSET (LABEL_OFFSET+LABEL_WIDTH+10)
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    traceEnter("ECOptionsTZRoot::cellForRowAtIndexPath");
    UITableViewCell *cell = nil;

    if (indexPath.section == 0) {	    // the auto/manual switch
	cell = [tableView dequeueReusableCellWithIdentifier:@"ECSwitchCell"];
	if (cell == nil) {
	    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ECSwitchCell"] autorelease];

            UIFont *font = [UIFont boldSystemFontOfSize:MAIN_FONT_SIZE];
            // Deprecated iOS 7:  CGSize size = [@"8" sizeWithFont:font forWidth:LABEL_WIDTH lineBreakMode:UILineBreakModeClip];
            CGRect sizeRect = [@"8" boundingRectWithSize:CGSizeMake(LABEL_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:font} context:nil];
            CGFloat sizeHeight = ceil(sizeRect.size.height);
            CGRect rect = CGRectMake(LABEL_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, LABEL_WIDTH, sizeHeight);
            UILabel *label = [[UILabel alloc] initWithFrame:rect];
            label.font = font;
            label.adjustsFontSizeToFitWidth = YES;
            label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
            label.highlightedTextColor = [UIColor whiteColor];
            label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
            label.text = NSLocalizedString(@"Set Automatically", @"Timezone auto set option item label");
            [cell.contentView addSubview:label];
            
            rect = CGRectMake(SWITCH_OFFSET, (ROW_HEIGHT-kSwitchButtonHeight-5)/2.0, kSwitchButtonWidth, kSwitchButtonHeight);
            UISwitch *switchCtl = [[UISwitch alloc] initWithFrame:rect];
            [switchCtl addTarget:self action:@selector(setAutoAction:) forControlEvents:UIControlEventValueChanged];
            switchCtl.backgroundColor = [UIColor clearColor];
            switchCtl.on = autoMode;
            switchCtl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            [cell.contentView addSubview:switchCtl];
            
            [switchCtl release];
            [label release];
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
        tracePrintf("switch cell");

#if 0
    } else if (indexPath.section == 0) {
	assert(autoMode);   // only one item in first section in manual mode
	cell = [tableView dequeueReusableCellWithIdentifier:@"ECTZCell0"];
	if (cell == nil) {
	    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ECTZCell0"] autorelease];
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	bool checkIt = false;
	switch (indexPath.row) {
	    case 1:
		cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Use timezone of %@", @"Use timezone of device"), [[UIDevice currentDevice] model]];
		checkIt = autoModeMode == ECAutoModeDevice;
		break;
	    case 2:
		cell.textLabel.text = NSLocalizedString(@"Use internal TZ database", @"Use timezone from EC database");
		checkIt = autoModeMode == ECAutoModeInternal;
		break;
	    case 3:
		cell.textLabel.text = NSLocalizedString(@"Use timezone of Location", @"Use iPhone tz in auto location, internal EC db in manual");
		checkIt = autoModeMode == ECAutoModeLocation;
		break;
	    case 0:
	    default:
		assert(false);
		break;
	}
	if (checkIt) {
	    cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
	    cell.accessoryType = UITableViewCellAccessoryNone;
	}
#endif
    } else {		    // continent list
	assert(!autoMode);
	NSString *selectedTZCity = nil;
	
	// is the currently selected tz in this continent:
	NSRange r = [[ECOptions currentTZName] rangeOfString:@"/"];
	NSString *selectedTZContinent;
	if (r.location == NSNotFound) {
	    selectedTZContinent = @"Other";
	} else {
	    selectedTZContinent = [[ECOptions currentTZName] substringToIndex:r.location];
	}
	//tracePrintf1("checking for '%s'", [selectedTZContinent UTF8String]);
	if ([continentData[indexPath.row].name rangeOfString:selectedTZContinent].location != NSNotFound || indexPath.row == 0 || indexPath.row == NUMCONTINENTS-1) {
	    //tracePrintf("searching");
	    for (int i=0; i<continentData[indexPath.row].numZones; i++) {
		if ([continentData[indexPath.row].zones[i] compare:[ECOptions currentTZName]] == NSOrderedSame) {
		    if (indexPath.row == NUMCONTINENTS-1 || r.location == NSNotFound) {
			selectedTZCity = continentData[indexPath.row].zones[i];
		    } else {
			selectedTZCity = [continentData[indexPath.row].zones[i] substringFromIndex:r.location+1];
		    }
		    //tracePrintf1("matched '%s'", [continentData[indexPath.row].zones[i] UTF8String]);
		    break;
		}
	    }
	}
	// setup the cell
	if (selectedTZCity) {
	    cell = [tableView dequeueReusableCellWithIdentifier:@"ECContinentCityCell"];
	    if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"ECContinentCityCell"] autorelease];
	    }
	    cell.textLabel.text = continentData[indexPath.row].name;
	    cell.detailTextLabel.text = selectedTZCity;
            tracePrintf2("%s %s", [cell.textLabel.text UTF8String], [selectedTZCity UTF8String]);
	} else {
	    cell = [tableView dequeueReusableCellWithIdentifier:@"ECContinentCell"];
	    if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ECContinentCell"] autorelease];
	    }
	    cell.textLabel.text = continentData[indexPath.row].name;
            tracePrintf1("%s", [cell.textLabel.text UTF8String]);
	}
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    traceExit("ECOptionsTZRoot::cellForRowAtIndexPath");
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return (section == 0 && autoMode) ? 80 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if ((section == 0 && autoMode) || (section == 1 && isIpad())) {
	UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 100)] autorelease];
	UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 20, 320, 20)] autorelease];
	label.font = [UIFont boldSystemFontOfSize:16];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [UIColor secondaryLabelColor];
	label.text = [ECOptions currentTZName];
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[view addSubview:label];
	
	label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 48, 320, 20)] autorelease];
	label.font = [UIFont boldSystemFontOfSize:13];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [UIColor secondaryLabelColor];
	label.text = [ECOptions currentTZInfo];
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[view addSubview:label];
	
	label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 70, 320, 20)] autorelease];
	label.font = [UIFont systemFontOfSize:12];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [UIColor secondaryLabelColor];
	label.text = [ECOptions currentTZSourceInfo];
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[view addSubview:label];
	
	return view;
    } else {
	return nil;
    }

}

// user clicked one of the cells
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
	// done in setAutoAction
    } else {
	assert(!autoMode);
	UITableViewController *vc = [[[ECOptionsTZ alloc] initWith:continentData[indexPath.row].numZones timeZones:continentData[indexPath.row].zones] autorelease];
	vc.navigationItem.title = continentData[indexPath.row].name;
        tracePrintf("pushed ECOptionsTZ controller");
	[self.navigationController pushViewController:vc animated:true];
    }
}

- (void)dealloc {
    traceEnter("ECOptionsTZRoot::dealloc");
    [super dealloc];
    traceExit("ECOptionsTZRoot::dealloc");
}


@end

