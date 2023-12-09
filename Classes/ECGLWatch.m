//
//  ECGLWatch.m
//  Emerald Chronometer
//
//  Created by Steve Pucci in Aug 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECGLWatch.h"
#import "ECGLTexture.h"
#import "ECGLPart.h"
#import "ECWatchArchive.h"
#import "EBVirtualMachine.h"
#import "ECErrorReporter.h"
#import "ECGlobals.h"
#import "ECGLDisplayList.h"
#import "Constants.h"
#import "ECWatchEnvironment.h"
#import "ECWatchTime.h"
#import "ECAlarmTime.h"
#import "ECAudio.h"
#import "ECAppLog.h"
#import "ChronometerAppDelegate.h"
#import "ECAstronomy.h"
#import "ECDynamicUpdate.h"
#import "ECTrace.h"
#import "ECFactoryUI.h"
#import "ECLocationManager.h"
#import "TSTime.h"

#include <stdatomic.h>  // For atomic_thread_fence()

#import "objc/runtime.h" // class_getInstanceSize

static ECGLWatch *backgroundWatch = nil;
static double alarmCounter = 0;

static bool animatingRotation = false;
static CGFloat targetRotation = 0;
static CGFloat startRotation = 0;
static CGFloat currentRotation = 0;
static NSTimeInterval animateRotationStartTime = 0;
static NSTimeInterval animateRotationStopTime = 0;
static CGFloat extendedHalfWidth = 0;
static CGFloat extendedHalfHeight = 0;

@interface ECGLWatch (ECGLWatchPrivate)

- (void)makeLoadingLists;
- (void)makeRedBannerList;
- (void)updateRedBannerListForWatchLandscapeZoomFactor:(double)watchLandscapeZoomFactor;
- (void)alarmTimerFire:(id)userInfo;
- (void)initializeAlarmTimeFromDefaults;
- (void)initializeStopwatchTimeFromDefaults;

@end

#define DEFAULT_RINGSECTOR 11		// London

@implementation ECGLWatch

@synthesize visible, loaded, currentModeNum, definedModes, isBackground, dragging, alarmManualSet, name, active, vm, topSector,
    activeIndex, availableIndex, canonicalIndex, alarmEnabled, drawCenter, mainTime, mainAstro, mainEnv, numEnvironments, maxSeparateLoc, landscapeZoomFactor, beatsPerSecond;

static ECGLDisplayListWithTextureVertices *redBannerDisplayList;
static int zoomFramesLeft = 5;

+ (ECGLWatch *)globalWatch {
    assert(backgroundWatch);
    return backgroundWatch;
}

- (id)initWithName:(NSString *)aName {
    assert([NSThread isMainThread]);
    [super init];
    loaded = false;
    partBases = nil;
    for (int i = 0; i < ECNumVisualZoomFactors; i++) {
	textureLoadRequiredMasksByZoom[i] = 0;
    }
    definedModes = 0;
    drawCenter.x = 0;
    drawCenter.y = 0;
    targetDrawCenter.x = 0;
    targetDrawCenter.y = 0;
    zoom = 1.0;
    targetZoom = 1.0;
    landscapeZoomFactor = 1.0;  // For now, until we read the archive.dat file
    name = [aName retain];
    displayName = nil;
    animatingPositionZoom = false;
    animatingFlip = false;
    visible = false;
    alarmManualSet = false;
    dragging = false;
    hasStopwatch = false;
    alarmTime = nil;
    isBackground = (([aName caseInsensitiveCompare:@"Background"] == NSOrderedSame) || ([aName caseInsensitiveCompare:@"BackgroundHD"] == NSOrderedSame));
    textures = nil;
    if (isBackground) {
	backgroundWatch = self;
	for (int i = 0; i < ECNumWatchDrawModes; i++) {
	    loadingDisplayListsByMode[i] = nil;
	}
    } else {
	[self makeLoadingLists];
    }
    currentModeNum = [[NSUserDefaults standardUserDefaults] integerForKey:[aName stringByAppendingString:@"-ModeNum"]];
    if (currentModeNum == 0) {
	currentModeNum = ECfrontMode;
    }
    timers = (ECWatchTime **) malloc(ECNumTimers * sizeof(ECWatchTime *));
    for (int i = 0; i < ECNumTimers; i++) {
	timers[i] = [[ECWatchTime alloc] init];
    }
    mainTime  = timers[0];
    [timers[ECStopwatchTimer] setUseSmoothTime:true];
    [timers[ECStopwatchLapTimer] setUseSmoothTime:true];
    // Make a dummy environment array to store a single environment, so we can initialize the first slot with the global state
    environments = (ECWatchEnvironment **) malloc(sizeof(ECWatchEnvironment *));
    environments[0] = [[ECWatchEnvironment alloc] initWithTimeZoneNamed:[NSString stringWithCString:ESCalendar_localTimeZoneName() encoding:NSUTF8StringEncoding]
								   city:nil
							       forWatch:self
						      usingLocAstroFrom:nil
							locationManager:nil
						    observingIPhoneTime:true];  // Needs to go after initialization of timers
    numEnvironments = 1;
    lastMainTimeEnv = 0;  // We used env[0]'s calendar to initialize the main time (and the astro cache?)
    mainEnv = environments[0];
    mainAstro = [mainEnv astronomyManager];  // Needs to go after initialization of timers
    [self initializeAlarmTimeFromDefaults];
    topSector = DEFAULT_RINGSECTOR;
    return self;
}

- (NSArray *)partBases {
    return partBases;
}

- (double)modifiedZoomForZoom:(double)rawZoom {  // Zoom which takes into account landscapeZoomFactor, if appropriate
    if (landscapeZoomFactor != 1.0 && [ChronometerAppDelegate currentOrientationIsLandscape]) {
        return rawZoom * landscapeZoomFactor;
    }
    return rawZoom;
}

- (double)zoom {
    return zoom;
}

- (void)setZoom:(double)z {
    assert([NSThread isMainThread]);
    assert(z != 0);
    zoom = [self modifiedZoomForZoom:z];
}

- (ECGLTextureAtlas **)addressOfTextureForSlotIndex:(int)slotIndex andZoomPower2:(int)z2 {
    assert(textures);
    assert(slotIndex >= 0);
    assert(z2 >= ECZoomMinPower2 && z2 <= ECZoomMaxPower2);
    return &textures[slotIndex * ECNumVisualZoomFactors + (z2 - ECZoomMinPower2)];
}

-(ESTimeZone *)mainEstz {
    return [mainEnv estz];
}

-(ESTimeZone *)estzForEnv:(int)envNumber {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    return [environments[envNumber] estz];
}

- (void)initializeStopwatchTimeFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    ECWatchTime *stopwatchTimer = timers[ECStopwatchTimer];
    bool stopwatchRunning = [defaults boolForKey:[name stringByAppendingString:@"-stopRunning"]];
    if (stopwatchRunning) {
	NSString *zeroTimeString = [defaults stringForKey:[name stringByAppendingString:@"-stopZeroTime"]];
	double zeroTime = [zeroTimeString doubleValue];
	[stopwatchTimer stopwatchInitRunningFromZeroTime:zeroTime];
	hasStopwatch = true;
    } else {
	NSString *stopwatchTimeString = [defaults stringForKey:[name stringByAppendingString:@"-stopTime"]];
	double stopwatchTime = [stopwatchTimeString doubleValue];
	[stopwatchTimer stopwatchInitStoppedReading:stopwatchTime];
    }
    ECWatchTime *ratTimer = timers[ECStopwatchLapTimer];
    bool ratRunning = [defaults boolForKey:[name stringByAppendingString:@"-ratRunning"]];
    if (ratRunning) {
	NSString *zeroTimeString = [defaults stringForKey:[name stringByAppendingString:@"-ratZeroTime"]];
	double zeroTime = [zeroTimeString doubleValue];
	[ratTimer stopwatchInitRunningFromZeroTime:zeroTime];
	hasStopwatch = true;
    } else {
	NSString *ratTimeString = [defaults stringForKey:[name stringByAppendingString:@"-ratTime"]];
	double ratTime = [ratTimeString doubleValue];
	[ratTimer stopwatchInitStoppedReading:ratTime];
    }
    if (hasStopwatch && !alarmTime) {
	[TSTime addTimeAdjustmentObserver:self];
    }
}

- (void)updateDefaultsForCurrentStopwatchState {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    ECWatchTime *stopwatchTimer = timers[ECStopwatchTimer];
    bool stopwatchRunning = ![stopwatchTimer isStopped];
    if (stopwatchRunning) {
	[defaults setBool:YES forKey:[name stringByAppendingString:@"-stopRunning"]];
	[defaults setObject:[NSString stringWithFormat:@"%.3f", -[stopwatchTimer ourTimeAtNTPZero]]
		     forKey:[name stringByAppendingString:@"-stopZeroTime"]];
    } else {
	[defaults setBool:NO forKey:[name stringByAppendingString:@"-stopRunning"]];
	[defaults setObject:[NSString stringWithFormat:@"%.3f", [stopwatchTimer ourTimeAtNTPZero]]
		     forKey:[name stringByAppendingString:@"-stopTime"]];
    }
    ECWatchTime *ratTimer = timers[ECStopwatchLapTimer];
    bool ratRunning = ![ratTimer isStopped];
    if (ratRunning) {
	[defaults setBool:YES forKey:[name stringByAppendingString:@"-ratRunning"]];
	[defaults setObject:[NSString stringWithFormat:@"%.3f", -[ratTimer ourTimeAtNTPZero]]
		     forKey:[name stringByAppendingString:@"-ratZeroTime"]];
    } else {
	[defaults setBool:NO forKey:[name stringByAppendingString:@"-ratRunning"]];
	[defaults setObject:[NSString stringWithFormat:@"%.3f", [ratTimer ourTimeAtNTPZero]]
		     forKey:[name stringByAppendingString:@"-ratTime"]];
    }
}

- (double)specifiedOffset {
    if (alarmTime) {
	return [alarmTime specifiedOffset];
    }
    return 0;
}

- (void)initializeAlarmTimeFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bool alarmEverSet = [defaults boolForKey:[name stringByAppendingString:@"-alarmEverSet"]];
    if (alarmEverSet) {
	alarmTime = [[ECAlarmTime alloc] initWithFireReceiver:self fireSelector:@selector(alarmTimerFire:) fireUserInfo:nil currentWatchTime:mainTime env:mainEnv];
	alarmEnabled = [defaults boolForKey:[name stringByAppendingString:@"-alarmEnabled"]];
	ECAlarmTimeMode alarmMode = (ECAlarmTimeMode)[defaults integerForKey:[name stringByAppendingString:@"-alarmMode"]];  // default is zero, meaning ECAlarmTimeTarget
	NSString *offsetString = [defaults stringForKey:[name stringByAppendingString:@"-alarmSpecifiedOffset"]];
	double offsetValue = offsetString ? [offsetString doubleValue] : 0.0;   // default of doubleValue is also zero, meaning midnight
	if (alarmMode == ECAlarmTimeTarget) {
	    [alarmTime specifyTargetAlarmAt:offsetValue];
	    if (alarmEnabled) {
		++alarmCounter;
	    }
	} else {
	    assert(alarmMode == ECAlarmTimeInterval);
	    [alarmTime specifyIntervalAlarmAt:offsetValue];
	    bool timerIsRunning = [defaults boolForKey:[name stringByAppendingString:@"-timerRunning"]]; // only used if in timer mode
	    if (timerIsRunning) {
		NSString *targetTimeString = [defaults stringForKey:[name stringByAppendingString:@"-timerTarget"]];
		double targetTime = [targetTimeString doubleValue];
		if ([alarmTime defaultsStartTimerWithTargetTime:targetTime]) {
		    if (alarmEnabled) {
			[ChronometerAppDelegate showECStatusWarning:NSLocalizedString(@"Missed Alarm", @"Alarm time passed while EC not active")];
		    }
		} else {
		    if (alarmEnabled) {
			++alarmCounter;
		    }
		}
	    } else {
		NSString *timerOffsetString = [defaults stringForKey:[name stringByAppendingString:@"-timerOffset"]];
		double timerOffset = [timerOffsetString doubleValue];
		[alarmTime defaultsSetCurrentInterval:timerOffset];
	    }
	}
	if (!hasStopwatch) {
	    [TSTime addTimeAdjustmentObserver:self];
	}
    } else {
	if ([name compare:@"Thebes"] == NSOrderedSame) {
	    alarmEnabled = true;
	    [self setAlarmToInterval];  // stores back to defaults
	    assert(alarmTime != nil);
	} else {
	    alarmEnabled = false;
	    alarmTime = nil;
	}
    }
}

- (void)updateDefaultsForCurrentAlarmState {
    if (alarmTime) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:YES                                                  forKey:[name stringByAppendingString:@"-alarmEverSet"]];
	[defaults setBool:alarmEnabled                                         forKey:[name stringByAppendingString:@"-alarmEnabled"]];
	[defaults setObject:[NSString stringWithFormat:@"%.3f", [alarmTime specifiedOffset]]
		                                                               forKey:[name stringByAppendingString:@"-alarmSpecifiedOffset"]];
	ECAlarmTimeMode alarmMode = [alarmTime specifiedMode];
	if (alarmMode == ECAlarmTimeTarget) {
	    [defaults setInteger:(int)ECAlarmTimeTarget                        forKey:[name stringByAppendingString:@"-alarmMode"]];
	} else {
	    assert(alarmMode == ECAlarmTimeInterval);
	    [defaults setInteger:(int)ECAlarmTimeInterval                      forKey:[name stringByAppendingString:@"-alarmMode"]];
	    bool timerIsRunning = [alarmTime timerIsStopped];  // backwards, yes
	    [defaults setBool:timerIsRunning                                   forKey:[name stringByAppendingString:@"-timerRunning"]]; // only used if in timer mode
	    if (timerIsRunning) {
		[defaults setObject:[NSString stringWithFormat:@"%.3f", [alarmTime currentAlarmTime]]
							                       forKey:[name stringByAppendingString:@"-timerTarget"]];
	    } else {
		[defaults setObject:[NSString stringWithFormat:@"%.3f", [alarmTime effectiveOffset]]
			                                                       forKey:[name stringByAppendingString:@"-timerOffset"]];
	    }
	}
    } else {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:[name stringByAppendingString:@"-alarmEverSet"]];
	// others don't matter if alarmEverSet is NO
    }
}

- (void)setTimeZone:(ESTimeZone *)estz {
    [environments[0] setTimeZone:estz];
    [alarmTime handleTZChange];
}

