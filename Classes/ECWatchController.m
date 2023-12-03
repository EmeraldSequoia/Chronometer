//
//  ECWatchController.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/15/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ChronometerAppDelegate.h"
#import "EBVirtualMachine.h"
#import "ECWatchController.h"
#import "ECPartController.h"
#import "ECWatchEnvironment.h"
#import "ECWatchTime.h"
#import "ECWatch.h"
#import "AudioFX.h"
#import "Constants.h"
#import "ECLocationManager.h"
#import "ECDemo.h"
#import "ECControllerView.h"
#import "ECWatchDefinitionManager.h"
#import "ECWatchArchive.h"
#import "ECErrorReporter.h"
#import "ECGLAtlasLayout.h"
#import "ECQView.h"
#import "ECWatchPart.h"
#import "ECGlobals.h"

@implementation ECWatchController

@synthesize watch, audibleTicks, audibleSWTicks, audibleChimes, reallyLoaded, name, faceWidth, statusBarLocation;

//// initialization methods

static bool doingShadow = false;

- (ECWatchController *)init {
    assert(false);
    self = [self initWithName:nil];
    return self;
}

- (ECWatchController *)initWithName:(NSString *)aName {
    if (self = [super init]) {
	// setup members
	subControllers = [[NSMutableArray alloc] initWithCapacity:ECDefaultNumParts+ECDefaultNumChimes+ECDefaultNumButtons];
	
	// create the top level model object for this watch
	watch = [[ECWatch alloc] initWithName:aName VMOwner:self];
	// but it hasn't been initialized by ECWatchDefinitionManager, yet
	
	// set sound toggles from info saved by Settings.app
	audibleTicks = false; // [[NSUserDefaults standardUserDefaults] boolForKey:@"Ticks"];
	audibleSWTicks = false; // [[NSUserDefaults standardUserDefaults] boolForKey:@"SWTicks"];
	audibleChimes = false; //[[NSUserDefaults standardUserDefaults] boolForKey:@"Chimes"];
	// these used to be separate for each watch with code like this:
	// defaultObject = [[NSUserDefaults standardUserDefaults] objectForKey:[aName stringByAppendingString:@"-SWTicks"]];
	// if (defaultObject != nil) {
	//    audibleSWTicks = [defaultObject boolValue];
	// } else {
	//     audibleSWTicks = [[NSUserDefaults standardUserDefaults] boolForKey:@"SWTicks"];
	// }
	name = [aName retain];
	reallyLoaded = false;
    }
    return self;    
}

- (int)addSubController: (ECPartController *)sub {
    if (doingShadow) {
	return 0;
    }
    assert(subControllers);
    
    [subControllers addObject:sub];
    
    return 0;
}

- (void)setExpectedFrontAtlasSize:(CGSize)frontAtlasSize
		    backAtlasSize:(CGSize)backAtlasSize
		   nightAtlasSize:(CGSize)nightAtlasSize {
    expectedFrontAtlasSize = frontAtlasSize;
    expectedBackAtlasSize = backAtlasSize;
    expectedNightAtlasSize = nightAtlasSize;
}

//// hacks to avoid having errors in Henry when evaluating init expressions meant for Chronometer
- (void)setAlarmToTarget {
}

- (void)setAlarmToInterval {
}

- (void)makeShadowImage:(NSString *)shadowImagePath fromMainImage:(NSString *)imagePath forZ:(double)z andThickness:(double)thickness {
    NSString *script = [@"$scripts" stringByAppendingPathComponent:@"makeOneShadow.pl"];
    NSString *command = [NSString stringWithFormat:@"\"%@\" \"%@\" \"%@\" %.2f %.2f", script, imagePath, shadowImagePath, z, thickness];
    //printf("%s\n", [command UTF8String]);
    // Doesn't work with XCode 5/iOS 7 simulator:  system([command UTF8String]);
    sendCommandToCommandServer([command UTF8String]);
}

static NSFileManager *fileMgr = nil;

- (void)submitSipsJobForFiles:(NSSet *)sipsSet watchTempPngDirectory:(NSString *)watchTempPngDirectory {
    NSString *script = [@"$scripts" stringByAppendingPathComponent:@"makeOneWatchZoomSet.pl"];
    NSString *listFile = [watchTempPngDirectory stringByAppendingPathComponent:@"sipsJob.txt"];
    NSError *error;
    [fileMgr removeItemAtPath:listFile error:&error];
    FILE *fp = fopen([listFile UTF8String], "w");
    if (!fp) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error creating sips job control list file %@: %s", listFile, strerror(errno)]];
    }
    for (NSString *fileName in sipsSet) {
	fprintf(fp, "%s\n", [fileName UTF8String]);
    }
    fclose(fp);
    NSString *command = [NSString stringWithFormat:@"\"%@\" \"%@\"", script, listFile];
    //printf("%s\n", [command UTF8String]);
    // Doesn't work with XCode 5/iOS 7 simulator:  system([command UTF8String]);
    sendCommandToCommandServer([command UTF8String]);
}