#ifdef HIRES_DUMP
- (void)hiresDump {
    ESDateComponents cs;
    cs.era = 1;
    cs.year = 2009;
    cs.month = 12;
    cs.day = 8;
    cs.hour = 10;
    cs.minute = 10;
    cs.seconds = 25.4;
    NSTimeInterval dumpDate = ESCalendar_timeIntervalFromLocalDateComponents(ESCalendar_localTimeZone(), &cs);
    NSTimeInterval dumpDate = [[ltCalendar dateFromComponents:cs] timeIntervalSinceReferenceDate] + subSeconds;
    [[self mainTime] setCurrentDate:[NSDate dateWithTimeIntervalSinceReferenceDate:dumpDate]];
    [[self mainTime] latchTimeForBeatsPerSecond:0];
    
    CGSize hiresPartSize = [ChronometerAppDelegate applicationSize];
    size_t bitsPerComponent = 8;
    assert(hiresPartSize.width > 0);
    assert(hiresPartSize.height > 0);
    int padding = ECTexturePartPadding;
    padding = 0;
    NSString *watchTempPngDirectory = [ECbundleTempPngDirectory stringByAppendingPathComponent:name];
    for (int modeNum = 0; modeNum < ECNumWatchDrawModes; modeNum++) {
	[self updateAllPartsForModeNum:modeNum animating:false];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	assert(colorSpace);
	CGContextRef context = CGBitmapContextCreate(NULL, ceil(hiresPartSize.width*HIRES_DUMP) + padding * 2, ceil(hiresPartSize.height*HIRES_DUMP) + padding * 2, bitsPerComponent, 0,
						     colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	assert(context);
	UIGraphicsPushContext(context);
	for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	    for (ECGLPart *part in partGroup) {
		NSString *partHiResImageName = [[watchTempPngDirectory stringByAppendingPathComponent:[part debugName]] stringByAppendingString:@"-hires.png"];
		UIImage *partImage = [[UIImage imageWithContentsOfFile:partHiResImageName] retain];
		if (!partImage) {
		    printf("Trouble constructing part image for %s\n", [partHiResImageName UTF8String]);
		}
		[part drawHiresImage:[partImage CGImage] intoContext:context];
		[partImage release];
	    }
	}
	UIGraphicsPopContext();
	CGImageRef cgImage = CGBitmapContextCreateImage(context);
	assert(cgImage);
	UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
	assert(uiImage);
	NSData *imageData = UIImagePNGRepresentation(uiImage);
	assert(imageData);
	NSError *error;
	NSString *hiresPath = [NSString stringWithFormat:@"%@/hires-%s.png", watchTempPngDirectory, ECmodeNames[modeNum]];
	if (![imageData writeToFile:hiresPath  options:NSAtomicWrite error:&error]) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Couldn't write PNG file to %@: %@", hiresPath, [error localizedDescription]]];
	}
	printf("Wrote hires image %s\n", [hiresPath UTF8String]);
	CGContextRelease(context);
	CGColorSpaceRelease(CGBitmapContextGetColorSpace(context));
    }
    [ltCalendar release];
    [cs release];
    [[self mainTime] unlatchTime];
    [[self mainTime] resetToLocal];
    for (int modeNum = 0; modeNum < ECNumWatchDrawModes; modeNum++) {
	[self updateAllPartsForModeNum:modeNum animating:false];
    }
}
#endif

// This routine should match ECWatchController::archiveAll in the way it reads data from the archive
// Also see ECGLAtlasLayout::mergeWatchAtlasesFromArchive
- (void)loadFromArchiveInDirectory:(NSString *)directory withName:(NSString *)aName {
    NSString *path = [directory stringByAppendingPathComponent:@"archive.dat"];
    ECWatchArchive *watchArchive = [[ECWatchArchive alloc] initForReadingFromPath:path];
    [watchArchive readInteger];  // faceWidth, unused for iOS, but used for watch devices like Android Wear
    numEnvironments = [watchArchive readInteger];
    maxSeparateLoc = [watchArchive readInteger];
    landscapeZoomFactor = [watchArchive readDouble];
    beatsPerSecond = [watchArchive readInteger];
    [watchArchive readInteger];  // statusBarLocation, unused for iOS, but used for Android Wear
    assert(maxSeparateLoc <= numEnvironments);
    if (numEnvironments < 1 || numEnvironments - 1 > ECEnvUB) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Bogus numEnvironments %d for watch %s", numEnvironments, [aName UTF8String]]];
	[watchArchive release];
	assert(false);
	return;
    }
    if (numEnvironments != 1) {
	ECWatchEnvironment **newEnvs = (ECWatchEnvironment **) malloc(numEnvironments * sizeof(ECWatchEnvironment *));
	newEnvs[0] = environments[0];
	free(environments);
	environments = newEnvs;
    }
    for (int i = 1; i < numEnvironments; i++) {
	ECLocationManager *locMgr;
	ECWatchEnvironment *clonee;
	if (i <= maxSeparateLoc) {
            locMgr = [[[ECLocationManager alloc] initWithOverrideLatitudeDegrees:[ECFactoryUI  latitudeForWatch:self env:i]
                                                                longitudeDegrees:[ECFactoryUI longitudeForWatch:self env:i]] autorelease];
            clonee = nil;
	} else {
	    locMgr = nil;
	    clonee = mainEnv;
	}
	if (i > maxSeparateLoc) {
	    [ECFactoryUI ensureTZValidityForWatch:self env:i];
	}
	environments[i] = [[ECWatchEnvironment alloc] initWithTimeZoneNamed:[ECFactoryUI timeZoneNameForWatch:self env:i]
								       city:[ECFactoryUI cityNameForWatch:self env:i]
								   forWatch:self
							  usingLocAstroFrom:clonee
							    locationManager:locMgr
							observingIPhoneTime:false];
	environments[i].latitude  = [ECFactoryUI  latitudeForWatch:self env:i];
    	environments[i].longitude = [ECFactoryUI longitudeForWatch:self env:i];
    }
    [self initializeStopwatchTimeFromDefaults];
    partBases = [[NSMutableArray alloc] initWithCapacity:50];
    numTextures = [watchArchive readInteger];
    textures = (ECGLTextureAtlas **)malloc(numTextures*ECNumVisualZoomFactors*sizeof(ECGLTextureAtlas *));
    int i;
    for (i = 0; i < numTextures; i++) {
	NSString *textureImageRelativePath = [watchArchive readString];
        // NOTE(spucci 2014 Jan 2):  If the number of atlases specified when building doesn't match the number of atlases
        // specified here when reading, the number of passes through the following loop will be wrong and as a result too
        // many or too few [watchArchive readInteger]s will be done when reading archive.dat, which will in turn result in
        // a problem with the instruction stream read below, which will then not actually be pointing at an instruction
        // stream.  Check EC_ARCHIVEHD being set properly on both sides.
	for (int z2 = ECZoomMinPower2; z2 <= ECZoomMaxPower2; z2++) {
	    int width = [watchArchive readInteger];
	    int height = [watchArchive readInteger];
	    if (isBackground && z2 < 0) {
		textures[i * ECNumVisualZoomFactors + (z2 - ECZoomMinPower2)] = nil;
	    } else {
		ECGLTextureAtlas *atlas = [ECGLTextureAtlas atlasForRelativePath:textureImageRelativePath create:true width:width height:height zoomPower2:z2];
		textures[i * ECNumVisualZoomFactors + (z2 - ECZoomMinPower2)] = atlas;
	    }
	}
    }
    int numVariables = [watchArchive readInteger];
    vm = [[EBVirtualMachine alloc] initWithOwner:self name:aName variableCount:numVariables variableImporter:&ECImportVariables];
#ifndef ESVM_BRIDGE
    vm->errorDelegate = [ECErrorReporter theErrorReporter];
#endif
#ifdef EC_HENRY
    [vm readVariableNamesFromFile:[directory stringByAppendingPathComponent:@"variable-names.txt"]];
#endif
    int numInits = [watchArchive readInteger];
    for (i = 0; i < numInits; i++) {
        // NOTE(spucci 2014 Jan 2):  See corresponding NOTE() above for why the following read might fail.
	EBVMInstructionStream *init = [watchArchive readInstructionStreamForVirtualMachine:vm];
	[vm evaluateInstructionStream:init errorReporter:[ECErrorReporter theErrorReporter]];
    }
    for (i = 0; i < ECNumWatchDrawModes; i++) {
	partGroupsByTextureMode[i] = [[NSMutableArray alloc] initWithCapacity:2];
    }
    for (i = 0; i < ECNumWatchDrawModes; i++) {
	displayListsByMode[i] = [[NSMutableArray alloc] initWithCapacity:2];
    }
    int currentTextureSlotIndexByMode[ECNumWatchDrawModes];
    for (i = 0; i < ECNumWatchDrawModes; i++) {
	currentTextureSlotIndexByMode[i] = -1;
    }
    NSMutableArray *partsInCurrentTextureByMode[ECNumWatchDrawModes];
    for (i = 0; i < ECNumWatchDrawModes; i++) {
	partsInCurrentTextureByMode[i] = nil;
    }
    int numParts = [watchArchive readInteger];
#ifdef HIRES_DUMP
    NSString *watchTempPngDirectory = [ECbundleTempPngDirectory stringByAppendingPathComponent:aName];
    NSString *partNamesFileName = [watchTempPngDirectory stringByAppendingPathComponent:@"parts.dat"];
    NSArray *namesArray = readStringsFileAtAbsolutePathIntoNSArray(partNamesFileName, numParts);
#endif
    for (i = 0; i < numParts; i++) {
	ECGLPart *part = [[ECGLPart alloc] initFromArchive:watchArchive usingVirtualMachine:vm intoWatch:self];
#ifdef HIRES_DUMP
	[part setDebugName:[namesArray objectAtIndex:i]];
#endif
	[partBases addObject:part];
	int partTextureSlotIndex;
	for (int modeNum = 0; modeNum < ECNumWatchDrawModes; modeNum++) {
	    ECWatchModeMask modeMask = 1 << modeNum;
	    if (part.modeMask & modeMask) {
		definedModes |= modeMask;
		partTextureSlotIndex = [part partTextureAtlasSlotIndexForModeNum:modeNum];
		if (partTextureSlotIndex != currentTextureSlotIndexByMode[modeNum]) {
		    currentTextureSlotIndexByMode[modeNum] = partTextureSlotIndex;
		    partsInCurrentTextureByMode[modeNum] = [NSMutableArray arrayWithCapacity:(numParts/2)];
		    [partGroupsByTextureMode[modeNum] addObject:partsInCurrentTextureByMode[modeNum]];
		}
		[partsInCurrentTextureByMode[modeNum] addObject:part];
	    }
	}
	[part release];
    }
    int numNoViewParts = [watchArchive readInteger];
    for (i = 0; i < numNoViewParts; i++) {
	CGRect boundsOnScreen = [watchArchive readRect];
	int enabledControl = [watchArchive readInteger];
	ECWatchModeMask modeMask = [watchArchive readInteger];
	EBVMInstructionStream *actionInstructionStream = [watchArchive readInstructionStreamForVirtualMachine:vm];
	ECPartRepeatStrategy repeatStrategy = [watchArchive readInteger];
	bool immediate = [watchArchive readInteger] ? true : false;
	bool expanded = [watchArchive readInteger] ? true : false;
	int grabPrio = [watchArchive readInteger];
	int envSlot = [watchArchive readInteger];
	bool flipXOnBack = [watchArchive readInteger] ? true : false;
	bool cornerRelative = [watchArchive readInteger] ? true : false;
	ECGLPartBase *part = [[ECGLPartBase alloc] initWithBoundsOnScreen:boundsOnScreen
                                                                 modeMask:modeMask
                                                           enabledControl:enabledControl
                                                           repeatStrategy:repeatStrategy
                                                                immediate:immediate
                                                                 expanded:expanded
                                                                 grabPrio:grabPrio
                                                                  envSlot:envSlot
                                                              flipXOnBack:flipXOnBack
                                                           cornerRelative:cornerRelative
                                                                       vm:vm
                                                                    watch:self
                                                  actionInstructionStream:actionInstructionStream];
	[partBases addObject:part];  // Note: adding an ECGLPartBase to the partBases array
    }
    int numSpareParts = [watchArchive readInteger];
    if (numSpareParts > 0) {
	spareParts = (NSMutableDictionary **)malloc(ECNumVisualZoomFactors * sizeof(NSMutableDictionary*));
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    spareParts[j] = [[NSMutableDictionary dictionaryWithCapacity:numSpareParts] retain];
	}
	for (i = 0; i < numSpareParts; i++) {
	    NSString *partName = [watchArchive readString];
	    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
		CGRect partRect = [watchArchive readRect];
		NSData *rectObj = [NSData dataWithBytes:&partRect length:sizeof(CGRect)];
		[spareParts[j] setObject:rectObj forKey:partName];
	    }
	}
    }
    [watchArchive release];
    watchArchive = nil;
    for (int modeNum = 0; modeNum < ECNumWatchDrawModes; modeNum++) {
	for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	    ECGLPart *firstPart = [partGroup objectAtIndex:0];
	    int textureAtlasSlotIndex = [firstPart partTextureAtlasSlotIndexForModeNum:modeNum];
	    int numPartsInGroup = [partGroup count];
	    ECGLDisplayList *displayList = [[ECGLDisplayList alloc] initForNumParts:numPartsInGroup
								     textureAtlases:[self addressOfTextureForSlotIndex:textureAtlasSlotIndex
													 andZoomPower2:ECZoomMinPower2]];
	    int partIndex = 0;
	    for (ECGLPart *part in partGroup) {
		[part setupForDisplayList:displayList atIndex:partIndex++ forModeNum:modeNum];
	    }
	    [displayListsByMode[modeNum] addObject:displayList];
	    [displayList release];
	}
    }
    [self updateAllPartsForCurrentModeAnimating:false];
#ifdef HIRES_DUMP
    [self hiresDump];
#endif
    atomic_thread_fence(memory_order_seq_cst);
    loaded = true;
}

- (void)loadFromArchive {
    NSString *path = [NSString stringWithFormat:@"%@/%@", ECbundleArchiveDirectory, name];
    if (![ECfileManager fileExistsAtPath:path]) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Can't find archive for watch %@", name]];
    }
    [self loadFromArchiveInDirectory:path withName:name];
}

- (bool)flipping {
    return animatingFlip;
}

- (size_t)textureBytesNeededForLoadOfModeNum:(ECWatchModeEnum)modeNum atZoomPower2:(int)z2 {
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    NSMutableSet *texturesUsedForMode = [NSMutableSet setWithCapacity:4];
    for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	int groupSize = [partGroup count];
	for (int i = 0; i < groupSize; i++) {
	    ECGLPart *part = [partGroup objectAtIndex:i];
	    int textureSlotIndex = [part partTextureAtlasSlotIndexForModeNum:modeNum];
	    ECGLTextureAtlas *atlas = *[self addressOfTextureForSlotIndex:textureSlotIndex andZoomPower2:z2];
	    [texturesUsedForMode addObject:atlas];
	}
    }
    size_t needsBytes = 0;
    for (ECGLTextureAtlas *atlas in texturesUsedForMode) {
	size_t bytes = [atlas bytesNeededForLoad];
	needsBytes += bytes;
    }
    return needsBytes;
}