// This routine should match ECGLWatch::initFromArchiveAtPath: in the way it writes data to the archive
- (void)archiveAllForDeviceWidth:(int)deviceWidth {
    assert(deviceWidth >= 0);
    NSString *widthSuffix = deviceWidth == 0 ? @"" : [NSString stringWithFormat:@"-W%d", deviceWidth];
    NSMutableSet *sipsSet = [[NSMutableSet alloc] initWithCapacity:[subControllers count] * 2];
    fileMgr = [NSFileManager defaultManager];
    NSString *watchName = [watch name];
    NSString *watchArchiveDirectory = [ECDocumentArchiveDirectory stringByAppendingPathComponent:watchName];
    NSString *watchTempPngDirectory = [ECTempPngDirectory stringByAppendingPathComponent:watchName];
#ifndef NDEBUG
    assert(watchArchiveDirectory);
    BOOL isD;
    assert([fileMgr fileExistsAtPath:ECDocumentArchiveDirectory isDirectory:&isD]);
    assert(isD);
#endif
    BOOL isDirectory;
    if ([fileMgr fileExistsAtPath:watchArchiveDirectory isDirectory:&isDirectory]) {
	if (!isDirectory) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Watch archive exists but is not a directory: '%@'", watchArchiveDirectory]];
	    [sipsSet release];
	    return;
	}
    } else {
	NSError *error;
	if (![fileMgr createDirectoryAtPath:watchArchiveDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Trouble creating watch archive directory '%@': %@", watchArchiveDirectory, [error localizedDescription]]];
	    [sipsSet release];
	    return;
	}
    }
    if ([fileMgr fileExistsAtPath:watchTempPngDirectory isDirectory:&isDirectory]) {
	if (!isDirectory) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Watch temp png directory exists but is not a directory: '%@'", watchTempPngDirectory]];
	    [sipsSet release];
	    return;
	}
    } else {
	NSError *error;
	if (![fileMgr createDirectoryAtPath:watchTempPngDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Trouble creating watch archive directory '%@': %@", watchTempPngDirectory, [error localizedDescription]]];
	    [sipsSet release];
	    return;
	}
    }
    EBVirtualMachine *vm = [watch vm];
    [vm writeVariableNamesToFile:[watchArchiveDirectory stringByAppendingPathComponent:@"variable-names.txt"]];
    NSString *rawArchivePath = [watchTempPngDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"archive%@.dat", widthSuffix]];
    ECWatchArchive *watchArchive = [[ECWatchArchive alloc] initForWritingIntoPath:rawArchivePath];
    [watchArchive writeInteger:faceWidth];
    [watchArchive writeInteger:[watch numEnvironments]];
    [watchArchive writeInteger:[watch maxSeparateLoc]];
    [watchArchive writeDouble:[watch landscapeZoomFactor]];
    [watchArchive writeInteger:[watch beatsPerSecond]];
    [watchArchive writeInteger:statusBarLocation];
    int viewCount = 0;
    int noViewButtonCount = 0;
    NSMutableSet *texturePartNames = [NSMutableSet setWithCapacity:[subControllers count]];
    for (ECPartController *ctlr in subControllers) {
	if ([ctlr ecView]) {
	    viewCount++;
	    ECWatchPart *mainHand = [ctlr model];
	    NSString *partName = [mainHand name];
	    if (![texturePartNames containsObject:partName]) {
		[texturePartNames addObject:partName];
		if ([mainHand z] != 0) {
		    [texturePartNames addObject:[partName stringByAppendingString:@"-shadow"]];
		    viewCount++;
		}
	    }
	} else if ([[ctlr model] actionInstructionStream]) {
	    noViewButtonCount++;
	}
    }
    [watchArchive writeInteger:[texturePartNames count]]; // number of textures
    NSMutableDictionary *textureSlotsByPartName = [NSMutableDictionary dictionaryWithCapacity:[subControllers count]];
    int textureSlot = 0;
    for (ECPartController *ctlr in subControllers) {
	ECWatchPart *mainHand = [ctlr model];
	NSString *partName = [mainHand name];
	if ([textureSlotsByPartName objectForKey:partName]) {
	    continue;
	}
	ECQView *ecView = [ctlr ecView];
	if (ecView) {
	    int padding = ECTexturePartPadding;
	    if ([partName caseInsensitiveCompare:@"dim"] == NSOrderedSame ||
		[partName caseInsensitiveCompare:@"red banner"] == NSOrderedSame) { // HACK
		padding = 0;
	    }
	    CGRect bounds = [ecView boundsOnScreen];

	    int ts = ([mainHand z] == 0) ? textureSlot : textureSlot + 1;
	    [textureSlotsByPartName setObject:[NSNumber numberWithInt:ts] forKey:partName];
	    partName = [partName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	    NSString *texturePath = [[[watchTempPngDirectory stringByAppendingPathComponent:partName] stringByAppendingString:widthSuffix] stringByAppendingString:@".png"];

	    if ([mainHand z] != 0) {
		NSString *shadowImagePath = [texturePath stringByReplacingOccurrencesOfString:@".png" withString:@"-shadow.png"];
		[watchArchive writeString:shadowImagePath];
		for (int j = 0; j < ECNumVisualZoomFactors; j++) {
		    [watchArchive writeInteger:0];
		    [watchArchive writeInteger:0];
		}
		[textureSlotsByPartName setObject:[NSNumber numberWithInt:textureSlot] forKey:[partName stringByAppendingString:@"-shadow"]];
		textureSlot++;
	    }
	    [watchArchive writeString:texturePath];
	    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
		[watchArchive writeInteger:ceil(bounds.size.width + padding * 2)];
		[watchArchive writeInteger:ceil(bounds.size.height + padding * 2)];
	    }
	    textureSlot++;
	}
    }
    [watchArchive writeInteger:[vm numVariables]];
    NSArray *inits = [watch inits];
    [watchArchive writeInteger:[inits count]];  // number of inits
    for (EBVMInstructionStream *init in inits) {
	[watchArchive writeInstructionStream:init usingVirtualMachine:vm];
    }
//    [watchArchive writeInteger:[subControllers count]];  // number of parts (happens to be same as number of textures here)
    [watchArchive writeInteger:viewCount];
    NSMutableSet *savedImages = [NSMutableSet setWithCapacity:[textureSlotsByPartName count]];
    int partIndex = 0;
    bool isBackgroundWatch = [[watch name] caseInsensitiveCompare:@"Background"] == NSOrderedSame || [[watch name] caseInsensitiveCompare:@"BackgroundHD"] == NSOrderedSame;
    NSString *partNamesFileName = [watchTempPngDirectory stringByAppendingPathComponent:@"parts.dat"];
    FILE *partNamesFile = fopen([partNamesFileName UTF8String], "w");
    for (ECPartController *ctlr in subControllers) {
	ECQView *mainView = [ctlr ecView];
        // printf("----\n");
        // printf("mainView boundsInView   %g %g %g %g\n", mainView.boundsInView.origin.x, mainView.boundsInView.origin.y, mainView.boundsInView.size.width, mainView.boundsInView.size.height);
        // printf("mainView boundsOnScreen %g %g %g %g\n", mainView.boundsOnScreen.origin.x, mainView.boundsOnScreen.origin.y, mainView.boundsOnScreen.size.width, mainView.boundsOnScreen.size.height);
	if (mainView) {
	    ECWatchPart *mainHand = [ctlr model];
	    [mainHand setPartIndex:partIndex++];
	    NSString *partName = [mainHand name];
	    [watchArchive logName:partName];
	    int textureSlotN = [[textureSlotsByPartName objectForKey:partName] intValue];
	    bool needToSaveImage = ![savedImages containsObject:partName] && ![mainView skipMakingPNG];
	    if (needToSaveImage) {
		[savedImages addObject:partName];
	    }
	    partName = [partName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	    NSString *imagePath = [[[watchTempPngDirectory stringByAppendingPathComponent:partName] stringByAppendingString:widthSuffix] stringByAppendingString:@".png"];
	    int masterIndex;
	    ECWatchPart *masterPart = [mainHand masterPart];
	    if (masterPart) {
		masterIndex = [masterPart partIndex];
	    } else {
		masterIndex = -1;
	    }
	    double mainHandZ = [mainHand z];
            NSString *templateImagePathForShadow = imagePath;
	    if (needToSaveImage) {
		[mainView archiveImageToPath:imagePath watchFaceWidthInXML:faceWidth forDeviceWidth:deviceWidth];
                if (deviceWidth != 0) {
                    templateImagePathForShadow = [imagePath stringByReplacingOccurrencesOfString:@".png" withString:@"-shadow-template.png"]; 
                    [mainView archiveImageToPath:templateImagePathForShadow watchFaceWidthInXML:0 forDeviceWidth:0];
                }
		[sipsSet addObject:imagePath];
	    }
	    double mainHandThickness = [mainHand thickness];
	    if (mainHandZ != 0) {
		doingShadow = true;
		NSString *shadowPartName = [partName stringByAppendingString:@"-shadow"];
		int shadowTextureSlot = [[textureSlotsByPartName objectForKey:shadowPartName] intValue];
		assert(shadowTextureSlot == textureSlotN - 1);
		ECWatchHand *shadowHand = [[ECWatchHand alloc] initWithName:shadowPartName
								   forWatch:watch
								   modeMask:[mainHand modeMask]
								       kind:ECNotTimerZeroKind
							     updateInterval:[mainHand updateInterval]
						       updateIntervalOffset:[mainHand updateIntervalOffset]
								updateTimer:[mainHand updateTimer]
								 masterPart:[mainHand masterPart]
								angleStream:[mainHand angleInstructionStream]
							       actionStream:nil
									  z:0
								  thickness:3
							      xOffsetStream:[mainHand xOffsetInstructionStream]
							      yOffsetStream:[mainHand yOffsetInstructionStream]
							       offsetRadius:[mainHand offsetRadius]
							  offsetAngleStream:[mainHand offsetAngleInstructionStream]];
		[shadowHand setPartIndex:partIndex++];

		// Go make shadow image file here
		NSString *shadowRawImagePath = [imagePath stringByReplacingOccurrencesOfString:@".png" withString:@"-shadowRaw.png"];
                NSString *shadowFinalImagePath = [imagePath stringByReplacingOccurrencesOfString:@".png" withString:@"-shadow.png"];
		[self makeShadowImage:shadowRawImagePath fromMainImage:templateImagePathForShadow forZ:mainHandZ andThickness:mainHandThickness];
                // printf("shadow raw from\n  %s\nto\n  %s\n", [imagePath UTF8String], [shadowRawImagePath UTF8String]);
		CGSize shadowImageSize = [[UIImage imageWithContentsOfFile:shadowRawImagePath] size];
                // printf("shadowImageSize   %g %g\n", shadowImageSize.width, shadowImageSize.height);
		double extraWidth = shadowImageSize.width - [mainView boundsOnScreen].size.width;
		double extraHeight = shadowImageSize.height - [mainView boundsOnScreen].size.height;
                // printf("extraWidth, extraHeight   %g %g\n", extraWidth, extraHeight);
		// Calculate anchor for image view here
		CGPoint shadowAnchorOnScreen = [mainView anchorPointOnScreen];
		//shadowAnchorOnScreen.x += extraWidth / 2;
		//shadowAnchorOnScreen.y += extraHeight / 2;
		//		shadowAnchorOnScreen.x += mainHandZ / 5;
		//		shadowAnchorOnScreen.y += mainHandZ / 2.5;
		CGRect viewAnchor = [mainView convertFromScreenToView:CGRectMake(shadowAnchorOnScreen.x, shadowAnchorOnScreen.y, 0, 0)];
		CGRect viewBounds = [mainView boundsInView];
		UIImage *shadowImage = [UIImage imageWithContentsOfFile:shadowRawImagePath];
                if (!shadowImage) {
                    printf("No raw path for shadow image!  path is\n %s\n", [shadowRawImagePath UTF8String]);
                }
		assert(shadowImage);
		ECImageView *shadowView = [[ECImageView alloc]initWithImage:shadowImage
								    image2x:nil  // Let the shadow be low-res
								    image4x:nil  // Let the shadow be low-res
					      xAnchorOffsetFromScreenCenter:shadowAnchorOnScreen.x + mainHandZ / 4.3
					      yAnchorOffsetFromScreenCenter:shadowAnchorOnScreen.y - mainHandZ / 2.15
							 xAnchorInViewSpace:viewAnchor.origin.x - viewBounds.origin.x + extraWidth / 2
							 yAnchorInViewSpace:viewAnchor.origin.y - viewBounds.origin.y + extraHeight / 2
								     xScale:1
								     yScale:1
								  animSpeed:[mainView animSpeed]
								    animDir:[mainView animDir]
								   dragType:[mainView dragType]
							  dragAnimationType:[mainView dragAnimationType]];
                // printf("shadowView boundsInView   %g %g %g %g\n", shadowView.boundsInView.origin.x, shadowView.boundsInView.origin.y, shadowView.boundsInView.size.width, shadowView.boundsInView.size.height);
                // printf("shadowView boundsOnScreen %g %g %g %g\n", shadowView.boundsOnScreen.origin.x, shadowView.boundsOnScreen.origin.y, shadowView.boundsOnScreen.size.width, shadowView.boundsOnScreen.size.height);
		ECPartController *shadowCtlr = [[ECHandController alloc] initWithModel:shadowHand
										  view:shadowView
										master:self
										opaque:0
									      grabPrio:-2
									       envSlot:[ctlr envSlot]
									   specialness:ECPartNotSpecial
								      specialParameter:0
                                                                        cornerRelative:false];
		[shadowHand release];
		if (needToSaveImage) {
		    [shadowView archiveImageToPath:shadowFinalImagePath watchFaceWidthInXML:faceWidth forDeviceWidth:deviceWidth];
		    [sipsSet addObject:shadowFinalImagePath];
		}
		[shadowCtlr archivePartToImagePath:shadowFinalImagePath
			    usingTextureSlotNumber:shadowTextureSlot
				   needToSaveImage:true
				       masterIndex:masterIndex
				 usingWatchArchive:watchArchive
			       usingVirtualMachine:vm];
		fprintf(partNamesFile, "%s", [shadowPartName UTF8String]);  // For use by HIRES_DUMP, among others
		char c = '\0';
		fwrite(&c, 1, 1, partNamesFile);
		[shadowCtlr release];
		[shadowView release];
		doingShadow = false;
	    }
	    [ctlr archivePartToImagePath:imagePath
		  usingTextureSlotNumber:textureSlotN
			 needToSaveImage:needToSaveImage
			     masterIndex:masterIndex
		       usingWatchArchive:watchArchive
		     usingVirtualMachine:vm];
	    fprintf(partNamesFile, "%s", [partName UTF8String]);  // For use by HIRES_DUMP, among others
	    char c = '\0';
	    fwrite(&c, 1, 1, partNamesFile);
	}
        // printf("----\n");
    }
    fclose(partNamesFile);
    [watchArchive writeInteger:noViewButtonCount];
    for (ECPartController *ctlr in subControllers) {
	if (![ctlr ecView] && [[ctlr model] actionInstructionStream]) {
	    [watchArchive logName:[[ctlr model] name]];
	    [ctlr archivePartToImagePath:nil
		  usingTextureSlotNumber:-1
			 needToSaveImage:false
			     masterIndex:-1
		       usingWatchArchive:watchArchive
		     usingVirtualMachine:vm];
	}
    }
    [watchArchive finishWriting];
    [watchArchive release];

#if !EC_HENRY_ANDROID
    [self submitSipsJobForFiles:sipsSet watchTempPngDirectory:watchTempPngDirectory];
#endif

    [sipsSet release];

    NSString *mergedArchivePath = [watchArchiveDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"archive%@.dat", widthSuffix]];
    [ECGLAtlasLayout mergeWatchAtlasesFromArchive:rawArchivePath
					toArchive:mergedArchivePath
			      usingVirtualMachine:vm
					watchName:[watch name]
			       inArchiveDirectory:watchArchiveDirectory
			     usingPngsInDirectory:watchTempPngDirectory
				isBackgroundWatch:isBackgroundWatch
                                   forDeviceWidth:deviceWidth
                                deviceWidthSuffix:widthSuffix
			  expectingFrontAtlasSize:expectedFrontAtlasSize
			   expectingBackAtlasSize:expectedBackAtlasSize
			  expectingNightAtlasSize:expectedNightAtlasSize];
}