- (void)requireTextureLoadForModeNum:(ECWatchModeEnum)modeNum atZoomPower2:(int)z2 {
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    // printf("Watch %s require texture load for mode %d and zoom %d\n",
    // [name UTF8String], (int)modeNum, z2);
    for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	int groupSize = [partGroup count];
	for (int i = 0; i < groupSize; i++) {
	    ECGLPart *part = [partGroup objectAtIndex:i];
	    int textureSlotIndex = [part partTextureAtlasSlotIndexForModeNum:modeNum];
	    ECGLTextureAtlas *atlas = *[self addressOfTextureForSlotIndex:textureSlotIndex andZoomPower2:z2];
	    [atlas watchPartModeRequiresLoad];
	}
    }
    textureLoadRequiredMasksByZoom[ECZoomIndexForPower2(z2)] |= (1 << modeNum);
}

- (size_t)releaseTextureLoadForModeNum:(ECWatchModeEnum)modeNum atZoomPower2:(int)z2 needUnattach:(bool *)needUnattach {
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    size_t releasedBytes = 0;
    *needUnattach = false;
    //printf("Watch %s release texture load for mode %d and zoom %d\n",
    //[name UTF8String], (int)modeNum, z2);
    for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	for (ECGLPart *part in partGroup) {
	    bool thisNeedsUnattach;
	    int textureSlotIndex = [part partTextureAtlasSlotIndexForModeNum:modeNum];
	    ECGLTextureAtlas *atlas = *[self addressOfTextureForSlotIndex:textureSlotIndex andZoomPower2:z2];
	    size_t bytes = [atlas watchPartModeReleasesLoadNeedingUnattach:&thisNeedsUnattach];
	    if (thisNeedsUnattach) {
		*needUnattach = true;
	    }
	    releasedBytes += bytes;
	}
    }
    textureLoadRequiredMasksByZoom[ECZoomIndexForPower2(z2)] &= ~(1 << modeNum);
    return releasedBytes;
}

- (void)dealloc {
    assert(false);
    if (hasStopwatch || alarmTime != nil) {
	[TSTime removeTimeAdjustmentObserver:self];
	[alarmTime release];
    }
    for (int i = 0; i < ECNumWatchDrawModes; i++) {
	for (NSMutableArray *partGroup in partGroupsByTextureMode[i]) {
	    [partGroup removeAllObjects];
	}
	[partGroupsByTextureMode[i] removeAllObjects];
	[partGroupsByTextureMode[i] release];
	[displayListsByMode[i] removeAllObjects];
	[displayListsByMode[i] release];
    }
    if (spareParts) {
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    [spareParts[j] removeAllObjects];
	    [spareParts[j] release];
	}
	free(spareParts);
    }
    [partBases release];
    [name release];
    [displayName release];
    free(environments);
    [super dealloc];
}

static NSDictionary *builtinDisplayNames = nil;

- (NSString *)displayName {
    if (displayName) {
	return displayName;
    }
    if (!builtinDisplayNames) {
	builtinDisplayNames = [[NSDictionary alloc] initWithObjectsAndKeys:@"Haleakalā", @"Haleakala", @"Neuchâtel", @"Neuchatel", nil];
    }
    NSString *dName = [builtinDisplayNames objectForKey:name];
    if (dName) {
	return dName;
    }
    return name;
}

- (void)setDisplayName:(NSString *)aDisplayName {
    [displayName release];
    displayName = [aDisplayName retain];
}

static NSDictionary *builtinHelpwordNames = nil;

- (NSString *)helpword {
    if (!builtinHelpwordNames) {
	builtinHelpwordNames = [[NSDictionary alloc] initWithObjectsAndKeys:
							 NSLocalizedString(@"Moonphase", @"Chandra switcher clue"),   @"Chandra", 
						         NSLocalizedString(@"Rise/Set",  @"Miami switcher clue"),     @"Miami", 
							 NSLocalizedString(@"Calendar",  @"Babylon switcher clue"),  @"Babylon",
							 NSLocalizedString(@"Alarm",     @"Istanbul switcher clue"),  @"Istanbul",
						      	 NSLocalizedString(@"Stopwatch", @"Olympia switcher clue"),   @"Olympia",
						      	 NSLocalizedString(@"Countdown", @"Thebes switcher clue"),    @"Thebes",
						      	 NSLocalizedString(@"Complications", @"Geneva switcher clue"),    @"Geneva",
						      	 NSLocalizedString(@"Orrery",    @"Firenze switcher clue"),   @"Firenze",
						      	 NSLocalizedString(@"World Time", @"Terra switcher clue"),    @"Terra",
						      	 NSLocalizedString(@"Japanese",  @"Kyoto switcher clue"),    @"Kyoto",
							 NSLocalizedString(@"24 hour",   @"Vienna switcher clue"),    @"Vienna",
						     	 nil];
    }
    return [builtinHelpwordNames objectForKey:name];
}

#ifndef NDEBUG
extern void printDate(const char *description);
extern void printADate(NSTimeInterval dt);
#endif