- (void)archiveAll {
#if EC_HENRY_ANDROID
    // For Android, and really for any watch-based platform which needs only one zoom, we can and do
    // optimize for each device hardware width.  To allow us to deploy only the assets we need on the
    // device, we create a complete archive with a single atlas for each watch width.  This is
    // different from iOS, where we create a single archive with an atlas for each zoom level shown
    // on the device.
    for (int i = 0; i < numAndroidWatchOutputWidths; i++) {
        [self archiveAllForDeviceWidth:androidWatchOutputWidths[i]];
    }
#else
    // For iOS, we generate powers-of-two archives for all device widths in a single atlas, by
    // specifying 0 for deviceWidth.
    [self archiveAllForDeviceWidth:0];
#endif
}

- (void)reallyLoad {
    ECWatchDefinitionManager *defnMgr = [[ECWatchDefinitionManager alloc] init];
    [defnMgr loadWatchWithName:watch.name intoController:self errorReporter:[ECErrorReporter theErrorReporter]];
    [defnMgr release];
    [self archiveAll];
}

//// termination methods

- (void)dealloc {				// apparently, we never get here except from removeCurrentWatch, not during app termination
    [subControllers removeAllObjects];
    [subControllers release];
    [watch release];
    [name release];
    [super dealloc];
}

@end