- (NSTimeInterval)prepareAllPartsForDrawForModeNum:(ECWatchModeEnum)modeNum
					    atTime:(NSTimeInterval)currentTime
				     forcingUpdate:(bool)forceUpdate
				    allowAnimation:(bool)allowAnimation
					  dragType:(ECDragType)dragType {
    // Check for unloaded watch first
    if (!loaded) {
	return ECFarInTheFuture;
    }
    
#undef EC_SCREEN_CAPTURE
#ifdef EC_SCREEN_CAPTURE
    ESDateComponents cs;

    // 512 EC
    cs.era = 1;
    cs.year = 2008;
    cs.month = 7;
    cs.day = 11;
    cs.hour = 21;
    cs.minute = 13;
    cs.seconds = 7;

    // Terra
    cs.era = 1;
    cs.year = 2010;
    cs.month = 11;
    cs.day = 5;
    cs.hour = 17;
    cs.minute = 1;
    cs.seconds = 53.6;

    // Geneva
    cs.era = 1;
    cs.year = 2010;
    cs.month = 11;
    cs.day = 26;
    cs.hour = 20;
    cs.minute = 51;
    cs.seconds = 20.8;

    // Geneva Eclipse
    // Set 3.48N, 11.70W, UTC
    cs.era = 1;
    cs.year = 2013;
    cs.month = 11;
    cs.day = 3;
    cs.hour = 4;  // Really 8 UTC
    cs.minute = 46;
    cs.seconds = 29;

    // 4-up
    cs.era = 1;
    cs.year = 2012;
    cs.month = 2;
    cs.day = 16;
    cs.hour = 9;
    cs.minute = 20;
    cs.seconds = 15;

    // 9-up (or 8-up in ECHD)
    cs.era = 1;
    cs.year = 2010;
    cs.month = 11;
    cs.day = 5;
    cs.hour = 17;
    cs.minute = 6;
    cs.seconds = 16.2;

    // MK
    cs.era = 1;
    cs.year = 2010;
    cs.month = 11;
    cs.day = 5;
    cs.hour = 17;
    cs.minute = 6;
    cs.seconds = 46.2;

    // 512 EG
    cs.era = 1;
    cs.year = 2009;
    cs.month = 11;
    cs.day = 7;
    cs.hour = 10;
    cs.minute = 39;
    cs.seconds = 44.2;

    // October 1582
    cs.era = 1;
    cs.year = 1582;
    cs.month = 10;
    cs.day = 4;
    cs.hour = 12;
    cs.minute = 0;
    cs.seconds = 0;

    // October 1582 -- 2
    cs.era = 1;
    cs.year = 1582;
    cs.month = 10;
    cs.day = 17;
    cs.hour = 12;
    cs.minute = 0;
    cs.seconds = 0;

    // App icon  -- use 75N -121.975(W)
    cs.era = 1;
    cs.year = 2012;
    cs.month = 10;
    cs.day = 18;
    cs.hour = 13;
    cs.minute = 55;
    cs.seconds = 51.8;

    // EG app icon
    cs.era = 1;
    cs.year = 2013;
    cs.month = 11;
    cs.day = 11;
    cs.hour = 11;
    cs.minute = 39;
    cs.seconds = 36;

    NSTimeInterval screenCaptureTime = ESCalendar_timeIntervalFromLocalDateComponents(ESCalendar_localTimeZone(), &cs);
    [mainTime setToFrozenDateInterval:screenCaptureTime];
#endif // EC_SCREEN_CAPTURE

    //if ([name compare:@"Terra"] == NSOrderedSame) {
    //    printf("\n"); printADate([mainTime currentTime]); printf(" (unlatched Terra)\n");
    //}

    [mainTime latchTimeForBeatsPerSecond:beatsPerSecond];  // use same time for all parts to avoid repeated entry into kernel

    //if ([name compare:@"Terra"] == NSOrderedSame) {
    //    printADate([mainTime currentTime]); printf(" (latched Terra)\n");
    //}

#ifdef EC_SCREEN_CAPTURE
    [mainTime resetToLocal];  // To avoid having the indicators think the watch is stopped -- but this disables the crown
#endif

    NSTimeInterval snappedWatchTime = [mainTime currentTime];
    NSTimeInterval soonestUpdateNeeded = ECFarInTheFuture;
    NSTimeInterval partUpdateNeeded;
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    bool doingFirstPart = true;
    //int changedSlot = 0;
    for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	for (ECGLPart *part in partGroup) {
	    int envSlot = [part envSlot];
	    ECAstronomyManager *astroMan = [self astroWithIndex:envSlot];
	    if (doingFirstPart) {
		[astroMan setupLocalEnvironmentForThreadFromActionButton:false];
		doingFirstPart = false;
	    } else if (lastMainTimeEnv != envSlot) {
		//changedSlot++;
		ECAstronomyManager *priorAstro = [self astroWithIndex:lastMainTimeEnv];
		[priorAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
		[astroMan setupLocalEnvironmentForThreadFromActionButton:false];
	    }
	    lastMainTimeEnv = envSlot;
	    partUpdateNeeded = [part prepareForDrawForModeNum:modeNum
						       atTime:currentTime
                                             snappedWatchTime:snappedWatchTime
						forcingUpdate:forceUpdate
					       allowAnimation:allowAnimation
					 draggingPartDragType:dragType];
	    if (partUpdateNeeded < soonestUpdateNeeded) {
		soonestUpdateNeeded = partUpdateNeeded;
	    }
            //if ([name compare:@"Terra"] == NSOrderedSame && 
            //    soonestUpdateNeeded > 0 && soonestUpdateNeeded < 0.1) {
            //    printf("quick Terra part update %.4f\n", soonestUpdateNeeded);
            //}
	}
    }
    //printf("Changed %d slots\n", changedSlot);
    [mainTime unlatchTime];
    //if ([name compare:@"Terra"] == NSOrderedSame) {
    //    printADate(currentTime + soonestUpdateNeeded); printf(" (soonest update Terra)\n");
    //    printADate(currentTime + soonestUpdateNeeded + [TSTime skew]); printf(" (soonest update Terra as NTP)\n");
    //}
    ECAstronomyManager *priorAstro = [self astroWithIndex:lastMainTimeEnv];
    [priorAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
    return soonestUpdateNeeded;
}

- (void)setCurrentModeNumInternal:(ECWatchModeEnum)modeNum {
    bool isNightFlip = (modeNum == ECnightMode || currentModeNum == ECnightMode);
    [[NSUserDefaults standardUserDefaults] setInteger:modeNum forKey:[name stringByAppendingString:@"-ModeNum"]];
    currentModeNum = modeNum;
    // reset parts, because update time isn't right
    [self updateAllPartsForModeNum:modeNum animating:(isBackground && !isNightFlip)];
}

- (void)setVisible:(bool)newVisible resetY:(bool)resetY {
    assert(!isBackground);
    //printf("Setting %s %svisible\n",
    //       [name UTF8String], newVisible ? "" : "NOT ");
    if (newVisible && resetY) {
	drawCenter.y = 0;
	targetDrawCenter.y = 0;
    }
    if (visible != newVisible) {
	visible = newVisible;
	if (newVisible) {  // turning on
	    [ChronometerAppDelegate activateWatch:self];
	} else {  // turning off
	    [ChronometerAppDelegate deactivateWatch:self];
	}
    }
}

static bool zoomsEqual(double zoom1,
                       double zoom2) {
    return fabs(zoom1 - zoom2) < .0001;
}

static void updateExtendedHalfSize(void) {
    double rotationRadians = currentRotation * M_PI / 180;
    double canonicalRotation = EC_fmod(rotationRadians, M_PI);
    if (canonicalRotation > M_PI/2) {
        canonicalRotation = M_PI - canonicalRotation;
    }
    CGSize rawAppSize = [ChronometerAppDelegate applicationSizePoints];
    CGFloat rawWidth = rawAppSize.width;
    CGFloat rawHeight = rawAppSize.height;
    double phi = atan2(rawWidth, rawHeight);
    assert(phi > 0);
    assert(phi < M_PI / 2);
    double halfDiagonal = sqrt(rawWidth*rawWidth + rawHeight*rawHeight) / 2;
    extendedHalfHeight = halfDiagonal * cos(phi - canonicalRotation);
    extendedHalfWidth = halfDiagonal * sin(phi + canonicalRotation);
}

+ (NSTimeInterval)updateDeviceRotationForTime:(NSTimeInterval)currentTime {
    NSTimeInterval soonestUpdateNeeded = ECFarInTheFuture;
    if (animatingRotation) {
        if (currentTime >= animateRotationStopTime) {
            animatingRotation = false;
            currentRotation = targetRotation;
        } else {
            double fractionComplete = (currentTime - animateRotationStartTime) / (animateRotationStopTime - animateRotationStartTime);
            currentRotation = startRotation + fractionComplete * (targetRotation - startRotation);
            soonestUpdateNeeded = -1;
        }
        updateExtendedHalfSize();
    }
    return soonestUpdateNeeded;
}


- (NSTimeInterval)updatePositionZoomForTime:(NSTimeInterval)currentTime {
    assert([NSThread isMainThread]);
    NSTimeInterval soonestUpdateNeeded = ECFarInTheFuture;

    if (animatingPositionZoom) {
        if (currentTime >= animationPositionZoomStopTime) {
            animatingPositionZoom = false;
            drawCenter = targetDrawCenter;
            zoom = targetZoom;
            //printf("Done %s animating position zoom, position = (%g, %g) zoom = %.2f\n", [name UTF8String], drawCenter.x, drawCenter.y, zoom);
            //if (zoomsEqual(zoom, 1/[ChronometerAppDelegate nogridZoom])) {
            [ChronometerAppDelegate donePositionZoomAnimatingWhenAllWatchesFinishDrawing];
        } else {
            assert(targetZoom != 0);
	    double fractionComplete = (currentTime - animationPositionZoomStartTime) / (animationPositionZoomStopTime - animationPositionZoomStartTime);
            if (zoomsEqual(zoom, targetZoom)) {
                drawCenter.x = startDrawCenter.x + fractionComplete * (targetDrawCenter.x - startDrawCenter.x);
                drawCenter.y = startDrawCenter.y + fractionComplete * (targetDrawCenter.y - startDrawCenter.y);
                //printf("Animating %s translate-only, %.1f%% complete from (%.1f, %.1f) to (%.1f, %.1f), position = (%g, %g) zoom = %.2f\n",
                //       [name UTF8String],
                //       fractionComplete * 100,
                //       startDrawCenter.x, startDrawCenter.y,
                //       targetDrawCenter.x, targetDrawCenter.y,
                //       drawCenter.x, drawCenter.y,
                //       zoom);
            } else {
                assert(targetZoom != 0);
                double logZ = log(startZoom);
                assert(targetZoom != 0);
                double logTargetZ = log(targetZoom);
                assert(targetZoom != 0);
                logZ = logZ + (logTargetZ - logZ) * fractionComplete;
                assert(targetZoom != 0);
                zoom = exp(logZ);
                assert(targetZoom != 0);
                assert(zoom != 0);

                drawCenter.x = targetDrawCenter.x + anchor.x * (targetZoom - zoom);
                drawCenter.y = targetDrawCenter.y + anchor.y * (targetZoom - zoom);
                //printf("Animating %s with zoom, %.1f%% complete, position = (%g, %g) zoom = %.2f\n", [name UTF8String], fractionComplete * 100, drawCenter.x, drawCenter.y, zoom);
            }

	    lastPositionZoomAnimationTime = currentTime;
	    soonestUpdateNeeded = -1;
        }
    }

    if ([ChronometerAppDelegate inGridMode]) {
        [self setVisible:true resetY:false];
    } else {
        if (extendedHalfWidth == 0) {
            updateExtendedHalfSize();
        }
        if (drawCenter.x > 2 * (extendedHalfWidth * .99)  || drawCenter.x < - 2 * (extendedHalfWidth * .99) ||
	    drawCenter.y > 2 * (extendedHalfHeight * .99) || drawCenter.y < - 2 * (extendedHalfHeight * .99)) {
            //printf("Turning off visibility for watch %s because drawCenter at %.1f, %.1f is outside half width/height (%.1f, %.1f)\n",
            //       [name UTF8String], drawCenter.x, drawCenter.y, extendedHalfWidth, extendedHalfHeight);
            [self setVisible:false resetY:false];
        } else {
            [self setVisible:true resetY:false];
            //assert(drawCenter.x == 0);
            //assert(drawCenter.y == 0);
            //drawCenter.x = 0;
            //drawCenter.y = 0;
        }
    }
    return soonestUpdateNeeded;
}

- (NSTimeInterval)drawForModeNum:(ECWatchModeEnum)modeNum
		   andZoomPower2:(int)z2
		      gridPower2:(int)gridZ2
			  atTime:(NSTimeInterval)currentTime
		       zoomingIn:(bool)zoomingIn
		  asCurrentWatch:(bool)asCurrentWatch
		   forcingUpdate:(bool)forceUpdate
		  allowAnimation:(bool)allowAnimation
			dragType:(ECDragType)dragType {
    assert(visible || isBackground);
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    assert([NSThread isMainThread]);
    NSTimeInterval soonestUpdateNeeded;
    bool cacheLoaded = loaded;  // protect against bg thread changing the value of 'loaded'; cache the value here
    if (cacheLoaded) {
	if (zoomingIn && !asCurrentWatch && !isBackground) {
	    soonestUpdateNeeded = -1;
	    [ChronometerAppDelegate forceUpdateWhenZoomStops];
	} else {
	    soonestUpdateNeeded = [self prepareAllPartsForDrawForModeNum:modeNum
								  atTime:currentTime
							   forcingUpdate:forceUpdate
							  allowAnimation:allowAnimation
								dragType:dragType];
	}
    } else {
	soonestUpdateNeeded = ECFarInTheFuture;  // We'll get an explicit redraw request when things get loaded
    }
    bool drawLoadingInstead;
    if (cacheLoaded) {
	drawLoadingInstead = false;
	if (!isBackground) {
	    for (ECGLDisplayList *displayList in displayListsByMode[modeNum]) {
		if (![displayList loadedForZoomPower2:z2]) {
		    if (z2 >= 0 && [displayList loadedForZoomPower2:gridZ2]) {
			// OK; displayList will draw what it has loaded
		    } else {
			drawLoadingInstead = true;
			break;
		    }
		}
	    }
#ifndef NDEBUG
	} else {  // Check background watch
	    for (ECGLDisplayList *displayList in displayListsByMode[modeNum]) {
		assert([displayList loadedForZoomPower2:[ChronometerAppDelegate screenScaleZoomTweak]]);
	    }
#endif
	}
    } else {
	assert(!isBackground);
	drawLoadingInstead = true;  // no parts, can't draw
    }

    CGRect appBoundsPixels = [ChronometerAppDelegate applicationBoundsPixels];
    CGSize appSizeWatchCoordinates = [ChronometerAppDelegate applicationSizeWatchCoordinates];

    CGFloat halfWidthWatchCoords = appSizeWatchCoordinates.width / 2;
    CGFloat halfHeightWatchCoords = appSizeWatchCoordinates.height / 2;

    glViewport(appBoundsPixels.origin.x, appBoundsPixels.origin.y, 
               appBoundsPixels.size.width, appBoundsPixels.size.height);

    // Projection matrix serves solely to map draw coordinates to unrotated pixels
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(-halfWidthWatchCoords, halfWidthWatchCoords, -halfHeightWatchCoords, halfHeightWatchCoords, -1.0f, 1.0f);

    // Modelview matrix is everything else, including the rotation of the device
    // Note that GL matrix transformations are specified in reverse order of effective operation (last to happen is specified first)
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    if (currentRotation) {
        // Rotate entire display to reflect device rotation
        glRotatef(currentRotation, 0, 0, 1);
    }
    // Locate this watch at its proper place
    glTranslatef(drawCenter.x, drawCenter.y, 0);

    //printf("watch %s (0x%08x) at (%.1f, %.1f), zoom %.1f\n",
    //       [name UTF8String], (unsigned int)self, drawCenter.x, drawCenter.y, zoom);

    assert(zoom != 0);

    // Now the center of the watch is at 0,0.  Do remaining transformations for this watch, in reverse order
    if (animatingFlip) {
	double halfwayPoint = animationFlipStopTime - (kECGLFlipAnimationTime / 2.0);
	if (lastFlipAnimationTime < halfwayPoint && currentTime >= halfwayPoint) {	    //   if this is the first time after the halfway point,
	                                                                            // make the old watch invisible and the new watch visible
	    if (currentModeNum == ECfrontMode) {
		[self setCurrentModeNumInternal:ECbackMode];
	    } else {
		assert(currentModeNum == ECbackMode);
		[self setCurrentModeNumInternal:ECfrontMode];
	    }
	}
	if (currentTime >= animationFlipStopTime) {
	    animatingFlip = false;
	} else {
	    GLfloat angle;
	    if (currentTime < halfwayPoint) {	  // if we're before the halfway point
		double secondsSinceAnimationStart = currentTime - (animationFlipStopTime - kECGLFlipAnimationTime);
		angle = - secondsSinceAnimationStart/kECGLFlipAnimationTime * 180;
	    } else {   // we're after the halfway point, ...
		double remainingAnimationSeconds = (animationFlipStopTime - currentTime);
		angle = remainingAnimationSeconds/kECGLFlipAnimationTime * 180;
	    }
	    GLfloat zoomFactor = 3;
	    GLfloat zTranslation = halfWidthWatchCoords * zoomFactor;
	    GLfloat zNear = halfWidthWatchCoords;
	    GLfloat zFar = zTranslation * 2;
	    GLfloat scaledWidth = 1.0 / zoomFactor;
            GLfloat scaledHeight = 1.0 / zoomFactor;
	    // Rotate about y axis, then translate into negative z space (because that's what perspective transformations expect; the eye is at zero looking down);
	    //    then make perspective transform
            // glFrustum is normally a projection transformation, but we don't want it to apply to the projection matrix (which can be in the process of rotation).
	    glFrustumf(-scaledWidth, scaledWidth, -scaledHeight, scaledHeight, zNear, zFar);
	    glTranslatef(0, 0, -zTranslation);
	    glRotatef(angle, 0, 1.0f, 0);  // rotate around y axis

	    soonestUpdateNeeded = -1;
	    lastFlipAnimationTime = currentTime;
	}
    }

    // Scale the whole watch
    if (zoom != 1.0) {
        glScalef(zoom, zoom, zoom);
    }
    if (!drawLoadingInstead && zoomFramesLeft && !isBackground) {
#ifndef NDEBUG
#ifndef EC_CWH_ANDROID
        static bool firstDraw = true;
        if (firstDraw) {
            [ChronometerAppDelegate noteTimeAtPhase:"First draw"];
            firstDraw = false;
        }
#endif
#endif
        double zoomFrameFactor = 1 << zoomFramesLeft;
        glScalef(1/zoomFrameFactor, 1/zoomFrameFactor, 1/zoomFrameFactor);
        zoomFramesLeft--;
        soonestUpdateNeeded = -1;
    }

    if (drawLoadingInstead) {
	glScalef(1/zoom, 1/zoom, 1/zoom);  // Not sure about this
	glTranslatef(0, -ECLoadingListIconOffset, 0);
    }

    int drawLoadingZoomScale = [ChronometerAppDelegate screenScaleZoomTweak];
    if (drawLoadingInstead) {
	ECGLDisplayListWithTextureVertices *loadingDisplayList = loadingDisplayListsByMode[modeNum];
	assert(!isBackground);
	assert(loadingDisplayList);
	if (z2 == gridZ2) {
	    [loadingDisplayList drawRangeForZoomPower2:drawLoadingZoomScale from:1 to:1];
	    glTranslatef(0, ECLoadingListIconOffset-ECLoadingListTextOffset, 0);
	    [loadingDisplayList drawRangeForZoomPower2:drawLoadingZoomScale from:0 to:0];
	} else {
	    //[loadingDisplayList print];
	    [loadingDisplayList drawForZoomPower2:drawLoadingZoomScale];
	}
	return soonestUpdateNeeded;
    }
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // printf("Drawing displayList for watch %s at %d (%d)\n", [name UTF8String], z2, gridZ2);

    for (ECGLDisplayList *displayList in displayListsByMode[modeNum]) {
	[displayList drawForZoomPower2:z2 altZoomPower2:gridZ2];
    }
    if (![mainTime isCorrect] && [ChronometerAppDelegate inGridMode] && !isBackground && backgroundWatch) {
	if (!redBannerDisplayList) {
	    [backgroundWatch makeRedBannerList];
	}
        [backgroundWatch updateRedBannerListForWatchLandscapeZoomFactor:landscapeZoomFactor];
	[redBannerDisplayList drawForZoomPower2:drawLoadingZoomScale];
    }
    return soonestUpdateNeeded;
}

#ifndef NDEBUG
- (void)checkDisplayListsForMode:(ECWatchModeEnum)modeNum {
    for (ECGLDisplayList *displayList in displayListsByMode[modeNum]) {
	[displayList checkInitialized];
    }
}

- (void)dumpVariableValues {
    [vm dumpVariableValues];
}
#endif

- (void)updateAllPartsForModeNum:(ECWatchModeEnum)modeNum animating:(bool)animate {
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    [mainTime latchTimeForBeatsPerSecond:beatsPerSecond];  // use same time for all parts to avoid repeated entry into kernel
    bool doingFirstPart = true;
    for (NSArray *partGroup in partGroupsByTextureMode[modeNum]) {
	for (ECGLPart *part in partGroup) {
	    if (![part isSlave]) {
		int envSlot = [part envSlot];
		ECAstronomyManager *astroMan = [self astroWithIndex:envSlot];
		if (doingFirstPart) {
		    [astroMan setupLocalEnvironmentForThreadFromActionButton:false];
		    doingFirstPart = false;
		} else if (lastMainTimeEnv != envSlot) {
		    ECAstronomyManager *priorAstro = [self astroWithIndex:lastMainTimeEnv];
		    [priorAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
		    [astroMan setupLocalEnvironmentForThreadFromActionButton:false];
		}
		lastMainTimeEnv = [part envSlot];
		[part updateDisplayListsAtTime:[NSDate timeIntervalSinceReferenceDate] forModeNum:modeNum evaluateExpressions:true animate:animate masterAngle:0 masterOffsetAngle:0 draggingPartDragType:ECDragNormal];
	    }
	}
    }
    [mainTime unlatchTime];
    ECAstronomyManager *priorAstro = [self astroWithIndex:lastMainTimeEnv];
    [priorAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
#ifndef NDEBUG
//    [self checkDisplayListsForMode:modeNum];
#endif
}

- (void)updateAllPartsForCurrentModeAnimating:(bool)animate {
    [self updateAllPartsForModeNum:currentModeNum animating:animate];
}

- (NSTimeInterval)drawForCurrentModeAtTime:(NSTimeInterval)redrawTime
				zoomPower2:(int)z2
				gridPower2:(int)gridZ2
				 zoomingIn:(bool)zoomingIn
			    asCurrentWatch:(bool)asCurrentWatch
			     forcingUpdate:(bool)forceUpdate
			    allowAnimation:(bool)allowAnimation
				  dragType:(ECDragType)dragType {
    return [self drawForModeNum:currentModeNum andZoomPower2:z2 gridPower2:gridZ2 atTime:redrawTime zoomingIn:zoomingIn asCurrentWatch:asCurrentWatch forcingUpdate:forceUpdate allowAnimation:allowAnimation dragType:dragType];
}

- (void)attachTextureForFlipSideAndZoomPower2:(int)z2 {
    assert([NSThread isMainThread]);
    ECWatchModeEnum flipModeNum;
    switch(currentModeNum) {
      case ECfrontMode:
	flipModeNum = ECbackMode;
	break;
      case ECbackMode:
	flipModeNum = ECfrontMode;
	break;
      case ECnightMode:
	flipModeNum = ECbackNightMode;
	break;
      case ECbackNightMode:
	flipModeNum = ECnightMode;
	break;
      default:
	assert(false);
	flipModeNum = ECfrontMode;
    }
    assert(flipModeNum < ECNumWatchDrawModes);
    for (NSArray *partGroup in partGroupsByTextureMode[flipModeNum]) {
	for (ECGLPart *part in partGroup) {
	    int textureSlotIndex = [part partTextureAtlasSlotIndexForModeNum:flipModeNum];
	    ECGLTextureAtlas *atlas = *[self addressOfTextureForSlotIndex:textureSlotIndex andZoomPower2:z2];
	    if ([atlas textureLoadedSize] > 0) {
		[atlas attachTexture];
	    }
	}
    }
}

- (void)startFlipAnimationForZoomPower2:(int)z2 {
    assert(!animatingFlip);
    assert([NSThread isMainThread]);
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    animationFlipStopTime = currentTime + kECGLFlipAnimationTime;
    lastFlipAnimationTime = currentTime;
    animatingFlip = true;
    [self attachTextureForFlipSideAndZoomPower2:z2];
    [ChronometerAppDelegate requestRedraw];
}

- (void)setCurrentModeNum:(ECWatchModeEnum)modeNum zoomPower2:(int)z2 allowAnimation:(bool)allowAnimation {
    // printf("Setting mode of %s to %s at z2 %d\n", [[self name] UTF8String], ECmodeNames[modeNum], z2);
    if (animatingFlip || animatingPositionZoom) {
	[self setCurrentModeNumInternal:modeNum];
	return;
    }
    if (allowAnimation) {
	if (modeNum == ECbackMode) {
	    assert(currentModeNum == ECfrontMode);
	    // Do a full update of all parts; the nextUpdateTime might be farInTheFuture for the other side's parts and we can only fix that with a force update
	    [self prepareAllPartsForDrawForModeNum:ECbackMode atTime:[NSDate timeIntervalSinceReferenceDate] forcingUpdate:true allowAnimation:false dragType:ECDragNotDragging];
	    [self startFlipAnimationForZoomPower2:z2];
	    return;
	} else if (modeNum == ECfrontMode && currentModeNum == ECbackMode) {
	    // Do a full update of all parts; the nextUpdateTime might be farInTheFuture for the other side's parts and we can only fix that with a force update
	    [self prepareAllPartsForDrawForModeNum:ECfrontMode atTime:[NSDate timeIntervalSinceReferenceDate] forcingUpdate:true allowAnimation:false dragType:ECDragNotDragging];
	    [self startFlipAnimationForZoomPower2:z2];
	    return;
	}
    }
    [self setCurrentModeNumInternal:modeNum];
}

// Returns currentModeNum except in the first half of a flip animation, when it returns the ultimate flip side
- (ECWatchModeEnum)finalCurrentModeNum {
    if (animatingFlip) {
	double halfwayPoint = animationFlipStopTime - (kECGLFlipAnimationTime / 2.0);
	if (lastFlipAnimationTime < halfwayPoint) {	    //   if this is the first time after the halfway point,
	    if (currentModeNum == ECfrontMode) {
		return ECbackMode;
	    } else if (currentModeNum == ECbackMode) {
		return ECfrontMode;
	    } else {
		assert(false); // If animatingFlip is true, we should be in night mode
	    }
	}
    }
    return currentModeNum;
}

- (void)notifyTimeAdjustment {
    if (alarmTime) {
	[self updateDefaultsForCurrentAlarmState];
    }
    if (hasStopwatch) {
	[self updateDefaultsForCurrentStopwatchState];
    }
}

- (void)stopwatchStartStopWithRounding:(double)rounding {
    [ECAppLog log:@"stopwatch start/stop"];
    if (!hasStopwatch) {
	hasStopwatch = true;
	if (!alarmTime) {
	    [TSTime addTimeAdjustmentObserver:self];
	}
    }
    ECWatchTime *stopwatchDisplayTime = timers[ECStopwatchDisplayTimer];
    ECWatchTime *stopwatchTime = timers[ECStopwatchTimer];
    ECWatchTime *stopwatchLapTime = timers[ECStopwatchLapTimer];
    bool displayingLapTime = ![stopwatchTime isIdenticalTo:stopwatchDisplayTime];  // For display of lap and sw on same hands
    bool rattrapanteEngaged = (![stopwatchTime isIdenticalTo:stopwatchLapTime]);   // for display of lap and sw on separate hands
    [stopwatchTime toggleStopWithRounding:rounding];  // Rounding makes it so the stopwatch will restart properly like a mechanical
    if (!displayingLapTime) {
	[stopwatchDisplayTime makeTimeIdenticalToOtherTimer:stopwatchTime];
    }
    if (!rattrapanteEngaged) {
	[stopwatchLapTime makeTimeIdenticalToOtherTimer:stopwatchTime];
    }
    [self updateDefaultsForCurrentStopwatchState];
}

- (void)stopwatchReset {
    [ECAppLog log:@"stopwatch reset"];
    if (!hasStopwatch) {
	hasStopwatch = true;
	if (!alarmTime) {
	    [TSTime addTimeAdjustmentObserver:self];
	}
    }
    ECWatchTime *stopwatchTime = timers[ECStopwatchTimer];
    [stopwatchTime stopwatchReset];
    [timers[ECStopwatchDisplayTimer] makeTimeIdenticalToOtherTimer:stopwatchTime];
    [timers[ECStopwatchLapTimer]  makeTimeIdenticalToOtherTimer:stopwatchTime];
    [self updateDefaultsForCurrentStopwatchState];
}

- (void)stopwatchRattrapanteWithRounding:(double)rounding {
    [ECAppLog log:@"stopwatch rattrapante"];
    if (!hasStopwatch) {
	hasStopwatch = true;
	if (!alarmTime) {
	    [TSTime addTimeAdjustmentObserver:self];
	}
    }
    ECWatchTime *stopwatchTime = timers[ECStopwatchTimer];
    ECWatchTime *stopwatchLapTime = timers[ECStopwatchLapTimer];
    if ([stopwatchTime isIdenticalTo:stopwatchLapTime]) {
	if (![stopwatchLapTime isStopped]) {
	    [stopwatchLapTime toggleStopWithRounding:rounding];
	}
    } else {
	[stopwatchLapTime makeTimeIdenticalToOtherTimer:stopwatchTime];
    }
    [self updateDefaultsForCurrentStopwatchState];
}

- (void)alarmTimerFire:(id)userInfo {
    tracePrintf1("ALARM! ALARM! ALARM! ALARM! %s", alarmEnabled ? "Enabled" : "");
    if (alarmEnabled) {
	// Play a sound here -- see also stopAlarmRinging below
#undef EC_LOCAL_NOTIFICATION_WHILE_LOCKED
#ifdef EC_LOCAL_NOTIFICATION_WHILE_LOCKED
#if __IPHONE_4_0
	Class classForUILocalNotification = NSClassFromString(@"UILocalNotification");
	bool presentLocalNotificationInstead = [ChronometerAppDelegate displayLocked];
	if (presentLocalNotificationInstead && classForUILocalNotification) {
	    printf("Presenting local notification\n");
	    UILocalNotification *localNotification = [[classForUILocalNotification alloc] init];
	    localNotification.soundName = @"Triangle4.caf";
	    localNotification.alertBody = [NSString stringWithFormat:@"The alarm on %@ has gone off!", [self displayName]];;
	    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
	    [localNotification release];
	} else
#endif
#endif
	    [ECAudio startRinging];		// ECAudio makes sure indicator gets the nod that it's now ringing

	// Make this watch visible so the user can tell why it's ringing
	[ChronometerAppDelegate alarmFiredInWatch:self];
	if (alarmTime.specifiedMode == ECAlarmTimeInterval) {
	    --alarmCounter;
	    [ChronometerAppDelegate updateAlarmStatus];
	}   
    }
    [self updateDefaultsForCurrentAlarmState];
}

- (bool)stopAlarmRinging {
    // Stop playing a sound here, and return true iff there was an alarm sound to stop
    return [ECAudio stopRinging];
    
    // ECAudio makes sure indicator gets the nod that it's now ringing
}

- (ECWatchTime *)alarmTimer {
    if (alarmTime) {
	return [[[ECWatchTime alloc] initWithFrozenDateInterval:[alarmTime currentAlarmTime]] autorelease];
    }
    // Otherwise return midnight tomorrow
    return [ECAlarmTime defaultAlarmTimeForTime:mainTime usingEnv:mainEnv];
}

- (ECWatchTime *)intervalTimer {
    if (alarmTime) {
	//printf("effective offset of interval timer is %.10f\n", [alarmTime effectiveOffset]);
	return [[[ECWatchTime alloc] initWithFrozenDateInterval:[alarmTime effectiveOffset]] autorelease];
    } else {
	return [[[ECWatchTime alloc] initWithFrozenDateInterval:0] autorelease];
    }
}

- (ECWatchTime *)stopwatchTimer {
    return timers[ECStopwatchTimer];
}

- (ECWatchTime *)stopwatchLapTimer {
    return timers[ECStopwatchLapTimer];
}

- (ECWatchTime *)stopwatchDisplayTimer {
    return timers[ECStopwatchDisplayTimer];
}

- (void)ensureAlarmTimerPresent {
    if (!alarmTime) {
	alarmTime = [[ECAlarmTime alloc] initWithFireReceiver:self fireSelector:@selector(alarmTimerFire:) fireUserInfo:nil currentWatchTime:mainTime env:mainEnv];
	[alarmTime specifyTargetAlarmAt:0];
	if (!hasStopwatch) {
	    [TSTime addTimeAdjustmentObserver:self];
	}
    }
}

- (void)advanceAlarmHour {
    [self ensureAlarmTimerPresent];
    [alarmTime advanceAlarmHour];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)advanceAlarmMinute {
    [self ensureAlarmTimerPresent];
    [alarmTime advanceAlarmMinute];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)toggleAlarmAMPM {
    [self ensureAlarmTimerPresent];
    [alarmTime toggleAlarmAMPM];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)advanceIntervalHour {
    [self ensureAlarmTimerPresent];
    [alarmTime advanceIntervalHour];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)advanceIntervalMinute {
    [self ensureAlarmTimerPresent];
    [alarmTime advanceIntervalMinute];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)advanceIntervalSecond {
    [self ensureAlarmTimerPresent];
    [alarmTime advanceIntervalSecond];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (double)alarmCount {
    assert(alarmCounter >= 0);
    return alarmCounter;
}

- (void)enableAlarm {
    assert(alarmCounter >= 0);
    if (!alarmEnabled && [alarmTime setToFire]) {
	++alarmCounter;
	[ChronometerAppDelegate updateAlarmStatus];
    }    
    alarmEnabled = true;
    [alarmTime recalculateAlarm];  // To enable/disable local notifications
    [self updateDefaultsForCurrentAlarmState];
    // Make sure indicator gets the nod
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)disableAlarm {
    if (alarmEnabled && [alarmTime setToFire]) {
	--alarmCounter;
	[ChronometerAppDelegate updateAlarmStatus];
	assert(alarmCounter >= 0);
    }    
    alarmEnabled = false;
    [alarmTime recalculateAlarm];  // To enable/disable local notifications
    [self updateDefaultsForCurrentAlarmState];
    // Make sure indicator gets the nod
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)startIntervalTimer {
    assert(alarmCounter >= 0);
    if (alarmEnabled) {
	++alarmCounter;
	[ChronometerAppDelegate updateAlarmStatus];
    }    
    [self ensureAlarmTimerPresent];
    [alarmTime startTimer];
    [self updateDefaultsForCurrentAlarmState];
}

- (void)stopIntervalTimer {
    assert(alarmCounter >= 0);
    if (alarmEnabled) {
	--alarmCounter;
	[ChronometerAppDelegate updateAlarmStatus];
    }    
    [self ensureAlarmTimerPresent];
    [alarmTime stopTimer];
    [self updateDefaultsForCurrentAlarmState];
}

- (void)toggleIntervalTimer {
    assert(alarmCounter >= 0);
    if (alarmEnabled) {
	if (![alarmTime timerIsStopped]) {
	    ++alarmCounter;
	} else {
	    --alarmCounter;
	}
	[ChronometerAppDelegate updateAlarmStatus];
    }
    [self ensureAlarmTimerPresent];
    [alarmTime toggleTimer];
    [self updateDefaultsForCurrentAlarmState];
}

- (void)setTargetOffset:(double)newOffset {
    [self ensureAlarmTimerPresent];
    [alarmTime specifyTargetAlarmAt:newOffset];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)setIntervalOffset:(double)newOffset {
    [self ensureAlarmTimerPresent];
    if (newOffset < .01) {
	newOffset = 24 * 3600;
    }
    [alarmTime specifyIntervalAlarmAt:newOffset];
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

- (void)alarmReset {
    [self ensureAlarmTimerPresent];
    double currentOffset = [alarmTime effectiveOffset];
    double specifiedOffset = [alarmTime specifiedOffset];
    if (fabs(currentOffset - specifiedOffset) > 0.1) {
        [self ensureAlarmTimerPresent];
        [alarmTime recalculateIntervalTime];
        [self updateDefaultsForCurrentAlarmState];
    } else {
        [self setIntervalOffset:0];
    }
}

- (double)currentOffset {
    if (alarmTime) {
	return [alarmTime effectiveOffset];
    } else {
	return 0;
    }
}

- (ECWatchTime *)timerWithIndex:(unsigned int)timerNumber {
    assert(ECNumTimers > 0);
    assert(ECNumTimers - 1 <= ECTimerUB);
    if (timerNumber == 0) {
	return mainTime;
    } else if (timerNumber < ECNumTimers) {
	return timers[timerNumber];
    } else {
	assert(false);
	return nil;
    }
}

- (ECAstronomyManager *)astroWithIndex:(unsigned int)timerNumber {
    assert(numEnvironments > 0);
    assert(numEnvironments - 1 <= ECEnvUB);
    if (timerNumber == 0) {
	return mainAstro;
    } else if (timerNumber < numEnvironments) {
	return [environments[timerNumber] astronomyManager];
    } else {
	assert(false);
	return nil;
    }
}

- (ECWatchEnvironment *)enviroWithIndex:(unsigned int)timerNumber {
    assert(numEnvironments > 0);
    assert(numEnvironments - 1 <= ECEnvUB);
    if (timerNumber < numEnvironments) {
	return environments[timerNumber];
    } else {
	assert(false);
	return nil;
    }
}

- (void)setVisible:(bool)newVisible {
    [self setVisible:newVisible resetY:true];
}

- (void)setInactive {
    active = false;
}

- (int)nextActiveIndexIncludingThisOne {
    return activeIndex;
}

- (int)isActive {
    return active;
}

- (bool)alarming {
    if (alarmEnabled) {
	assert(alarmTime != nil);
	if ([alarmTime setToFire]) {		// && ([[alarmTime alarmWatchTime] currentTime] - [mainTime currentTime]) <= 12*3600) {
	    return true;
	}
    }
    return false;
}

- (ECAlarmTimeMode)alarmMode {
    return [alarmTime specifiedMode];
}

- (void)handleTouchMoveWithDeltaX:(CGFloat)dx forAdjacentIndex:(int)adjacentIndex {
    CGFloat windowWidth = [ChronometerAppDelegate applicationSizePoints].width;
    drawCenter.x = dx + windowWidth * adjacentIndex;
    drawCenter.y = 0;
    targetDrawCenter = drawCenter;
    animatingPositionZoom = false;
    [ChronometerAppDelegate requestRedraw];
}

- (void)handle2DTouchMoveTo:(CGPoint)pt {
    drawCenter = pt;
    targetDrawCenter = drawCenter;
    animatingPositionZoom = false;
    [ChronometerAppDelegate requestRedraw];
}

- (void)handleTouchReleaseWithoutSwipeToDrawCenter:(CGPoint)drawC animationStartTime:(NSTimeInterval)animationStartTime {
    assert([NSThread isMainThread]);
    targetDrawCenter = drawC;
    targetZoom = zoom;
    assert(zoom != 0);
    CGFloat dx = targetDrawCenter.x - drawCenter.x;
    CGFloat dy = targetDrawCenter.y - drawCenter.y;
    CGFloat pixelsToMove = sqrtf(dx*dx + dy*dy);
    if (pixelsToMove > 0) {
        animatingPositionZoom = true;
        animationPositionZoomStartTime = animationStartTime;
	lastPositionZoomAnimationTime = animationStartTime;
        startDrawCenter = drawCenter;
        startZoom = zoom;
        anchor.x = 0;
        anchor.y = 0;
        NSTimeInterval myStopTime = lastPositionZoomAnimationTime + pixelsToMove / kECGLSwipeAnimateSpeed;
        //printf("pixels to move %.1f, zoom %.1f, animation interval %.1f seconds\n", pixelsToMove, zoom, pixelsToMove / (kECGLSwipeAnimateSpeed * zoom));
        if (myStopTime > animationPositionZoomStopTime) {
            animationPositionZoomStopTime = myStopTime;
        }
    } else {
	drawCenter = targetDrawCenter;
        animatingPositionZoom = false;
        [ChronometerAppDelegate donePositionZoomAnimatingWhenAllWatchesFinishDrawing];
    }
    [ChronometerAppDelegate requestRedraw];
}

- (void)handleTouchReleaseWithoutSwipeForAdjacentIndex:(int)adjacentIndex {
    CGFloat windowWidth = [ChronometerAppDelegate applicationSizePoints].width;
    drawCenter.y = 0;  // should be redundant
    [self handleTouchReleaseWithoutSwipeToDrawCenter:CGPointMake(windowWidth * adjacentIndex, 0) animationStartTime:[NSDate timeIntervalSinceReferenceDate]];
}

- (void)setupForAnimateDrawResettingY:(bool)resetY {
    if (!visible) {
	[self setVisible:true resetY:resetY];
    }
}

- (void)scrollToDrawCenter:(CGPoint)drawC animationStartTime:(NSTimeInterval)animationStartTime atZoom:(double)aZoom animationInterval:(NSTimeInterval)animationInterval {
    assert([NSThread isMainThread]);
    CGFloat dx = targetDrawCenter.x - drawC.x;
    CGFloat dy = targetDrawCenter.y - drawC.y;
    CGFloat pixelsToMove = sqrtf(dx*dx + dy*dy);
    double tZoom = [self modifiedZoomForZoom:aZoom];
    assert(aZoom != 0);
    if (((pixelsToMove > 0) || !zoomsEqual(tZoom, zoom)) && animationInterval != 0) {
        if (animationInterval < 0) {
            animationInterval = pixelsToMove * aZoom / kECGLSwipeAnimateSpeed;
            //printf("pixels to move %.1f, zoom %.1f, animation interval %.1f seconds\n", pixelsToMove, zoom, animationInterval);
        }
        [self setPosition:drawC
                     zoom:aZoom
              animationStartTime:animationStartTime
              animationInterval:animationInterval];
    } else {
        //printf("No animation, scrollToDrawCenter setting %s at (%.1f, %.1f)\n", [name UTF8String], drawC.x, drawC.y);
	drawCenter = drawC;
        zoom = tZoom;
        animatingPositionZoom = false;
        if (animationInterval != 0) {
            [ChronometerAppDelegate donePositionZoomAnimatingWhenAllWatchesFinishDrawing];
        }
    }
    [self setupForAnimateDrawResettingY:(drawC.y == 0)];
    [ChronometerAppDelegate requestRedraw];
}

- (void)snapToPosition:(int)newPosition atZoom:(double)atZoom {
    CGFloat windowWidth = [ChronometerAppDelegate applicationSizePoints].width;
    [self scrollToDrawCenter:CGPointMake(windowWidth *newPosition, 0) animationStartTime:0 atZoom:atZoom animationInterval:0];
}

- (void)scrollIntoPosition:(int)newPosition atZoom:(double)newZoom animationStartTime:(NSTimeInterval)animationStartTime animationInterval:(NSTimeInterval)animationInterval {
    CGFloat windowWidth = [ChronometerAppDelegate applicationSizePoints].width;
    [self scrollToDrawCenter:CGPointMake(windowWidth *newPosition, 0) animationStartTime:animationStartTime atZoom:newZoom animationInterval:animationInterval];
}

- (void)setPosition:(CGPoint)pos
               zoom:(float)newZoom 
 animationStartTime:(NSTimeInterval)animationStartTime
  animationInterval:(NSTimeInterval)animationInterval {

    //printf("Watch %s setPosition (%.1f, %.1f) (was (%.1f, %.1f)) at zoom %.2f (current zoom %.2f, %s), animationInterval %.2f\n",
    //       [name UTF8String], pos.x, pos.y, drawCenter.x, drawCenter.y, newZoom, zoom, (zoomsEqual(zoom, newZoom) ? "SAME" : "DIFFERENT"), animationInterval);

    assert([NSThread isMainThread]);
    assert(newZoom != 0);
    if (animationInterval < 0) {
        CGFloat dx = targetDrawCenter.x - pos.x;
        CGFloat dy = targetDrawCenter.y - pos.y;
        CGFloat pixelsToMove = sqrtf(dx*dx + dy*dy);
        animationInterval = pixelsToMove / kECGLSwipeAnimateSpeed;
    }

    double zCur = zoom;
    double zTar = [self modifiedZoomForZoom:newZoom];
    if (fabs(zCur - zTar) < 0.001) {
        anchor = CGPointMake(0, 0);
        targetZoom = zoom;
        assert(zoom != 0);
    } else {
        anchor = CGPointMake((pos.x - drawCenter.x)/(zCur - zTar),
                             (pos.y - drawCenter.y)/(zCur - zTar));
        //printf("...anchor at (%.1f, %.1f)\n", anchor.x, anchor.y);
        targetZoom = zTar; 
    }
    // Ending point:
    targetDrawCenter = pos;

    animatingPositionZoom = true;
    assert(targetZoom != 0);
    lastPositionZoomAnimationTime = animationStartTime;
    animationPositionZoomStartTime = animationStartTime;
    startDrawCenter = drawCenter;
    startZoom = zoom;
    NSTimeInterval myStopTime = lastPositionZoomAnimationTime + animationInterval;
    if (myStopTime > animationPositionZoomStopTime) {
        animationPositionZoomStopTime = myStopTime;
    }
    [self setupForAnimateDrawResettingY:false];
}

static CGFloat
effectiveStartRotationForStartAndTarget(CGFloat start,
                                        CGFloat target) {
    int startInt = (int)start;
    int targetInt = (int)target;
    switch (startInt) {
      case 0:
        switch (targetInt) {
          case 0:
          case 90:
          case 180:
            return 0;
          case 270:
            return 360;
        }
      case 90:
        switch (targetInt) {
          case 0:
          case 90:
          case 180:
            return 90;
          case 270:
            return 450;
        }
      case 180:
        switch (targetInt) {
          case 0:
          case 90:
          case 180:
          case 270:
            return 180;
        }
      case 270:
        switch (targetInt) {
          case 0:
          case 90:
            return -90;
          case 180:
          case 270:
            return 270;
        }
    }        
    printf("Unexpected start/target rotation pair: %.1f (%d) / %.1f (%d)\n",
           start, startInt, target, targetInt);
    return start;
}

+ (void)setRotation:(CGFloat)rotationDegrees animationStartTime:(NSTimeInterval)animationStartTime animationInterval:(NSTimeInterval)animationInterval {
    if (animationInterval > 0) {
        animatingRotation = true;
        targetRotation = rotationDegrees;
        startRotation = effectiveStartRotationForStartAndTarget(currentRotation, targetRotation);
        // printf("setRotation %.1f => %.1f\n", startRotation, targetRotation);
        animateRotationStartTime = animationStartTime;
        animateRotationStopTime = animationStartTime + animationInterval;
    } else {
        animatingRotation = false;
        currentRotation = rotationDegrees;
        updateExtendedHalfSize();
    }
}

-(bool)manualSet {
    return [mainTime warp] == 0;
}

-(bool)runningBackward {
    return [mainTime lastMotionWasInReverse];
}

-(void)setRunningBackward:(bool)runningBack {  // set by watch's mechanical switch
    bool runningBackwardAlready = [mainTime lastMotionWasInReverse];
    if (runningBack != runningBackwardAlready) {
	[mainTime reverse];
	[ChronometerAppDelegate setupDSTEventTimer];
	[ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
	[ChronometerAppDelegate showECStatusMessage:nil];
    }
}

- (void)stemIn {
    [mainTime start];
    [ChronometerAppDelegate setupDSTEventTimer];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [ChronometerAppDelegate showECStatusMessage:nil];
}

- (void)stemOut {
    [mainTime stop];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [ChronometerAppDelegate showECStatusMessage:nil];
}

- (void)resetTime {
    [mainTime resetToLocal];
    [ChronometerAppDelegate setupDSTEventTimer];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [ChronometerAppDelegate showECStatusMessage:nil];
    // topSector = DEFAULT_RINGSECTOR;
}

- (void)rotateRing:(int)delta {
    topSector = (topSector + delta) % 24;
    if (topSector < 0) {
	topSector += 24;
    }
}

- (bool)hasCityAtLatitude:(double)lat longitude:(double)lng {
    for (int i=1; i<numEnvironments; i++) {
	if (fabs(lat - environments[i].latitude) < 0.01 && fabs(lng - environments[i].longitude) < 0.01) {
	    return true;
	}
    }
    return false;
}

- (void)setAlarmToTarget {
    [self ensureAlarmTimerPresent];
    [alarmTime setSpecifiedModeToTarget];
    [self updateDefaultsForCurrentAlarmState];
}

- (void)setAlarmToInterval {
    if (!alarmTime) {
	[self ensureAlarmTimerPresent];
	[alarmTime setSpecifiedModeToInterval];
	[alarmTime specifyIntervalAlarmAt:0];
    } else {
	[alarmTime setSpecifiedModeToInterval];
    }
    [self updateDefaultsForCurrentAlarmState];
}

- (void)alarmStemIn {
    alarmManualSet = false;
    [ChronometerAppDelegate showECStatusMessage:nil];
}

- (void)alarmStemOut {
    assert(alarmCounter >= 0);
    alarmManualSet = true;
    if (!alarmTime) {
	[self ensureAlarmTimerPresent];
    }
    if (alarmTime.specifiedMode == ECAlarmTimeTarget) {
	if (!alarmEnabled) {
	    ++alarmCounter;
	    alarmEnabled = true;
	    [ChronometerAppDelegate updateAlarmStatus];
	}
    } else {
	if (alarmEnabled) {
	    if ([alarmTime timerIsStopped]) {
		--alarmCounter;
		assert(alarmCounter >= 0);
		[ChronometerAppDelegate updateAlarmStatus];
	    }
	}
	[alarmTime stopTimer];
    }
    [self updateDefaultsForCurrentAlarmState];
    [ChronometerAppDelegate showECStatusMessage:nil];
}

static void addPartCenteredAtYToLoadingLists(ECGLDisplayListWithTextureVertices **loadingLists,
					     int                                 numDisplayListsToAdd,
					     int             			 partIndex,
					     ECWatchModeEnum                     watchMode,
					     NSDictionary    			 *spareParts,
					     NSString        			 *partName,
					     CGFloat         			 y) {
    
    NSString *tryName;
    NSData *rectData = nil;
    if (watchMode != ECfrontMode) {
	if (watchMode == ECbackMode) {
	    tryName = [partName stringByAppendingString:@" b"];
	} else {
	    assert(watchMode == ECnightMode);
	    tryName = [partName stringByAppendingString:@" n"];
	}
	rectData = [spareParts objectForKey:tryName];
    }
    if (!rectData) {
	rectData = [spareParts objectForKey:partName];
	if (!rectData) {
#ifndef EC_CWH_ANDROID
            printf("Can't find spare part named %s in background watch\n", [partName UTF8String]);
#endif
	    rectData = [spareParts objectForKey:@"watch"];
	    assert(rectData);
	    if (!rectData) {
		return;
	    }
	}
    }
    CGRect *textureRect = (CGRect *)[rectData bytes];

    int drawLoadingZoomScale = [ChronometerAppDelegate screenScaleZoomTweak];
    double divisor = 1 << drawLoadingZoomScale;
    CGFloat halfWidth = (textureRect->size.width / 2) / divisor;
    CGFloat halfHeight = (textureRect->size.height / 2) / divisor;

    // UL, UR, LL, LR
    CGPoint quadVertices[4];
    quadVertices[0].x = -halfWidth;   quadVertices[0].y = y + halfHeight;
    quadVertices[1].x =  halfWidth;   quadVertices[1].y = y + halfHeight;
    quadVertices[2].x = -halfWidth;   quadVertices[2].y = y - halfHeight;
    quadVertices[3].x =  halfWidth;   quadVertices[3].y = y - halfHeight;
    for (int i = 0; i < numDisplayListsToAdd; i++) {
	[loadingLists[i] setPartTextureBounds:*textureRect forPartIndex:partIndex flipX:false flipY:false pixelCoords:true zoomPower2:drawLoadingZoomScale];
	[loadingLists[i] setPartShapeCoords:quadVertices forPartIndex:partIndex];
    }
}

- (void)makeLoadingListsForWatchNamed:(NSString *)watchName intoLoadingLists:(ECGLDisplayListWithTextureVertices **)loadingLists {
    assert([name caseInsensitiveCompare:@"Background"] == NSOrderedSame || [name caseInsensitiveCompare:@"BackgroundHD"] == NSOrderedSame);  // This is only legal on the background watch
    ECGLDisplayList *myFrontDisplayList = [displayListsByMode[ECfrontMode] objectAtIndex:0];
    assert(myFrontDisplayList);
    assert(spareParts);  // The background better define spare parts
    for (int i = 0; i < ECNumWatchDrawModes; i++) {
	loadingLists[i] = [[ECGLDisplayListWithTextureVertices alloc] initForNumParts:2 textureAtlasesFrom:myFrontDisplayList];
    }
    int drawLoadingZoomScale = [ChronometerAppDelegate screenScaleZoomTweak];
    int drawLoadingZoomScaleIndex = ECZoomIndexForPower2(drawLoadingZoomScale);
    addPartCenteredAtYToLoadingLists(loadingLists, ECNumWatchDrawModes, 0, ECfrontMode, spareParts[drawLoadingZoomScaleIndex], @"loading", ECLoadingListTextOffset);
    for (int i = 0; i < ECNumWatchDrawModes; i++) {
	addPartCenteredAtYToLoadingLists(&loadingLists[i], 1, 1, i, spareParts[drawLoadingZoomScaleIndex], watchName, ECLoadingListIconOffset);
    }
}

- (void)makeLoadingLists {
    if (backgroundWatch && !isBackground) {
	[backgroundWatch makeLoadingListsForWatchNamed:name intoLoadingLists:loadingDisplayListsByMode];
    }
}

- (void)updateRedBannerListForWatchLandscapeZoomFactor:(double)watchLandscapeZoomFactor {
    CGSize screenSize;
    if ([ChronometerAppDelegate currentOrientationIsLandscape]) {
        screenSize.width = 320 / watchLandscapeZoomFactor;
        screenSize.height = 480 / watchLandscapeZoomFactor;
    } else {
        screenSize.width = 320;
        screenSize.height = 480;
    }

    CGFloat bannerLow = screenSize.height*7/16;
    CGFloat bannerHeight = 25;
    CGFloat bannerLowOffset = screenSize.height/2 - bannerLow;

    CGRect boundsOnScreen = CGRectMake(-screenSize.width/2, bannerLow, screenSize.width, bannerHeight);
    [redBannerDisplayList setPartShapeRect:boundsOnScreen        forPartIndex:0];

    boundsOnScreen = CGRectMake(-screenSize.width/2, -screenSize.height/2, 4, screenSize.height - bannerLowOffset);
    [redBannerDisplayList setPartShapeRect:boundsOnScreen        forPartIndex:1];

    boundsOnScreen = CGRectMake(screenSize.width/2 - 4, -screenSize.height/2, 4, screenSize.height - bannerLowOffset);
    [redBannerDisplayList setPartShapeRect:boundsOnScreen        forPartIndex:2];

    boundsOnScreen = CGRectMake(-screenSize.width/2, -screenSize.height/2, screenSize.width, 4);
    [redBannerDisplayList setPartShapeRect:boundsOnScreen        forPartIndex:3];
}

- (void)makeRedBannerList {
    assert(isBackground);
    assert(!redBannerDisplayList);
    assert(displayListsByMode[ECfrontMode]);
    assert([displayListsByMode[ECfrontMode] objectAtIndex:0]);
    redBannerDisplayList = [[ECGLDisplayListWithTextureVertices alloc] initForNumParts:4 textureAtlasesFrom:[displayListsByMode[ECfrontMode] objectAtIndex:0]];
    int drawLoadingZoomScale = [ChronometerAppDelegate screenScaleZoomTweak];
    NSData *rectData = [spareParts[ECZoom0Index + drawLoadingZoomScale] objectForKey:@"red banner"];
    assert(rectData);
    CGRect *textureRect = (CGRect *)[rectData bytes];
    CGRect actualTextureRect = CGRectMake(CGRectGetMidX(*textureRect), CGRectGetMidY(*textureRect), 0, 0);
    [redBannerDisplayList setPartTextureBounds:actualTextureRect forPartIndex:0 flipX:false flipY:false pixelCoords:true zoomPower2:drawLoadingZoomScale];
    [redBannerDisplayList setPartTextureBounds:actualTextureRect forPartIndex:1 flipX:false flipY:false pixelCoords:true zoomPower2:drawLoadingZoomScale];
    [redBannerDisplayList setPartTextureBounds:actualTextureRect forPartIndex:2 flipX:false flipY:false pixelCoords:true zoomPower2:drawLoadingZoomScale];
    [redBannerDisplayList setPartTextureBounds:actualTextureRect forPartIndex:3 flipX:false flipY:false pixelCoords:true zoomPower2:drawLoadingZoomScale];
}

- (bool)loadArchiveIfRequiredTestOnly:(bool)testOnly {
    if (!loaded) {
	if (!testOnly) {
#ifdef MEMORY_TRACK_TEXTURE
	    NSString *description = [NSString stringWithFormat:@"load %@ archive", name];
	    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
	    [self loadFromArchive];
#ifdef MEMORY_TRACK_TEXTURE
	    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
	}
	return true;
    }
    return false;
}

- (bool)loadTextureIfRequiredForModeNum:(ECWatchModeEnum)modeNum zoomPower2:(int)z2 testOnly:(bool)testOnly needsBytes:(size_t *)needsBytes {
    *needsBytes = 0;
    if (loaded && !((1 << modeNum) & textureLoadRequiredMasksByZoom[ECZoomIndexForPower2(z2)])) {
	if (!testOnly) {
	    size_t textureBytes = [self textureBytesNeededForLoadOfModeNum:modeNum atZoomPower2:z2];
	    size_t totalLoadedSize = [ECGLTextureAtlas totalLoadedSize];
	    if (textureBytes + totalLoadedSize > ECMaxLoadedTextureSize) {
		// don't do anything, but return neededBytes
		*needsBytes = textureBytes + totalLoadedSize - ECMaxLoadedTextureSize;
		return false;
	    }
#ifdef MEMORY_TRACK_TEXTURE
	    NSString *description = [NSString stringWithFormat:@"%@ %s load texture", name, ECmodeNames[modeNum]];
	    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
	    [self requireTextureLoadForModeNum:modeNum atZoomPower2:z2];
	    *needsBytes = 0;
#ifdef MEMORY_TRACK_TEXTURE
	    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
	    if ([ChronometerAppDelegate currentWatch] == self && modeNum == currentModeNum && z2 == 0 || (z2 != 0 && [ChronometerAppDelegate displayingZ2:z2])) {
		//printf("Requesting redraw %s %s %d\n", [[self name] UTF8String], ECmodeNames[modeNum], z2);
		[ChronometerAppDelegate performSelector:@selector(requestRedraw) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
	    }
	}
	return true;
    }
    return false;
}

- (size_t)markTextureUnloadedForModeNum:(ECWatchModeEnum)modeNum zoomPower2:(int)z2 needUnattach:(bool *)needUnattach {
    assert(![NSThread isMainThread] || [ChronometerAppDelegate inBackground]);
    // if the watch is loaded
    *needUnattach = false;
    if (loaded) {
	// if the texture is loaded
	if ((1 << modeNum) & textureLoadRequiredMasksByZoom[ECZoomIndexForPower2(z2)]) {
	    return [self releaseTextureLoadForModeNum:modeNum atZoomPower2:(int)z2 needUnattach:needUnattach];
	}
    }
    return 0;
}

- (void)doPendingUnattaches {
    assert([NSThread isMainThread]);
    if (loaded) {  // can't be attached if we aren't loaded
	for (int i = 0; i < numTextures; i++) {
	    for (int z2 = ECZoomMinPower2; z2 <= ECZoomMaxPower2; z2++) {
		[textures[i * ECNumVisualZoomFactors + (z2 - ECZoomMinPower2)] unattachIfMarked];
	    }
	}
    }
}

- (void)unloadAllTextures {
    assert([NSThread isMainThread]);
    if (loaded) {  // can't be attached if we aren't loaded
	for (int i = 0; i < numTextures; i++) {
	    for (int z2 = ECZoomMinPower2; z2 <= ECZoomMaxPower2; z2++) {
		[textures[i * ECNumVisualZoomFactors + (z2 - ECZoomMinPower2)] forceUnloadOrUnattach];
	    }
	}
    }
    for (int z2 = ECZoomMinPower2; z2 <= ECZoomMaxPower2; z2++) {
	textureLoadRequiredMasksByZoom[ECZoomIndexForPower2(z2)] = 0;
    }
}

// Called by ECWatchTime when skew bumped prior to first ntp fix
- (void)notifyBumpIntervalSkewBy:(double)skewIncrement {
    // DO SOMETHING
}

- (void)print {
    printf("\n\n************* WATCH %s ***************\n", [name UTF8String]);
    printf("    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   FRONT   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n");
    for (NSArray *partGroup in partGroupsByTextureMode[ECfrontMode]) {
	for (ECGLPart *part in partGroup) {
	    [part print];
	}
    }
    printf("\n\n\n    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   BACK   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n");
    for (NSArray *partGroup in partGroupsByTextureMode[ECbackMode]) {
	for (ECGLPart *part in partGroup) {
	    [part print];
	}
    }
    printf("\n\n\n    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   NIGHT   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n");
    for (NSArray *partGroup in partGroupsByTextureMode[ECnightMode]) {
	for (ECGLPart *part in partGroup) {
	    [part print];
	}
    }
}

- (int)numPartBases {
    return [partBases count];
}

- (NSTimeInterval)nextDSTTransition {
    NSTimeInterval closestTime = [ECDynamicUpdate getNextUpdateTimeForInterval:ECDynamicUpdateNextDSTChange
								     andOffset:0
								    startingAt:0  // startingAt unused when using dynamic updater fns
								forEnvironment:mainEnv
								     watchTime:mainTime];
    //printf("%20s env %2d %25s %s\n",
    //	   [name UTF8String],
    //	   0,
    //	   [[[mainEnv timeZone] name] UTF8String],
    //	   [[[NSDate dateWithTimeIntervalSinceReferenceDate:closestTime] description] UTF8String]);
    if (loaded) {
	for (int i = 1; i < numEnvironments; i++) {
	    NSTimeInterval envTime = [ECDynamicUpdate getNextUpdateTimeForInterval:ECDynamicUpdateNextDSTChange
									 andOffset:0
									startingAt:0  // startingAt unused when using dynamic updater fns
								    forEnvironment:environments[i]
									 watchTime:mainTime];
	    //printf("%20s env %2d %25s %s\n",
	    //	   [name UTF8String],
	    //	   i,
	    //	   [[[environments[i] timeZone] name] UTF8String],
	    //	   [[[NSDate dateWithTimeIntervalSinceReferenceDate:envTime] description] UTF8String]);
	    if (envTime < closestTime) {
		closestTime = envTime;
	    }
	}
    }
    return closestTime;
}

// Method-pointer types
typedef double (*WatchMainTimeNoArgSelectorFn)(id, SEL, id);   // self, selector, env
typedef int (*WatchMainTimeIntNoArgSelectorFn)(id, SEL, id);   // self, selector, env
typedef bool (*WatchMainTimeBoolNoArgSelectorFn)(id, SEL, id);   // self, selector, env
typedef ECWatchTime *(*AstroWatchTimeSelectorFn)(id, SEL);     // self, selector (no params)
typedef ECWatchTime *(*AstroPlanetWatchTimeSelectorFn)(id, SEL, int);  // self, selector, planetNumber
typedef void (*WatchAdvanceDoubleArgSelectorFn)(id, SEL, double);          // self, selector, amount
typedef void (*WatchAdvanceEnvOnlySelectorFn)(id, SEL, id);          // self, selector, env
typedef void (*WatchAdvanceEnvIntSelectorFn)(id, SEL, int, id);          // self, selector, amount, env
typedef void (*WatchAdvanceEnvDoubleSelectorFn)(id, SEL, double, id);          // self, selector, amount, env

-(double)currentMainTime {
    return [mainTime currentTime];
}

-(double)getValueFromMainTime:(SEL)watchTimeSelector {
    WatchMainTimeNoArgSelectorFn fn = (WatchMainTimeNoArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    return (*fn)(mainTime, watchTimeSelector, mainEnv);
}

-(int)getIntValueFromMainTime:(SEL)watchTimeSelector {
    WatchMainTimeIntNoArgSelectorFn fn = (WatchMainTimeIntNoArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    return (*fn)(mainTime, watchTimeSelector, mainEnv);
}

-(bool)getBoolValueFromMainTime:(SEL)watchTimeSelector {
    WatchMainTimeBoolNoArgSelectorFn fn = (WatchMainTimeBoolNoArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    return (*fn)(mainTime, watchTimeSelector, mainEnv);
}

-(double)getValueFromAlarmTime:(SEL)watchTimeSelector {
    ECWatchTime *alarmTimer = [self alarmTimer];
    WatchMainTimeNoArgSelectorFn fn = (WatchMainTimeNoArgSelectorFn)[alarmTimer methodForSelector:watchTimeSelector];
    return (*fn)(alarmTimer, watchTimeSelector, mainEnv);
}

-(int)getIntValueFromAlarmTime:(SEL)watchTimeSelector {
    ECWatchTime *alarmTimer = [self alarmTimer];
    WatchMainTimeIntNoArgSelectorFn fn = (WatchMainTimeIntNoArgSelectorFn)[alarmTimer methodForSelector:watchTimeSelector];
    return (*fn)(alarmTimer, watchTimeSelector, mainEnv);
}

-(double)getValueFromTimeForEnv:(int)envNumber watchTimeSelector:(SEL)watchTimeSelector {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    WatchMainTimeNoArgSelectorFn fn = (WatchMainTimeNoArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    return (*fn)(mainTime, watchTimeSelector, environments[envNumber]);
}

-(int)getIntValueFromTimeForEnv:(int)envNumber watchTimeSelector:(SEL)watchTimeSelector {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    WatchMainTimeIntNoArgSelectorFn fn = (WatchMainTimeIntNoArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    return (*fn)(mainTime, watchTimeSelector, environments[envNumber]);
}

-(bool)getBoolValueFromTimeForEnv:(int)envNumber watchTimeSelector:(SEL)watchTimeSelector {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    WatchMainTimeBoolNoArgSelectorFn fn = (WatchMainTimeBoolNoArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    return (*fn)(mainTime, watchTimeSelector, environments[envNumber]);
}

-(double)getValueFromMainAstroWatchTime:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector {
    AstroWatchTimeSelectorFn aFn = (AstroWatchTimeSelectorFn)[mainAstro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(mainAstro, astroSelector);
    WatchMainTimeNoArgSelectorFn wFn = (WatchMainTimeNoArgSelectorFn)[watchTime methodForSelector:watchTimeSelector];
    return (*wFn)(watchTime, watchTimeSelector, mainEnv);
}

-(int)getIntValueFromMainAstroWatchTime:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector {
    AstroWatchTimeSelectorFn aFn = (AstroWatchTimeSelectorFn)[mainAstro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(mainAstro, astroSelector);
    WatchMainTimeIntNoArgSelectorFn wFn = (WatchMainTimeIntNoArgSelectorFn)[watchTime methodForSelector:watchTimeSelector];
    return (*wFn)(watchTime, watchTimeSelector, mainEnv);
}

-(double)getValueFromMainAstroWatchTime:(SEL)astroSelector planetNumber:(int)planetNumber watchTimeSelector:(SEL)watchTimeSelector {
    AstroPlanetWatchTimeSelectorFn aFn = (AstroPlanetWatchTimeSelectorFn)[mainAstro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(mainAstro, astroSelector, planetNumber);
    WatchMainTimeNoArgSelectorFn wFn = (WatchMainTimeNoArgSelectorFn)[watchTime methodForSelector:watchTimeSelector];
    return (*wFn)(watchTime, watchTimeSelector, mainEnv);
}

-(int)getIntValueFromMainAstroWatchTime:(SEL)astroSelector planetNumber:(int)planetNumber watchTimeSelector:(SEL)watchTimeSelector {
    AstroPlanetWatchTimeSelectorFn aFn = (AstroPlanetWatchTimeSelectorFn)[mainAstro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(mainAstro, astroSelector, planetNumber);
    WatchMainTimeIntNoArgSelectorFn wFn = (WatchMainTimeIntNoArgSelectorFn)[watchTime methodForSelector:watchTimeSelector];
    return (*wFn)(watchTime, watchTimeSelector, mainEnv);
}

-(double)getValueFromAstroWatchTimeForEnv:(int)envNumber astroSelector:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    ECWatchEnvironment *enviro = environments[envNumber];
    ECAstronomyManager *astro = [enviro astronomyManager];
    AstroWatchTimeSelectorFn aFn = (AstroWatchTimeSelectorFn)[astro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(astro, astroSelector);
    WatchMainTimeNoArgSelectorFn wFn = (WatchMainTimeNoArgSelectorFn)[watchTime methodForSelector:watchTimeSelector];
    return (*wFn)(watchTime, watchTimeSelector, enviro);
}

-(int)getIntValueFromAstroWatchTimeForEnv:(int)envNumber astroSelector:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    ECWatchEnvironment *enviro = environments[envNumber];
    ECAstronomyManager *astro = [enviro astronomyManager];
    AstroWatchTimeSelectorFn aFn = (AstroWatchTimeSelectorFn)[astro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(astro, astroSelector);
    WatchMainTimeIntNoArgSelectorFn wFn = (WatchMainTimeIntNoArgSelectorFn)[watchTime methodForSelector:watchTimeSelector];
    return (*wFn)(watchTime, watchTimeSelector, enviro);
}

-(int)getDayOffsetValueFromMainAstroWatchTime:(SEL)astroSelector {  // return number of days from main watchTime to given astro watch time
    AstroWatchTimeSelectorFn aFn = (AstroWatchTimeSelectorFn)[mainAstro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(mainAstro, astroSelector);
    return [watchTime numberOfDaysOffsetFrom:mainTime usingEnv:mainEnv];
}

-(int)getDayOffsetValueFromAstroWatchTimeForEnv:(int)envNumber astroSelector:(SEL)astroSelector {  // return number of days from main watchTime to given astro watch time
    assert(envNumber >= 0 && envNumber < numEnvironments);
    ECWatchEnvironment *enviro = environments[envNumber];
    ECAstronomyManager *astro = [enviro astronomyManager];
    AstroWatchTimeSelectorFn aFn = (AstroWatchTimeSelectorFn)[astro methodForSelector:astroSelector];
    ECWatchTime *watchTime = (*aFn)(astro, astroSelector);
    return [watchTime numberOfDaysOffsetFrom:mainTime usingEnv:enviro];
}

-(int)offsetDaysFromMainForEnv:(int)envNumber {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    return [mainTime numberOfDaysOffsetFrom:mainTime usingEnv1:mainEnv env2:environments[envNumber]];
}

-(int)offsetDaysFrom:(int)envNumber1 forEnv:(int)envNumber2 {
    assert(envNumber1 >= 0 && envNumber1 < numEnvironments);
    assert(envNumber2 >= 0 && envNumber2 < numEnvironments);
    return [mainTime numberOfDaysOffsetFrom:mainTime usingEnv1:environments[envNumber1] env2:environments[envNumber2]];
}

// Note:  This function does not work in October 1582 after the transition
static int
columnOfFirstOfMonth(ECWatchTime *watchTime,
                     ECWatchEnvironment *env) {
    int weekday = [watchTime weekdayNumberAsCalendarColumnUsingEnv:env];
    int dayOfMonth = [watchTime dayNumberUsingEnv:env];   // 1st of month is 0
    int ret = (weekday + 7 - (dayOfMonth % 7)) % 7;
    //printf("columnOfFirstOfMonth, weekday %d, dayOfMonth %d, ret %d\n", weekday, dayOfMonth, ret);
    return ret;
}

// The rotationForCalendar methods all operate on mainTime
-(double)rotationForCalendarWheel012BDesignedForWeekdayStart:(int)wheelWeekdayStart {
    if (ECCalendarWeekdayStart != wheelWeekdayStart) {
        return 0;
    }
    int wd1 = columnOfFirstOfMonth(mainTime, mainEnv);
    //printf("rotationForCalendarWheel012B, wd1 = %d\n", wd1);
    assert(wd1 >= 0);
    if (wd1 > 2) {
        return 3 * M_PI / 2;  // The cutout section
    } else {
        return wd1 * M_PI / 2;
    }
}

-(double)rotationForCalendarWheel3456DesignedForWeekdayStart:(int)wheelWeekdayStart {
    if (ECCalendarWeekdayStart != wheelWeekdayStart) {
        return 0;
    }
    int wd1 = columnOfFirstOfMonth(mainTime, mainEnv);
    assert(wd1 >= 0);
    assert(wd1 < 7);
    //printf("rotationForCalendarWheel3456, wd1 = %d\n", wd1);
    if (wd1 < 4) {
        return 0;
    } else {
        return (wd1 - 3) * M_PI / 2;
    }
}

-(double)rotationForCalendarWheelOct1582DesignedForWeekdayStart:(int)wheelWeekdayStart {
    if (ECCalendarWeekdayStart != wheelWeekdayStart) {
        return 0;
    }
    int month = [mainTime monthNumberUsingEnv:mainEnv];  // 0-11; October is 9
    int year = [mainTime yearNumberUsingEnv:mainEnv];
    if (year == 1582 && month == 9) {
        return 0;
    } else {
        return M_PI /2;   // The cutout section (well, anything but 0 is the cutout section, but this avoids having the lower right poke into the area
    }
}

-(int)calendarColumn {
    return [mainTime weekdayNumberAsCalendarColumnUsingEnv:mainEnv];
}

-(int)calendarRow {
    int dayNumber = [mainTime dayNumberUsingEnv:mainEnv];
    int firstOfMonthColumn = columnOfFirstOfMonth(mainTime, mainEnv);
    //printf("dayNumber starts out %d, ", dayNumber);
    if ([mainTime yearNumberUsingEnv:mainEnv] == 1582 &&
        [mainTime monthNumberUsingEnv:mainEnv] == 9 &&
        [mainTime eraNumberUsingEnv:mainEnv] == 1 &&
        dayNumber > 4) {  // October 1582 CE
        assert(dayNumber >= 14);
        dayNumber -= 10;
        firstOfMonthColumn = (8 - ECCalendarWeekdayStart) % 7;  // October 1582 started on a Monday
    }
    int cellNumber = dayNumber + firstOfMonthColumn;
    //printf("...dayNumber is %d, cellNumber is %d\n", dayNumber, cellNumber);
    return cellNumber / 7;
}

-(double)calendarRowCoverOffsetForType:(ECCalendarRowCoverType)coverType
                          overallWidth:(CGFloat)overallWidth
                             cellWidth:(CGFloat)cellWidth
                          spacingWidth:(CGFloat)spacingWidth {
    // There are two common questions:
    //   1)  What is the weekday of the first of next month
    //   2)  How far is that row from the first of this month

    NSTimeInterval now = [mainTime currentTime];

    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(now, mainEnv->estz, &cs);
    // Find the first of this month
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisMonth = ESCalendar_timeIntervalFromLocalDateComponents(mainEnv->estz, &cs);
    int thisMonthStartWeekday = ESCalendar_localWeekdayFromTimeInterval(firstOfThisMonth, mainEnv->estz);
    int thisMonthStartWeekdayColumn = (7 + thisMonthStartWeekday - ECCalendarWeekdayStart) % 7;

    NSTimeInterval firstOfNextMonth = ESCalendar_addMonthsToTimeInterval(firstOfThisMonth, mainEnv->estz, 1);
    int nextMonthStartWeekday = ESCalendar_localWeekdayFromTimeInterval(firstOfNextMonth, mainEnv->estz);
    int nextMonthStartWeekdayColumn = (7 + nextMonthStartWeekday - ECCalendarWeekdayStart) % 7;

    int daysInThisMonth = (int)rint((firstOfNextMonth - firstOfThisMonth) / (24 * 3600));
    int nextMonthStartRow = (daysInThisMonth + thisMonthStartWeekdayColumn) / 7;
    
    int columnMotion = 7;  // place offscreen by default
    switch(coverType) {
      case ECCalendarCoverRow56Right:
        if (nextMonthStartRow == 4) {  // It's my row 5, or row6 needs a second
            columnMotion = nextMonthStartWeekdayColumn;
        }
        break;
      case ECCalendarCoverRow6Left:
        if (nextMonthStartRow == 5) {  // It's my row 6
            columnMotion = nextMonthStartWeekdayColumn;
        } else if (nextMonthStartRow == 4) {
            columnMotion = nextMonthStartWeekdayColumn - 7;
        }
        break;
      default:
        break;  // caught elsewhere
    }
    //printf("column motion for type %d is %d\n",
    //       (int)coverType, columnMotion);
    return rint(columnMotion * (cellWidth + spacingWidth));
}

-(double)calendarRowUnderlayOffsetForType:(ECCalendarRowCoverType)coverType
                             overallWidth:(CGFloat)overallWidth
                                cellWidth:(CGFloat)cellWidth
                             spacingWidth:(CGFloat)spacingWidth {
    NSTimeInterval now = [mainTime currentTime];

    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(now, mainEnv->estz, &cs);
    // Find the first of this month
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisMonth = ESCalendar_timeIntervalFromLocalDateComponents(mainEnv->estz, &cs);
    int thisMonthStartWeekday = ESCalendar_localWeekdayFromTimeInterval(firstOfThisMonth, mainEnv->estz);
    int thisMonthStartWeekdayColumn = (7 + thisMonthStartWeekday - ECCalendarWeekdayStart) % 7;

    NSTimeInterval firstOfLastMonth = ESCalendar_addMonthsToTimeInterval(firstOfThisMonth, mainEnv->estz, -1);

    int daysInLastMonth = (int)rint((firstOfThisMonth - firstOfLastMonth) / (24 * 3600));
    if (daysInLastMonth < 28) {
        // Must be October 1582
        daysInLastMonth = 31;
    }
    
    int columnMotion = 0;
    switch(coverType) {
      case ECCalendarCoverRow1Left:
        columnMotion = thisMonthStartWeekdayColumn + 22 - daysInLastMonth;
        if (columnMotion < -4) {
            columnMotion = -4;
        }
        break;
      case ECCalendarCoverRow1Right:
        columnMotion = thisMonthStartWeekdayColumn + 26 - daysInLastMonth;
        if (columnMotion < -5) {
            columnMotion = -5;
        }
        break;
      default:
        break;  // caught elsewhere
    }
    //printf("column motion for underlay type %d is %d\n",
    //       (int)coverType, columnMotion);
    return columnMotion * (cellWidth + spacingWidth);
}

-(int)mainTimeWeekOfYearNumber {
    return [mainTime weekOfYearNumberUsingEnv:mainEnv
                                   useISO8601:ECUseISO8601WeekNumber
                                 weekStartDay:ECCalendarWeekdayStart];
}

-(int)weekOfYearNumberForEnv:(int)envNumber {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    return [mainTime weekOfYearNumberUsingEnv:environments[envNumber]
                                   useISO8601:ECUseISO8601WeekNumber
                                 weekStartDay:ECCalendarWeekdayStart];
}

-(void)setMainTimeToFrozenDateInterval:(NSTimeInterval)dateInterval {
    [mainTime setToFrozenDateInterval:dateInterval];
}

-(void)advanceMainTimeUsingSelector:(SEL)watchTimeSelector withDoubleParameter:(double)parameter {
    WatchAdvanceDoubleArgSelectorFn fn = (WatchAdvanceDoubleArgSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    (*fn)(mainTime, watchTimeSelector, parameter);
}

-(void)advanceMainTimeUsingEnvSelector:(SEL)watchTimeSelector {
    WatchAdvanceEnvOnlySelectorFn fn = (WatchAdvanceEnvOnlySelectorFn)[mainTime methodForSelector:watchTimeSelector];
    (*fn)(mainTime, watchTimeSelector, mainEnv);
}

-(void)advanceTimeForEnvUsingEnvSelector:(SEL)watchTimeSelector forEnv:(int)envNumber {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    WatchAdvanceEnvOnlySelectorFn fn = (WatchAdvanceEnvOnlySelectorFn)[mainTime methodForSelector:watchTimeSelector];
    (*fn)(mainTime, watchTimeSelector, environments[envNumber]);
}

-(void)advanceMainTimeUsingEnvSelector:(SEL)watchTimeSelector withIntParameter:(int)parameter {
    WatchAdvanceEnvIntSelectorFn fn = (WatchAdvanceEnvIntSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    (*fn)(mainTime, watchTimeSelector, parameter, mainEnv);
}

-(void)advanceTimeForEnvUsingEnvSelector:(SEL)watchTimeSelector withDoubleParameter:(double)parameter forEnv:(int)envNumber {
    assert(envNumber >= 0 && envNumber < numEnvironments);
    WatchAdvanceEnvDoubleSelectorFn fn = (WatchAdvanceEnvDoubleSelectorFn)[mainTime methodForSelector:watchTimeSelector];
    (*fn)(mainTime, watchTimeSelector, parameter, environments[envNumber]);
}

- (void)displayListMemoryUsage:(size_t *)displayListSize numDisplayLists:(int *)numDisplayLists numDisplayListParts:(int *)numDisplayListParts {
    *displayListSize = 0;
    *numDisplayLists = 0;
    *numDisplayListParts = 0;
    size_t displayListClassSize = class_getInstanceSize([ECGLDisplayList class]);
    for (ECWatchModeEnum modeNum = 0; modeNum < ECNumWatchDrawModes; modeNum++) {
	for (ECGLDisplayList *displayList in displayListsByMode[modeNum]) {
	    (*numDisplayLists)++;
	    int numParts = [displayList partCount];
	    *numDisplayListParts += numParts;
	    int arraySizeInBytes = 3 * 2 * 2 * numParts * sizeof(ECDLCoordType);
	    *displayListSize += arraySizeInBytes * 2 + displayListClassSize;
	}
    }
}

- (void)printDisplayListForModeNum:(ECWatchModeEnum)modeNum {
#ifndef NDEBUG
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    for (ECGLDisplayList *displayList in displayListsByMode[modeNum]) {
	[displayList print];
    }
#endif
}

- (void)printDisplayListForCurrentMode {
    printf("current mode is %d\n", currentModeNum);
#ifndef NDEBUG
    [self printDisplayListForModeNum:currentModeNum];
#endif
}

@end

