//
//  ChronometerAppDelegate.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/16/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "Constants.h"
#import "ChronometerAppDelegate.h"
#import "EBVirtualMachine.h"
#import "ECWatch.h"
#import "ECWatchTime.h"
#import "ECWatchEnvironment.h"
#import "ECWatchPart.h"
#import "ECPartController.h"
#import "ECWatchController.h"
#import "ECErrorReporter.h"
#import "ECLocationManager.h"
#import "ECGLTexture.h"
#import "ECAstronomy.h"
#import "ECAddressKey.h"
#import "ECGLWatch.h"
#import "ECGLTexture.h"
#import "ECGLView.h"
#import "ECGLPart.h"
#import "ECGLWatchLoader.h"
#import "ECGLPartFinder.h"
#import "ECGlobals.h"
#import "ECRotatableNavController.h"
#import "ECHelpController.h"
#import "ECWatchSelector.h"
#import "ECFactoryUI.h"
#import "ECOptions.h"
#import "ECBackgroundData.h"
#import "ECTS.h"
#import "ECAudio.h"
#import "ECAppLog.h"
#import "ECGeoNames.h"  // For test
#import "ECOptionsLoc.h"
#define ECTRACE
#import "ECTrace.h"
#import "ECAstronomyCache.h"
#import "ECGLViewController.h"
#import "ESCalendar.h"
#import "TSTime.h"
#import "ECTopLevelViewController.h"
#import "ECTopLevelView.h"
#ifdef EC_STORE
#import "ECStore.h"
#import "ECStoreViewController.h"
#endif

#import "objc/runtime.h" // Selectors on an object, class_getInstanceSize

#ifndef NDEBUG
#import "ECOptionsTZRoot.h"
#endif

#include <sys/types.h>
#include <sys/sysctl.h>
#include <unistd.h>  // For usleep

#import <mach/mach.h>   // For RAM size investigation
#import <mach/mach_host.h>

#import <UserNotifications/UserNotifications.h>

#ifdef EC_HENRY
#import "ECWatchDefinitionManager.h"
#endif

// forward decl
static void requestPerformanceTest(void);
static void saveWatchDefaults(void);

@class ECGLStaticButton;

@interface ChronometerAppDelegateObserverDescriptor : NSObject {
    id   observer;
    SEL  significantTimeChangeSelector;
}

@property (nonatomic, retain) id observer;
@property (nonatomic) SEL significantTimeChangeSelector;

@end

@implementation ChronometerAppDelegateObserverDescriptor

@synthesize observer;
@synthesize significantTimeChangeSelector;

@end

static int currentWatchIndex = -1;
static int lastWatchIndex = -1;
static int adjacentWatchIndex = -1;		 // index of watch also visible onscreen as a result of a touch move
static bool adjacentIsUp = false;

static bool displayLocked = false;		 // Isn't really displayLocked (yet), just not active
static bool factoryWorkNeeded = false;		 // ECFactoryUI changed something
static bool zoomingIn = false;			 // True iff we're zooming into the 2d grid (or is that zooming out)
static bool initializationDone = false;

static NSMutableArray *watches;			 // holds the ECWatchController for each loaded watch

static NSMutableArray      *glWatches;           // holds the array of watches, ECGLWatch* in each slot
static NSMutableArray      *availableWatches;    // ditto, but includes inactive watches
static int                 glWatchCount;         // fast access to the number of watches
static NSMutableSet        *glDrawWatches;       // those watches which we should draw in the draw loop
static ECGLWatch           *backgroundWatch;
static ECGLPartFinder      *partFinder;
static ECGLPart            *draggingPart;
static NSTimer             *repeatingPartTimer;
static ECGLPartBase        *repeatingPart;
static int                 repeatCount;
static NSTimeInterval      animationOverrideInterval;

static bool                isFirstGenerationHardware;  // Meaning: is slow

#ifdef ECDIMMER
static UIView              *dimmerCover;        // the view that darkens everything
static UILabel		   *dimmerLabel;	// shows dimmer level
#endif
static UIView              *osStatusBGView;     // the black background which appears behind the status bar (and on top of the GL view) when Help is up
static UILabel		   *warpLabel;		// the EC Status line
static UILabel		   *timeSyncLabel;	// label for the time sync status indicator
static UILabel		   *locSyncLabel;	// label for the location manager status indicator
static UILabel		   *alarmStateLabel;	// label for the alarm status indicator
static NSTimer		   *suTimer;		// clears the status line after a few seconds
static bool		   helping = false;	// showing a help screen
static bool		   switching = false;	// showing the switcher
static bool		   optioning = false;	// showing the options screen
static bool		   dataing = false;	// showing one of the data screens
static bool		   switcherReady = false; // startup animation done; ready for input
static bool		   warningMessage = false;// put up an ECStatusMessage during intialization

static bool                displayingGrid = false;
static bool                animatingGrid = false; // When this is true, we limit user input and we still have other watches' textures loaded
static int                 currentZ2 = 0;
//static int                 currentZ2 = -1;
//static bool                currentZoomFactor = 1;
//static bool                gridLength = 1;      // n where there is a n x n grid of watches displayed

static UINavigationController *helpNavigationController = nil;
static ECHelpController *helpController = nil;

static ECTopLevelViewController *theRootViewController = nil;
static UIWindow *theWindow;
static ECTopLevelView *theTopLevelView;
static CGRect theWindowSafeBounds;  // NOTE: origin at top left, unlike gl safe bounds.

//static UIPageControl *pager;

#ifdef EC_HENRY
static ECWatchDefinitionManager *watchDefinitionManager = nil;
static NSArray *approvalsArray = nil;
static NSArray *enabledArray = nil;
#endif

static NSMutableDictionary *observers = nil;
static NSMutableDictionary *reallySignificantObservers = nil;

// for saveState/writeState
static UIApplication *theApplication = nil;
static UIImage       *applicationImage = nil;
static NSDate        *dateReflectingCapturedImage = nil;

static ECGLView      *glView = nil;

// We keep an array, sorted by "importance" (meaning how quickly we are likely to switch to that mode)
// This array changes every time we switch watches or we switch modes
typedef struct WatchModeDescriptor {
    ECGLWatch *watch;
    ECWatchModeEnum modeNum;
    int       z2;
} WatchModeDescriptor;
static WatchModeDescriptor **watchModesByImportance = NULL;
static WatchModeDescriptor *watchModeStorage = NULL;
#ifndef NDEBUG
static const char **watchModeSortReasons = NULL;
#endif
static NSLock *watchModeDescriptorLock = nil;
static int numWatchModeDescriptors = 0;
static int numWatchModeUsedDescriptors = 0;
static double iPhoneScaleFactor = 0; // How much bigger should watches on this phone be
static int maxZoomIndex = 0;

// Returns a rect with origin at lower left.
// Note that this function uses the bounds of glView, so is not a direct representation of the
// device, except insofar as the view uses the device bounds when it is constructed.
static CGRect getApplicationBoundsPoints() {
    assert(theWindow != nil);
    CGSize windowSize = theWindow.bounds.size;
    if (glView) {
        CGSize glViewSize = glView.bounds.size;

        if (@available(iOS 11.0, *)) {
            UIEdgeInsets edgeInsets = glView.safeAreaInsets;
            return CGRectMake(edgeInsets.left, edgeInsets.bottom, 
                              glViewSize.width - edgeInsets.left - edgeInsets.right,
                              glViewSize.height - edgeInsets.top - edgeInsets.bottom);
        } else {
            return CGRectMake(0, 0, glViewSize.width, glViewSize.height);
        }
    }
    assert(false);
    return CGRectMake(0, 0, windowSize.width, windowSize.height);
}

// Note that this function uses the bounds of glView, so is not a direct representation of the
// device, except insofar as the view uses the device bounds when it is constructed.
static CGSize getApplicationSizePoints() {
    assert(theWindow != nil);
    CGSize windowSize = theWindow.bounds.size;
    if (glView) {
        CGSize glViewSize = glView.bounds.size;
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets edgeInsets = glView.safeAreaInsets;
            return CGSizeMake(glViewSize.width - edgeInsets.left - edgeInsets.right,
                              glViewSize.height - edgeInsets.top - edgeInsets.bottom);
        } else {
            return glViewSize;
        }
    }
    return windowSize;
}

// Note that this function uses the bounds of glView, so is not a direct representation of the
// device, except insofar as the view uses the device bounds when it is constructed.
static CGSize getApplicationViewSizePoints() {
    assert(theWindow != nil);
    CGSize windowSize = theWindow.bounds.size;
    assert(glView);
    if (glView) {
        return glView.bounds.size;
    }
    return windowSize;
}

static CGSize getApplicationWindowSizePoints() {
    assert(theWindow != nil);
    return theWindow.bounds.size;
}

// The amount by which we scale up archived watch coordinates, which are based on a 320-pixel
// screen, in order to match the current device bounds.
static void getIphoneScaleFactor() {
    assert(glView != nil);
    CGSize screenBounds = getApplicationSizePoints();
    assert(screenBounds.width > 0);
    printf("screenBounds %.1f %.1f\n", screenBounds.width, screenBounds.height);
    double scaleFactorWidth = screenBounds.width / 320;
    double scaleFactorHeight = screenBounds.height / 480;
    if (scaleFactorWidth > scaleFactorHeight) {
        iPhoneScaleFactor = scaleFactorHeight;  // Use smaller factor
    } else {
        iPhoneScaleFactor = scaleFactorWidth;
    }
    printf("iPhoneScaleFactor %.4f  (w %.4f h %.4f)\n", iPhoneScaleFactor, scaleFactorWidth, scaleFactorHeight);
}

// Note that this function uses the bounds of glView, so is not a direct representation of the
// device, except insofar as the view uses the device bounds when it is constructed.
static CGSize getApplicationSizeWatchCoordinates() {
    assert(iPhoneScaleFactor != 0);
    CGSize appSize = getApplicationSizePoints();
    return CGSizeMake(appSize.width / iPhoneScaleFactor, appSize.height / iPhoneScaleFactor);
}

static CGRect getApplicationBoundsWatchCoordinates() {
    assert(iPhoneScaleFactor != 0);
    CGRect appBounds = getApplicationBoundsPoints();
    return CGRectMake(appBounds.origin.x / iPhoneScaleFactor, appBounds.origin.y / iPhoneScaleFactor, 
                      appBounds.size.width / iPhoneScaleFactor, appBounds.size.height / iPhoneScaleFactor);
}

static ssize_t realMemoryAvailableOnDevice() {
    static ssize_t cachedValue = 0;
    if (cachedValue == 0) {
        cachedValue = (ssize_t) [NSProcessInfo processInfo].physicalMemory;

        printf("total:    %15.1f GB\n", cachedValue / (1024.0 * 1024 * 1024));

        assert(cachedValue != 0);
    }
    return cachedValue;
}

static void printBounds() {
    printf("**** BOUNDS ****\n");
    CGSize sz = [[UIScreen mainScreen] bounds].size;
    printf("Screen size from OS: %d x %d\n", (int)round(sz.width), (int)round(sz.height));
    sz = theWindow.bounds.size;
    printf("Window size: %d x %d\n", (int)round(sz.width), (int)round(sz.height));
    sz = theTopLevelView.bounds.size;
    printf("Top-level view size: %d x %d\n", (int)round(sz.width), (int)round(sz.height));
    sz = glView.bounds.size;
    printf("GL view size: %d x %d\n", (int)round(sz.width), (int)round(sz.height));
    printf("**** BOUNDS ****\n");
}


// The max zoom index is the largest atlas size we will actually use, regardless of what is shipped
// in the app.  The number is derived from two components:  The physical size of the memory on the
// device, and the number of pixels (it must be both safe and useful).
static int getMaxZoomIndex() {
    int realMemoryGB = (int)(realMemoryAvailableOnDevice() / 1024 / 1024 / 1024);
    printf("realMemoryGB %d\n", realMemoryGB);

    CGSize nativeScreenSize = [UIScreen mainScreen].nativeBounds.size;

    printBounds();
    
    if (realMemoryGB < 3) {  // The 6+ and 6S+ had 2GB memory and 1080px width; support at 2x only.
        return 1;  // 2x atlases (retina iPhone, non-retina iPad)
    }
    if (nativeScreenSize.width >= 1080) { // 6+, 7+, 8+ (but note memory removes 6+)
        return 2;  // 4x atlases
    } else {
        return 1;  // 2x atlases
    }
}

static bool getCurrentOrientationIsLandscape() {
    CGSize appSize = getApplicationViewSizePoints();
    return appSize.width > appSize.height;
}

static char gridRowsForWatchCountPortrait[25] = {
    1,  // 1 
    2,  // 2 
    2,  // 3 
    2,  // 4 
    3,  // 5 
    3,  // 6 
    3,  // 7 
    3,  // 8 
    3,  // 9 
    4,  // 10
    4,  // 11
    4,  // 12
    4,  // 13
    4,  // 14
    4,  // 15
    4,  // 16
    5,  // 17
    5,  // 18
    5,  // 19
    5,  // 20
    5,  // 21
    5,  // 22
    5,  // 23
    5,  // 24
    5   // 25
};

static char gridRowsForWatchCountLandscape[25] = {
    1,  // 1 
    1,  // 2 
    2,  // 3 
    2,  // 4 
    2,  // 5 
    2,  // 6 
    3,  // 7 
    3,  // 8 
    3,  // 9 
    3,  // 10
    3,  // 11
    3,  // 12
    4,  // 13
    4,  // 14
    4,  // 15
    4,  // 16
    4,  // 17
    4,  // 18
    4,  // 19
    4,  // 20
    5,  // 21
    5,  // 22
    5,  // 23
    5,  // 24
    5   // 25
};

static CGFloat iPadZoomsForLandscape[25] = {
    1,        // 1 
    0.8,      // 2 
    0.5,      // 3 
    0.4,      // 4 
    0.4,      // 5 
    0.4,      // 6 
    0.33,     // 7 
    0.33,     // 8 
    0.3,      // 9 
    0.3,      // 10
    0.3,      // 11
    0.3,      // 12
    0.25,     // 13
    0.25,     // 14
    0.25,     // 15
    0.25,     // 16
    0.25,     // 17
    0.25,     // 18
    0.25,     // 19
    0.25,     // 20
    0.2,      // 21
    0.2,      // 22
    0.2,      // 23
    0.2,      // 24
    0.2       // 25
};

#define EC_IPAD_FACTOR (1024.0 / 960.0)
static CGFloat iPadZoomsForPortrait[25] = {  // on iPhone, portrait is always 1/numRows
    EC_IPAD_FACTOR / 1.0,      // 1 
    EC_IPAD_FACTOR / 1.8,      // 2
    EC_IPAD_FACTOR / 1.8,      // 3 
    EC_IPAD_FACTOR / 1.8,      // 4 
    EC_IPAD_FACTOR / 2.4,      // 5 
    EC_IPAD_FACTOR / 2.8,      // 6 
    EC_IPAD_FACTOR / 2.8,      // 7 
    EC_IPAD_FACTOR / 2.8,      // 8 
    EC_IPAD_FACTOR / 3.0,      // 9 
    EC_IPAD_FACTOR / 3.3,      // 10
    EC_IPAD_FACTOR / 3.7,      // 11
    EC_IPAD_FACTOR / 3.7,      // 12
    EC_IPAD_FACTOR / 3.7,      // 13
    EC_IPAD_FACTOR / 3.7,      // 14
    EC_IPAD_FACTOR / 3.7,      // 15
    EC_IPAD_FACTOR / 3.7,      // 16
    EC_IPAD_FACTOR / 4.3,      // 17
    EC_IPAD_FACTOR / 4.3,      // 18
    EC_IPAD_FACTOR / 4.4,      // 19
    EC_IPAD_FACTOR / 4.4,      // 20
    EC_IPAD_FACTOR / 4.4,      // 21
    EC_IPAD_FACTOR / 4.4,      // 22
    EC_IPAD_FACTOR / 4.5,      // 23
    EC_IPAD_FACTOR / 4.5,      // 24
    EC_IPAD_FACTOR / 4.5,      // 25
};

static char colsForRowPortrait[25][5] = { 
    { 1, 0, 0, 0, 0},  // 1 
    { 1, 1, 0, 0, 0},  // 2 
    { 2, 1, 0, 0, 0},  // 3 
    { 2, 2, 0, 0, 0},  // 4 
    { 2, 1, 2, 0, 0},  // 5 
    { 2, 2, 2, 0, 0},  // 6 
    { 2, 3, 2, 0, 0},  // 7 
    { 3, 2, 3, 0, 0},  // 8 
    { 3, 3, 3, 0, 0},  // 9 
    { 3, 2, 3, 2, 0},  // 10
    { 3, 3, 3, 2, 0},  // 11
    { 3, 3, 3, 3, 0},  // 12
    { 4, 3, 3, 3, 0},  // 13
    { 4, 3, 4, 3, 0},  // 14
    { 4, 4, 4, 3, 0},  // 15
    { 4, 4, 4, 4, 0},  // 16
    { 3, 4, 3, 4, 3},  // 17
    { 4, 3, 4, 3, 4},  // 18
    { 4, 4, 3, 4, 4},  // 19
    { 4, 4, 4, 4, 4},  // 20
    { 4, 4, 5, 4, 4},  // 21
    { 4, 5, 4, 5, 4},  // 22
    { 5, 4, 5, 4, 5},  // 23
    { 5, 5, 4, 5, 5},  // 24
    { 5, 5, 5, 5, 5}   // 25
};

static char colsForRowLandscape[25][5] = { 
    { 1, 0, 0, 0, 0},  // 1 : 1 row  
    { 2, 0, 0, 0, 0},  // 2 : 1 row  
    { 2, 1, 0, 0, 0},  // 3 : 2 rows 
    { 2, 2, 0, 0, 0},  // 4 : 2 rows 
    { 3, 2, 0, 0, 0},  // 5 : 2 rows 
    { 3, 3, 0, 0, 0},  // 6 : 2 rows 
    { 2, 3, 2, 0, 0},  // 7 : 3 rows 
    { 3, 2, 3, 0, 0},  // 8 : 3 rows 
    { 3, 3, 3, 0, 0},  // 9 : 3 rows 
    { 3, 4, 3, 0, 0},  // 10 : 3 rows
    { 4, 3, 4, 0, 0},  // 11 : 3 rows
    { 4, 4, 4, 0, 0},  // 12 : 3 rows
    { 4, 3, 3, 3, 0},  // 13 : 4 rows
    { 4, 3, 4, 3, 0},  // 14 : 4 rows
    { 4, 4, 4, 3, 0},  // 15 : 4 rows
    { 4, 4, 4, 4, 0},  // 16 : 4 rows
    { 5, 4, 4, 4, 0},  // 17 : 4 rows
    { 5, 4, 5, 4, 0},  // 18 : 4 rows
    { 5, 5, 4, 5, 0},  // 19 : 4 rows
    { 5, 5, 5, 5, 0},  // 20 : 4 rows
    { 4, 4, 5, 4, 4},  // 21 : 5 rows
    { 4, 5, 4, 5, 4},  // 22 : 5 rows
    { 5, 4, 5, 4, 5},  // 23 : 5 rows
    { 5, 5, 4, 5, 5},  // 24 : 5 rows
    { 5, 5, 5, 5, 5}   // 25 : 5 rows
};

static int rowsForCount(int count) {
    return (getCurrentOrientationIsLandscape() ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[count - 1];
}

static double zoomForCount(int count) {
    if (!isIpad()) {
        return 1.0 / rowsForCount(count);
    } else if (getCurrentOrientationIsLandscape()) {
        return iPadZoomsForLandscape[count - 1];
    } else {
        return iPadZoomsForPortrait[count - 1];
    }
}

static double zoomForCountOtherRotation(int count) {
    if (!isIpad()) {
        return zoomForCount(count);
    } else if (getCurrentOrientationIsLandscape()) {
        return iPadZoomsForPortrait[count - 1];
    } else {
        return iPadZoomsForLandscape[count - 1];
    }
}

static double nogridZoom() {
    return zoomForCount(1);
}

static double nogridZoomForBG() {
    if (!isIpad()) {
        return 1.0 / rowsForCount(1);
    } else if (getCurrentOrientationIsLandscape()) {
        return 1.0;
    } else {
        return 1.0;
    }
}

static int z2ForZoom(double zoom) {
    double l2 = log2(1/zoom);
    assert(!isnan(l2));
    int z = (int)ceil(-l2);
    if (z > 0) {
        z = 0;  // Otherwise zoom = 1.1, in iPad portrait, 1-up grid, gets 1
    }
    return z;
}

static int z2ForCount(int watchCount) {
    return z2ForZoom(zoomForCount(watchCount));
}

static int z2ForCountOtherRotation(int watchCount) {
    return z2ForZoom(zoomForCountOtherRotation(watchCount));
}

// The "zoom tweak" is the amount we add to the log2 zoom index to reflect that
// "normal" is not 0 (zoom 0 atlases were for the original iPhone 320x480 full screen).  Specifically:
//   - original iPhone:    0
//   - iPhone 4 (retina):  1
//   - original iPad:      1
//   - iPad retina:        2
// Valid tweak values are 0, 1, 2.  Since we don't supply atlases at greater than
// 4x (z=2), tweak values greater than 2 are not helpful.
static int zoomTweakForScreenScale(CGFloat aScreenScale) {
    if (aScreenScale <= 1.0) {
	return 0;
    } else if (aScreenScale <= 2.0) {
	return 1;
    } else { // 2x on Retina iPad?
	return 2;  // tweaking more than 2 doesn't do any good anyway
    }
}

static void initWatchModeDescriptorArray() {
    int availableWatchCount = [availableWatches count];
    numWatchModeDescriptors = availableWatchCount * ECNumWatchDrawModes * ECNumLogicalVisualZoomFactors;
    watchModeDescriptorLock = [[NSLock alloc] init];
    watchModesByImportance = (WatchModeDescriptor **)malloc(sizeof(WatchModeDescriptor *) * numWatchModeDescriptors);
#ifndef NDEBUG
    watchModeSortReasons = (const char **)malloc(sizeof(const char *) * numWatchModeDescriptors);
#endif
    // Avoid a bunch of little calls to malloc -- just allocate space for objects in one chunk:
    watchModeStorage = (WatchModeDescriptor *)malloc(sizeof(WatchModeDescriptor) * numWatchModeDescriptors);
    WatchModeDescriptor *stgPtr = watchModeStorage;
    int availableIndex = 0;
    // printf("watchModeStorage allocating space for %d watches, %d faces\n", (int) numWatchModeDescriptors, (int) (sizeof(WatchModeDescriptor) * numWatchModeDescriptors));
    // int descriptorIndex = 0;
    for (ECGLWatch *watch in availableWatches) {
	// printf("initializing mode descriptor array for watch 0x%08x\n", (int)watch);
	assert([watch availableIndex] >= 0);
	assert([watch availableIndex] < [availableWatches count]);
	[watch setCanonicalIndex:[watch availableIndex]];
	for (int j = 0; j < ECNumWatchDrawModes; j++) {
	    for (int k = 0; k < ECNumLogicalVisualZoomFactors; k++) {
                // printf("... %3d %2d %d %d %s\n", descriptorIndex++, [watch availableIndex], j, k, [[watch name] UTF8String]);
		stgPtr->watch = watch;
		stgPtr->modeNum = (ECWatchModeEnum)j;
		stgPtr->z2 = k + ECZoomMinPower2;
		stgPtr++;
	    }
	}
	availableIndex++;
    }
}

#define WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, modeNum, z2) (((canonicalIndex) * ECNumWatchDrawModes + (modeNum)) * ECNumLogicalVisualZoomFactors + (z2-ECZoomMinPower2))

static int indexAtOffsetPosition(int offsetPosition) {
    if (offsetPosition > 0) {
	return (currentWatchIndex + offsetPosition) % glWatchCount;
    } else {
	return (currentWatchIndex + offsetPosition + glWatchCount) % glWatchCount;
    }
}

static CGFloat screenScale = 1.0;
static CGFloat nativeScale = 1.0;
static int screenScaleZoomTweak = 0;

static int tweakZoomForScreenScale(int zoom) {
    int maxZ = 2;
    if (zoom + screenScaleZoomTweak <= maxZ) {
	return zoom + screenScaleZoomTweak;
    } else {
        return maxZ;
    }
}

#ifndef NDEBUG
static void printWatchDescriptorArrayToSize(int numDescriptors) {
    int numDescriptorsCorrect = [availableWatches count] * ECNumWatchDrawModes * ECNumLogicalVisualZoomFactors;
    int numDescriptorsAlt;
    if (numDescriptorsCorrect > numDescriptors) {
        numDescriptorsAlt = numDescriptors;
        numDescriptors = numDescriptorsCorrect;
    } else if (numDescriptorsCorrect < numDescriptors) {
        numDescriptorsAlt = numDescriptorsCorrect;
    } else {  // They're equal
        numDescriptorsAlt = numDescriptors;
    }
    printf("Watch descriptor array with %d descriptors (printing %d), of which %d are used\n", numDescriptorsCorrect, numDescriptors, numWatchModeUsedDescriptors);
    for (int i = 0; i < numDescriptors; i++) {
        if (i == numWatchModeUsedDescriptors) {
            printf("====== entries past this point are unused ===\n");
        }
        if (i == numDescriptorsAlt) {
            printf("====== entries past this point are BEYOND THE END OF THE ALLOCATED ARRAY ===\n");
        }
	WatchModeDescriptor *descriptor = watchModesByImportance[i];
	if (descriptor) {
	    printf("%3d %s %2d %5s %2d (%2d) %10s %s\n",
		   i,
		   ([descriptor->watch isActive] ? "ACTIVE" : "------"),
		   [descriptor->watch availableIndex],
		   ECmodeNames[descriptor->modeNum],
		   descriptor->z2, tweakZoomForScreenScale(descriptor->z2),
		   [[descriptor->watch name] UTF8String],
                   watchModeSortReasons[i]);
	} else {
	    printf("nil descriptor\n");
	}

	fflush(stdout);
    }
    printf("\n");
}

static void printWatchDescriptorArray() {
    printWatchDescriptorArrayToSize([availableWatches count] * ECNumWatchDrawModes * ECNumLogicalVisualZoomFactors);
}
#endif

#ifndef NDEBUG
static void printWatchArrays()
{
    printf("=======\n");
    for (int i = 0; i < [availableWatches count]; i++) {
	ECGLWatch *watch = [availableWatches objectAtIndex:i];
	printf("%2d avail=%2d, active=%2d, %s %s\n",
	       i, [watch availableIndex], [watch activeIndex],
	       [watch isActive] ? "ACTIVE" : "------",
	       [[watch name] UTF8String]);
    }
    printf("==\n");
    for (int i = 0; i < [glWatches count]; i++) {
	ECGLWatch *watch = [glWatches objectAtIndex:i];
	printf("%2d active=%2d, avail=%2d, %s %s\n",
	       i, [watch activeIndex], [watch availableIndex],
	       [watch isActive] ? i == currentWatchIndex ? "ACT***" : "ACTIVE" : "------",
	       [[watch name] UTF8String]);
    }
    printf("=======\n");
}
#endif

static ECGLWatch *loadMeFirst = nil;  // Used to force a watch to be early in the sort order

static void sortWatchModeDescriptorArray(bool alreadyLocked) {
    assert([NSThread isMainThread]);
    if (!alreadyLocked) {
	[watchModeDescriptorLock lock];
    }
    WatchModeDescriptor **arrayPtr = watchModesByImportance;
#ifndef NDEBUG
    const char **reasonPtr = watchModeSortReasons;
#define REASON(str) *reasonPtr++ = str
#else
#define REASON(str) 
#endif

    ECGLWatch *watch;
    int canonicalIndex;

    int gridZ2 = z2ForCount(glWatchCount);
    int gridZ2OtherRotation = z2ForCountOtherRotation(glWatchCount);
    // printf("currentZ2 = %d, gridZ2 = %d, gridZ2OtherRotation = %d, count = %d\n", (int)currentZ2, (int)gridZ2, (int)gridZ2OtherRotation, (int)glWatchCount);

    // Used to load Terra when processing Terra-specific options that require a reload
    if (loadMeFirst) {
	*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX([loadMeFirst canonicalIndex], [loadMeFirst finalCurrentModeNum], -2)];  // Load smallest atlas to save time
        REASON("loadMeFirst at z2 (Terra?)");
    }

    // If we're looking at the grid, then load all of the grid watches first at currentZ2 at current mode
    if (currentZ2 == gridZ2) {
	for (watch in glWatches) {
	    if (watch != loadMeFirst || gridZ2 != -2) {
		canonicalIndex = [watch canonicalIndex];
		*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, [watch finalCurrentModeNum], currentZ2)];
                REASON("all grid watches at currentZ2 (== gridZ2) at current mode");
	    }
	}
        // Now the other rotation in case we rotate -- this should never happen on a phone
        if (gridZ2 != gridZ2OtherRotation) {
            for (watch in glWatches) {
                if (watch != loadMeFirst || gridZ2 != -2) {
                    canonicalIndex = [watch canonicalIndex];
                    *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, [watch finalCurrentModeNum], gridZ2OtherRotation)];
                    REASON("all grid watches at gridZ2OtherRotation at current mode");
                }
            }
        }
    }

    ECGLWatch *currentWatch = [glWatches objectAtIndex:currentWatchIndex];
    int currentCanonicalIndex = [currentWatch canonicalIndex];
    ECWatchModeEnum currentWatchMode = [currentWatch finalCurrentModeNum];

    // First: current watch index, current mode, z2==0
    //   weird logic:     if (gridZ2 != 0 || currentZ2 != 0) {
    //     gridZ2 == 0, currentZ2 == 0:  We did it above, skip
    //     gridZ2 == 0, currentZ2 != 0:  Not possible, we assert
    //     gridZ2 != 0, currentZ2 == 0:  Did nothing above, do 0 here
    //     gridZ2 != 0, currentZ2 != 0:  We (maybe) did some other z2 for grid above, we do 0 here anyway
    //   isn't this equivalent to gridZ2 != 0 ???
    if (gridZ2 != 0 && (currentZ2 != gridZ2 || gridZ2OtherRotation != 0)) {
        assert(currentZ2 <= 0);
        assert(!(gridZ2 == 0 && currentZ2 != 0));
	*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(currentCanonicalIndex, [currentWatch finalCurrentModeNum], 0)];
        REASON("current watch index, current mode, z2=0");
    }

    // Then current watch index at grid view (so we can re-use it after returning from grid, before z2=0 is loaded)
    if (currentZ2 == 0 && gridZ2 != 0 && !(currentWatch == loadMeFirst && gridZ2 == -2)) {
	*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(currentCanonicalIndex, [currentWatch finalCurrentModeNum], gridZ2)];
        REASON("current watch index at grid view, current mode, gridZ2");
    }

    // Then: immediately adjacent watches
    int indx;
    if (glWatchCount > 1 && gridZ2 != 0 && (currentZ2 != gridZ2 || gridZ2OtherRotation != 0)) {
	indx = indexAtOffsetPosition(1);
	watch = [glWatches objectAtIndex:indx];
        *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX([watch canonicalIndex], [watch finalCurrentModeNum], 0)];
        REASON("adjacent watch(1) at z2=0, current mode");
	if (glWatchCount > 2) {
	    indx = indexAtOffsetPosition(-1);
	    watch = [glWatches objectAtIndex:indx];
	    *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX([watch canonicalIndex], [watch finalCurrentModeNum], 0)];
            REASON("adjacent watch(2) at z2=0, current mode");
	}
    }

    // Then: other modes on current watch
    for (int i = 0; i < ECNumWatchDrawModes; i++) {
	if (i != currentWatchMode) {
	    *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(currentCanonicalIndex, i, 0)];
            REASON("other modes on current watch, z2=0");
	}
    }

    // Then the grid, if we're not looking at the grid
    if (currentZ2 == 0 && gridZ2 != 0 && (currentZ2 != gridZ2 || gridZ2OtherRotation != 0)) {
	for (watch in glWatches) {
	    if (watch != currentWatch && !(watch == loadMeFirst && gridZ2 == -2)) {
		canonicalIndex = [watch canonicalIndex];
                // printf("Adding index %d for canonical watch %d at mode %d and gridZ2 %d\n",
                //     (int)(arrayPtr - watchModesByImportance), canonicalIndex, (int)[watch finalCurrentModeNum], (int)gridZ2);
		*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, [watch finalCurrentModeNum], gridZ2)];
                REASON("The grid (if we're not already on the grid), z2=gridz2");
	    }
	}
    }

    // Then current mode on the rest of the active watches, closest to current watch first
    // 7 watches: positionOffset <= 3
    // 8 watches: positionOffset <= 4, and skip negative (arbitrarily; could also skip positive) on last offset
    // Long term this should change to prefer moving in the same direction we've already shown to be moving
    // so you can skip through a long section in one direction without loading the watches in the other direction
    int lastPositiveOffset = glWatchCount / 2;  // which is also the last time through the loop
    int lastNegativeOffset;
    if (glWatchCount % 2) {  // if odd
	lastNegativeOffset = -lastPositiveOffset;
    } else {
	lastNegativeOffset = -lastPositiveOffset + 1;
    }
    if (gridZ2 != 0 && (currentZ2 != gridZ2 || gridZ2OtherRotation != 0)) {
        for (int positionOffset = 2; positionOffset <= lastPositiveOffset; positionOffset++) {
            indx = indexAtOffsetPosition(positionOffset);
            watch = [glWatches objectAtIndex:indx];
            *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX([watch canonicalIndex], [watch finalCurrentModeNum], 0)];
            REASON("Current mode on the rest of the active watches, closest first (positive)");
            
            int negativeOffset = -positionOffset;
            if (negativeOffset >= lastNegativeOffset) {
                indx = indexAtOffsetPosition(negativeOffset);
                watch = [glWatches objectAtIndex:indx];
                *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX([watch canonicalIndex], [watch finalCurrentModeNum], 0)];
                REASON("Current mode on the rest of the active watches, closest first (negative)");
            }
        }
    }
    // Finally, remaining modes on active watches, starting with closest
    for (int positionOffset = 1; positionOffset <= lastPositiveOffset; positionOffset++) {
	indx = indexAtOffsetPosition(positionOffset);
	watch = [glWatches objectAtIndex:indx];
	canonicalIndex = [watch canonicalIndex];
	ECWatchModeEnum watchMode = [watch finalCurrentModeNum];
	for (int i = 0; i < ECNumWatchDrawModes; i++) {
	    if (i != watchMode) {
		*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, i, 0)];
                REASON("Remaining modes on active watches, closest first (positive)");
	    }
	}

	int negativeOffset = -positionOffset;
	if (negativeOffset >= lastNegativeOffset) {
	    indx = indexAtOffsetPosition(negativeOffset);
	    watch = [glWatches objectAtIndex:indx];
	    canonicalIndex = [watch canonicalIndex];
	    watchMode = [watch finalCurrentModeNum];
	    for (int i = 0; i < ECNumWatchDrawModes; i++) {
		if (i != watchMode) {
		    *arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, i, 0)];
                    REASON("Remaining modes on active watches, closest first (negative)");
		}
	    }
	}
    }
    // Now, all modes of inactive watches, no particular ordering needed so just 0 to available count
    for (watch in availableWatches) {
	canonicalIndex = [watch canonicalIndex];
	if (![watch isActive]) {
	    for (int i = 0; i < ECNumWatchDrawModes; i++) {
		*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, i, 0)];
                REASON("all modes of inactive watches, in canonical order, z2=0");
	    }
	}
    }

    // Now all z2s of available watches that aren't zero and aren't the appropriate size for the grid of all active watches
    for (watch in availableWatches) {
	canonicalIndex = [watch canonicalIndex];
	ECWatchModeEnum watchMode = [watch finalCurrentModeNum];
	bool watchActive = [watch isActive];
	for (int z2 = ECZoomMinPower2; z2 <= ECZoomMaxLogicalPower2; z2++) {
	    if (z2 == 0) {
		continue;
	    }
	    for (int i = 0; i < ECNumWatchDrawModes; i++) {
		if ((int)watchMode == i && watchActive &&
                    (z2 == gridZ2 || (currentZ2 == gridZ2 && z2 == gridZ2OtherRotation))) {
		    continue;
		}
		if (watch == loadMeFirst && z2 == -2 && (int)watchMode == i) {
		    continue;
		}
		// printf("last chance watch %s mode %d (for watch with current mode %d) z2 %d (grid z2 %d)\n", [[watch name] UTF8String], i, (int)watchMode, z2, z2ForCount(glWatchCount));
		*arrayPtr++ = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canonicalIndex, i, z2)];
                REASON("z2s of available watches that aren't zero and aren't grid size for active watches");
	    }
	}
    }

    numWatchModeUsedDescriptors = numWatchModeDescriptors;

    // Did we get to the end (exactly)?
#ifndef NDEBUG    
    for (int dbgi = 0; dbgi < [availableWatches count]; dbgi++) {
	assert([[availableWatches objectAtIndex:dbgi] availableIndex] == dbgi);
    }
    bool foundError = false;
    if (arrayPtr != &watchModesByImportance[numWatchModeDescriptors]) {
	assert(numWatchModeDescriptors == [availableWatches count] * ECNumWatchDrawModes * ECNumLogicalVisualZoomFactors);
	printf("Didn't get to the right place after sorting: arrayPtr 0x%016lx, end of array 0x%016lx, numWatchModeDescriptors %d, arrayPtr index %d\n",
	       (long)arrayPtr,
	       (long)(&watchModesByImportance[numWatchModeDescriptors]),
	       numWatchModeDescriptors,
	       (int)((arrayPtr - watchModesByImportance)));
	if (arrayPtr > &watchModesByImportance[numWatchModeDescriptors]) {
	    printf("...went too far:\n");
	    // Duplicates supposedly caught below
	} else {
	    // Didn't go far enough:  Look for what's missing in the array
	    printf("...didn't go far enough:\n");
	    for (int dbgi = 0; dbgi < [availableWatches count]; dbgi++) {
		ECGLWatch *dbgwatch = [availableWatches objectAtIndex:dbgi];
		assert([dbgwatch availableIndex] == dbgi);
		int canon = [dbgwatch canonicalIndex];
		for (int z2 = ECZoomMinPower2; z2 <= ECZoomMaxLogicalPower2; z2++) {
		    for (int i = 0; i < ECNumWatchDrawModes; i++) {
			WatchModeDescriptor *targetPtr = &watchModeStorage[WATCHMODE_DESCRIPTOR_INDEX(canon, i, z2)];
			bool foundIt = false;
			for (WatchModeDescriptor **dbgPtr = &watchModesByImportance[0]; dbgPtr < arrayPtr; dbgPtr++) {
			    if (*dbgPtr == targetPtr) {
				foundIt = true;
				break;
			    }
			}
			if (!foundIt) {
			    printf("...missing watch %10s, side %5s, zoom %2d\n",
				   [[dbgwatch name] UTF8String], ECmodeNames[i], z2);
			}
		    }
		}
	    }
	}
        foundError = true;
    }
    // Check for duplicates (even if we went exactly to the end or went too far)
    int dbgcount = numWatchModeDescriptors;
    if (arrayPtr - watchModesByImportance > numWatchModeDescriptors) {
        dbgcount = arrayPtr - watchModesByImportance;
    }
    for (int dbgi = 0; dbgi < dbgcount; dbgi++) {
        for (int dbgj = dbgi+1; dbgj < dbgcount; dbgj++) {
            WatchModeDescriptor *descriptori = watchModesByImportance[dbgi];
            WatchModeDescriptor *descriptorj = watchModesByImportance[dbgj];
            if (descriptori == descriptorj) {
                foundError = true;
                printf("Duplicate: %10s, side %5s, zoom %2d at indices %2d and %2d\n",
                       [[descriptori->watch name] UTF8String],
                       ECmodeNames[descriptori->modeNum],
                       descriptori->z2,
                       dbgi, dbgj);
            }
        }
    }
    if (foundError) {
	printWatchDescriptorArrayToSize(dbgcount);
        assert(false);
    }
#endif

    if (!alreadyLocked) {
	[watchModeDescriptorLock unlock];
    }
}

@interface ChronometerAppDelegate (ChronometerAppDelegeatePrivate)
+ (void)showQuickStart;
+ (void)editorFlip;
+ (void)storeFlip;
+ (void)setAll2DGridPositions;
+ (void)setup2DGridWithAnimationInterval:(NSTimeInterval)animationInterval;
+ (void)unsetAll2DGridPositions;
+ (void)setAllNoGridPositionsWithAnimationInterval:(NSTimeInterval)animationInterval oneDirectionOnly:(bool)oneDirectionOnly;
+ (void)requestUnattachCheckingForWork:(bool)checkingForWork;
@end

@implementation ChronometerAppDelegate

double startOfMainTime;
double lastTimeNoted = -1;

static ChronometerAppDelegate *theAppDelegate = nil;

- (ChronometerAppDelegate *)init {
    if (self = (id)[super init]) {
	assert(watches);
    }
    return self;
}

+ (CGSize)applicationSizePoints {
    return getApplicationSizePoints();
}

+ (CGSize)applicationViewSizePoints {
    return getApplicationViewSizePoints();
}

+ (CGSize)applicationWindowSizePoints {
    return getApplicationWindowSizePoints();
}

+ (CGSize)applicationSize {
    // FIX FIX FIX: Change all callers, then remove
    return [self applicationViewSizePoints];
}

+ (CGSize)applicationSizeWatchCoordinates {
    return getApplicationSizeWatchCoordinates();
}

+ (CGSize)applicationSizePixels {
    CGSize appSizePoints = getApplicationSizePoints();
    assert(nativeScale != 0);
    return CGSizeMake(appSizePoints.width * nativeScale,
                      appSizePoints.height * nativeScale);
}

+ (CGRect)applicationBoundsPoints {
    return getApplicationBoundsPoints();
}

+ (CGRect)applicationBoundsPixels {
    CGRect appBoundsPoints = getApplicationBoundsPoints();
    assert(nativeScale != 0);
    return CGRectMake(appBoundsPoints.origin.x * nativeScale,
                      appBoundsPoints.origin.y * nativeScale,
                      appBoundsPoints.size.width * nativeScale,
                      appBoundsPoints.size.height * nativeScale);
}

+ (CGFloat)iPhoneScaleFactor {
    return iPhoneScaleFactor;
}

#ifndef NDEBUG
NSString *
orientationNameForOrientation(UIInterfaceOrientation orient) {
    switch (orient) {
      case UIInterfaceOrientationPortrait:
	return @"Portrait";
      case UIInterfaceOrientationPortraitUpsideDown:
	return @"PortraitUpsideDown";
      case UIInterfaceOrientationLandscapeLeft:
	return @"LandscapeLeft";
      case UIInterfaceOrientationLandscapeRight:
	return @"LandscapeRight";
      default:
	assert(false);
    }
}
#endif

+ (void)setNewOrientation:(UIInterfaceOrientation)newOrient duration:(NSTimeInterval)duration skipRedraw:(bool)skipRedraw {
#ifndef NDEBUG
    //printf("Switching to orientation %s\n", [orientationNameForOrientation(newOrient) UTF8String]);
#endif
    CGFloat rotationDegrees = 0;
    switch (newOrient) {
      case UIInterfaceOrientationPortrait:
	rotationDegrees = 0;
        break;
      case UIInterfaceOrientationPortraitUpsideDown:
	rotationDegrees = 180;
        break;
      case UIInterfaceOrientationLandscapeLeft:
	rotationDegrees = 90;
        break;
      case UIInterfaceOrientationLandscapeRight:
	rotationDegrees = 270;
        break;
      default:
	assert(false);
    }
    [glView orientationChange];
    if (!initializationDone) {
        return;
    }
    [ChronometerAppDelegate ignoreRedrawRequests];
    bool currentOrientationIsLandscape = (newOrient == UIInterfaceOrientationLandscapeRight ||
                                          newOrient == UIInterfaceOrientationLandscapeLeft);
    if (isIpad()) {
	locSyncLabel.frame = CGRectMake((currentOrientationIsLandscape ? 1024 : 768)-65, 55, 65, 40);
    }
    if (displayingGrid) {
	[self setup2DGridWithAnimationInterval:duration];
	if (glWatchCount == 1) {
	    [self showECStatusMessage:nil];
	}
    } else {
        [self setAllNoGridPositionsWithAnimationInterval:duration oneDirectionOnly:false];
    }
    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [ChronometerAppDelegate unignoreRedrawRequestsRedrawingIfDoneIgnoring:!skipRedraw];
}

bool shouldShowQuickStart;

+ (void)willLayoutSubviews {
    getIphoneScaleFactor();
    UIScreen *mainScreen = [UIScreen mainScreen];
    screenScale = [mainScreen scale];
    nativeScale = [mainScreen nativeScale];
    // printf("screen scale returns %.2f (coming soon! to a theater near you)\n", screenScale);
    screenScaleZoomTweak = zoomTweakForScreenScale(screenScale);
    printf("screenScaleZoomTweak = %d\n", screenScaleZoomTweak);
    if (isIpad()) {
        screenScaleZoomTweak++;        // FIX FIX FIX
    }
    // printf("CAD willLayoutSubViews screenScale is %.2f\n", screenScale);
    // [self printBounds];
}

+ (void)willAnimateRotationToOrientation:(UIInterfaceOrientation)newOrient duration:(NSTimeInterval)duration {
    //printf("CAD willAnimateRotation to %s\n", [orientationNameForOrientation(newOrient) UTF8String]);
    [self setNewOrientation:newOrient duration:duration skipRedraw:true];
}

+ (void)didRotateFromOrientation:(UIInterfaceOrientation)fromOrient {
    //printf("CAD didRotate from %s\n", [orientationNameForOrientation(fromOrient) UTF8String]);
    if (initializationDone && shouldShowQuickStart) {
        [self showQuickStart];
    }
}

+ (void)willRotateToOrientation:(UIInterfaceOrientation)newOrient duration:(NSTimeInterval)duration {
    //printf("CAD willRotate to %s\n", [orientationNameForOrientation(newOrient) UTF8String]);
}

+ (bool)currentOrientationIsLandscape {
    return getCurrentOrientationIsLandscape();
}

+ (void)waitForWatchToLoad:(ECGLWatch *)watch {
    assert([NSThread isMainThread]);
    assert(!loadMeFirst);
    if (watch) {  // Maybe this is Emerald Geneva and the caller didn't check (tsk, tsk)
	assert(watch);
	if (![watch loaded]) {
	    loadMeFirst = watch;
	    sortWatchModeDescriptorArray(false);
	    [ECGLWatchLoader checkForWork];
#ifndef NDEBUG
	    [ChronometerAppDelegate noteTimeAtPhase:"wait"];
#endif
	    while (![watch loaded]) {
		usleep(100000);  // 0.1 seconds
	    }
#ifndef NDEBUG
	    [ChronometerAppDelegate noteTimeAtPhase:"done waiting"];
#endif
	    loadMeFirst = nil;
	}
    }
}

+ (CGFloat)screenScale {
    return screenScale;
}

+ (CGFloat)nativeScale {
    return nativeScale;
}

+ (int)screenScaleZoomTweak {
    return screenScaleZoomTweak;
}

+ (double)nogridZoom {
    return nogridZoom();
}

// Note: This function only works on the background watch, because its scaling is special and this routine knows about it.
+ (void)translateCornerRelativeOrigin:(CGPoint *)origin {
    if (iPhoneScaleFactor == 0) {
        // View isn't there yet, do nothing.
        return;
    }
    CGRect appBounds = getApplicationBoundsWatchCoordinates();
    CGFloat cornerTranslationOffsetX = (appBounds.size.width - 320) / 2.0;
    CGFloat cornerTranslationOffsetY = (appBounds.size.height - 480) / 2.0;
    // printf("translateCornerRelativeOrigin from %.1f %.1f, app size %.1f %.1f, offsetXY %.1f %.1f\n",
    //         origin->x, origin->y, appBounds.size.width, appBounds.size.height, cornerTranslationOffsetX, cornerTranslationOffsetY);
    if (origin->x > 0) {
        origin->x += cornerTranslationOffsetX;
    } else {
        origin->x -= cornerTranslationOffsetX;
    }
    if (origin->y > 0) {
        origin->y += cornerTranslationOffsetY;
    } else {
        origin->y -= cornerTranslationOffsetY;
    }
    // printf("...translated to %.1f %.1f\n", origin->x, origin->y);
}

#ifndef NDEBUG
extern void printDate(const char *description);
extern void printADate(NSTimeInterval dt);
extern void printADateWithTimeZone(NSTimeInterval dt, ESTimeZone *estz);
#endif

+ (void)initialize {
    // set up statics
    watches = [[NSMutableArray alloc] init];
    observers = [[NSMutableDictionary alloc] initWithCapacity:40];
    reallySignificantObservers = [[NSMutableDictionary alloc] initWithCapacity:2];
    // register default settings
    NSLocale *loc = [NSLocale currentLocale];
    NSNumber *val = [loc objectForKey:NSLocaleUsesMetricSystem];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:val forKey:@"ECSIUnits"];
    
    [defaults registerDefaults:appDefaults];
}

+ (void)startOfMain {
    //printf("Emerald Chronometer BOJ\n");
    [TSTime startOfMainWithSignature:"Chro"];
    [ECGlobals initGlobals];
    ESCalendar_init();
    [ECAppLog newSession];
    startOfMainTime = [[NSDate date] timeIntervalSinceReferenceDate];
#ifndef NDEBUG
    [ChronometerAppDelegate noteTimeAtPhase:"start of main"];
#endif
}

+ (void)noteTimeAtPhase:(const char *)phaseName {
    [TSTime noteTimeAtPhase:phaseName];
}

+ (void)noteTimeAtPhaseWithString:(NSString *)phaseName {
    [TSTime noteTimeAtPhase:[phaseName UTF8String]];
}

+ (void)printAllFonts {
#ifndef NDEBUG
    NSArray *fontFamilies = [UIFont familyNames];
    printf("Fonts in system:\n");
    for (NSString *fontFamily in fontFamilies) {
	printf("%s\n", [fontFamily UTF8String]);
	NSArray *fonts = [UIFont fontNamesForFamilyName:fontFamily];
	for (NSString *fontName in fonts) {
	    printf("   %s\n", [fontName UTF8String]);
	}
    }
#endif
}

+ (void)printAllCountryCodes {
#ifndef NDEBUG
    NSArray *list = [NSLocale ISOCountryCodes];
    for (NSString *s in list) {
	printf("%s = %s\n", [s UTF8String], [[[NSLocale currentLocale]displayNameForKey:NSLocaleCountryCode value:s] UTF8String]);
    }
#endif
}

+ (void)reallySignificantTimeChange:(UIApplication *)application {
    tracePrintf("reallySignificantTimeChange");
    // Tell all observers
    for (ECAddressKey *addressKey in reallySignificantObservers) {
	ChronometerAppDelegateObserverDescriptor *descriptor = [reallySignificantObservers objectForKey:addressKey];
	if (descriptor.significantTimeChangeSelector) {
	    [descriptor.observer performSelector:descriptor.significantTimeChangeSelector withObject:application];
	}
    }
    [self forceUpdateInMainThread];
}

+ (void)doReallySignificantTimeChangeInMainThread {
    [self performSelector:@selector(reallySignificantTimeChange:) onThread:[NSThread mainThread] withObject:[UIApplication sharedApplication] waitUntilDone:NO];
}

+ (void)statusTick: (NSTimer *)t {
    [self showECStatusMessage:nil];
//    [self forceUpdateAllowingAnimation:true dragging:false];
}

+ (void)setNetworkActivityOn {
    assert([NSThread isMainThread]);
    // [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;  // Deprecated in iOS 13
}
+ (void)setNetworkActivityOff {
    assert([NSThread isMainThread]);
    // [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;   // Deprecated in iOS 13
}

+ (void)setNetworkActivityIndicator:(bool)active {
    if ([NSThread isMainThread]) {
        // [UIApplication sharedApplication].networkActivityIndicatorVisible = active;   // Deprecated in iOS 13
    } else {
        [self performSelectorOnMainThread:(active ? @selector(setNetworkActivityOn) : @selector(setNetworkActivityOff)) withObject:nil waitUntilDone:NO];
    }
}

+ (void)hideStatus {
    [self setNetworkActivityIndicator:[ECTS active]];
    if (!helping && !switching && !optioning && !dataing) {
        [theRootViewController setStatusBarHidden:YES];
    }
}

+ (void)showStatus {
#ifndef EC_RED
    if (displayLocked) {
	printf("skipping status display because display is locked\n");
	return;
    }
    [theRootViewController setStatusBarHidden:NO];
    [self setNetworkActivityIndicator:[ECTS active]];
#endif
}

+ (void)killStatusUpdate {
    [self setNetworkActivityIndicator:[ECTS active]];
    [suTimer invalidate];
    suTimer = nil;
}

+ (void)showECTimeStatus {
    if ([NSThread isMainThread]) {
	timeSyncLabel.layer.opacity = 1;
	timeSyncLabel.text = [ECTS statusText];
	[self killStatusUpdate];
	suTimer = [NSTimer scheduledTimerWithTimeInterval:ECStatusPersistence target:self selector:@selector(statusTick:) userInfo:nil repeats:false];
    } else {
	[self performSelectorOnMainThread:@selector(showECTimeStatus) withObject:nil waitUntilDone:NO];
    }
}

+ (void)showAlarmStatus {
    if ([NSThread isMainThread]) {
	[self updateAlarmStatus];
	alarmStateLabel.layer.opacity = 1;
	[self killStatusUpdate];
	suTimer = [NSTimer scheduledTimerWithTimeInterval:ECStatusPersistence target:self selector:@selector(statusTick:) userInfo:nil repeats:false];
    } else {
	[self performSelectorOnMainThread:@selector(showAlarmStatus) withObject:nil waitUntilDone:NO];
    }
}

+ (void)updateAlarmStatus {
    if ([NSThread isMainThread]) {
	int n = (int)[[self currentWatch] alarmCount];
	switch (n) {
	    case 0:
		[alarmStateLabel setText:NSLocalizedString(@"no\nalarms", @"no alarms are set")];
		break;
	    case 1:
		[alarmStateLabel setText:NSLocalizedString(@"1\nalarm", @"one alarm set")];
		break;
	    default:
		[alarmStateLabel setText:[NSString stringWithFormat:NSLocalizedString(@"%d\nalarms", @"more than one alarms set"), n]];
	}
    } else {
	[self performSelectorOnMainThread:@selector(updateAlarmStatus) withObject:nil waitUntilDone:NO];
    }
}

+ (void)showECLocationStatus {
    if ([NSThread isMainThread]) {
	locSyncLabel.layer.opacity = 1;
	locSyncLabel.text = [[ECLocationManager theLocationManager] statusText];
	[self killStatusUpdate];
	suTimer = [NSTimer scheduledTimerWithTimeInterval:ECStatusPersistence target:self selector:@selector(statusTick:) userInfo:nil repeats:false];
    } else {
	[self performSelectorOnMainThread:@selector(showECLocationStatus) withObject:nil waitUntilDone:NO];
    }
}

+ (void)hideECTimeLocationStatus {
    if ([NSThread isMainThread]) {
	alarmStateLabel.layer.opacity = 0;
	timeSyncLabel.layer.opacity = 0;
	locSyncLabel.layer.opacity = 0;
    } else {
	[self performSelectorOnMainThread:@selector(hideECTimeLocationStatus) withObject:nil waitUntilDone:NO];
    }
}

+ (void)toggleECTimeLocationStatus {
    if ([NSThread isMainThread]) {
	timeSyncLabel.layer.opacity = timeSyncLabel.layer.opacity ? 0 : 1;
	locSyncLabel.layer.opacity =  locSyncLabel.layer.opacity  ? 0 : 1;
	alarmStateLabel.layer.opacity =  alarmStateLabel.layer.opacity  ? 0 : 1;
    } else {
	[self performSelectorOnMainThread:@selector(toggleECTimeLocationStatus) withObject:nil waitUntilDone:NO];
    }
}

+ (void)toggleECStatusNameDisplay {		// show or hide the name of the current watch and the buttons
    if (suTimer) {
	if ([[[self currentWatch] mainTime] isCorrect] && ![[self currentWatch] alarmManualSet]) {
	    [ChronometerAppDelegate showECStatusMessage:nil];
	    [self hideECTimeLocationStatus];
	} else {
	    [self toggleECTimeLocationStatus];
	}
    } else {
	[ChronometerAppDelegate showECStatusMessage:[[self currentWatch] displayName]];
	[self showECTimeStatus];
	[self showECLocationStatus];
	[self showAlarmStatus];
    }
}

+ (void)hideECStatus {		// really hide it, correct time or not
    warpLabel.layer.opacity = 0;
    [self killStatusUpdate];
}

+ (void)showECStatusMessage:(NSString *)msg withColor:clr {		// display a message below the status bar
    if ([NSThread isMainThread]) {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:ECControlFadeTime];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];

	[self killStatusUpdate];
	ECWatchTime *tim = [[self currentWatch] mainTime];
	if (msg != nil) {
	    if (![msg isEqualToString:@""]) {
		[warpLabel setText:msg];
		[warpLabel setBackgroundColor:clr];
		warpLabel.layer.opacity = 1;
	    }
	    [ChronometerAppDelegate showStatus];
	    suTimer = [NSTimer scheduledTimerWithTimeInterval:tim.isCorrect ? ECStatusPersistence : 1 target:self selector:@selector(statusTick:) userInfo:nil repeats:false];
	} else {
	    [ChronometerAppDelegate hideECTimeLocationStatus];
	    ECWatchEnvironment *environment = [[self currentWatch] mainEnv];
	    if (tim.isCorrect) {
		if ([[self currentWatch] alarmManualSet]) {
		    warpLabel.layer.opacity = 1;
		    [warpLabel setBackgroundColor:[UIColor colorWithRed:0.75 green:0 blue:0 alpha:.5]];
		    if ([[self currentWatch] alarmMode] == ECAlarmTimeInterval) {
			ECWatchTime *intTim = [[self currentWatch] intervalTimer];
			[warpLabel setText:[NSString stringWithFormat:@"Setting Alarm Interval = %02d:%02d:%02d", [intTim stopwatchHour24Number], [intTim stopwatchMinuteNumber], (int)round([intTim stopwatchSecondValue])]];
//    			[warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Setting Alarm Interval = %02d:%02d:%02d", @"Setting Interval type alarm to value"), [intTim stopwatchHour24Number], [intTim stopwatchMinuteNumber], (int)round([intTim stopwatchSecondValue])]];
		    } else {
			ECWatchTime *alarmTim = [[self currentWatch] alarmTimer];
		    	[warpLabel setText:[NSString stringWithFormat:@"Setting Alarm @ %2d:%02d %@",
						     [alarmTim hour12NumberUsingEnv:environment] == 0 ? 12 : [alarmTim hour12NumberUsingEnv:environment],
						     [alarmTim minuteNumberUsingEnv:environment],
						     [alarmTim hour24NumberUsingEnv:environment] >= 12 ? @"PM" : @"AM"]];
//			[warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Setting Alarm @ %2d:%02d %@", @"Setting alarm target time to value"), [alarmTim hour12Number] == 0 ? 12 : [alarmTim hour12Number], [alarmTim minuteNumber], [alarmTim hour24Number] >= 12 ? @"PM" : @"AM"]];
		    }
		    [ChronometerAppDelegate showStatus];
		    suTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(statusTick:) userInfo:nil repeats:false];
		} else {
		    [ChronometerAppDelegate hideStatus];
		    [ChronometerAppDelegate hideECStatus];
		}
	    } else {
		if ([tim checkAndConstrainAbsoluteTime]) {
		    [warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Off by %@; at limit!", @"difference between real time and watch time; watch time is at the limits of our range"), [tim representationOfDeltaOffsetUsingEnv:environment]]];
		} else if (tim.warp == 1) {
		    [warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Off by %@", @"difference between real time and watch time"), [tim representationOfDeltaOffsetUsingEnv:environment]]];
		} else if (tim.warp == -1) {
		    [warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Off by %@; running backwards", @"difference between real time and watch; watch is running backwards"), [tim representationOfDeltaOffsetUsingEnv:environment]]];
		} else if (tim.warp == 0) {
		    if ([tim lastMotionWasInReverse]) {
			[warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Off by %@; stopped backward", @"difference between real time and watch time; watch is stopped"), [tim representationOfDeltaOffsetUsingEnv:environment]]];
		    } else {
			[warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Off by %@; stopped", @"difference between real time and watch time; watch is stopped"), [tim representationOfDeltaOffsetUsingEnv:environment]]];
		    }
		} else {
		    assert(false);
		    [warpLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Off by %@; rate %@", @"difference between real time and watch time; watch is running in warp mode (not implemented)"),
						 [tim representationOfDeltaOffsetUsingEnv:environment], [tim representationOfWarp]]];	// no longer implemented
		}
		warpLabel.layer.opacity = 1;
		if ([[self currentWatch] alarmManualSet]) {
		    [warpLabel setBackgroundColor:[UIColor colorWithRed:0.75 green:0 blue:0 alpha:1]];
		} else {
		    [warpLabel setBackgroundColor:[UIColor colorWithRed:0.75 green:0 blue:0 alpha:.5]];
		}
		[ChronometerAppDelegate showStatus];
		suTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(statusTick:) userInfo:nil repeats:false];
	    }
	}

	[UIView commitAnimations];
    } else {
	[self performSelectorOnMainThread:@selector(showECStatusMessage:) withObject:msg waitUntilDone:NO];
    }
}

+ (void)showECStatusWarning:(NSString *)msg {		// display a red warningbelow the status bar
    [self showECStatusMessage:msg withColor:[UIColor colorWithRed:0.75 green:0 blue:0 alpha:.5]];
    warningMessage = true;
}

+ (void)showECStatusMessage:(NSString *)msg {		// display a message below the status bar
    [self showECStatusMessage:msg withColor:[UIColor clearColor]];
}
    
#ifdef EC_HENRY
+ (bool)addWatch:(ECWatchController *)aWatchCon {
    assert(aWatchCon);
    // first check for dups
    for (ECWatchController *w in watches) {
	if ([aWatchCon.watch.name caseInsensitiveCompare:w.watch.name] == NSOrderedSame) {
	    return false;
	}
    }
    [watches addObject:aWatchCon];
    //[self noteTimeAtPhase:"HENRY adding watch"];
    //printf("adding %d: %s\n",[watches count]-1, [aWatchCon.watch.name UTF8String]);
    return true;
}
#endif

#if 0
+ (ECWatchController *)controllerForIndex:(int)watchNumber {
    return [watches objectAtIndex:watchNumber];
}
#endif

#ifdef EC_HENRY
+ (ECWatchController *)controllerForWatchNamed:(NSString *)watchName {
    int i;
    for (i=0; i<(int)[watches count]; i++) {
	ECWatchController *watchController = [watches objectAtIndex:i];
	if ([watchName caseInsensitiveCompare:[[watchController watch] name]] == NSOrderedSame) {
	    return watchController;
	}
    }
    return nil;
}
#endif

+ (NSString *)watchNameForIndex:(int)watchNumber {
    return [[glWatches objectAtIndex:watchNumber] name];
}

+ (int)currentWatchNumber {
    return currentWatchIndex;
}

#ifdef EC_HENRY
+ (void)ensureWatchLoadedInHenry:(NSString *)watchName {
    ECWatchController *wc = [self controllerForWatchNamed:watchName];
    if (!wc) {
	[self noteTimeAtPhaseWithString:[NSString stringWithFormat:@"Henry start loading %@", watchName]];
	[watchDefinitionManager loadAllWatchesWithErrorReporter:[ECErrorReporter theErrorReporter] butJustHackIn:watchName];
	//[self noteTimeAtPhaseWithString:[NSString stringWithFormat:@"Henry done loading %@", watchName]];
	wc = [self controllerForWatchNamed:watchName];
	assert(wc);
	[wc archiveAll];
    }
}
#endif

+ (ECGLWatch *)activeWatchForIndex:(int)watchNumber {
    if (watchNumber < 0 || watchNumber >= glWatchCount) {
	assert(false);
	return nil;
    }
    return [glWatches objectAtIndex:watchNumber];
}

+ (ECGLWatch *)activeWatchForIndex:(int)watchNumber availableIndex:(int *)availIndex {
    if (watchNumber < 0 || watchNumber >= glWatchCount) {
	assert(false);
	return nil;
    }
    ECGLWatch *watch = [glWatches objectAtIndex:watchNumber];
    if (watch) {
	*availIndex = [watch availableIndex];
    }
    return watch;
}


+ (ECGLWatch *)availableWatchForIndex:(int)watchNumber {
    if (watchNumber < 0 || watchNumber >= [availableWatches count]) {
	assert(false);
	return nil;
    }
    return [availableWatches objectAtIndex:watchNumber];
}

+ (ECGLWatch *)availableWatchForIndex:(int)watchNumber isActive:(bool *)watchIsActive {
    if (watchNumber < 0 || watchNumber >= [availableWatches count]) {
	assert(false);
	return nil;
    }
    ECGLWatch *watch = [availableWatches objectAtIndex:watchNumber];
    if (watch) {
	*watchIsActive = [watch isActive];
    } else {
	*watchIsActive = false;
    }
    return watch;
}

+ (ECGLWatch *)availableWatchWithName:(NSString *)nam {
    if (nam == nil) {
	return nil;
    }
    for (ECGLWatch *watch in availableWatches) {
	if ([nam caseInsensitiveCompare:[watch displayName]] == NSOrderedSame ||
	    [nam caseInsensitiveCompare:[watch name]] == NSOrderedSame) {
	    return watch;
	}
    }
    return nil;
}

+ (NSArray *)indexPathsForInactiveWatches {
    int inactiveWatchCount = [availableWatches count] - glWatchCount;
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:inactiveWatchCount];
    int availableIndex = 0;
    for (ECGLWatch *watch in availableWatches) {
	if (![watch isActive]) {
	    [indexPaths addObject:[NSIndexPath indexPathForRow:availableIndex inSection:0]];
	}
	availableIndex++;
    }
    assert([indexPaths count] == inactiveWatchCount);
    return indexPaths;
}

#ifndef NDEBUG
static void checkWatchArrayConsistency() {
    int availIndex = 0;
    int activeCount = 0;
    assert([glWatches count] == glWatchCount);
    for (ECGLWatch *watch in availableWatches) {
	assert([watch availableIndex] == availIndex);
	assert([watch activeIndex] == activeCount);
	if ([watch active]) {
	    assert([watch activeIndex] == activeCount);
	    assert([glWatches objectAtIndex:activeCount] == watch);
	    activeCount++;
	}
	availIndex++;
    }
}
#endif

static void resetWatchIndices() {
    int activeCount = 0;
    int availableIndex = 0;
    for (ECGLWatch *watch in availableWatches) {
	[watch setActiveIndex:activeCount];
	if ([watch active]) {
	    activeCount++;
	}
	[watch setAvailableIndex:availableIndex];
	availableIndex++;
    }
}

static void resetActiveWatchIndices() {
    int activeCount = 0;
    for (ECGLWatch *watch in availableWatches) {
	[watch setActiveIndex:activeCount];
	if ([watch active]) {
	    activeCount++;
	}
    }
}

+ (void)moveWatchAtAvailableIndex:(int)fromIndex toIndex:(int)toIndex {
    //printf("Move watch from %d to %d\n", fromIndex, toIndex);
    //printWatchArrays();
    assert(fromIndex != toIndex);
    assert(fromIndex >= 0);
    assert(toIndex < [availableWatches count]);
    [watchModeDescriptorLock lock];
    ECGLWatch *movingWatch = [availableWatches objectAtIndex:fromIndex];

    int fromActiveIndex;
    int toActiveIndex;

    bool movingWatchIsActive = [movingWatch isActive];
    if (movingWatchIsActive) {
	fromActiveIndex = [movingWatch activeIndex];
	if (toIndex > fromIndex) {  // we remove first, thus moving everybody down
	    if (toIndex >= [availableWatches count] - 1) {  // going to overflow the array with toIndex+1
		assert(toIndex == [availableWatches count] - 1);  // We're moving it to the end
		toActiveIndex = [glWatches count] - 1;        // So the new active index is the end
	    } else {
		toActiveIndex = [[availableWatches objectAtIndex:(toIndex+1)] nextActiveIndexIncludingThisOne] - 1;
	    }
	} else {
	    toActiveIndex = [[availableWatches objectAtIndex:toIndex] nextActiveIndexIncludingThisOne];
	}
    } else {
	fromActiveIndex = -100;  // Shut up compiler warning
	toActiveIndex = -100;
    }

    // Move watch in available array
    [movingWatch retain];
    [availableWatches removeObjectAtIndex:fromIndex];
    [availableWatches insertObject:movingWatch atIndex:toIndex];
    [movingWatch release];

    if (movingWatchIsActive && fromActiveIndex != toActiveIndex) {  // Need to reorder active array
	//printf("active: %d => %d\n", fromActiveIndex, toActiveIndex);
	// Move watch in active array
	[glWatches removeObjectAtIndex:fromActiveIndex];
	[glWatches insertObject:movingWatch atIndex:toActiveIndex];
	if (currentWatchIndex == fromActiveIndex) {
	    currentWatchIndex = toActiveIndex;
	} else if (fromActiveIndex < toActiveIndex) {
	    if (currentWatchIndex > fromActiveIndex && currentWatchIndex <= toActiveIndex) {
		currentWatchIndex--;
	    }
	} else {
	    if (currentWatchIndex < fromActiveIndex && currentWatchIndex >= toActiveIndex) {
		currentWatchIndex++;
	    }
	}
    }

    lastWatchIndex = currentWatchIndex;
    resetWatchIndices();

#ifndef NDEBUG
    //printWatchArrays();
    checkWatchArrayConsistency();
#endif
    sortWatchModeDescriptorArray(true);
    [watchModeDescriptorLock unlock];
    saveWatchDefaults();
    //printWatchDescriptorArray();
    [ECGLWatchLoader checkForWork];
}

#ifndef NDEBUG
static void printActiveAvailable(const char *description) {
    printf("\n%s: Watches in available list:\n", description);
    int availIndex = 0;
    for (ECGLWatch *watch in availableWatches) {
	assert([watch availableIndex] == availIndex);
	printf("%s %2d %2d %2d %s\n", ([watch activeIndex] == currentWatchIndex ? "**" : "  "), availIndex, [watch availableIndex], [watch activeIndex], [[watch name] UTF8String]);
	availIndex++;
    }
    printf("Draw list:\n");
    for (ECGLWatch *watch in glDrawWatches) {
	printf("%s\n", [[watch name] UTF8String]);
    }
}
#endif

static void enableWatch(ECGLWatch *watch) {
    [watch scrollIntoPosition:0 atZoom:nogridZoom() animationStartTime:[NSDate timeIntervalSinceReferenceDate] animationInterval:0];
}

+ (void)setWatchActive:(bool)newActive forAvailableIndex:(int)availIndex alreadyLocked:(bool)alreadyLocked {
    assert(availIndex >= 0);
    assert(availIndex < [availableWatches count]);

    // printActiveAvailable("Before setWatchActive");

    if (!alreadyLocked) {
	[watchModeDescriptorLock lock];  // Because for internal consistency the active watches must remain constant while the sort is running
    }

    ECGLWatch *watch = [availableWatches objectAtIndex:availIndex];
	
    assert([watch active] != newActive);
    assert([glWatches containsObject:watch] ? !newActive : newActive);
    [watch setActive:newActive];
    if (!newActive) {
	[watch setVisible:false];  // Just in case
    }
    int activeIndex = [watch activeIndex];
    if (newActive) {
	[glWatches insertObject:watch atIndex:[watch activeIndex]];
	glWatchCount++;
	if (currentWatchIndex >= activeIndex) {
	    currentWatchIndex++;
	}
    } else {
	assert(glWatchCount > 1); // always need at least one watch
	// Watch was active -- better check current index
	// printf("Setting watch with avail index %d and active index %d to be inactive\n", availIndex, activeIndex);
	[glWatches removeObjectAtIndex:activeIndex];
	glWatchCount--;
	if (currentWatchIndex == activeIndex) {
	    [watch setVisible:false];
	    // printf("Turning off visibility for watch %s\n", [[watch name] UTF8String]);
	    if (currentWatchIndex == glWatchCount) {
		currentWatchIndex--;
	    }
	    enableWatch([glWatches objectAtIndex:currentWatchIndex]);
	    // printf("Turning on visibility for watch %s\n", [[[glWatches objectAtIndex:currentWatchIndex] name] UTF8String]);
	} else if (currentWatchIndex > activeIndex) {
	    currentWatchIndex--;
	}
    }

    lastWatchIndex = currentWatchIndex;
    resetActiveWatchIndices();

    // printActiveAvailable("After setWatchActive");

#ifndef NDEBUG
    checkWatchArrayConsistency();
#endif
    if (displayingGrid) {
	[self setAll2DGridPositions];  // Do this before sorting, so currentZ2 is set properly
	if (glWatchCount == 1) {
	    [self showECStatusMessage:nil];
	}
    } else {
	[self unsetAll2DGridPositions];  // Do this before exiting
    }
    sortWatchModeDescriptorArray(true);
    saveWatchDefaults();
    // printWatchDescriptorArray();
    [ECGLWatchLoader checkForWork];

    if (!alreadyLocked) {
	[watchModeDescriptorLock unlock];  // Because for internal consistency the active watches must remain constant while the sort is running
    }
}

+ (void)setActiveForAllAvailableWatches:(bool)turnOn {
    [watchModeDescriptorLock lock];
    int n = [availableWatches count];
    for (int i = 0; i < n; i++) {
	ECGLWatch *watch = [availableWatches objectAtIndex:i];
	bool watchOn = [watch active];
	if (turnOn) {
	    if (watchOn) {
		// nothing to do
	    } else {
		[self setWatchActive:true forAvailableIndex:i alreadyLocked:true];
	    }
	} else {
	    if (watchOn) {
		if ([watch activeIndex] != currentWatchIndex) {
		    [self setWatchActive:false forAvailableIndex:i alreadyLocked:true];
		}
	    } else {
		// nothing to do
	    }
	}
    }
    [watchModeDescriptorLock unlock];
    if ([glWatches count] == 1) {
	[self showECStatusMessage:[[self currentWatch] displayName]];
	[self showStatus];
    } else {
	[self hideStatus];			// hide the iPhone status line
	[self hideECStatus];		// hide the status line
    }
}

+ (int)watchCount {
    return glWatchCount;
}

+ (int)availableWatchCount {
    return [availableWatches count];
}

+ (ECGLWatch *)currentWatch {
    if (currentWatchIndex == -1) {
	return nil;
    }
    return [glWatches objectAtIndex:currentWatchIndex];
}

+ (ECGLWatch *)backgroundWatch {
    return backgroundWatch;
}

+ (ECGLWatch *)adjacentWatch {
    if (adjacentWatchIndex >= 0) {
	return [glWatches objectAtIndex:adjacentWatchIndex];
    } else {
	return nil;
    }
}

+ (void)nextWatch {
    int t = currentWatchIndex + 1;
    if (t == glWatchCount) {
	t = 0;
    }
    [self switchToWatchNumber:t];
}

+ (void)previousWatch {
    int t = currentWatchIndex - 1;
    if (t < 0) {
	t = glWatchCount - 1;
    }
    [self switchToWatchNumber:t];
}

+ (bool)isFirstGenerationHardware {
    return isFirstGenerationHardware;
}

static bool ignoreRedrawRequests = false;
static int ignoreRedrawRequestsStack = 0;

+ (void)ignoreRedrawRequests {
    ignoreRedrawRequests = true;
    ignoreRedrawRequestsStack++;
}

+ (void)unignoreRedrawRequestsRedrawingIfDoneIgnoring:(bool)redrawIfDoneIgnoring {
    if (!--ignoreRedrawRequestsStack) {
        ignoreRedrawRequests = false;
        if (redrawIfDoneIgnoring) {
            [self requestRedraw];
        }
    }
    assert(ignoreRedrawRequestsStack >= 0);
}

+ (void)unignoreRedrawRequests {
    [self unignoreRedrawRequestsRedrawingIfDoneIgnoring:true];
}

bool activeSwipeCancelled = false;

+ (void)cancelActiveSwipe {
    activeSwipeCancelled = true;
}

+ (void)setCurrentWatchNumber:(int)watchNumber {
    assert(watchNumber >= 0 && watchNumber < glWatchCount);
    [watchModeDescriptorLock lock];
    currentWatchIndex = watchNumber;
    adjacentWatchIndex = -1;
    [[NSUserDefaults standardUserDefaults] setObject:[self watchNameForIndex:currentWatchIndex] forKey:@"lastWatch"];
//	pager.currentPage = currentWatchIndex;
    sortWatchModeDescriptorArray(true);
    [watchModeDescriptorLock unlock];
    // printWatchDescriptorArray();
    [ECGLWatchLoader checkForWork];
}

// This method should only be used when z2 = 0 (for now; we may allow landscape switching at some point)
+ (void)switchToWatchNumber:(int)watchNumber {
    assert(watchNumber >= 0 && watchNumber < glWatchCount);
    [self cancelActiveSwipe];
    ECWatchModeEnum newModeNum = [[glWatches objectAtIndex:watchNumber] currentModeNum];
    [backgroundWatch setCurrentModeNum:newModeNum zoomPower2:0 allowAnimation:false];
    if (currentWatchIndex != watchNumber) {
	[self setCurrentWatchNumber:watchNumber];
        [self setAllNoGridPositionsWithAnimationInterval:0.5 oneDirectionOnly:true];
    }
    [ChronometerAppDelegate showECStatusMessage:[[ChronometerAppDelegate activeWatchForIndex:watchNumber] displayName]];
}

+ (void)switchToWatch:(ECGLWatch *)watch {
    // Pop down options
    if (optioning) {
	[self optionDone];
    }
    if (dataing) {
	[self dataDone];
    }
    // Pop down help
    if (helping) {
	[self infoDone:nil];
    }
    // Pop down watch switcher
    if (switching) {
	[self selectorCancel];
    }
    // Close the pocket watch cover
    if (watch == nil) {
	[backgroundWatch updateAllPartsForModeNum:[[glWatches objectAtIndex:currentWatchIndex] currentModeNum] animating:false];
	return;
    }
    // Make sure watch is active
    if (![watch isActive]) {
	NSUInteger availIndex = [availableWatches indexOfObject:watch];
	assert(availIndex != NSNotFound);
	if (availIndex != NSNotFound) {
	    [self setWatchActive:true forAvailableIndex:availIndex alreadyLocked:false];
	}
    }
    assert([watch isActive]);
    NSUInteger activeIndex = [glWatches indexOfObject:watch];
    assert(activeIndex != NSNotFound);
    if (activeIndex != NSNotFound) {
	[self switchToWatchNumber:activeIndex];
    }
}

+ (bool)switchToNextActiveAlarmWatch {
    int t = [availableWatches indexOfObject:[self currentWatch]];
    int n = 0;
    while (n < [availableWatches count]) {
	++t;
	if (t == [availableWatches count]) {
	    t = 0;
	}
	ECGLWatch *watch = [availableWatches objectAtIndex:t];
	if ([watch alarming]) {
	    [self switchToWatch:watch];
	    return true;
	}
	++n;
    }
    return false;	// didn't find one
}

static double interpolateByLog(int currentX,      // x ranges from startX to maximumX
			       int startX,
			       int endX,
			       double startY,     // y ranges from startY to maximumY
			       double endY) {
    double logStartY = log(startY);
    double logEndY = log(endY);
    return exp(logStartY + (logEndY - logStartY) * (currentX - startX) / (endX - startX));
}

#undef REPEAT_STATS
#ifdef REPEAT_STATS
typedef struct RepeatStats {
    double requestedInterval;
    double actualInterval;
} RepeatStats;

static RepeatStats repeatStats[1000];
static double lastScheduleTime = 0;
static double lastRepeatingPartInterval = 0;

#endif

+ (void)repeatingPartAction:(NSTimer *)timer {
    if (repeatingPart) { // Might have been cancelled  [stevep 3/19/2010:  Really? How? We invalidate the timer before setting repeatingPart to nil.  Different threads?  Don't think so.]
	ECPartRepeatStrategy repeatStrategy = [repeatingPart repeatStrategy];
	assert(repeatStrategy != ECPartDoesNotRepeat);
	double effectiveRepeatingPartInterval = kECButtonRepeatInterval;
	int numberOfTimesToAct = 1;
	if (++repeatCount > 1 && repeatStrategy != ECPartRepeatsSlowlyOnly) {
	    int iterationOfMaximumSpeed;
	    double maximumSpeedInterval;
	    if (repeatStrategy == ECPartRepeatsAndAcceleratesOnce) {
		iterationOfMaximumSpeed = 11;
		maximumSpeedInterval = kECButtonFastRepeatInterval;
	    } else {
		assert(repeatStrategy == ECPartRepeatsAndAcceleratesTwice);
		iterationOfMaximumSpeed = 35;
		maximumSpeedInterval = kECButtonFasterRepeatInterval;
	    }
	    if (repeatCount < iterationOfMaximumSpeed) {
		effectiveRepeatingPartInterval = interpolateByLog(repeatCount, 1, iterationOfMaximumSpeed, kECButtonRepeatInterval, maximumSpeedInterval);
	    } else {
		effectiveRepeatingPartInterval = maximumSpeedInterval;
	    }
	}
	double repeatingPartInterval = effectiveRepeatingPartInterval;
	double minimumRepeatInterval = [self isFirstGenerationHardware] ? 0.10 : 0.05; // faster rates need to act more times each update
	while (repeatingPartInterval < minimumRepeatInterval) {
	    numberOfTimesToAct++;
	    repeatingPartInterval = effectiveRepeatingPartInterval * numberOfTimesToAct;
	}
	//printf("repeat interval %.3f effect %.3f numAct %d  min %.3f\n",
	//     repeatingPartInterval, effectiveRepeatingPartInterval, numberOfTimesToAct, minimumRepeatInterval);
	//[self noteTimeAtPhaseWithString:[NSString stringWithFormat:@"repeatingPartAction effective %.4f actual %.4f acting %d", effectiveRepeatingPartInterval, repeatingPartInterval, numberOfTimesToAct]];
#ifdef REPEAT_STATS
	if (repeatCount <= 1000) {
	    double now = [NSDate timeIntervalSinceReferenceDate];
	    repeatStats[repeatCount - 1].requestedInterval = lastRepeatingPartInterval;
	    repeatStats[repeatCount - 1].actualInterval = now - lastScheduleTime;
	    lastScheduleTime = now;
	    lastRepeatingPartInterval = repeatingPartInterval;
	}
#endif
	animationOverrideInterval = repeatingPartInterval * 3 / 4;  // Make sure we're done animating by the time the next update comes along
	if (repeatingPartTimer) { // [stevep 3/19/2010: Similarly, there seems no reason for this check either.]
	    [repeatingPartTimer invalidate];  // This *should* be a no-op, since the timer never repeats (the update interval changes every time so we can't)
	    repeatingPartTimer = [NSTimer scheduledTimerWithTimeInterval:repeatingPartInterval
								  target:self
								selector:@selector(repeatingPartAction:)
								userInfo:nil
								 repeats:NO];
	}
	[repeatingPart actNumberOfTimes:numberOfTimesToAct];  // Do this *after* setting up the animation override interval, so the animation between now and the next update will finish before the next update
    }
}

+ (void)addRepeatingPartTimerForPart:(ECGLPartBase *)part {
    repeatCount = 0;
    assert(!repeatingPartTimer);
    assert([part repeatStrategy] != ECPartDoesNotRepeat);
    repeatingPart = part;
    animationOverrideInterval = kECButtonFirstRepeatInterval * 3 / 4;
    repeatingPartTimer = [NSTimer scheduledTimerWithTimeInterval:kECButtonFirstRepeatInterval
							  target:self
							selector:@selector(repeatingPartAction:)
							userInfo:nil
							 repeats:YES];
#ifdef REPEAT_STATS
    lastScheduleTime = [NSDate timeIntervalSinceReferenceDate];
    lastRepeatingPartInterval = kECButtonFirstRepeatInterval;
#endif
}

+ (void)cancelRepeatingPartTimers {
    [repeatingPartTimer invalidate];
    repeatingPartTimer = nil;
    repeatingPart = nil;
    animationOverrideInterval = 0;
#ifdef REPEAT_STATS
    printf("\nRepeat statistics:\n");
    for (int i = 0; i < repeatCount; i++) {
	printf("Iteration %3d: req %.02f act %.02f\n", i, repeatStats[i].requestedInterval, repeatStats[i].actualInterval);
    }
#endif
}

+ (void)resetRepeatingPartTimer {
    repeatCount = 0;
    [repeatingPartTimer invalidate];
    animationOverrideInterval = kECButtonRepeatInterval * 3 / 4;
    repeatingPartTimer = [NSTimer scheduledTimerWithTimeInterval:kECButtonRepeatInterval
							  target:self
							selector:@selector(repeatingPartAction:)
							userInfo:nil
							 repeats:YES];
}

+ (bool)inGridOrOptionMode {
    return displayingGrid || optioning;
}

+ (bool)inGridMode {
    return displayingGrid;
}

+ (bool)displayingZ2:(int)z2 {
    return z2 == currentZ2;
}

+ (bool)inSpecialMode {
    return animatingGrid || displayingGrid || optioning || helping || switching || !initializationDone;
}

ECGLPartBase *buttonPressed = nil;
ECGLPartBase *partBeingEvaluated = nil;
bool stoppingAlarmRing = false;

+ (void) setPartBeingEvaluated:(ECGLPartBase *)part {
    partBeingEvaluated = part;
}
+ (bool) thisButtonPressed {
    return buttonPressed && (buttonPressed == partBeingEvaluated);
}

+ (bool)stopAlarmsRinging {
    bool foundAnyAlarmsRinging = false;
    for (ECGLWatch *watch in availableWatches) {
	if ([watch stopAlarmRinging]) {
	    foundAnyAlarmsRinging = true;
	}
    }
    return foundAnyAlarmsRinging;
}

+ (void)touchBeganAtPoint:(CGPoint)point {
    stoppingAlarmRing = [self stopAlarmsRinging];
    if (stoppingAlarmRing || animatingGrid) {
	return;
    }
    activeSwipeCancelled = false;
    if (displayingGrid) {
	return;
    }
    ECGLPartBase *part = [partFinder findClosestActivePartInWatch:[self currentWatch]
                                                            andBG:backgroundWatch
                                                          toPoint:point];
#ifndef NDEBUG
    if(buttonPressed) {
	printf("touchBeganAtPoint but buttonPressed\n");
    }
#endif
    if (part) {
	buttonPressed = part;
	[self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
	if ([part drags]) {
            ECGLPart *draggableFullPart = [part asDraggableFullPart];
	    [draggableFullPart dragStartAtPoint:point];
	    draggingPart = draggableFullPart;
	} else {
	    if ([part immediate] || [part repeatStrategy] != ECPartDoesNotRepeat) {
		[part act];
	    }
	    if ([part repeatStrategy] != ECPartDoesNotRepeat) {
		[self addRepeatingPartTimerForPart:part];
	    }
	}
    }
    //[ChronometerAppDelegate showECStatusMessage:[NSString stringWithFormat:@"<- %@        %@        %@ ->", [[glWatches objectAtIndex:(currentWatchIndex+glWatchCount-1)%glWatchCount] displayName], [[glWatches objectAtIndex:currentWatchIndex] displayName], [[glWatches objectAtIndex:(currentWatchIndex+1)%glWatchCount] displayName]]];
}

static void fillInGridPositions(int numRows, int numWatches, bool isLandscape, CGPoint *positions) {
    //printf("\nfillInGridPositions %d rows %d watches\n", numRows, numWatches);
    CGSize screenSize = [ChronometerAppDelegate applicationSizeWatchCoordinates];
    //double zoom = zoomForCount(numWatches);
    //screenSize.height /= zoom;
    //screenSize.width /= zoom;
    int watchIndex = numWatches - 1;
    float cellHeight = screenSize.height / numRows;
    //printf("...cellHeight = %g, numWatches %d\n", cellHeight, numWatches);
    int largestRowCols = (int)ceil(1.0 * numWatches / numRows);
    float cellWidth = screenSize.width / largestRowCols;
    char (*colsForRowPtr)[5] = (isLandscape ? colsForRowLandscape : colsForRowPortrait);
    for (int rowNumber = 0; rowNumber < numRows; rowNumber++) {
	float y = (rowNumber + 0.5) * cellHeight - screenSize.height / 2;
	int numColsForThisRow = colsForRowPtr[numWatches-1][rowNumber];
        bool isShortRow = (numColsForThisRow * numRows) < numWatches;
	//printf("...row %d cellWidth %g y %g cols for this row %d\n", rowNumber, cellWidth, y, numColsForThisRow);
	for (int col = numColsForThisRow - 1; col >= 0; col--) {
            float x;
            if (isShortRow) {
                x = (col + 1.0) * cellWidth - screenSize.width / 2;
            } else {
                x = (col + 0.5) * cellWidth - screenSize.width / 2;
            }
	    //printf(".....col %d x %g\n", col, x);
	    positions[watchIndex].x = x;
	    positions[watchIndex--].y = y;
	}
    }
}

+ (void)handleTouchMoveIn2DGridWithDeltaX:(CGFloat)dx {
    int numActiveWatches = [glWatches count];
    bool isLandscape = getCurrentOrientationIsLandscape();
    int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
    CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
    fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
    int watchIndex = 0;
    [self ignoreRedrawRequests];
    for (ECGLWatch *watch in glWatches) {
	CGPoint pt = positions[watchIndex++];
	pt.x += dx;
	[watch handle2DTouchMoveTo:pt];
    }
    [self unignoreRedrawRequests];
    free(positions);
}

+ (void)handleSwipeReleaseIn2DGridWithAnimation:(bool)withAnimation {
    int numActiveWatches = [glWatches count];
    bool isLandscape = getCurrentOrientationIsLandscape();
    int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
    CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
    fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
    NSTimeInterval animationStartTime = withAnimation ? [NSDate timeIntervalSinceReferenceDate] : ECFarInThePast;
    int watchIndex = 0;
    [self ignoreRedrawRequests];
    for (ECGLWatch *watch in glWatches) {
	[watch handleTouchReleaseWithoutSwipeToDrawCenter:positions[watchIndex++] animationStartTime:animationStartTime];
    }
    free(positions);
    [self unignoreRedrawRequests];
}

static CGFloat gridOffsetForEditor = 0;

+ (void)scrollWatchesToX:(CGFloat)x animating:(bool)animating {
    int numActiveWatches = [glWatches count];
    bool isLandscape = getCurrentOrientationIsLandscape();
    int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
    CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
    fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
    int watchIndex = 0;
    NSTimeInterval animationStartTime = [NSDate timeIntervalSinceReferenceDate];
    [self ignoreRedrawRequests];
    double zoom = zoomForCount(numActiveWatches);
    for (ECGLWatch *watch in glWatches) {
	CGPoint pt = positions[watchIndex++];
	pt.x += x;
	[watch scrollToDrawCenter:pt animationStartTime:animationStartTime atZoom:zoom animationInterval:0.5];
    }
    free(positions);
    [self unignoreRedrawRequests];
}

+ (void)handleSwipeLeftIn2DGrid {
    CGSize screenSize = [ChronometerAppDelegate applicationSize];
    gridOffsetForEditor = -(screenSize.width * 1.5);
    [self scrollWatchesToX:gridOffsetForEditor animating:true];
}

+ (void)handleSwipeRightIn2DGrid {
    CGSize screenSize = [ChronometerAppDelegate applicationSize];
    gridOffsetForEditor = (screenSize.width * 1.5);
    [self scrollWatchesToX:gridOffsetForEditor animating:true];
}

+ (NSTimeInterval)animationOverrideInterval {
    return animationOverrideInterval;
}

+ (void)touchMovedFromFirstTouch:(CGPoint)firstTouchPoint to:(CGPoint)currentPoint {
    ECGLWatch *thisWatch = [glWatches objectAtIndex:currentWatchIndex];
    if (stoppingAlarmRing || activeSwipeCancelled || animatingGrid) {
	return;
    }
    if (draggingPart) {
#undef EC_INSTRUMENT_DRAG
#ifdef EC_INSTRUMENT_DRAG
	static double accumulatedTime = 0;
	static int numDrags = 0;
	//[ChronometerAppDelegate noteTimeAtPhase:"drag process start"];
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
#endif
	[draggingPart dragFrom:firstTouchPoint to:currentPoint];
#ifdef EC_INSTRUMENT_DRAG
	NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
	//[ChronometerAppDelegate noteTimeAtPhase:"drag process end"];
	numDrags++;
	accumulatedTime += (end - start);
	if ((numDrags % 10) == 0) {
	    printf("Average part drag: %.3f seconds\n", accumulatedTime / numDrags);
	}
#endif
	return;
    } else if (repeatingPartTimer || [buttonPressed immediate]) {
	// [self resetRepeatingPartTimer];
	return;
    } else if (([thisWatch manualSet] || [thisWatch alarmManualSet]) && [buttonPressed expanded] && [buttonPressed enclosesPointExpanded:currentPoint forModeNum:[thisWatch currentModeNum]]) {
	return;
    } else if (buttonPressed) {
	ECGLPartBase *part = [partFinder findClosestActivePartInWatch:[self currentWatch]
                                                                andBG:backgroundWatch
                                                              toPoint:currentPoint];
	if (part == buttonPressed) {
	    return;
	} else if ([thisWatch manualSet] || [thisWatch alarmManualSet] || [thisWatch flipping]) {
	    return;
	} else {
	    buttonPressed = nil;	// no longer in that button
	    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
	}
    } else {
	ECGLWatch *watch = [self currentWatch];
	if ((!displayingGrid && ([watch manualSet] || [watch alarmManualSet])) || [watch flipping] || ECSingleWatchProduct) {
	    return;
	}
    }
    [ChronometerAppDelegate hideECTimeLocationStatus];
    CGFloat dx = currentPoint.x - firstTouchPoint.x;
    [self ignoreRedrawRequests];
    if (displayingGrid) {
	[self handleTouchMoveIn2DGridWithDeltaX:dx];
    } else {
	[thisWatch handleTouchMoveWithDeltaX:dx forAdjacentIndex:0];
	//    [self setControlButtonVisibility:0 fade:ECSwipeControlFadeOffTime];
	int newAdjacentIndex;
	bool movingUp = false;
	if (dx < 0) {
	    movingUp = true;
	    newAdjacentIndex = currentWatchIndex + 1;
	    if (newAdjacentIndex == glWatchCount) {
		newAdjacentIndex = 0;
	    }
	} else if (dx > 0) {
	    newAdjacentIndex = currentWatchIndex - 1;
	    if (newAdjacentIndex < 0) {
		newAdjacentIndex = glWatchCount - 1;
	    }
	} else {
	    newAdjacentIndex = -1;
	}
	if (adjacentWatchIndex != newAdjacentIndex) {
	    if (adjacentWatchIndex >= 0) {
		[[self adjacentWatch] setVisible:false];
	    }
	    adjacentWatchIndex = newAdjacentIndex;
	    [[self adjacentWatch] setVisible:true];
	}
	if (adjacentWatchIndex >= 0 && glWatchCount > 1) {
	    ECGLWatch *adjacentWatch = [glWatches objectAtIndex:adjacentWatchIndex];
	    if (movingUp) {
		adjacentIsUp = true;
		[adjacentWatch handleTouchMoveWithDeltaX:dx forAdjacentIndex:1];
		[ChronometerAppDelegate showECStatusMessage:[NSString stringWithFormat:@"<- %@                     %@ ->", [thisWatch displayName], [adjacentWatch displayName]]];
	    } else {
		adjacentIsUp = false;
		[adjacentWatch handleTouchMoveWithDeltaX:dx forAdjacentIndex:-1];
		[ChronometerAppDelegate showECStatusMessage:[NSString stringWithFormat:@"<- %@                     %@ ->", [adjacentWatch displayName], [thisWatch displayName]]];
	    }
	}
    }
    [self unignoreRedrawRequests];
}

+ (void)touchEndedPossiblySwipingLeft:(bool)swipeLeft right:(bool)swipeRight press:(bool)press hold:(bool)hold at:(CGPoint)currentPoint count:(int)tapCount {
    if (stoppingAlarmRing || activeSwipeCancelled || animatingGrid) {
	buttonPressed = nil;
	if (activeSwipeCancelled && displayingGrid) {
	    [self handleSwipeReleaseIn2DGridWithAnimation:true];
	}
	return;
    }
    if (displayingGrid) {
	if (swipeLeft && !ECSingleWatchProduct) {
	    [self editorFlip];
	    [self handleSwipeLeftIn2DGrid];
	} else if (swipeRight && !ECSingleWatchProduct) {
	    [self editorFlip];
	    [self handleSwipeRightIn2DGrid];
	} else {
	    [self handleSwipeReleaseIn2DGridWithAnimation:false];
	    if (press) {  // Select a watch
		animatingGrid = true;
		[self unGridifyFromPressAtPoint:currentPoint]; // Should really be original point; the grid has moved with us
	    } else if (hold) {  // Copy/paste menu
		//printf("hold\n");
	    } else {  // Just go back to grid view
		//printf("release\n");
	    }
	}
	return;
    }
    bool saveButtonPressed = buttonPressed;
    ECGLWatch *watch = [self currentWatch];
    if (buttonPressed) {
	if ([buttonPressed immediate] || [buttonPressed repeatStrategy] != ECPartDoesNotRepeat) {
	    // already done
	} else if (([watch manualSet] || [watch alarmManualSet]) && [buttonPressed expanded] && [buttonPressed enclosesPointExpanded:currentPoint forModeNum:[watch currentModeNum]]) {
	    [buttonPressed act];
	} else {
	    ECGLPartBase *part = [partFinder findClosestActivePartInWatch:[self currentWatch]
                                                                    andBG:backgroundWatch
                                                                  toPoint:currentPoint];
	    if (part == buttonPressed) {
		// up in the same button as down
		if (![part drags]) {
		    [buttonPressed act];
		}
	    } else if ([watch manualSet] || [watch alarmManualSet] || [watch flipping]) {
		// do nothing
	    } else {
		// it's a swipe after all
		saveButtonPressed = false;
	    }
	}
	buttonPressed = nil;
	[self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    }
    if (draggingPart) {
	[draggingPart dragComplete];
	draggingPart = nil;
	animationOverrideInterval = 0;
	return;
    } else if (repeatingPartTimer) {
	[self cancelRepeatingPartTimers];
	return;
    } else if (saveButtonPressed) {
	return;
    } else {
	if (adjacentWatchIndex != -1) {
	    [ChronometerAppDelegate showECStatusMessage:[watch displayName]];
	} else {
	    switch (tapCount) {
		case 1:
		    [self toggleECStatusNameDisplay];
		    break;
		case 2:
		    break;
		default:
		    ; // ignore third and subsequent taps
	    }
	    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
	}
	if ([watch manualSet] || [watch alarmManualSet] || [watch flipping]) {
	    return;
	}
    }
    ECGLWatch *thisWatch = [glWatches objectAtIndex:currentWatchIndex];
    if (swipeLeft && glWatchCount > 1) {
	[self nextWatch];
    } else if (swipeRight && glWatchCount > 1) {
	[self previousWatch];
    } else {
	[thisWatch handleTouchReleaseWithoutSwipeForAdjacentIndex:0];
	if (adjacentWatchIndex >= 0  && glWatchCount > 1) {
	    ECGLWatch *adjacentWatch = [glWatches objectAtIndex:adjacentWatchIndex];
	    if (adjacentIsUp) {
		[adjacentWatch handleTouchReleaseWithoutSwipeForAdjacentIndex:1];
	    } else {
		[adjacentWatch handleTouchReleaseWithoutSwipeForAdjacentIndex:-1];
	    }
	    adjacentWatchIndex = -1;
	    [ChronometerAppDelegate showECStatusMessage:[thisWatch displayName]];
	}
    }
}

+ (void)addObserver:(id)observer significantTimeChangeSelector:(SEL)significantTimeChangeSelector {
    [observer retain];
    ChronometerAppDelegateObserverDescriptor *descriptor = [[ChronometerAppDelegateObserverDescriptor alloc] init];
    descriptor.observer = observer;
    descriptor.significantTimeChangeSelector = significantTimeChangeSelector;
    [observers setObject:descriptor forKey:[ECAddressKey keyForAddress:observer]];
    [descriptor release];
}

+ (void)removeObserver:(id)observer {
    [observers removeObjectForKey:[ECAddressKey keyForAddress:observer]];
    [observer release];
}

+ (void)addReallySignficantObserver:(id)observer significantTimeChangeSelector:(SEL)significantTimeChangeSelector {
    [observer retain];
    ChronometerAppDelegateObserverDescriptor *descriptor = [[ChronometerAppDelegateObserverDescriptor alloc] init];
    descriptor.observer = observer;
    descriptor.significantTimeChangeSelector = significantTimeChangeSelector;
    [reallySignificantObservers setObject:descriptor forKey:[ECAddressKey keyForAddress:observer]];
    [descriptor release];
}

+ (void)removeReallySignificantObserver:(id)observer {
    [reallySignificantObservers removeObjectForKey:[ECAddressKey keyForAddress:observer]];
    [observer release];
}

- (void)applicationSignificantTimeChange:(UIApplication *)application {
    // seems to happen about 5 seconds after midnight
    // supposed to happen for DST and timezone changes
    //   and time of day updates from the carrier
    [ECAppLog log:@"appSigTimChg"];
#ifndef NDEBUG
#ifndef EC_CWH_ANDROID
    [ChronometerAppDelegate noteTimeAtPhase:"applicationSignificantTimeChange"];
#endif
#endif
    [TSTime applicationSignificantTimeChange];
    // Tell all observers
    for (ECAddressKey *addressKey in observers) {
	ChronometerAppDelegateObserverDescriptor *descriptor = [observers objectForKey:addressKey];
	if (descriptor.significantTimeChangeSelector) {
	    [descriptor.observer performSelector:descriptor.significantTimeChangeSelector withObject:application];
	}
    }
    ESCalendar_localTimeZoneChanged();
    [ECOptions autoTZUpdate];
    [ChronometerAppDelegate forceUpdateInMainThread];  // In case there was a tz change
}

#ifdef EC_HENRY
static void checkHenryForWatch(NSString *name,
			       bool     isLastWatch) {
    if (!isLastWatch) {
	NSString *watchArchiveDirectory = [ECbundleArchiveDirectory stringByAppendingPathComponent:name];
	BOOL isDirectory;
	if ([ECfileManager fileExistsAtPath:watchArchiveDirectory isDirectory:&isDirectory]) {
	    assert(isDirectory);
	    if ([ECfileManager fileExistsAtPath:[watchArchiveDirectory stringByAppendingPathComponent:@"archive.dat"]] &&
		[ECfileManager fileExistsAtPath:[watchArchiveDirectory stringByAppendingPathComponent:@"variable-names.txt"]] &&
		[ECfileManager fileExistsAtPath:[watchArchiveDirectory stringByAppendingPathComponent:@"front-atlas-Z0.png"]] &&
		[ECfileManager fileExistsAtPath:[watchArchiveDirectory stringByAppendingPathComponent:@"back-atlas-Z0.png"]] &&
		[ECfileManager fileExistsAtPath:[watchArchiveDirectory stringByAppendingPathComponent:@"night-atlas-Z0.png"]]) {
		return;
	    }
	}
    }
    [ChronometerAppDelegate ensureWatchLoadedInHenry:name];
}
#endif


static NSString *lastWatchName;
static NSString *documentDirectoryName;
static NSArray *watchSortOrderDefaults;
static NSString *firstVersionRun;
bool isNewbie;

+ (bool)firstRun {
    return shouldShowQuickStart;
}

static void calculateDefaultWeekdayStart() {
    NSString *locale = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    if (locale) {
        if ([locale caseInsensitiveCompare:@"us"] == NSOrderedSame ||
            [locale caseInsensitiveCompare:@"ca"] == NSOrderedSame ||
            [locale caseInsensitiveCompare:@"mx"] == NSOrderedSame) {
            ECCalendarWeekdayStart = 0;
        } else {
            ECCalendarWeekdayStart = 1;
        }
        //printf("Setting default weekday start to %d via country code %s\n",
        //       ECCalendarWeekdayStart,
        //       [locale UTF8String]);
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:ECCalendarWeekdayStart]
                                                  forKey:@"ECCalendarWeekdayStart"];
        return;
    }
    ECCalendarWeekdayStart = 0; // Sunday by default (we have more US customers than any other country's)
    printf("Setting default weekday start to 0 (but not setting user defaults) because no country code\n");
}

static void setDefaultPropertiesForWatchName(NSMutableDictionary *defaultsDict,
					     NSString            *name,
					     BOOL                active) {

    [defaultsDict setObject:[NSDictionary dictionaryWithObjectsAndKeys:
					  [NSNumber numberWithBool:active], @"active",
					  nil]
		  forKey:[@"ECWatchProperty-" stringByAppendingString:name]];
}

- (bool)setupDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    firstVersionRun = [defaults objectForKey:@"ECFirstVersionRun"];
    NSString *thisVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (!firstVersionRun) {
	// First see if there's a lastWatch property -- if so, this user has run EC before
	//   (strictly speaking, maybe not, if they never switched watches before.  But in that case the use still qualifies as a newbie)
	NSString *defLastWatch = [defaults objectForKey:@"lastWatch"];
	if (defLastWatch) {
	    firstVersionRun = @"2.0.3";  // The last version which didn't set ECFirstVersionRun, in case that isn't set
	} else {
	    firstVersionRun = thisVersion;
	}
	[defaults setObject:firstVersionRun forKey:@"ECFirstVersionRun"];
	[defaults synchronize];
    }
    isNewbie = [firstVersionRun compare:thisVersion] == NSOrderedSame;
    // Protocol is:  Always register defaults in registration domain.  These will only get used if the user has not overridden.
    NSNumber *defaultABWarned  = [NSNumber numberWithBool:NO];
    NSNumber *defaultSatView  = [NSNumber numberWithBool:NO];
    NSNumber *defaultULS  = [NSNumber numberWithBool:YES];
    NSNumber *defaultDAL  = [NSNumber numberWithBool:NO];
    NSNumber *defaultDIMMER  = [NSNumber numberWithFloat:1.0];
#if 0
    NSNumber *defaultLatSpan  = [NSNumber numberWithFloat:1.0];
    NSNumber *defaultLongSpan  = [NSNumber numberWithFloat:2.0];
#endif
    NSNumber *defaultUNTP = [NSNumber numberWithBool:YES];
    NSNumber *defaultAutoTZ = [NSNumber numberWithBool:YES];
    NSNumber *defaultRED = [NSNumber numberWithDouble:0];
    NSNumber *defaultSlot = [NSNumber numberWithDouble:DEFAULT_ENVSLOT];
    NSNumber *defaultAlarmRings = [NSNumber numberWithDouble:ECAlarmTriangleRings];
    NSNumber *defaultAlarmRI = [NSNumber numberWithDouble:ECAlarmTriangleRepeat];
    NSNumber *defaultCalendarWeekdayStart = [NSNumber numberWithInt:-1];  // indicate we need to look up country code to initialize
#ifdef SHAREDCLOCK
    NSNumber *defaultUSC = [NSNumber numberWithBool:NO];
#endif
    NSArray *watchNameSortOrder = [NSArray arrayWithObjects:@"Alexandria",
				       			@"Atlantis",
							@"AtlantisIV",
							@"Babylon",
//							@"Cairo",
				       			@"Chandra",
				       			@"ChandraII",
							@"Firenze",
							@"Geneva",
							@"Haleakala",
							@"Hernandez",
							@"Istanbul",
							@"Kyoto",
							@"London",
				       			@"Mauna Kea",
				       			@"McAlester",
							@"Miami",
						        @"Milano",
							@"Neuchatel",
							@"Olympia",
							@"Paris",
							@"Terra",
							@"Thebes",
							@"Tombstone",
							@"Uraniborg",
							@"Vienna",
							nil ];
    NSString *defaultLastWatch =
        @"Alexandria";
    NSMutableDictionary *defaultsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 defaultLastWatch,  @"lastWatch",
								 defaultABWarned,   @"ECABWarned",
								 //defaultLatSpan,  @"ECLatSpan",
								 //defaultLongSpan, @"ECLongSpan",
								 ECAlarmTriangle,   @"ECAlarmName",
								 defaultAlarmRings, @"ECAlarmRings",
								 defaultAlarmRI,    @"ECAlarmRepeatInterval",
								 defaultSatView,    @"ECSatView",
								 defaultULS,	    @"ECUseLocationServices",
							         defaultDAL,	    @"ECDisableAutoLock",
								 defaultUNTP,	    @"ECUseNTP",
								 defaultAutoTZ,	    @"ECAutoTZ",
								 @"",		    @"ECCurrentCity",
					 			 @"",		    @"ECCurrentRegion",
								 defaultRED,	    @"ECRedOverlay",
								 defaultDIMMER,	    @"ECDimmerSetting",
								 defaultSlot,	    @"Terra-VMVariable-0",
                                                                 defaultCalendarWeekdayStart, @"ECCalendarWeekdayStart",
#ifdef SHAREDCLOCK
								 defaultUSC,	    @"ECUseSharedClock",
#endif
								 firstVersionRun,   @"ECFirstVersionRun",
							         watchNameSortOrder,@"ECWatchSortOrder",
							         nil ];
    setDefaultPropertiesForWatchName(defaultsDict, @"Alexandria", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Atlantis", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"AtlantisIV", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Babylon", YES);
    //    setDefaultPropertiesForWatchName(defaultsDict, @"Cairo", NO);
    setDefaultPropertiesForWatchName(defaultsDict, @"Chandra", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"ChandraII", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Firenze", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Geneva", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Haleakala", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Hernandez", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Istanbul", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Kyoto", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"London", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Mauna Kea", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"McAlester", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Miami", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Milano", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Neuchatel", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Olympia", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Paris", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Terra", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Thebes", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Tombstone", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Uraniborg", YES);
    setDefaultPropertiesForWatchName(defaultsDict, @"Vienna", YES);
    [defaults registerDefaults:defaultsDict];
    
    // Now that we've registered the defaults so we know they're there, go get the ones according to the lookup rules
    lastWatchName = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastWatch"];
    assert(lastWatchName);
    [lastWatchName retain];
    watchSortOrderDefaults = [[defaults objectForKey:@"ECWatchSortOrder"] retain];

    ECCalendarWeekdayStart = [defaults integerForKey:@"ECCalendarWeekdayStart"];
    if (ECCalendarWeekdayStart != 0 &&
        ECCalendarWeekdayStart != 1 &&
        ECCalendarWeekdayStart != 6) {
        calculateDefaultWeekdayStart();
    }

    bool showQuickStart = false;
    NSString *lastVersion = [defaults objectForKey:@"ECVersionMsg"];
    if (lastVersion) {
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	if (version) {
	    if ([version compare:lastVersion] != NSOrderedSame) {
		showQuickStart = true;
	    }
#if 0  // We might want this again later
            if (([lastVersion compare:@"3.7"] == NSOrderedSame || [lastVersion compare:@"3.7.1"] == NSOrderedSame || [lastVersion compare:@"3.7.2"] == NSOrderedSame) &&
                [version compare:@"3.7.3"] == NSOrderedSame) {
                showQuickStart = false;
            }
#endif
	}
    } else {
	showQuickStart = true;
    }
    
    // releases prior to 3.0 used a string value ECUseLocationServices; convert that to a bool now
    NSString *useLS = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECUseLocationServices"];
    if (useLS && [useLS caseInsensitiveCompare:@"Use"] == NSOrderedSame) {
	[[NSUserDefaults standardUserDefaults] setBool:true forKey:@"ECUseLocationServices"];
	tracePrintf("converted pre-3.0 value for ECUseLocationServices to  True");
    } else if (useLS && [useLS caseInsensitiveCompare:@"Ignore"] == NSOrderedSame) {
	[[NSUserDefaults standardUserDefaults] setBool:false forKey:@"ECUseLocationServices"];
	tracePrintf("converted pre-3.0 value for ECUseLocationServices to False");
    }
    
    return showQuickStart;
}

static void
saveWatchDefaults() {
    NSMutableArray *watchNameSortOrder = [NSMutableArray arrayWithCapacity:[availableWatches count]];
    for (ECGLWatch *watch in availableWatches) {
	[watchNameSortOrder addObject:[watch name]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
								       [NSNumber numberWithBool:[watch active]], @"active",
								       nil]
					       forKey:[@"ECWatchProperty-" stringByAppendingString:[watch name]]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:watchNameSortOrder forKey:@"ECWatchSortOrder"];
}

+(void)showQuickStart {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *version = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionSummaryString = NSLocalizedString(@"This app will be removed from the store on Dec 15 2023.\n\nIt also includes some new watches from the developers' workbench.\n\nPlease read the Details via the button below.", @"Version 2.3.5 first-run alert summary");
    NSString *quickStartButtonText = NSLocalizedString(@"Details", @"Details about Emerald Sequoia shutdown");
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"WARNING", @"WARNING")
                                                                   message:[NSString stringWithFormat:versionSummaryString, version]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    // Details
    UIAlertAction* quickStartAction = [UIAlertAction actionWithTitle:quickStartButtonText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) { 
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://emeraldsequoia.com/esblog/2022/12/21/emerald-sequoias-future/"] options:@{} completionHandler:NULL];
    }];
    [alert addAction:quickStartAction];
    // Later
    UIAlertAction* laterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Later", @"First-run alert button to skip release notes for now")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) { 
        // Do nothing
    }];
    [alert addAction:laterAction];
    // Never
    UIAlertAction* neverAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Never", @"First-run alert button to permanently skip release notes")
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) { 
        // set the default, don't show again
        [[NSUserDefaults standardUserDefaults] setObject:version forKey:@"ECVersionMsg"];
        [[NSUserDefaults standardUserDefaults] synchronize];  // make sure we get written to disk (helpful for poor developers)
    }];
    [alert addAction:neverAction];

    [theRootViewController presentViewController:alert animated:YES completion:nil];
}

static void checkDates(ESTimeZone *estz) {
#ifndef NDEBUG
    for (int i = 4000; i > 0; i--) {
	// Expect proleptic Julian
	NSTimeInterval now;
	NSTimeInterval nextYear;
	ESDateComponents cs;
	cs.era = 0;
	cs.year = i;
	cs.month = 1;
	cs.day = 1;
	cs.hour = 12;
	cs.minute = 0;
	cs.seconds = 0;
	if (estz) {
	    now = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	    cs.year = i-1;
	    nextYear = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	} else {
	    now = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	    cs.year = i-1;
	    nextYear = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	}
	double numSecondsInYear = nextYear - now;
	double numDaysInYear = numSecondsInYear / 3600 / 24;
	int predictedNumDaysInYear = (i-1) % 4 ? 365 : 366;
	if (predictedNumDaysInYear != (int)rint(numDaysInYear)) {
	    printf("Year BCE %04d: predicted %d days in year, got %.2f\n", i, predictedNumDaysInYear, numDaysInYear);
	    //assert(false);
	}
	ESDateComponents csReturn;
	if (estz) {
	    ESCalendar_localDateComponentsFromTimeInterval(now, estz, &csReturn);
	} else {
	    ESCalendar_UTCDateComponentsFromTimeInterval(now, &csReturn);
	}
	assert(i == csReturn.year);
	assert(1 == csReturn.month);
	assert(1 == csReturn.day);
	assert(0 == csReturn.era);
	//printf("Year BCE %04d: %.2f days, back out as %d %04d-%02d-%02d.  Delta from Jan 1 of this year: %d %04d-%02d-%02d\n",
	//i, numDaysInYear,
	//thiscs.era, thiscs.year, thiscs.month, thiscs.day,
	//deltacs.era, deltacs.year, deltacs.month, deltacs.day);
    }
    for (int i = 1; i < 1582; i++) {
	// Expect Julian
	NSTimeInterval now;
	NSTimeInterval nextYear;

	ESDateComponents cs;
	cs.era = 1;
	cs.year = i;
	cs.month = 1;
	cs.day = 1;
	cs.hour = 12;
	cs.minute = 0;
	cs.seconds = 0;
	if (estz) {
	    now = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	    cs.year = i+1;
	    nextYear = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	} else {
	    now = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	    cs.year = i+1;
	    nextYear = ESCalendar_timeIntervalFromUTCDateComponents(&cs);
	}
	double numSecondsInYear = nextYear - now;
	double numDaysInYear = numSecondsInYear / 3600 / 24;
	int predictedNumDaysInYear = i % 4 ? 365 : 366;
	if (predictedNumDaysInYear != (int)rint(numDaysInYear)) {
	    printf("Year CE %04d: predicted %d days in year, got %.2f\n", i, predictedNumDaysInYear, numDaysInYear);
	    //assert(false);
	}
	ESDateComponents csReturn;
	if (estz) {
	    ESCalendar_localDateComponentsFromTimeInterval(now, estz, &csReturn);
	} else {
	    ESCalendar_UTCDateComponentsFromTimeInterval(now, &csReturn);
	}
	if (estz) {
	    ESCalendar_localDateComponentsFromTimeInterval(now, estz, &csReturn);
	} else {
	    ESCalendar_UTCDateComponentsFromTimeInterval(now, &csReturn);
	}
	assert(i == csReturn.year);
	assert(1 == csReturn.month);
	assert(1 == csReturn.day);
	assert(1 == csReturn.era);
	//printf("Year BCE %04d: %.2f days, back out as %d %04d-%02d-%02d.  Delta from Jan 1 of this year: %d %04d-%02d-%02d\n",
	//i, numDaysInYear,
	//thiscs.era, thiscs.year, thiscs.month, thiscs.day,
	//deltacs.era, deltacs.year, deltacs.month, deltacs.day);
    }
#endif
}

static bool inBackground = false;
#define ECBackgroundTextureSize (2 * 1024 * 1024);  // Enough for the largest single size Z0 atlas  (fix HD)
static size_t lastNonBackgroundTextureSize = 0;

static size_t ECMaxMaxTextureSize     = 24 * 1024 * 1024;
static size_t ECInitialMaxTextureSize = 24 * 1024 * 1024;
static size_t ECMinMaxTextureSize     = 6  * 1024 * 1024;
static size_t ECMemoryDecrementAmount = 6  * 1024 * 1024;
size_t ECMaxLoadedTextureSize = 0;

+ (bool)inBackground {
    return inBackground;
}

- (void)setBatteryMonitoringEnabled:(BOOL)enabled {  // Fake out compiler
}

- (void)beginGeneratingBatteryStateChangeNotifications { // Fake out compiler

}

+ (float)batteryLevel {
    UIDevice *dev = [UIDevice currentDevice];
    assert([dev respondsToSelector:@selector(batteryLevel)]);
    return [dev batteryLevel];
}
    
static const char *batteryStateNameForState(int batteryState) {
    char *stateName;
    switch (batteryState) {
      case 1:
	stateName = "unplugged";
	break;
      case 2:
	stateName = "charging";
	break;
      case 3:
	stateName = "full";
	break;
      default:
      case 0:
	stateName = "unknown";
	break;
    }
    return stateName;
}

static bool batteryStatesAreEquivalent(int batteryState1,
				       int batteryState2) {
    return
	batteryState1 == batteryState2
	|| (batteryState1 == 2 && batteryState2 == 3)  // Charging == Full
	|| (batteryState1 == 3 && batteryState2 == 2); // Full == Charging
}

- (int)batteryState {
    UIDevice *dev = [UIDevice currentDevice];
    assert([dev respondsToSelector:@selector(batteryState)]);
    return [dev batteryState];
}

static BOOL currentDAL;

+ (void)setDAL:(BOOL)newVal {
    assert([NSThread isMainThread]);
    currentDAL = newVal;
    [ECAppLog log:(newVal ? @"idleLock disabled" : @"idleLock enabled")];
    theApplication.idleTimerDisabled = !newVal;
    theApplication.idleTimerDisabled = newVal;
}

- (void)setDALHeartbeatFire:(NSTimer *)timer {
    if (currentDAL) {
	theApplication.idleTimerDisabled = !currentDAL;
	theApplication.idleTimerDisabled = currentDAL;
    }
}

- (void)setDALForBatteryState:(int) batteryState {
    //printf("power: %s\n", batteryStateNameForState(batteryState));
    [ECAppLog log:[NSString stringWithFormat:@"power: %s", batteryStateNameForState(batteryState)]];
    
    BOOL dalDefault;
    if (batteryState == 2 // charging
	|| batteryState == 3) { // full
	dalDefault = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECDisableAutoLock"];
    } else {
	dalDefault = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECDisableAutoLockUnplugged"];
    }
    [ChronometerAppDelegate setDAL:dalDefault];
}

- (void)setDALForBatteryState {
    [self setDALForBatteryState:[self batteryState]];
}

+ (void)setDALForBatteryState {
    [theAppDelegate setDALForBatteryState];
}

- (void)delayedSetDal:(NSTimer *)timer {
    [self setDALForBatteryState];
}

- (void)popUpBatteryState {
    const char *stateName = batteryStateNameForState([self batteryState]);
    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"The battery state is now %.2f '%s'", [ChronometerAppDelegate batteryLevel], stateName]];
}

static int lastBatteryState = -1;

- (void)batteryStateDidChange:(id)foo {
    int newState = [self batteryState];
    //[self popUpBatteryState];
    if (!batteryStatesAreEquivalent(newState,lastBatteryState)) {
	[self setDALForBatteryState:newState];
    }
    lastBatteryState = newState;
}

#undef EC_PROXIMITY
#ifdef EC_PROXIMITY
- (void)setProximityMonitoringEnabled:(BOOL)enabled { // Fake out compiler
}

- (BOOL)proximityState { // Fake out compiler with the name -- don't change it
    id dev = [UIDevice currentDevice];
    if ([dev respondsToSelector:@selector(proximityState)]) {
	return [dev proximityState];
    } else {
	return NO;
    }
}

- (void)proximityStateDidChange:(id)foo {
    BOOL closeToUser = [self proximityState];
    printf("Proximity sensor change to %s\n", closeToUser ? "CLOSE" : "NOT CLOSE");
}
#endif

- (void)delayedPrintMemoryUsage:(id)foo {
    [ChronometerAppDelegate printMemoryUsage:@"-----------"];
}

- (void)delayedSpecialPartInvalidate:(id)foo {
    [ECGLTextureAtlas invalidateSpecialParts];
}

static void setCurrentZ2(int curZ2) {
    assert(curZ2 <= ECZoomMaxLogicalPower2);
    assert(curZ2 <= ECZoomMaxPower2);
    assert(curZ2 >= ECZoomMinPower2);
    currentZ2 = curZ2;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:currentZ2] forKey:@"currentZ2"];
}

static void setCurrentZ2ForZoom(double zoom) {
    setCurrentZ2(z2ForZoom(zoom));
}

+ (void)setup2DGridWithAnimationInterval:(NSTimeInterval)animationInterval {
    [watchModeDescriptorLock lock];
    int numActiveWatches = [glWatches count];
    bool isLandscape = getCurrentOrientationIsLandscape();
    int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
    CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
    fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
    int watchIndex = 0;
    //CGPoint currentCellPosition = positions[currentWatchIndex];
    //for (int ii = 0; ii < numActiveWatches; ii++) {
    //    printf("%2d is (%.1f, %.1f)\n", ii, positions[ii].x, positions[ii].y);
    //}
    double zoom = zoomForCount(numActiveWatches);
    NSTimeInterval animationStartTime = [NSDate timeIntervalSinceReferenceDate];
    for (ECGLWatch *watch in glWatches) {
        [watch setPosition:CGPointMake(positions[watchIndex].x /* - currentCellPosition.x*/,
                                       positions[watchIndex].y /* - currentCellPosition.y*/)
                      zoom:zoom
        animationStartTime:animationStartTime
         animationInterval:animationInterval];
        watchIndex++;  // Don't try putting this in the expression with two references
    }
    displayingGrid = true;
    animatingGrid = true;
    setCurrentZ2ForZoom(zoom);
    //printf("setup2DGrid %s, zoom %.2f, Z2 %d\n", currentOrientationIsLandscape ? "LANDSCAPE" : "PORTRAIT", zoom, currentZ2);
    free(positions);
    sortWatchModeDescriptorArray(true);
    [watchModeDescriptorLock unlock];
    [ECGLWatchLoader checkForWork];
    zoomingIn = true;
    [self requestRedraw];
}

+ (void)setAllNoGridPositionsWithAnimationInterval:(NSTimeInterval)animationInterval oneDirectionOnly:(bool)oneDirectionOnly {
    [self ignoreRedrawRequests];
    int lastPositiveOffset = glWatchCount / 2;  // which is also the last time through the loop
    int lastNegativeOffset;
    //printf("setAllNoGridPositionsWithAnimationInterval with watch count %d\n", glWatchCount);
    if (glWatchCount % 2) {  // if odd
	lastNegativeOffset = -lastPositiveOffset;
    } else {
	lastNegativeOffset = -lastPositiveOffset + 1;
    }
    // First, determine (if necessary) which direction to restrict to by looking at (new) currentWatch
    bool movingUp = !oneDirectionOnly || [self currentWatch].drawCenter.x < 0;  // It will be zero, so if it's negative, it's moving up
    //printf("Current watch %s moving up %s\n", [[[self currentWatch] name] UTF8String], movingUp ? "true" : "false");
    double nogz = nogridZoom();
    NSTimeInterval animationStartTime = [NSDate timeIntervalSinceReferenceDate];
    CGFloat windowWidth = [ChronometerAppDelegate applicationSize].width;
    for (int positionOffset = 0; positionOffset <= lastPositiveOffset; positionOffset++) {
	int indx = indexAtOffsetPosition(positionOffset);
	ECGLWatch *watch = [glWatches objectAtIndex:indx];
        //printf("Placing %s at position %d\n", [[watch name] UTF8String], positionOffset);
        CGFloat newX = windowWidth * positionOffset;
        bool watchMovingUp = newX > watch.drawCenter.x;
        if (oneDirectionOnly && (watchMovingUp != movingUp)) {
            //printf("Watch %s doesnt't match movingUp, snapping\n", [[watch name] UTF8String]);
            [watch snapToPosition:positionOffset atZoom:nogz]; 
        } else {
            [watch scrollIntoPosition:positionOffset atZoom:nogz animationStartTime:animationStartTime animationInterval:animationInterval];
        }
        if (positionOffset != 0) {
            int negativeOffset = -positionOffset;
            if (negativeOffset >= lastNegativeOffset) {
                indx = indexAtOffsetPosition(negativeOffset);
                watch = [glWatches objectAtIndex:indx];
                //printf("Placing %s at position %d\n", [[watch name] UTF8String], negativeOffset);
                newX = windowWidth * negativeOffset;
                watchMovingUp = newX > watch.drawCenter.x;
                if (oneDirectionOnly && (watchMovingUp != movingUp)) {
                    //printf("Watch %s doesnt't match movingUp, snapping\n", [[watch name] UTF8String]);
                    [watch snapToPosition:negativeOffset atZoom:nogz]; 
                } else {
                    [watch scrollIntoPosition:negativeOffset atZoom:nogz animationStartTime:animationStartTime animationInterval:animationInterval];
                }
            }
        }
    }
    [self unignoreRedrawRequests];
}

ECGLWatch *switchToThisWatchWhenDoneAnimatingGrid = nil;

+ (void)unGridifyCommonToPosition:(CGPoint)newCellPosition numRows:(int)numRows newIndex:(int)newCurrentWatchIndex numActiveWatches:(int)numActiveWatches {
    //printf("Ungridifying to watch %s\n", [[[glWatches objectAtIndex:newCurrentWatchIndex] name] UTF8String]);
    assert(newCurrentWatchIndex >= 0 && newCurrentWatchIndex < [glWatches count]);
    [self setCurrentWatchNumber:newCurrentWatchIndex];
    displayingGrid = false;
    animatingGrid = true;   // Put this before the call to setAllNoGridPositions in case the latter turns it off because it's a 1-up grid
    [self setAllNoGridPositionsWithAnimationInterval:kECGLGridAnimationTime oneDirectionOnly:false];
}

+ (void)unGridifyToWatch:(ECGLWatch *)watch {
    assert([NSThread isMainThread]);
    if ([glWatches containsObject:watch]) {
	int numActiveWatches = [glWatches count];
        bool isLandscape = getCurrentOrientationIsLandscape();
	int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
	CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
	fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
	int newIndex = [watch activeIndex];
	assert(newIndex >= 0 && newIndex < numActiveWatches);
	assert([glWatches objectAtIndex:newIndex] == watch);
	[self unGridifyCommonToPosition:positions[[watch activeIndex]] numRows:numRows newIndex:newIndex numActiveWatches:numActiveWatches];
	free(positions);
    } else {  // given watch isn't active.  First get out of grid mode and then switch to it
	switchToThisWatchWhenDoneAnimatingGrid = watch;
	assert([glWatches containsObject:[self currentWatch]]); // detect infinite recursion
	[self unGridifyToWatch:[self currentWatch]];
    }
}

+ (void)unGridifyFromPressAtPoint:(CGPoint)gridSelectionPoint {
    int numActiveWatches = [glWatches count];
    bool isLandscape = getCurrentOrientationIsLandscape();
    int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
    CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
    fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
    gridSelectionPoint.x /= iPhoneScaleFactor;
    gridSelectionPoint.y /= iPhoneScaleFactor;
    double minSqDist = 1E100;
    int newCurrentWatchIndex = -1;
    for (int i = 0; i < numActiveWatches; i++) {
	CGPoint *pos = &positions[i];
	double sqdist = (pos->x - gridSelectionPoint.x) * (pos->x - gridSelectionPoint.x) + (pos->y - gridSelectionPoint.y) * (pos->y - gridSelectionPoint.y);
	if (sqdist < minSqDist) {
	    newCurrentWatchIndex = i;
	    minSqDist = sqdist;
	}
    }
    [self unGridifyCommonToPosition:positions[newCurrentWatchIndex] numRows:numRows newIndex:newCurrentWatchIndex numActiveWatches:numActiveWatches];
    free(positions);
}

static NSTimer *delayForceUpdateTimer = nil;
+ (void)delayedForceUpdateTimerFire:(NSTimer *)timer {
    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    delayForceUpdateTimer = nil;
}

+ (void)callForForceUpdateAfterDelay {
    if (delayForceUpdateTimer && [delayForceUpdateTimer isValid]) {
	return;  // Already one pending
    }
    delayForceUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(delayedForceUpdateTimerFire:) userInfo:nil repeats:false];
}

bool forceUpdateWhenZoomStops = false;

+ (void)doneAnimatingGrid {
    assert([NSThread isMainThread]);
    if (animatingGrid) {
	animatingGrid = false;
	[backgroundWatch setCurrentModeNum:[[self currentWatch] currentModeNum] zoomPower2:0 allowAnimation:false];
	[backgroundWatch prepareAllPartsForDrawForModeNum:[[self currentWatch] currentModeNum] atTime:[NSDate timeIntervalSinceReferenceDate] forcingUpdate:true allowAnimation:true dragType:ECDragNotDragging];
	if (displayingGrid) {
	    if (forceUpdateWhenZoomStops) {
		[self callForForceUpdateAfterDelay];
	    }
	} else {
	    setCurrentZ2(0);
	    sortWatchModeDescriptorArray(false);
	    [ECGLWatchLoader checkForWork];
	    [self showECStatusMessage:[[self currentWatch] displayName]];
	}
	if (switchToThisWatchWhenDoneAnimatingGrid) {
	    if (displayingGrid) {  // caught on the way *to* the grid, now reverse direction to get back out
		[self unGridifyToWatch:switchToThisWatchWhenDoneAnimatingGrid];
	    } else {
		[self switchToWatch:switchToThisWatchWhenDoneAnimatingGrid];
	    }
	    switchToThisWatchWhenDoneAnimatingGrid = nil;
	}
	zoomingIn = false;
    }
}

+ (void)forceUpdateWhenZoomStops {
    forceUpdateWhenZoomStops = true;
}

bool doneAnimatingGridWhenAllWatchesFinishDrawing = false;

+ (void)donePositionZoomAnimatingWhenAllWatchesFinishDrawing {
    doneAnimatingGridWhenAllWatchesFinishDrawing = true;
}

+ (void)setAll2DGridPositions {
    bool isLandscape = getCurrentOrientationIsLandscape();
    //printf("setAll2DGridPositions %s\n", isLandscape ? "LANDSCAPE" : "PORTRAIT");
    int numActiveWatches = [glWatches count];
    int numRows = (isLandscape ? gridRowsForWatchCountLandscape : gridRowsForWatchCountPortrait)[numActiveWatches - 1];
    CGPoint *positions = (CGPoint*)malloc(numActiveWatches * sizeof(CGPoint));
    fillInGridPositions(numRows, numActiveWatches, isLandscape, positions);
    //double zoom = isLandscape ? zoomsForLandscape[numActiveWatches - 1] : 1.0/numRows;
    double zoom = zoomForCount(numActiveWatches);
    //printf("Zoom is %g\n", zoom);
    setCurrentZ2ForZoom(zoom);
    //printf("currentZ2 is %d\n", currentZ2);
    int watchIndex = 0;
    CGFloat correctedX = 0;
    if (gridOffsetForEditor != 0) {
	if (currentZ2 < 0) {
	    correctedX = gridOffsetForEditor * (1 << (-currentZ2));
	} else {
	    correctedX = gridOffsetForEditor * (1 << currentZ2);
	}
    }
    [self ignoreRedrawRequests];
    for (ECGLWatch *watch in glWatches) {
	if (correctedX) {
	    CGPoint pos = positions[watchIndex++];
	    pos.x += correctedX;
	    [watch handle2DTouchMoveTo:pos];
	} else {
	    [watch handle2DTouchMoveTo:positions[watchIndex++]];
	}
	[watch setZoom:zoom];
    }
    [self unignoreRedrawRequests];
    free(positions);
}

+ (void)unsetAll2DGridPositions {
    assert(currentZ2 == 0);
    currentZ2 = 0;  // Shouldn't be necessary; we only call this from the editor when we aren't in grid mode
    [self ignoreRedrawRequests];
    [self setAllNoGridPositionsWithAnimationInterval:kECGLGridAnimationTime oneDirectionOnly:false];
    [self unignoreRedrawRequests];
}

#ifdef ECDIMMER
+ (double)dimmerValue {
    return dimmerLabel.layer.opacity;
}

+ (double)setDimmer:(double)val {
#define maxStop 10
    assert(0 <= val && val <= 1);
    double roundedVal = round(val * maxStop) / maxStop;
    val = exp2((roundedVal-1) * maxStop / 2);
    dimmerCover.layer.opacity = 1.0 - val;
    dimmerLabel.layer.opacity = roundedVal;
    [[NSUserDefaults standardUserDefaults] setDouble:roundedVal forKey:@"ECDimmerSetting"];
    return roundedVal;
}

+ (void)clearDimmerLabel {
    dimmerLabel.text = @"";
    dimmerLabel.layer.opacity = 0;
}
#endif

#ifndef NDEBUG
- (void)testLocationData:(id)foo {
    ECLocationManager *locMgr = [ECLocationManager theLocationManager];
    float latit = [locMgr lastLatitudeDegrees];
    float longit = [locMgr lastLongitudeDegrees];
    ECGeoNames *geoNames = [[ECGeoNames alloc] init];
    [geoNames findClosestCityToLatitudeDegrees:latit longitudeDegrees:longit];
    NSString *cityName = [geoNames selectedCityName];
    NSString *tzName = [geoNames selectedCityTZName];
    printf("Found city %s with time zone %s\n", [cityName UTF8String], [tzName UTF8String]);
    [geoNames release];
}
- (void)testLocationSearchInternal:(NSString *)searchString {
    ECGeoNames *geoNames = [[ECGeoNames alloc] init];
    [geoNames searchForCityNameFragment:searchString withProximity:true];
    printf("Matching city name '%s'\n", [searchString UTF8String]);
    for (int i = 0; i < 30; i++) {
	NSString *name = [geoNames topCityNameAtIndex:i];
	if (name) {
	    [geoNames selectNthTopCity:i];
	    NSString *regionName = [geoNames selectedCityRegionName];
	    printf("%s, %s\n", [name UTF8String], [regionName UTF8String]);
	} else {
	    printf("no more matches\n");
	    break;
	}
    }
    [geoNames release];
}
- (void)printBestCityForEachTZSlot {
    ECGeoNames *geoNames = [[ECGeoNames alloc] init];
    for (int i = -12; i <= 12; i++) {
	int i2 = i < 0 ? i + 1 : i;
	printf("For slot %d, GMT%s%d:00, centered at %s%d:30:\n",
	       i,
	       i < 0 ? "" : "+",
	       i,
	       i2 < 0 ? "" : "+",
	       i2);
	[geoNames searchForCityNameFragment:@"" appropriateForNominalTZSlot:i];
	for (int j = 0; j < 30; j++) {
	    NSString *name = [geoNames topCityNameAtIndex:j];
	    if (name) {
		[geoNames selectNthTopCity:j];
		NSString *regionName = [geoNames selectedCityRegionName];
		ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([[geoNames selectedCityTZName] UTF8String]);
		NSTimeInterval now = [TSTime currentTime];
		NSInteger currentOffset = ESCalendar_tzOffsetForTimeInterval(estz, now);
		assert((currentOffset % 60) == 0);
		NSTimeInterval nextTransition = ESCalendar_nextDSTChangeAfterTimeInterval(estz, now);
		if (nextTransition) {
		    NSInteger postTransitionOffset = ESCalendar_tzOffsetForTimeInterval(estz, nextTransition + 7200);
		    if (postTransitionOffset < currentOffset) {
			NSInteger tmp = postTransitionOffset;
			postTransitionOffset = currentOffset;
			currentOffset = tmp;
		    }
		    printf("... %s, %s (population %lu) TZ %s offset %s%g => %s%g\n", [name UTF8String], [regionName UTF8String], [geoNames selectedCityPopulation],
			   ESCalendar_timeZoneName(estz),
			   currentOffset < 0 ? "" : "+",
			   currentOffset / 3600.0,
			   postTransitionOffset < 0 ? "" : "+",
			   postTransitionOffset / 3600.0);
		} else {
		    printf("... %s, %s (population %lu) TZ %soffset %s%g\n", [name UTF8String], [regionName UTF8String], [geoNames selectedCityPopulation],
			   ESCalendar_timeZoneName(estz),
			   currentOffset < 0 ? "" : "+",
			   currentOffset / 3600.0);
		}
		ESCalendar_releaseTimeZone(estz);
	    } else {
		printf("no more matches\n");
	    }
	}
    }
    [geoNames release];
}

- (void)testLocationSearch:(id)foo {
    [self testLocationSearchInternal:@"SFO"];
    [self testLocationSearchInternal:@"STL"];
    [self testLocationSearchInternal:@"BKK"];
    [self testLocationSearchInternal:@"CHI"];
}
#endif

NSTimer *DSTEventTimer = nil;

+ (void)DSTEvent:(NSTimer *)timer {
    assert([NSThread isMainThread]);
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [self setupDSTEventTimer];
}

+ (void)setupDSTEventTimer {
    if ([DSTEventTimer isValid]) {
	[DSTEventTimer invalidate];
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval nextEvent = ECFarInTheFuture;
    for (ECGLWatch *watch in glWatches) {
	NSTimeInterval nextWatchEvent = [watch nextDSTTransition];
	if (nextWatchEvent < nextEvent) {
	    nextEvent = nextWatchEvent;
	}
    }
    if (nextEvent == ECFarInTheFuture) {  // All watches are stopped
	//nextEvent = now + 3600;  // Try again in an hour?  Shouldn't be necessary...
    }
#if 0
    ECGLWatch *watch = [self currentWatch];  // Note: Isn't really right, since we don't know which watch triggered the next update
    if ([watch loaded] && [watch numEnvironments] > 0) {
	ESTimeZone *estz = [[watch enviroWithIndex:0] timeZone];
	ECWatchTime *watchTime = [watch mainTime];
	printf("\nNext DST event (in iPhone time): ");  printADate(nextEvent); printf("; and in watch time: "); printADateWithTimeZone([watchTime convertFromIPhoneToWatch:nextEvent], estz); printf("\n");
	printf(  "           Now (in iPhone time): ");  printADate(now);       printf("; and in watch time: "); printADateWithTimeZone([watchTime convertFromIPhoneToWatch:now], estz); printf("\n");
    } else {
	printf("Next DST event (in iPhone time): ");  printADate(nextEvent); printf("\n");
	printf("           Now (in iPhone time): ");  printADate(now);       printf("\n");
    }
    printf("nextEvent %25.4f\n", nextEvent);
    printf("now       %25.4f\n", now);
    printf("delta     %25.4f\n", nextEvent - now);
    fflush(stdout);
#endif
    assert (nextEvent >= now);
    DSTEventTimer = [NSTimer scheduledTimerWithTimeInterval:(nextEvent - now) target:self selector:@selector(DSTEvent:) userInfo:nil repeats:false];
}

+ (void)notifyTimeAdjustment {
    assert([NSThread isMainThread]);
    [self setupDSTEventTimer];
    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

#ifdef EC_HENRY
- (bool)shouldSkipWatch:(NSString *)name {  // return true iff this watch should NOT be read this time
    if (!approvalsArray) {
	NSString *approvalsFileName = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Watches"] stringByAppendingPathComponent:@"Approvals.txt"];
	NSString *approvalsString = [NSString stringWithContentsOfFile:approvalsFileName encoding:NSUTF8StringEncoding error:nil];
	assert(approvalsString);
	approvalsArray = [approvalsString componentsSeparatedByString:@"\n"];
	NSString *watchesFile = [ECbundleProductDirectory stringByAppendingPathComponent:@"watches.txt"];
	NSString *enabledString = [NSString stringWithContentsOfFile:watchesFile encoding:NSUTF8StringEncoding error:nil];
	assert(enabledString);
	assert(!enabledArray);
	enabledArray = [enabledString componentsSeparatedByString:@"\n"];
    }
    if (![enabledArray containsObject:name]) {
	//printf("Skipping unenabled watch %s\n", [name UTF8String]);
	return true;  // Skip it if it's not in the list at all
    }
    // const char *userName = getenv("USER");
    // assert(userName != NULL);
    // NSString *user = [NSString stringWithUTF8String:userName];
    NSString *user = sendCommandToCommandServer("/usr/bin/printenv USER");
    if ([user hasSuffix:@"\n"]) {
        user = [user substringToIndex:([user length] - 1)];
    }
    // printf("Got back user '%s' from command server\n", [user UTF8String]);
    assert(user && [user length] > 0);
    for (NSString *line in approvalsArray) {
	NSArray *words = [line componentsSeparatedByString:@"\t"];
	if ([[words objectAtIndex:0] caseInsensitiveCompare:name] == NSOrderedSame) {
	    NSString *approval = [[words lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	    if ([approval caseInsensitiveCompare:@"yes"] == NSOrderedSame ||
		[approval caseInsensitiveCompare:user] == NSOrderedSame) {
		return false;
	    }
	    break;
	}
    }
    return true;
}
#endif

- (void)determineHardware {
    //[ChronometerAppDelegate noteTimeAtPhase:"determineHardware start"];
    size_t size;
 
    // Set 'oldp' parameter to NULL to get the size of the data
    // returned so we can allocate appropriate amount of space
    sysctlbyname("hw.machine", NULL, &size, NULL, 0); 
 
    // Allocate the space to store name
    char *name = malloc(size);
 
    // Get the platform name
    sysctlbyname("hw.machine", name, &size, NULL, 0);
 
    isFirstGenerationHardware =
	strcmp(name, "iPhone1,1") == 0 ||
	strcmp(name, "iPhone1,2") == 0 ||
	strcmp(name, "iPod1,1") == 0 ||
	strcmp(name, "iPod1,2") == 0;

    // Done with this
    free(name);
    //[ChronometerAppDelegate noteTimeAtPhase:"determineHardware finish"];
}

+ (int)maxZoomIndex {
    return maxZoomIndex;
}

+ (void)listLocalNotifications {
    [[UNUserNotificationCenter currentNotificationCenter]
        getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
            printf("=== Local notifications:\n");
            for (UNNotificationRequest *request in requests) {
                UNNotificationContent *content = request.content;
                UNNotificationTrigger *trigger = request.trigger;
                NSDictionary *userInfo = content.userInfo;
                NSString *notificationWatchName = [userInfo objectForKey:@"watch"];
                if (!notificationWatchName) {
                    notificationWatchName = @"<none>";
                }
                if ([trigger isKindOfClass:[UNCalendarNotificationTrigger class]]) {
                    UNCalendarNotificationTrigger *calendarTrigger = (UNCalendarNotificationTrigger *)trigger;
                    printf("... Calendar %s, (%s) title: '%s' subtitle: '%s' body: '%s'\n",
                           [[[calendarTrigger nextTriggerDate] description] UTF8String],
                           [notificationWatchName UTF8String],
                           [content.title UTF8String], [content.subtitle UTF8String], [content.body UTF8String]);
                } else if ([trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]]) {
                    UNTimeIntervalNotificationTrigger *intervalTrigger = (UNTimeIntervalNotificationTrigger *)trigger;
                    printf("... Interval %s, (%s) title: '%s' subtitle: '%s' body: '%s'\n",
                           [[[intervalTrigger nextTriggerDate] description] UTF8String],
                           [notificationWatchName UTF8String],
                           [content.title UTF8String], [content.subtitle UTF8String], [content.body UTF8String]);
                } else {
                    printf("...unknown trigger type %s, (%s) title: '%s' subtitle: '%s' body: '%s'\n",
                           [NSStringFromClass([trigger class]) UTF8String],
                           [notificationWatchName UTF8String],
                           [content.title UTF8String], [content.subtitle UTF8String], [content.body UTF8String]);
                }
            }
            printf("=== End local notifications\n");
        }
     ];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {  // <-------- this is the main initialization entry point -----------
    theAppDelegate = self;
    theApplication = application;
    UNUserNotificationCenter *notification_center = [UNUserNotificationCenter currentNotificationCenter];
    [notification_center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (error) {
                                  NSLog(@"notification request authorization failed!");
                              } else {
                                  NSLog(@"notification request authorization succeeded!");
                              }
                          }];

    maxZoomIndex = getMaxZoomIndex();
#if 0
    printf("Startup:\n");
    [ChronometerAppDelegate listLocalNotifications];
#endif

#if 0
    for (UIScreen *screen in [UIScreen screens]) {
	printf("Screen: bounds (in points) %.1f by %.1f origin (%1.f, %.1f) scale %.1f. Available modes:\n",
	       screen.bounds.size.width,
	       screen.bounds.size.height,
	       screen.bounds.origin.x,
	       screen.bounds.origin.y,
	       screen.scale);
	for (UIScreenMode *mode in screen.availableModes) {
	    printf("  mode: %.1f by %.1f (pixels), pixel aspect ratio %.3f\n",
		   mode .size.width,
		   mode.size.height,
		   mode.pixelAspectRatio);
	}
    }
#endif

#undef TEST_ESCAL
#ifdef TEST_ESCAL
    ESTestCalendar();
#endif

#ifndef NDEBUG
#ifndef EC_CWH_ANDROID
    [ChronometerAppDelegate noteTimeAtPhase:"applicationDidFinishLaunching start"];
#endif
#endif
    [ECAppLog log:[[NSBundle mainBundle] bundleIdentifier]];  // Distinguish between EC and ECHD
    UIScreen *mainScreen = [UIScreen mainScreen];
    screenScale = [mainScreen scale];
    printf("screen scale returns %.2f\n", screenScale);
    printf("native screen scale returns %.2f\n", [mainScreen nativeScale]);
    printf("bounds:       %g x %g\n", mainScreen.bounds.size.width, mainScreen.bounds.size.height);
    printf("nativeBounds: %g x %g\n", mainScreen.nativeBounds.size.width, mainScreen.nativeBounds.size.height);
#ifndef NDEBUG
    // printf("screenScale is %.2f\n", screenScale);
    // [ChronometerAppDelegate printBounds];
#endif
    screenScaleZoomTweak = zoomTweakForScreenScale(screenScale);
    if (isIpad()) {
        screenScaleZoomTweak++;
    }
#ifndef NDEBUG
    // printf("screenScaleZoomTweak is %d\n", screenScaleZoomTweak);
#endif

    ssize_t availableRAM = realMemoryAvailableOnDevice();
#ifndef NDEBUG
    // printf("hardware RAM: %zd MB\n", availableRAM / (1024*1024));
#endif
    if (availableRAM > 200 * 1024 * 1024) {
	if (screenScaleZoomTweak != 0) {
            if (screenScaleZoomTweak >= 2) {
                printf("Setting 96 MB minimum atlas memory for Retina iPad\n");
                ECMinMaxTextureSize =   96 * 1024 * 1024;  // Enough to display a 64-MB (4096x4096) Z2 archive and the 32-MB "hacked" iPad bg (4096x2048)
            } else {
                ECMinMaxTextureSize =   32 * 1024 * 1024;  // Enough to display a 16-MB (2048x2048) Z1 archive and the 16-MB "hacked" iPad bg
            }
	}
        ECMemoryDecrementAmount =  32 * 1024 * 1024;
        if (availableRAM > 800 * 1024 * 1024) {
            ECMaxMaxTextureSize =     256 * 1024 * 1024;
            ECInitialMaxTextureSize = 256 * 1024 * 1024;
	} else if (availableRAM > 300 * 1024 * 1024) {
            ECMaxMaxTextureSize =     128 * 1024 * 1024;
            ECInitialMaxTextureSize = 128 * 1024 * 1024;
        } else {
            ECMaxMaxTextureSize =      64 * 1024 * 1024;
            ECInitialMaxTextureSize =  64 * 1024 * 1024;
        }
#ifndef NDEBUG
	// printf("starting with : %d MB\n", (int)ECInitialMaxTextureSize / (1024*1024));
#endif
    }

#ifdef EC_HENRY
    ECMaxLoadedTextureSize = ECHenryMaxTextureSize;
#else
    ECMaxLoadedTextureSize = ECInitialMaxTextureSize;
#endif
    
#ifdef EC_HENRY
    NSString *iosVersion = [[UIDevice currentDevice] systemVersion];
    NSString *henryVersion = @"11.4";
    if (/*screenScale > 1 || screenScaleZoomTweak > 0 || */ ![iosVersion isEqualToString:henryVersion]) {
	printf("Run Henry on iPhone iOS %s simulator only (your version is %s) (see line %d of %s).\n",
               [henryVersion UTF8String], [iosVersion UTF8String], __LINE__, __FILE__);
	assert(false);
    }
#endif
    
    shouldShowQuickStart = [self setupDefaults];  // Put this *BEFORE* the location manager init
    
    id dev = [UIDevice currentDevice];

#if 0
    unsigned int mc = 0;
    Method *mlist = class_copyMethodList(object_getClass(dev), &mc);
    printf("%d methods on UIDevice\n", mc);
    for(int i=0;i<mc;i++) {
	printf("Method #%d: %s\n", i, sel_getName(method_getName(mlist[i])));
    }
#endif

    if ([dev respondsToSelector:@selector(setBatteryMonitoringEnabled:)]) {
	[ECAppLog log:@"setBattMonEnabled"];
	[dev setBatteryMonitoringEnabled:YES];
    } else if ([dev respondsToSelector:@selector(beginGeneratingBatteryStateChangeNotifications)]) {
	[dev beginGeneratingBatteryStateChangeNotifications];
	[ECAppLog log:@"begGenBatStChNotif"];
    }

    [ECAppLog log:@"notifCtr reqBatUpd"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryStateDidChange:)
                                                 name:@"UIDeviceBatteryStateDidChangeNotification" object:nil];
#ifdef EC_PROXIMITY
    if ([dev respondsToSelector:@selector(setProximityMonitoringEnabled:)]) {
	printf("Turning on proximity enabling\n");
	[dev setProximityMonitoringEnabled:YES];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(proximityStateDidChange:)
                                                 name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
#endif

#ifndef NDEBUG
    checkDates(NULL);
#if 0
    ECGeoNames *geoNames = [[ECGeoNames alloc] init];
    NSArray *tzNames = [[geoNames tzNames] retain];
    printf("Sampling %d timezones...\n", [tzNames count]);
    for (NSString *tzName in tzNames) {
	ESTimeZone *estz = ESCalendar_makeTimeZoneFromOlsonID([tzName UTF8String]);
	printf("...%s\n", [tzName UTF8String]);
	checkDates(estz);
	ESCalendar_freeTimeZone(estz);
    }
    [tzNames release];
#endif
#endif

    //[ChronometerAppDelegate printAllFonts];
    //[ChronometerAppDelegate printAllCountryCodes];
    //[ChronometerAppDelegate printAllTimeZones];
    
    [ECLocationManager theLocationManager];		// this has the side-effect of firing up LocationServices to get the first fix
    [ECAstronomyManager initializeStatics];

    // [ChronometerAppDelegate printTZOffsetError];  // Needs to go after astronomy manager static initialization

    CGRect screenBounds = [mainScreen bounds];
    theWindow = [[UIWindow alloc] initWithFrame:screenBounds];
    CGSize windowSize = theWindow.bounds.size;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets edgeInsets = theWindow.safeAreaInsets;
        theWindowSafeBounds = CGRectMake(edgeInsets.left, edgeInsets.top, 
                                         windowSize.width - edgeInsets.left - edgeInsets.right,
                                         windowSize.height - edgeInsets.top - edgeInsets.bottom);
    } else {
        theWindowSafeBounds = CGRectMake(0, 0, windowSize.width, windowSize.height);
    }
    theRootViewController = [[ECTopLevelViewController alloc] init];
    theWindow.rootViewController = theRootViewController;
    theTopLevelView = (ECTopLevelView *)theWindow.rootViewController.view;

    bool doGridFlip = false;
    currentZ2 = [[NSUserDefaults standardUserDefaults] integerForKey:@"currentZ2"];
    if (currentZ2 != 0) {
	currentZ2 = 0;  // Let it be set by the grid setup code in case the number of watches has changed so that currentZ2 is now invalid
	doGridFlip = true;
    }

#ifdef EC_RED    
    [[UIApplication sharedApplication] setStatusBarHidden:YES animated:NO];
#endif
    // must do this early for messages during initialization
    // but the addSubView happens later to get right order

#ifdef ECDIMMER
    dimmerCover = [[UIView alloc] initWithFrame:screenBounds];
    dimmerCover.backgroundColor = [UIColor blackColor];
    dimmerCover.opaque = NO;
    dimmerCover.layer.opacity = 0;
    dimmerCover.userInteractionEnabled = NO;
#endif
    warpLabel = [[UILabel alloc]initWithFrame:CGRectMake(theWindowSafeBounds.origin.x, theWindowSafeBounds.origin.y + 20, theWindowSafeBounds.size.width, 20)];
    warpLabel.numberOfLines = 1;
    warpLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    warpLabel.adjustsFontSizeToFitWidth = true;
    warpLabel.textAlignment = NSTextAlignmentCenter;
#ifdef EC_RED
    warpLabel.textColor = [UIColor redColor];
#else
    warpLabel.textColor = [UIColor whiteColor];
#endif
    warpLabel.font = [UIFont systemFontOfSize:16];     
    
    osStatusBGView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 20)];
    osStatusBGView.backgroundColor = [UIColor blackColor];
    osStatusBGView.opaque = NO;
    osStatusBGView.layer.opacity = 0;
    osStatusBGView.userInteractionEnabled = NO;
    osStatusBGView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    timeSyncLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 55, 65, 40)];
    timeSyncLabel.numberOfLines = 2;
    timeSyncLabel.textAlignment = NSTextAlignmentLeft;
#ifdef EC_RED
    timeSyncLabel.textColor = [UIColor redColor];
#else
    timeSyncLabel.textColor = [UIColor whiteColor];
#endif
    timeSyncLabel.font = [UIFont systemFontOfSize:10];
    timeSyncLabel.backgroundColor = [UIColor clearColor];
    
    locSyncLabel = [[UILabel alloc]initWithFrame:CGRectMake(screenBounds.size.width-65, 55, 65, 40)];
    locSyncLabel.numberOfLines = 2;
    locSyncLabel.textAlignment = NSTextAlignmentRight;
#ifdef EC_RED
    locSyncLabel.textColor = [UIColor redColor];
#else
    locSyncLabel.textColor = [UIColor whiteColor];
#endif
    locSyncLabel.font = [UIFont systemFontOfSize:10];
    locSyncLabel.backgroundColor = [UIColor clearColor];
    
    alarmStateLabel = [[UILabel alloc]initWithFrame:CGRectMake(15, 42, 50, 40)];
    alarmStateLabel.numberOfLines = 2;
    alarmStateLabel.textAlignment = NSTextAlignmentRight;
#ifdef EC_RED
    alarmStateLabel.textColor = [UIColor redColor];
#else
    alarmStateLabel.textColor = [UIColor yellowColor];
#endif
    alarmStateLabel.font = [UIFont systemFontOfSize:10];
    alarmStateLabel.backgroundColor = [UIColor clearColor];
    
#ifdef ECDIMMER
    dimmerLabel = [[UILabel alloc]initWithFrame:CGRectMake(210, 20, 30, 20)];
    dimmerLabel.numberOfLines = 1;
    dimmerLabel.textAlignment = NSTextAlignmentRight;
#ifdef EC_RED
    dimmerLabel.textColor = [UIColor redColor];
#else
    dimmerLabel.textColor = [UIColor whiteColor];
#endif
    dimmerLabel.font = [UIFont systemFontOfSize:10];
    dimmerLabel.backgroundColor = [UIColor clearColor];
    [ChronometerAppDelegate clearDimmerLabel];
#endif
    

    [ECGLTextureAtlas setRedOverlay:[[NSUserDefaults standardUserDefaults] doubleForKey:@"ECRedOverlay"]];

#ifdef EC_HENRY
    watchDefinitionManager = [[ECWatchDefinitionManager alloc] init];
#ifdef EC_HENRY_ANDROID
    NSError *haError;
    NSArray *haWatchNames  = [ECfileManager contentsOfDirectoryAtPath:ECbundleXMLDirectory error:&haError];
    printf("Looked for watches in path %s\n", [ECbundleXMLDirectory UTF8String]);
    for (NSString* watchName in haWatchNames) {
        if ([self shouldSkipWatch:watchName]) {
            printf("... skipping %s\n", [watchName UTF8String]);
            continue;
        }
        if ([watchName hasSuffix:@"~"] || [watchName hasSuffix:@".txt"] || [watchName isEqualToString:@"Background"] || [watchName isEqualToString:@"partsBin"]) {
            continue;
        }
        printf("... loading %s\n",  [watchName UTF8String]);
        [ChronometerAppDelegate addWatch:[watchDefinitionManager loadWatchWithName:watchName errorReporter:[ECErrorReporter theErrorReporter]]];
    }
    
    printf("\nAll watches loaded, now archiving:\n\n");

    for (ECWatchController *watchCon in watches) {
        printf("... archiving %s\n", [watchCon.name UTF8String]);
        [watchCon archiveAll];
    }
    // The only purpose of Henry for Android is to generate watch atlases and archive data files,
    // so once that's been done, we exit.  We *can't* continue, because we're not generating iOS archives and
    // because the VM we're using isn't the chronometer VM.
    printf("Henry for Android done, calling exit\n");
    exit(0);
#endif
    // read the watch definitions for the last watch only, and the background
    [ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"Henry start loading %@", lastWatchName]];
    [watchDefinitionManager loadAllWatchesWithErrorReporter:[ECErrorReporter theErrorReporter] butJustHackIn:lastWatchName];
    [ChronometerAppDelegate noteTimeAtPhaseWithString:@"Henry start loading Background"];
    [watchDefinitionManager loadAllWatchesWithErrorReporter:[ECErrorReporter theErrorReporter] butJustHackIn:@"Background"];
    for (ECWatchController *watchCon in watches) {
#undef  SKIP_BACKGROUND
#ifdef SKIP_BACKGROUND
	if ([[watchCon name] caseInsensitiveCompare:@"Background"] == NSOrderedSame) {
	    [ChronometerAppDelegate noteTimeAtPhaseWithString:@"Not archiving Background"];
	} else {
	    [ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"Henry archiving %@", [watchCon name]]];
	    [watchCon archiveAll];
	}
#else
	[watchCon archiveAll];
#endif
    }
#endif

    int totalCount = [watchSortOrderDefaults count];
    NSMutableArray *watchSortOrder = [NSMutableArray arrayWithCapacity:totalCount];

    NSError *error;
    NSArray *archiveNames  = [ECfileManager contentsOfDirectoryAtPath:ECbundleArchiveDirectory error:&error];

    // Record in a hash the watches that are in the default array:
    NSMutableSet *watchNamesSeen = [NSMutableSet setWithCapacity:totalCount];
    bool resaveSortOrder = false;
    for (NSString *name in watchSortOrderDefaults) {
#ifdef EC_HENRY
	if ([self shouldSkipWatch:name]) {
	    totalCount--;
	    continue;
	}
#endif
	if ([archiveNames containsObject:name]) {
	    [watchNamesSeen addObject:name];
	    [watchSortOrder addObject:name];
	} else {
	    resaveSortOrder = true;
	    printf("Removing obsolete watch %s from sort order\n", [name UTF8String]);
	}
    }
    [watchSortOrderDefaults release];
    watchSortOrderDefaults = nil;
    if (resaveSortOrder) {
	printf("Resaving watch sort order into defaults\n");
	saveWatchDefaults();
    }

    // Now add in any archive or Henry watches that weren't stored in the prior defaults:
    for (NSString *name in archiveNames) {
	if ([name hasPrefix:@"."] ||
#ifdef EC_HENRY
	    [self shouldSkipWatch:name] ||
#endif
	    [name caseInsensitiveCompare:@"partsBin"] == NSOrderedSame ||
	    [name caseInsensitiveCompare:@"BackgroundHD"] == NSOrderedSame ||
	    [name caseInsensitiveCompare:@"Background"] == NSOrderedSame ||
	    [name caseInsensitiveCompare:@"archiveVersion.txt"] == NSOrderedSame) {
	    continue;
	}
	if (![watchNamesSeen containsObject:name]) {
	    [watchSortOrder addObject:name];
#ifdef EC_HENRY
	    [watchNamesSeen addObject:name];
#endif
	    totalCount++;
	}
    }
#ifdef EC_HENRY
    NSArray *henryWatchNames = [ECfileManager contentsOfDirectoryAtPath:ECbundleXMLDirectory error:&error];
    for (NSString *name in henryWatchNames) {
	if ([self shouldSkipWatch:name]) {
	    continue;
	}
	if (![watchNamesSeen containsObject:name]) {
	    [watchSortOrder addObject:name];
	    totalCount++;
	}
    }
#endif
    // Set up the view -- need this before loading bg watch so that full-screen parts will be sized properly
    ECGLViewController *glViewController = [[ECGLViewController alloc] initForWindow:theWindow];
    glView = [glViewController glView];  // Force load
    getIphoneScaleFactor();
    //[theWindow insertSubview:glView belowSubview:theTopLevelView];
    [theTopLevelView addSubview:glView];
    theTopLevelView.glView = glView;
    
    // Load Background "watch" -- needs to happen before other watches attempt to use the texture
    //[ChronometerAppDelegate noteTimeAtPhase:"Loading background watch: init"];
    backgroundWatch = [[ECGLWatch alloc] initWithName:@"Background"];
    //[ChronometerAppDelegate noteTimeAtPhase:"Loading background watch: loadFromArchive"];
    [backgroundWatch loadFromArchive];  // Need this just to display the "Loading message"
    [backgroundWatch setZoom:nogridZoomForBG()];
    size_t needsBytes;
    //[ChronometerAppDelegate noteTimeAtPhase:"Loading background watch: loadTextureIfRequiredForModeNum"];
    [backgroundWatch loadTextureIfRequiredForModeNum:[backgroundWatch currentModeNum] zoomPower2:tweakZoomForScreenScale(0) testOnly:false needsBytes:&needsBytes];
    assert(needsBytes == 0);
    //[ChronometerAppDelegate noteTimeAtPhase:"Done loading background watch"];

    glWatchCount = 0;
    glWatches = [[NSMutableArray alloc] initWithCapacity:totalCount];
    availableWatches = [[NSMutableArray alloc] initWithCapacity:totalCount];

    //[ChronometerAppDelegate noteTimeAtPhase:"Creating empty watches"];

    currentWatchIndex = 0;
    for (NSString *fileName in watchSortOrder) {
	if (!fileName) {
	    assert(false);
	    continue;
	}
#ifdef EC_HENRY
	if (![ECfileManager fileExistsAtPath:[ECbundleXMLDirectory stringByAppendingPathComponent:fileName]])
#else
	if (![ECfileManager fileExistsAtPath:[ECbundleArchiveDirectory stringByAppendingPathComponent:fileName]])
#endif
        {
	    // Nothing
#ifndef NDEBUG
	    [ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"Skipping watch %@ not in application bundle", fileName]];
#endif
	    continue;
	}
	bool isLastWatch = [lastWatchName caseInsensitiveCompare:fileName] == NSOrderedSame;
#ifdef EC_HENRY
	checkHenryForWatch(fileName, isLastWatch);
#endif
	NSDictionary *watchDefault = [[NSUserDefaults standardUserDefaults] objectForKey:[@"ECWatchProperty-" stringByAppendingString:fileName]];
	BOOL active = [[watchDefault objectForKey:@"active"] boolValue];
	ECGLWatch *lw = [[ECGLWatch alloc] initWithName:fileName];
	[availableWatches addObject:lw];
	[lw setActive:active];
        [lw setZoom:nogridZoom()];
	if (active) {
	    [glWatches addObject:lw];
	    if (isLastWatch) {
		currentWatchIndex = lastWatchIndex = glWatchCount;
	    }
	    glWatchCount++;
	}
	[[lw mainTime] restoreStateForWatch:fileName];
	[lw release];
    }

    ECSingleWatchProduct = [availableWatches count] == 1;
    if (glWatchCount == 0) {
	ECGLWatch *watch = [availableWatches objectAtIndex:0];
	assert(![watch active]);
	[watch setActive:true];
	[glWatches addObject:watch];
	currentWatchIndex = lastWatchIndex = 0;
	glWatchCount++;
    }

    int i;
    for (i = 0; i < ECNumWatchDrawModes; i++) {
	//[ChronometerAppDelegate noteTimeAtPhase:"Loading background watch: updateAllPartsForModeNum"];
	[backgroundWatch updateAllPartsForModeNum:i animating:false];  // Do this after determining ECSingleWatchProduct
    }

    [lastWatchName release];
    lastWatchName = [[[glWatches objectAtIndex:currentWatchIndex] name] retain];
    //[ChronometerAppDelegate noteTimeAtPhase:"Done creating empty watches"];
    glDrawWatches = [[NSMutableSet alloc] initWithCapacity:3];

    resetWatchIndices();
    initWatchModeDescriptorArray();

    sortWatchModeDescriptorArray(false);
    //[ChronometerAppDelegate noteTimeAtPhase:"Done sorting empty watches"];
    [[ChronometerAppDelegate currentWatch] setVisible:true];

    partFinder = [[ECGLPartFinder alloc] init];

    // Deprecated iOS 13.0: theApplication.statusBarStyle = UIStatusBarStyleLightContent;

    // these must be on top of the OGLES view (that is, added *after* glView)
    //printf("window contentMode %d\n", theTopLevelView.contentMode);
    //printf("window resizing mask 0x%x\n", theTopLevelView.autoresizingMask);
    //printf("glView contentMode %d\n", glView.contentMode);
    //printf("glView resizing mask 0x%x\n", glView.autoresizingMask);
    [theTopLevelView addSubview:osStatusBGView];
    [theTopLevelView addSubview:warpLabel];
    [theTopLevelView addSubview:timeSyncLabel];
    [theTopLevelView addSubview:locSyncLabel];
    if (!ECSingleWatchProduct) {
	[theTopLevelView addSubview:alarmStateLabel];
    }
#ifdef ECDIMMER
    [theTopLevelView addSubview:dimmerCover];
    [theTopLevelView addSubview:dimmerLabel];	    // needed on 3GS to make dimmerCover effective
#endif

    // Toggle DAL state to work around apparent bug in OS
    [ChronometerAppDelegate setDAL:false];
    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(delayedSetDal:) userInfo:nil repeats:false];
    [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(setDALHeartbeatFire:) userInfo:nil repeats:YES];
#ifdef ECDIMMER
    double lastDim = [[NSUserDefaults standardUserDefaults] doubleForKey:@"ECDimmerSetting"];
    if (lastDim > 0) {
	[ChronometerAppDelegate setDimmer:lastDim];
    }
#endif
    
#ifdef SHAREDCLOCK
    [ECWatchEnvironment setGlobalTimes:[[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseSharedClock"]];
#endif

    [ChronometerAppDelegate ignoreRedrawRequests];
    [ChronometerAppDelegate requestRedraw];  // bootstrap
    [ECOptions restoreTZ];				// must be after ECLocationManager startup and watch creation but before initializing the watch loader
    [ChronometerAppDelegate unignoreRedrawRequestsRedrawingIfDoneIgnoring:false];
    // [[ChronometerAppDelegate currentWatch] print];
    
#undef PERFORMANCE_TEST
#ifdef PERFORMANCE_TEST
    requestPerformanceTest();
#endif

    [ECGLWatchLoader init];
    [ECGLWatchLoader checkForWork];

    // initialize the location manager and set up to catch location change events
    [ [ECLocationManager theLocationManager] addLocationChangeObserver:self
					       locationChangedSelector:@selector(forceUpdateLocation)
					     locationFixFailedSelector:@selector(forceUpdateLocation)];
    
    //[ChronometerAppDelegate noteTimeAtPhase:"Starting heartbeat thread"];

    //[ChronometerAppDelegate noteTimeAtPhase:"Setting up audio"];

    [ECAudio setup];

    // HACK
    // [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(delayedPrintMemoryUsage:) userInfo:nil repeats:NO];
    // [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(delayedSpecialPartInvalidate:) userInfo:nil repeats:NO];

    // when we get memory warnings we reduce our memory usage; this timer tries to nudge it back up
    [NSTimer scheduledTimerWithTimeInterval:ECMemoryBumpInterval target:self selector:@selector(tryToIncreaseMemory:) userInfo:nil repeats:true];

    initializationDone = true;  // Do before makeKeyAndVisible
    [theWindow makeKeyAndVisible];
    
    if (warningMessage) {
	// don't overwrite the previous msg
    } else {
	//[ChronometerAppDelegate noteTimeAtPhase:"Showing status message"];
	[ChronometerAppDelegate showECStatusMessage:[[ChronometerAppDelegate currentWatch] displayName]];
	warningMessage = false;
    }
    //[ChronometerAppDelegate noteTimeAtPhase:"Leaving applicationDidFinishLaunching"];

    if (shouldShowQuickStart) {
	[ChronometerAppDelegate showQuickStart];
    }

    [ChronometerAppDelegate ignoreRedrawRequests];
    if (doGridFlip) {
	[ChronometerAppDelegate gridFlip];
    } else {
        [ChronometerAppDelegate setAllNoGridPositionsWithAnimationInterval:0 oneDirectionOnly:false];
    }
    [ChronometerAppDelegate unignoreRedrawRequestsRedrawingIfDoneIgnoring:false];

    [TSTime addTimeAdjustmentObserver:(id<TSTimeAdjustmentObserver>)[ChronometerAppDelegate class]];
    [ChronometerAppDelegate setupDSTEventTimer];  // After restoring the timezone above with restoreTZ

    [self determineHardware];

#ifdef EC_STORE
    [ECStore restart];
#endif

#if 0
    for (UIScreen *screen in [UIScreen screens]) {
	printf("Screen: bounds (in points) %.1f by %.1f origin (%1.f, %.1f) scale %.1f. Available modes:\n",
	       screen.bounds.size.width,
	       screen.bounds.size.height,
	       screen.bounds.origin.x,
	       screen.bounds.origin.y,
	       screen.scale);
	for (UIScreenMode *mode in screen.availableModes) {
	    printf("  mode: %.1f by %.1f (pixels), pixel aspect ratio %.3f\n",
		   mode.size.width,
		   mode.size.height,
		   mode.pixelAspectRatio);
	}
    }
#endif

    //[self printGTODOffset];
    //[self printBestCityForEachTZSlot];
    //[self testLocationSearch:nil];
    //[NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(testLocationSearch:) userInfo:nil repeats:false];
    
#ifndef NDEBUG
#ifndef EC_CWH_ANDROID
    [ChronometerAppDelegate noteTimeAtPhase:"applicationDidFinishLaunching end"];
#endif
#endif
}

+(void)saveState {  // Capture the state into RAM
    // Go get the active watch, and use its main time as the time to squirrel away
    [dateReflectingCapturedImage release];
    dateReflectingCapturedImage = [[[[self currentWatch] mainTime] currentDate] retain];

    // save the current visible state of the app
    [applicationImage release];
    applicationImage = [UIImage imageWithCGImage:[(UIApplicationHack*)theApplication createApplicationDefaultPNG]];
    [applicationImage retain];
}

+ (void) activateWatch:(ECGLWatch *)watch {
    [glDrawWatches addObject:watch];
    if (glView) {  // If not during initialization
	[self callForForceUpdateAfterDelay];
    }
}

+ (void) deactivateWatch:(ECGLWatch *)watch {
    [glDrawWatches removeObject:watch];
    //assert([glDrawWatches count] > 0);
}

+ (void)setTimeZone:(ESTimeZone *)newTZ {
    //traceEnter("setTimeZone");
    // set the timezone for all watches
    ESCalendar_localTimeZoneChanged();
    for (ECGLWatch *watch in availableWatches) {
	//tracePrintf2("setting TZ of %s to %s", [[watch name] UTF8String], [[newTZ description]UTF8String]);
	[watch setTimeZone:newTZ];
    }
    [ChronometerAppDelegate setupDSTEventTimer];
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    //traceExit ("setTimeZone");
}

+ (void)printVisibleWatches {
    printf("Visible watches:\n");
    for (ECGLWatch *watch in glDrawWatches) {
        double width = [self applicationSize].width;
        printf("... %20s at (%7.1f, %.1f) (%4.1f widths away from center)\n",
               [[watch name] UTF8String],
               watch.drawCenter.x, watch.drawCenter.y,
               watch.drawCenter.x / width);
    }
}

// Update timer:  There is now but one timer in EC, owned here.  This timer will fire the next time there
// is something to do.  When a part is updated (including its first, initializing update), it returns back
// through the call chain the time at which it needs to be updated, relative to the supplied redraw time.
// A negative return value means a repeating update is requested at the global frame rate.

+ (NSTimeInterval) redrawAtTime:(NSTimeInterval)redrawTime
		  forcingUpdate:(bool)forceUpdate
		 allowAnimation:(bool)allowAnimation
		       dragType:(ECDragType)dragType {
    //[TSTime reportAllSkewsAndOffset:"redraw start"];
    assert([NSThread isMainThread]);
    if (displayLocked) {
	return 1.0;  // do nothing and say we want to update in one second
    }
    NSTimeInterval soonestUpdateNeeded = ECFarInTheFuture;
    bool ignoreRedrawRequestsForThisDraw = ignoreRedrawRequests;
    if (!ignoreRedrawRequests) {
	if (![glView startDraw]) {
            ignoreRedrawRequestsForThisDraw = true;
        }
    }
    //[self printVisibleWatches];
    NSArray *thisDrawSet = [glDrawWatches allObjects];  // Make a copy to avoid thread conflicts [hmm.  Really? I suspect I really meant conflicts with redraw removing items from the set]
    NSArray *thisActiveSet = [NSArray arrayWithArray:glWatches]; // Ditto
    //assert([thisDrawSet count] > 0);
    int watchesDrawn = 0;
    if (ignoreRedrawRequestsForThisDraw) {
	soonestUpdateNeeded = [backgroundWatch prepareAllPartsForDrawForModeNum:[backgroundWatch currentModeNum] atTime:redrawTime forcingUpdate:forceUpdate allowAnimation:allowAnimation dragType:dragType];
	for (ECGLWatch *watch in thisDrawSet) {
	    NSTimeInterval soonest = [watch prepareAllPartsForDrawForModeNum:[watch currentModeNum] atTime:redrawTime forcingUpdate:forceUpdate allowAnimation:allowAnimation dragType:dragType];
	    if (soonest < soonestUpdateNeeded) {
		soonestUpdateNeeded = soonest;
	    }
	}
    } else {
        soonestUpdateNeeded = [ECGLWatch updateDeviceRotationForTime:redrawTime];
        // Presumably the background watch doesn't change position or zoom...
	NSTimeInterval soonest = [backgroundWatch drawForModeNum:[backgroundWatch currentModeNum]
                                                   andZoomPower2:tweakZoomForScreenScale(0)
                                                      gridPower2:tweakZoomForScreenScale(0)
                                                          atTime:redrawTime
                                                       zoomingIn:zoomingIn
                                                  asCurrentWatch:false
                                                   forcingUpdate:forceUpdate
                                                  allowAnimation:allowAnimation
                                                        dragType:dragType];
        if (soonest < soonestUpdateNeeded) {
            soonestUpdateNeeded = soonest;
        }
	for (ECGLWatch *watch in thisActiveSet) {  // Do all watches, even invisible ones, so that when they become visible they are in their proper location for animation
            soonest = [watch updatePositionZoomForTime:redrawTime];
            if (soonest < soonestUpdateNeeded) {
                soonestUpdateNeeded = soonest;
            }
            if ([watch visible]) {  // May have changed after updatePositionZoomForTime, so may not match glDrawSet
                if (watch.landscapeZoomFactor >= 1.0) {
                    //printf("Drawing %s\n", [[watch name] UTF8String]);
                    watchesDrawn++;
                    bool watchIsCurrent = [glWatches objectAtIndex:currentWatchIndex] == watch;
                    soonest = [watch drawForCurrentModeAtTime:redrawTime
                                                   zoomPower2:tweakZoomForScreenScale(currentZ2)
                                                   gridPower2:tweakZoomForScreenScale(z2ForCount(glWatchCount))
                                                    zoomingIn:zoomingIn
                                               asCurrentWatch:watchIsCurrent
                                                forcingUpdate:forceUpdate
                                               allowAnimation:allowAnimation
                                                     dragType:dragType];
                    if (soonest < soonestUpdateNeeded) {
                        soonestUpdateNeeded = soonest;
                    }
                }
            }
        }
        // Now draw watches with landscapeZoomFactor < 1, which presumably have interesting things in the vertical dimension that want to be on top
	for (ECGLWatch *watch in thisActiveSet) {  // Do all watches, even invisible ones, so that when they become visible they are in their proper location for animation
            if ([watch visible]) {  // May have changed after updatePositionZoomForTime, so may not match glDrawSet
                if (watch.landscapeZoomFactor < 1.0) {
                    //printf("Drawing (special) %s\n", [[watch name] UTF8String]);
                    watchesDrawn++;
                    bool watchIsCurrent = [glWatches objectAtIndex:currentWatchIndex] == watch;
                    soonest = [watch drawForCurrentModeAtTime:redrawTime
                                                   zoomPower2:tweakZoomForScreenScale(currentZ2)
                                                   gridPower2:tweakZoomForScreenScale(z2ForCount(glWatchCount))
                                                    zoomingIn:zoomingIn
                                               asCurrentWatch:watchIsCurrent
                                                forcingUpdate:forceUpdate
                                               allowAnimation:allowAnimation
                                                     dragType:dragType];
                    if (soonest < soonestUpdateNeeded) {
                        soonestUpdateNeeded = soonest;
                    }
                }
            }
        }
    }
    if (!ignoreRedrawRequestsForThisDraw) {
	[glView finishDraw];
    }
    if (doneAnimatingGridWhenAllWatchesFinishDrawing) {
	doneAnimatingGridWhenAllWatchesFinishDrawing = false;
	[self doneAnimatingGrid];
    }
    //[TSTime reportAllSkewsAndOffset:[[NSString stringWithFormat:@"redraw end, update in %.3f", soonestUpdateNeeded] UTF8String]];
    //printf("\nredraw, %d watches in draw set, %d watches actually on in active set\n",
    //       [thisDrawSet count], watchesDrawn);
    return soonestUpdateNeeded;
}

NSTimer *updateTimer;

static bool updatesPaused = false;

+ (void)reinstallTimerForNextUpdate:(NSTimeInterval)soonestUpdateNeeded givenStartTime:(NSTimeInterval)startTime {
    assert([NSThread isMainThread]);
    // Check to see if it's a repeating timer, and if so whether we still need one
    if ([updateTimer isValid]) {
	if ([updateTimer timeInterval]) { // repeating timer
	    if (soonestUpdateNeeded < 0) {  // we want a repeating timer, we're done
		// we're done
		return;
	    } else {
		[updateTimer invalidate];
	    }
	} else {
	    // One-shot: invalidate existing timer (before or after, it's no good any more)
	    //assert(!theTimer);  // a one-shot timer fired, and it's still valid?
	    [updateTimer invalidate];
	}
    }
    // install new timer
    BOOL repeats;
    NSTimeInterval deltaT;
    if (soonestUpdateNeeded < 0) {
	// install repeating timer at frame rate
	repeats = YES;
	deltaT = kECGLFrameRate;
    } else {
	// install one-shot timer at time requested
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	repeats = NO;
	deltaT = (startTime + soonestUpdateNeeded - now);
    }
    if (displayLocked && deltaT < 1.0) {
	deltaT = 1.0;
    }
    if (!updatesPaused) {
	updateTimer = [NSTimer scheduledTimerWithTimeInterval:deltaT
						       target:self
						     selector:@selector(updateTimerFire:)
						     userInfo:nil
						      repeats:repeats];
    }
}

static bool forceUpdateNextTime = false;

+ (void)resetUpdateTime {
    forceUpdateNextTime = true;
    [self reinstallTimerForNextUpdate:-1 givenStartTime:[NSDate timeIntervalSinceReferenceDate]];
}

+ (void)cancelMainThreadRedrawUpdate {
    assert([NSThread isMainThread]);
    updatesPaused = true;
    [updateTimer invalidate];
    updateTimer = nil;
}

+ (void)resumeMainThreadRedrawUpdate {
    assert([NSThread isMainThread]);
    updatesPaused = false;
    [self resetUpdateTime];
}

+ (void)updateAction:(NSTimer *)theTimer allowAnimation:(bool)allowAnimation forcingUpdate:(bool)forceUpdate dragType:(ECDragType)dragType {
    assert(!theTimer || theTimer == updateTimer);
    // Parts are updated, if necessary, immediately before being drawn
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval soonestUpdateNeeded = [self redrawAtTime:startTime forcingUpdate:forceUpdate allowAnimation:allowAnimation dragType:dragType];
    soonestUpdateNeeded = soonestUpdateNeeded;
#if 0
    static int printCount = 0;
    if (printCount < 100) {
	printCount++;
	printf("%.4fs redraw, soonest %s\n", [NSDate timeIntervalSinceReferenceDate] - startTime, soonestUpdateNeeded < 0 ? "animating" : ESCalendar_dateIntervalDescription(startTime + soonestUpdateNeeded));
    }
#endif
    [self reinstallTimerForNextUpdate:soonestUpdateNeeded givenStartTime:startTime];
}

#ifdef PERFORMANCE_TEST
+ (void)performanceTestFire:(NSTimer *)theTimer {
    printf("Peformance test beginning\n");
    int iterations = 1000;
    NSTimeInterval startTime, endTime, testTime;
#undef REPAINT_PERFORMANCE
#ifdef REPAINT_PERFORMANCE
    startTime = [NSDate timeIntervalSinceReferenceDate];
    for(int i = 0; i < iterations; i++) {
	[self updateAction:nil allowAnimation:true forcingUpdate:false dragType:ECDragNotDragging];
    }
    endTime = [NSDate timeIntervalSinceReferenceDate];
    testTime = endTime - startTime;
    printf("%d iterations in %.4f seconds; frame rate %.1f frames per second (no update)\n",
	   iterations, testTime, iterations/testTime);
    iterations = 100;
    startTime = [NSDate timeIntervalSinceReferenceDate];
    for(int i = 0; i < iterations; i++) {
	[self updateAction:nil allowAnimation:true forcingUpdate:true dragType:ECDragNotDragging];
    }
    endTime = [NSDate timeIntervalSinceReferenceDate];
    testTime = endTime - startTime;
    printf("%d iterations in %.4f seconds; frame rate %.1f frames per second (updating each time)\n",
	   iterations, testTime, iterations/testTime);
#endif

    iterations = 100;
    startTime = [NSDate timeIntervalSinceReferenceDate];
    for(int i = 0; i < iterations; i++) {
	[self updateAction:nil allowAnimation:true forcingUpdate:true dragType:ECDragNotDragging];
	clearAllCaches();
    }
    endTime = [NSDate timeIntervalSinceReferenceDate];
    testTime = endTime - startTime;
    printf("%d iterations in %.4f seconds; frame rate %.1f frames per second (updating and clearing cache each time)\n",
	   iterations, testTime, iterations/testTime);
}

void requestPerformanceTest() {
    printf("requested performance test\n");
    [NSTimer scheduledTimerWithTimeInterval:30  // Enough to get past the bg loader
				     target:[ChronometerAppDelegate class]
				   selector:@selector(performanceTestFire:)
				   userInfo:nil
				    repeats:NO];
}

#endif

+ (void)updateTimerFire:(NSTimer *)theTimer {
    bool doForceUpdate = forceUpdateNextTime;
    if (forceUpdateNextTime) {
	forceUpdateNextTime = false;
    }
    [self updateAction:theTimer allowAnimation:true forcingUpdate:doForceUpdate dragType:ECDragNotDragging];
}

+ (void)forceUpdateAllowingAnimation:(bool)allowAnimation dragType:(ECDragType)dragType {
    if ([glDrawWatches count] == 0) {
	return;
    }
    if (displayLocked) {
	return;
    }
    [self updateAction:nil allowAnimation:allowAnimation forcingUpdate:true dragType:dragType];
}

+ (void)forceUpdateEntryPoint {
    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
}

+ (void)forceUpdateInMainThread {
    [self performSelectorOnMainThread:@selector(forceUpdateEntryPoint) withObject:nil waitUntilDone:NO];
}

- (void)forceUpdateLocation {
    [ChronometerAppDelegate updateAction:nil allowAnimation:true forcingUpdate:true dragType:ECDragNotDragging];
}

+ (void)requestRedraw {
    if (!ignoreRedrawRequests) {
	[self updateAction:nil allowAnimation:true forcingUpdate:false dragType:ECDragNotDragging];
    }
}

+ (bool)needToStayAlive {
    for (ECGLWatch *watch in availableWatches) {
	if ([watch alarming]) {
	    return true;
	}
    }
    return false;
}

+ (void)alarmFiredInWatch:(ECGLWatch *)watch {
    assert([NSThread isMainThread]);
    if (switching) {
	[self selectorCancelAnimatingInGrid:false];  // Do this first
    }
    if (displayingGrid || animatingGrid) {
	if (animatingGrid) {
	    switchToThisWatchWhenDoneAnimatingGrid = watch;
	} else {
	    [self unGridifyToWatch:watch];
	}
    } else {
	[self switchToWatch:watch];
    }
    if (displayLocked) {
	if ([self needToStayAlive]) {
	    [ECAudio setupSilentSounds];
	} else {
	    [ECAudio cancelSilentSounds];
	}
    }
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)applicationWillResignActive:(UIApplication *)application {
#ifndef NDEBUG
    [ChronometerAppDelegate noteTimeAtPhase:"applicationWillResignActive"];
#endif
    [ChronometerAppDelegate stopAlarmsRinging];
    [[ECLocationManager theLocationManager] suspend];
    if ([ChronometerAppDelegate needToStayAlive]) {
	[ECAudio setupSilentSounds];
    }
    displayLocked = true;
    [TSTime goingToSleep];
    [ECAppLog log:[NSString stringWithFormat:@"=> inactive, DAL %s, power: %s", (theApplication.idleTimerDisabled ? "true" : "false"), batteryStateNameForState([self batteryState])]];
    [[NSUserDefaults standardUserDefaults] synchronize];  // make sure we get written to disk at *some* boundary
}

static bool firstTime = true;

+ (void)showStatusAfterDelay {
    //printf("delaying status display\n");
    [NSTimer scheduledTimerWithTimeInterval:0.1  // Enough to get past the oddities when becoming active
				     target:self
				   selector:@selector(showStatus)
				   userInfo:nil
				    repeats:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
#ifndef NDEBUG
#ifndef EC_CWH_ANDROID
    [ChronometerAppDelegate noteTimeAtPhase:"applicationDidBecomeActive"];
#endif
#endif
    [ECAppLog log:[NSString stringWithFormat:@"=> active, DAL %s", (theApplication.idleTimerDisabled ? "true" : "false")]];
    [ChronometerAppDelegate stopAlarmsRinging];
    [TSTime wakingUp];
    [ECAudio cancelSilentSounds];
    if (!firstTime) {
	[[ECLocationManager theLocationManager] resume];
    }
    displayLocked = false;
    if (warpLabel.layer.opacity != 0) {
	[ChronometerAppDelegate showStatusAfterDelay]; // in case we ignored the request while locked
    }
    [self applicationSignificantTimeChange:theApplication];  // Put this *after* resetting displayLocked to false above
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [ECTS reSync];
    //[ChronometerAppDelegate noteTimeAtPhase:"exiting DidBecomeActive"];
    firstTime = false;  // Should be last
}

+ (bool)displayLocked {
    return displayLocked;
}

// For 4.0: we went into hibernation.  Make ourselves as small as possible
- (void)applicationDidEnterBackground:(UIApplication *)application {
#ifdef EC_HENRY
    exit(0);
#endif
    inBackground = true;
    [[NSUserDefaults standardUserDefaults] synchronize];  // make sure defaults get written
#ifndef NDEBUG
    [ECAppLog log:[NSString stringWithFormat:@"Did enter background start"]];
    [ChronometerAppDelegate noteTimeAtPhase:"didEnterBackground:"];
    [ChronometerAppDelegate printMemoryUsage:@"------------ "];
#endif
    [ECGLWatchLoader pauseBG];
    lastNonBackgroundTextureSize = ECMaxLoadedTextureSize;
    ECMaxLoadedTextureSize = ECBackgroundTextureSize;
    [ChronometerAppDelegate doOneBackgroundLoad];  // Which will kill off the loaded textures
    [ChronometerAppDelegate requestUnattachCheckingForWork:false];  // Now unattach those that were unloaded
#ifndef NDEBUG
    [ChronometerAppDelegate printMemoryUsage:@"------------ "];
#ifdef MEMORY_TRACK_TEXTURE
    [ECGLTextureAtlas reportAllAttachedOrLoadedTextures];
#endif
    [ChronometerAppDelegate noteTimeAtPhase:"didEnterBackground end:"];
    [ECAppLog log:[NSString stringWithFormat:@"Did enter background end"]];
#endif
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    inBackground = false;
#ifndef NDEBUG
    [ECAppLog log:[NSString stringWithFormat:@"will enter foreground start"]];
    [ChronometerAppDelegate noteTimeAtPhase:"willEnterForeground:"];
    [ChronometerAppDelegate printMemoryUsage:@"------------ "];
#endif
    ECMaxLoadedTextureSize = lastNonBackgroundTextureSize;
    [ECGLWatchLoader resumeBG];
    [ECGLWatchLoader checkForWork];
    [ECTS reSync];
#ifndef NDEBUG
    [ECAppLog log:[NSString stringWithFormat:@"will enter foreground end"]];
#endif
}

+ (void)backFlip {
    ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
    if ([watch currentModeNum] == ECfrontMode) {
	[watch setCurrentModeNum:ECbackMode zoomPower2:currentZ2 allowAnimation:true];
	[backgroundWatch setCurrentModeNum:ECbackMode zoomPower2:0 allowAnimation:false];
    } else {
	assert([watch currentModeNum] == ECbackMode);
	[watch setCurrentModeNum:ECfrontMode zoomPower2:currentZ2 allowAnimation:true];
	[backgroundWatch setCurrentModeNum:ECfrontMode zoomPower2:0 allowAnimation:false];
    }
    sortWatchModeDescriptorArray(false);
    [ECGLWatchLoader checkForWork];
}

+ (void)nightFlip {
    ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
    assert([watch currentModeNum] == ECfrontMode);  // For now but will change with back night
    [watch setCurrentModeNum:ECnightMode zoomPower2:currentZ2 allowAnimation:false];
    [backgroundWatch setCurrentModeNum:ECnightMode zoomPower2:0 allowAnimation:false];
    sortWatchModeDescriptorArray(false);
    [ECGLWatchLoader checkForWork];
}

+ (void)dayFlip {
    ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
    assert([watch currentModeNum] == ECnightMode);
    [watch setCurrentModeNum:ECfrontMode zoomPower2:currentZ2 allowAnimation:false];
    [backgroundWatch setCurrentModeNum:ECfrontMode zoomPower2:0 allowAnimation:false];
    sortWatchModeDescriptorArray(false);
    [ECGLWatchLoader checkForWork];
}

+ (void)infoFlip  {				// action of the "i" button: bring up the EC Help system
    assert([NSThread isMainThread]);
    if (helpNavigationController == nil) {
	[self helpFlip:nil];
    }
}

+ (void)helpFlip:(NSString *)topic {
    assert([NSThread isMainThread]);
    [ChronometerAppDelegate showStatus];
    [self killStatusUpdate];
    helping = true;

    if (helpNavigationController == nil) {
	helpController = [[[ECHelpController alloc] initWithNibName:nil bundle:nil] autorelease];
	helpController.title = @"Loading Help...";
	helpNavigationController = [[ECRotatableNavController alloc] initWithRootViewController:helpController];
	helpNavigationController.navigationBar.barStyle = UIBarStyleBlack;
    }

    // animate up from the bottom just the height of the Nav bar
    CGPoint p = helpNavigationController.view.center;
    //printf("nav controller view size is %g x %g\n", helpNavigationController.view.bounds.size.width, helpNavigationController.view.bounds.size.height);
    helpNavigationController.view.center = CGPointMake(p.x, p.y+[self applicationSize].height);	    // start below the screen
    [theTopLevelView addSubview:[helpNavigationController view]];
#ifdef ECDIMMER
    [theTopLevelView bringSubviewToFront:dimmerCover];
    [theTopLevelView bringSubviewToFront:dimmerLabel];
#endif
    [self infoSlideUp:64.1 notify:false];				// slide up to show just the nav bar (plus one pixel!)

    [helpController showHelp:topic];		// show the real stuff
}

+ (void)infoSlideUp:(double)deltaY notify:(BOOL)notify {
    assert([NSThread isMainThread]);
    bool goingAllUp = false;
    if (deltaY == 0) {
        // We started at 64.1 from bottom of view area.  We want to go to bottom of top inset.
        // insetBounds is Y-up from bottom of view area.
        CGRect insetBounds = [self applicationBoundsPoints];
	deltaY = insetBounds.origin.y + insetBounds.size.height  - 64.1;
	goingAllUp = true;
    }
    CGPoint p = helpNavigationController.view.center;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:ECHelpFadeTime];
    if (notify) {
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(helpAnimationDone: finished: context:)];
        osStatusBGView.layer.opacity = 0;
    } else if (goingAllUp) {
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(helpAnimationAllUp: finished: context:)];
        osStatusBGView.layer.opacity = 1;
    } else {
	[UIView setAnimationDelegate:nil];
	[UIView setAnimationDidStopSelector:nil];
    }
    helpNavigationController.view.center = CGPointMake(p.x, p.y-deltaY);
    [UIView commitAnimations];
}

+ (void)infoDone:(NSString *)lastPage {
    assert([NSThread isMainThread]);
    [self infoSlideUp:-[self applicationSize].height notify:true];	    // slide down off screen
    helping = false;
    [self switchToWatch:[self availableWatchWithName:lastPage]];
    [self hideECTimeLocationStatus];
}

+ (void)helpAnimationAllUp:(id)animationID finished:(bool)finished context:(id)context {
    assert([NSThread isMainThread]);
    [helpController allUp];
}

+ (void)helpAnimationDone:(id)animationID finished:(bool)finished context:(id)context {
    assert([NSThread isMainThread]);
    if (!helping) {
	[[helpNavigationController view] removeFromSuperview];
	helpController = nil;
	[helpNavigationController release];
	helpNavigationController = nil;
    }
}

+ (bool)helping {
    return helping;
}

#ifdef EC_STORE
#if !TARGET_IPHONE_SIMULATOR
static ECStoreViewController *storeVC = nil;
#endif

// The following is a big hack just so I can get the UI up quickly. It should be thrown out and
// replaced with something else.
+ (void)storeFlip {
#if TARGET_IPHONE_SIMULATOR
    [[ECErrorReporter theErrorReporter] reportError:@"The store is not available in the simulator"];
#else
    if (!storeVC) {
	storeVC = [[ECStoreViewController alloc] init];
    }
    [theTopLevelView addSubview:[storeVC view]];
#endif
}
#endif

// Selector/editor screen ---------------------------------------------------------------------------------------------------------------------------------------------

static UINavigationController *selectorNavigationController = nil;
static ECWatchSelector *selectorController = nil;

+ (void)clearSelectorPanel {
    [theRootViewController dismissViewControllerAnimated:YES completion:NULL];  // Dismiss child panel
    selectorController = nil;    // Is this a leak?
    [selectorNavigationController release];
    selectorNavigationController = nil;
}

+ (void)startSelector:(NSTimer *)timer {
    [theRootViewController presentViewController:selectorNavigationController animated:YES completion:NULL];
#ifdef ECDIMMER
    [theTopLevelView bringSubviewToFront:dimmerCover];
    [theTopLevelView bringSubviewToFront:dimmerLabel];
#endif
    switcherReady = true;  // Should be after animation, but we don't know when that will be
}

+ (void)selectorFlipStartWithEdit:(bool)startWithEdit afterDelay:(NSTimeInterval)afterDelay {
    [ChronometerAppDelegate showStatus];
    [ChronometerAppDelegate hideECStatus];
    [self killStatusUpdate];
    switching = true;
    switcherReady = false;

    if (selectorNavigationController == nil) {
	selectorController = [[[ECWatchSelector alloc] initWithNibName:nil bundle:nil] autorelease];
	selectorNavigationController = [[ECRotatableNavController alloc] initWithRootViewController:selectorController];
	selectorNavigationController.navigationBar.barStyle = UIBarStyleBlack;
        if (@available(iOS 13.0, *)) {
            selectorNavigationController.modalInPresentation = YES;
        }
    }
    [selectorController setEditingOnly:startWithEdit];
    [selectorNavigationController viewWillAppear:false];

    if (afterDelay) {
	[NSTimer scheduledTimerWithTimeInterval:afterDelay
					 target:self
				       selector:@selector(startSelector:)
				       userInfo:nil
					repeats:NO];
    } else {
	[self startSelector:nil];
    }
}

+ (void)selectorFlip {
#ifdef EC_STORE
    [self storeFlip];
#else
    if (selectorNavigationController == nil) {
	[self selectorFlipStartWithEdit:false afterDelay:0];
    }
#endif
}

+ (void)selectorCancelAnimatingInGrid:(bool)animatingInGrid {
    switching = false;
    [self clearSelectorPanel];
    if (displayingGrid) {
	[self hideStatus];			// hide the iPhone status line
	[self scrollWatchesToX:0 animating:animatingInGrid];
	gridOffsetForEditor = 0;
    } else {
	[self showECStatusMessage:[[self currentWatch] displayName]];
    }
    [self hideECTimeLocationStatus];
    [self ignoreRedrawRequests];
    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [self unignoreRedrawRequestsRedrawingIfDoneIgnoring:false];
}

+ (void)selectorCancel {
    [self selectorCancelAnimatingInGrid:true];
}

+ (void)editorFlip {
    [self selectorFlipStartWithEdit:true afterDelay:0.18];
}

+ (void)watchSwitcherTimerFire:(NSTimer *)theTimer {
    [self switchToWatchNumber:[[theTimer userInfo] intValue]];
}

static void delayedSwitchToWatchNumber(int indx) {
    [NSTimer scheduledTimerWithTimeInterval:0.25
				     target:[ChronometerAppDelegate class]
				   selector:@selector(watchSwitcherTimerFire:)
				   userInfo:[NSNumber numberWithInt:indx]
				    repeats:NO];
}

+ (void)selectorChoose:(int)indx {
    if (switcherReady) {
	switching = false;
        [self clearSelectorPanel];
	[self showECStatusMessage:[[self currentWatch] displayName]];
	[self hideECTimeLocationStatus];
	//    [self switchToWatchNumber:indx];
	delayedSwitchToWatchNumber(indx);
    } // else ignore input until startup animation is done
}

// Grid button ---------------------------------------------------------------------------------------------------------------------------------------------

+ (void)gridFlip {
    if ([glWatches count] > 1) {
	[self hideStatus];			// hide the iPhone status line
	[self hideECStatus];		// hide the status line
    }
    [self hideECTimeLocationStatus];	// and the indicator labels (but leave the indicator lights themselves)
    [self setup2DGridWithAnimationInterval:kECGLGridAnimationTime];
}

// EC Options screen ---------------------------------------------------------------------------------------------------------------------------------------------

static UINavigationController *optionNavigationController = nil;
static ECOptions *optionController = nil;

+ (void)optionFlip  {				// action of the option button: bring up the EC Options screen
    //[self printVisibleWatches];
    if (optionNavigationController == nil) {
        //printf("optionFlip, topLevelViewController thinks it's %s\n", [orientationNameForOrientation([theRootViewController interfaceOrientation]) UTF8String]);
	[ChronometerAppDelegate showStatus];
	[self killStatusUpdate];
	optioning = true;
	
	if (optionNavigationController == nil) {
	    optionController = [[[ECOptions alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
	    optionNavigationController = [[ECRotatableNavController alloc] initWithRootViewController:optionController];
	    optionNavigationController.navigationBar.barStyle = UIBarStyleBlack;
            optionNavigationController.navigationBar.translucent = NO;
            optionNavigationController.navigationBar.backgroundColor = [UIColor systemBackgroundColor];
            optionNavigationController.navigationBar.titleTextAttributes = @{
                NSForegroundColorAttributeName: [UIColor grayColor],
            };
            if (@available(iOS 13.0, *)) {
                optionNavigationController.modalInPresentation = YES;
            }
        }
        [theRootViewController presentViewController:optionNavigationController animated:YES completion:NULL];
#ifdef ECDIMMER
	[theTopLevelView bringSubviewToFront:dimmerCover];
	[theTopLevelView bringSubviewToFront:dimmerLabel];
#endif
    }
}

+ (void)clearOptionPanel {
    assert(optioning);
    optioning = false;
#if DIMMERLABEL
    [self clearDimmerLabel];
#endif
    [theRootViewController dismissViewControllerAnimated:YES completion:NULL];  // Dismiss child panel
    // [optionNavigationController dismissModalViewControllerAnimated:YES];  // Will forward to parent, but if it has its own modal controller it will only delete the child
    optionController = nil;  // Is this a leak?
    [optionNavigationController release];
    optionNavigationController = nil;
}

+ (void)optionDone {
    traceEnter("CAD::optionDone");
    [self clearOptionPanel];
    [self showECStatusMessage:[[self currentWatch] displayName]];
    [self hideECTimeLocationStatus];
    if (factoryWorkNeeded) {
	[ECGLTextureAtlas invalidateSpecialParts];
	factoryWorkNeeded = false;
    }
    [self ignoreRedrawRequests];
    [self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    [self unignoreRedrawRequestsRedrawingIfDoneIgnoring:false];
    //[ECAudio stopRingingNow];
    traceExit("CAD::optionDone");
}

+ (void)optionToHelp:(NSString *)topic {
    [self clearOptionPanel];
    [self helpFlip:topic];
}

// end EC Options screen ---------------------------------------------------------------------------------------------------------------------------------------------

// EC Data screens ---------------------------------------------------------------------------------------------------------------------------------------------

static UINavigationController *dataNavigationController = nil;
static ECBackgroundData *dataController = nil;

+ (void)dataAnimationDone:(id)animationID finished:(bool)finished context:(id)context {
    [dataController.navigationController.topViewController dismissViewControllerAnimated:NO completion:NULL];
    [[dataNavigationController view] removeFromSuperview];
    dataController = nil;
    [dataNavigationController release];
    dataNavigationController = nil;
}

+ (void)dataSlideUp:(double)deltaY animationDidStopSelector:(SEL)animationDidStopSelector {
    if (deltaY == 0) {
	deltaY = -[self applicationSize].height;
    }
    CGPoint p = dataNavigationController.view.center;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:ECHelpFadeTime];
    if (animationDidStopSelector) {
	[UIView setAnimationDelegate:self];
    } else {
	[UIView setAnimationDelegate:nil];
    }
    [UIView setAnimationDidStopSelector:animationDidStopSelector];
    dataNavigationController.view.center = CGPointMake(p.x, p.y-deltaY);
    [UIView commitAnimations];
    if (deltaY > 0) {
	[self forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
    }
}

+ (void)dataFlip:(int)which  {				// action of the data buttons: bring up one of the EC data screens
    if (isIpad()) {
        [ChronometerAppDelegate showStatus];
        dataing = true;
        [self killStatusUpdate];
        [self showECStatusMessage:[[self currentWatch] displayName]];

        dataController = [[ECBackgroundData alloc] initForCategory:which];
        [dataController setPreferredContentSize:CGSizeMake(480,210)];
        dataController.modalPresentationStyle = UIModalPresentationPopover;
        [theRootViewController presentViewController:dataController animated:YES completion:nil];
        dataController.popoverPresentationController.sourceView = theTopLevelView;
        double x = which == 0 ? 32 : [self applicationSize].width - 32;
        dataController.popoverPresentationController.sourceRect = CGRectMake(x, 105, 1, 1);
	dataController.popoverPresentationController.delegate = theAppDelegate;
    } else {
        if (dataNavigationController == nil) {
            [ChronometerAppDelegate showStatus];
            [self killStatusUpdate];
            dataing = true;
            
            if (dataNavigationController == nil) {
                dataController = [[[ECBackgroundData alloc] initForCategory:which] autorelease];
                dataNavigationController = [[ECRotatableNavController alloc] initWithRootViewController:dataController];
                dataNavigationController.navigationBar.barStyle = UIBarStyleBlack;
            }
            
            // animate down from the top
            CGPoint p = dataNavigationController.view.center;
            CGFloat appHeight = [self applicationSize].height;
            dataNavigationController.view.center = CGPointMake(p.x, p.y - appHeight);	    // start above the screen
            [theTopLevelView addSubview:[dataNavigationController view]];
#ifdef ECDIMMER
            [theTopLevelView bringSubviewToFront:dimmerCover];
            [theTopLevelView bringSubviewToFront:dimmerLabel];
#endif
            [self dataSlideUp:-appHeight animationDidStopSelector:nil];				// slide down
        }
    }
}

- (void)popOverControllerReleaser:(NSTimer *)timr {
    [timr.userInfo release];
}

- (void)presentationControllerDidDismiss:(UIPopoverPresentationController *)popoverController {
    assert(popoverController);
    assert(popoverController.presentedViewController);
    [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(popOverControllerReleaser:) userInfo:popoverController.presentedViewController repeats:false];
    [ChronometerAppDelegate dataDone];
}

+ (void)dataDone {
    assert(dataing);
    dataing = false;
#if DIMMERLABEL
    [self clearDimmerLabel];
#endif
    if (!isIpad()) {
        [self dataSlideUp:[self applicationSize].height animationDidStopSelector:@selector(dataAnimationDone: finished: context:)];	    // slide up off screen
    }
    [self showECStatusMessage:[[self currentWatch] displayName]];
    [self hideECTimeLocationStatus];
}

// end EC Data screens ---------------------------------------------------------------------------------------------------------------------------------------------

+ (void)needFactoryWork {
    factoryWorkNeeded = true;
}

+ (void)requestUnattachCheckingForWork:(bool)checkingForWork {
    assert([NSThread isMainThread]);
    //[ChronometerAppDelegate noteTimeAtPhase:"requestUnattach start"];
    for (ECGLWatch *watch in glWatches) {
	[watch doPendingUnattaches];
    }
    //[ChronometerAppDelegate noteTimeAtPhase:"requestUnattach end"];
    if (checkingForWork) {
	[ECGLWatchLoader checkForWork];
    }
}

+ (void)requestUnattach {
    [self requestUnattachCheckingForWork:true];
}

+ (void)unloadAllTextures {
    assert([NSThread isMainThread]);
    //[ChronometerAppDelegate noteTimeAtPhase:"requestUnattach start"];
    [ECGLWatchLoader pauseBG];
    //[ChronometerAppDelegate noteTimeAtPhase:"Loader paused"];
    for (ECGLWatch *watch in glWatches) {
	[watch unloadAllTextures];
    }
    [backgroundWatch unloadAllTextures];
    //[ChronometerAppDelegate noteTimeAtPhase:"after unloadAllTextures"];
    size_t needsBytes;
    [backgroundWatch loadTextureIfRequiredForModeNum:[backgroundWatch currentModeNum] zoomPower2:0 testOnly:false needsBytes:&needsBytes];
    //[ChronometerAppDelegate noteTimeAtPhase:"BG Texture loaded"];
    [ECGLWatchLoader resumeBG];
    //[ChronometerAppDelegate noteTimeAtPhase:"checking for work"];
    // [ChronometerAppDelegate printMemoryUsage:@"After unloadAllTextures"];
    [ECGLWatchLoader checkForWork];
    //[ChronometerAppDelegate noteTimeAtPhase:"requestUnattach end"];
}

// Protocol:
//   BG load does as much as it can, up to 24 Meg (larger for larger devices)
//     - retries on every configuration change (triggered from main thread)
//     - walks from most important to least important (including active watch mode), accumulating
//       "approved space". When it runs out of loaded space, it walks from the "back" of the list
//       (least important, e.g., back side of furthest-away watch) backward, unloading, until the
//       approved space is achieved or we reach the mode we're attempting to load; if the latter,
//       there's nothing more to be done.
//     - the approved space may be more than the actual space if the texture has been attached; in
//       that case, we call into the main thread, requesting a "unload all marked-for-removal faces"
//       pass, which then calls back into the loader thread to allow loading.
//     - easiest to do this back-and-forth if we always keep a sorted list of watch modes sorted by
//       importance
// The presumption is that *all* loading is done through this method, and always through the ECGLWatchLoader's thread;
// this eliminates the need to guard against more than one writer.  Background here means "in the background in another thread"
// and not the "background watch".
// The logic is a bit complicated to avoid making two passes through the watches.  The function does exactly one load, and then
// proceeds enough further to determine whether it needs to be called again.  Hence the "didSomething" -- the presence of that
// flag means we're in test-only mode and we should return when something returns true.
+ (bool)doOneBackgroundLoad {
    assert(inBackground || ![NSThread isMainThread]);

    bool didSomething = false;
    bool didSomethingHere = false;
    size_t usedBytes = [ECGLTextureAtlas totalLoadedSize];
    size_t textureLoadNeedsBytes;
    if (usedBytes > ECMaxLoadedTextureSize) {
	textureLoadNeedsBytes = usedBytes - ECMaxLoadedTextureSize;
    } else {
	textureLoadNeedsBytes = 0;
    }
#ifdef MEMORY_TRACK_TEXTURE
    printf("doOneBackgroundLoad: usedBytes=%.2f MB, max=%.2f MB\n", usedBytes/(1024.0*1024), ECMaxLoadedTextureSize/(1024.0*1024));
#endif

    // Cache the ordered array of descriptors to avoid holding the lock
    WatchModeDescriptor **watchModesByImportanceCache = (WatchModeDescriptor **)malloc(sizeof(WatchModeDescriptor *) * numWatchModeUsedDescriptors);
    [watchModeDescriptorLock lock];
    for (int i = 0; i < numWatchModeUsedDescriptors; i++) {
	watchModesByImportanceCache[i] = watchModesByImportance[i];
    }
    [watchModeDescriptorLock unlock];

    for (int i = 0; i < numWatchModeUsedDescriptors; i++) {
	if (!textureLoadNeedsBytes) {
	    WatchModeDescriptor *descriptor = watchModesByImportanceCache[i];
	    ECGLWatch *watch = descriptor->watch;
	    if ((didSomethingHere = [watch loadArchiveIfRequiredTestOnly:didSomething]) && didSomething) {
		free(watchModesByImportanceCache);
		return true;
	    }
	    didSomething = didSomething || didSomethingHere;
	    didSomethingHere = [watch loadTextureIfRequiredForModeNum:descriptor->modeNum zoomPower2:tweakZoomForScreenScale(descriptor->z2) testOnly:didSomething needsBytes:&textureLoadNeedsBytes];
	    if (didSomethingHere && didSomething) {
		free(watchModesByImportanceCache);
		return true;
	    }
	    didSomething = didSomething || didSomethingHere;
	}
	if (textureLoadNeedsBytes) {
	    bool anyUnattachesNeeded = false;
	    for (int j = numWatchModeUsedDescriptors - 1; j > i && textureLoadNeedsBytes; j--) {
		WatchModeDescriptor *descriptor2 = watchModesByImportanceCache[j];
		ECGLWatch *watch2 = descriptor2->watch;
		bool needUnattach = false;
		size_t bytesMarkedForUnload = [watch2 markTextureUnloadedForModeNum:descriptor2->modeNum zoomPower2:tweakZoomForScreenScale(descriptor2->z2) needUnattach:&needUnattach];
		if (needUnattach) {
		    anyUnattachesNeeded = true;		    
		}
		if (textureLoadNeedsBytes > bytesMarkedForUnload) {
		    textureLoadNeedsBytes -= bytesMarkedForUnload;
		} else {
		    textureLoadNeedsBytes = 0;
		}
	    }
	    // If any unattaches required, tell the main thread
	    if (anyUnattachesNeeded) {
		[self performSelector:@selector(requestUnattach) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
	    }

	    // Question: What do we do next time?  It depends on whether we unloaded or just marked for unattach
	    // If any watches need another pass, then no point in trying again until we have the space
	    // Also, if we were unable to find space, there's no point in continuing
	    free(watchModesByImportanceCache);
	    bool moreToDo = textureLoadNeedsBytes == 0 && !anyUnattachesNeeded;
	    didSomethingHere = [ECGLTextureAtlas writeOnePngTestOnly:moreToDo];
	    moreToDo = moreToDo || didSomethingHere;
	    return moreToDo;
	}
    }
    free(watchModesByImportanceCache);
    didSomethingHere = [ECGLTextureAtlas writeOnePngTestOnly:didSomething];
    didSomething = didSomething || didSomethingHere;
    return didSomething;
}

+ (UIImage *)savedImage {
    [ChronometerAppDelegate saveState];
    return applicationImage;
}

+ (void)writeStateImage:(UIImage *)stateImage ToPath:(NSString *)path {
    NSData *imageData = UIImagePNGRepresentation(stateImage);
    [imageData writeToFile:path atomically:YES];
#ifndef NDEBUG
//    printf("writeToFileAtomically to '%s' = %d\n", [path UTF8String], ret);
#endif
}

+ (void)writeState { // Write the state in RAM to disk
    [ChronometerAppDelegate writeStateImage:applicationImage ToPath:[documentDirectoryName  stringByAppendingPathComponent:@"Default.png"]];
    
    // Write the captured date to prefs
    NSData *dateData = [NSKeyedArchiver archivedDataWithRootObject:dateReflectingCapturedImage requiringSecureCoding:NO error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:dateData forKey:@"lastDate"];
    // Write all the stopwatch timers to prefs
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [applicationImage release];
    applicationImage = nil;
#ifndef NDEBUG
    [ChronometerAppDelegate noteTimeAtPhase:"applicationDidReceiveMemoryWarning:"];
    [ChronometerAppDelegate printMemoryUsage:@"------------ "];
#endif
    if (!inBackground) { // we're already at zero if we're in the background
	ECMaxMaxTextureSize = fmax(ECMaxMaxTextureSize - 1024*1024, ECMinMaxTextureSize);  // Avoid cycling between low and high water marks forever
	if (ECMaxLoadedTextureSize > ECMinMaxTextureSize + ECMemoryDecrementAmount) {
	    ECMaxLoadedTextureSize = fmax(ECMaxLoadedTextureSize-ECMemoryDecrementAmount, ECMinMaxTextureSize);
	} else {
	    ECMaxLoadedTextureSize = ECMinMaxTextureSize;
	}
#ifndef NDEBUG
	//printf("Reducing memory to %.2f MB\n", ECMaxLoadedTextureSize / (1024.0 * 1024));
	//printWatchDescriptorArray();
#endif
	[ECGLWatchLoader checkForWork];
    }
}

static unsigned int reservedMemory;

- (void)tryToIncreaseMemory:(NSTimer *)t {
    if (inBackground) {
	return;
    }
    if (ECMaxLoadedTextureSize + reservedMemory < ECMaxMaxTextureSize) {
	ECMaxLoadedTextureSize += 1024*1024;
#ifndef NDEBUG
	//[ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"bumped ECMaxLoadedTextureSize to %d MB", (int)ECMaxLoadedTextureSize/(1024*1024)]];
#endif
	[ECGLWatchLoader checkForWork];
    }
}

+ (void)reserveBytesOfMemory:(unsigned int)bytes {
    assert(reservedMemory == 0);
    if (!inBackground) {
	reservedMemory = fmin(bytes, (ECMaxLoadedTextureSize - ECMinMaxTextureSize));
	ECMaxLoadedTextureSize -= reservedMemory;
#ifndef NDEBUG
	//[ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"reducing ECMaxLoadedTextureSize by %d k to %d MB", reservedMemory/(1024), (int)ECMaxLoadedTextureSize/(1024*1024)]];
#endif
	[ECGLWatchLoader checkForWork];
    }
}

+ (void)releaseReservedMemory {
    if (inBackground) {
	lastNonBackgroundTextureSize += reservedMemory;
	return;
    }
    ECMaxLoadedTextureSize += reservedMemory;
#ifndef NDEBUG
    [ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"increasing ECMaxLoadedTextureSize by %d k to %d MB", reservedMemory/(1024), (int)ECMaxLoadedTextureSize/(1024*1024)]];
#endif
    [ECGLWatchLoader checkForWork];
    reservedMemory = 0;
}

static NSNumberFormatter *sizeFormatter;

#if !TARGET_IPHONE_SIMULATOR
#ifdef EC_HENRY
syntax error;  // Don't try to build Henry for the device
#endif
#endif

static void initializeSizeFormatter() {
    sizeFormatter = [[NSNumberFormatter alloc] init];
    [sizeFormatter setUsesGroupingSeparator:YES];
}

static NSString *formattedSize(size_t size) {
    if (!sizeFormatter) {
	initializeSizeFormatter();
    }
    if (size % (1024 * 1024) == 0) {
	return [NSString stringWithFormat:@"%ld  MB  ", size / (1024 * 1024)];
    }
    NSNumber *number = [NSNumber numberWithUnsignedLong:size];
    assert(number);
    NSString *numberString = [sizeFormatter stringFromNumber:number];
    assert(numberString);
    return numberString;
}

static void printMemoryLine(size_t size, NSString *description) {
    NSString *formattedString = formattedSize(size);
    printf("%12s : %s\n", [formattedString UTF8String], [description UTF8String]);
}

+ (void)printMemoryUsage:(NSString *)msg {
    printf("\n%s: Memory usage at %s\n", [msg UTF8String], [[[NSDate date] description] UTF8String]);
    size_t totalMemory = 0;
    size_t watchSize = class_getInstanceSize([ECGLWatch class]);
    size_t partSize = class_getInstanceSize([ECGLPart class]);
    size_t textureAtlasSize = class_getInstanceSize([ECGLTextureAtlas class]);
    printMemoryLine(ECMaxLoadedTextureSize, @"ECMaxLoadedTextureSize");
    printMemoryLine(watchSize * glWatchCount, [NSString stringWithFormat:@"%3d %3zd-byte ECGLWatch objects (direct storage)", glWatchCount, watchSize]);
    totalMemory += watchSize * glWatchCount;
    int numParts = 0;
    for (ECGLWatch *watch in glWatches) {
	numParts += [watch numPartBases];
    }
    printMemoryLine(partSize * numParts, [NSString stringWithFormat:@"%3d %3zd-byte ECGLPart objects (direct storage)", numParts, partSize ]);
    totalMemory += partSize * numParts;

    int totDisplayLists = 0;
    int totDisplayListParts = 0;
    size_t totDisplayListSize = 0;
    for (ECGLWatch *watch in glWatches) {
	int numDisplayLists;
	int numDisplayListParts;
	size_t displayListSize;
	[watch displayListMemoryUsage:&displayListSize numDisplayLists:&numDisplayLists numDisplayListParts:&numDisplayListParts];
	totDisplayListSize += displayListSize;
	totDisplayLists += numDisplayLists;
	totDisplayListParts += numDisplayListParts;
    }
    printMemoryLine(totDisplayListSize, [NSString stringWithFormat:@"%3d display lists with %3d parts", totDisplayLists, totDisplayListParts]);
    totalMemory += totDisplayListSize;

    size_t attachedSize;
    size_t pendingSize;
    int numLoaded;
    int numAttached;
    int numTotal;
    [ECGLTextureAtlas reportMemoryUsage:&attachedSize pendingSize:&pendingSize numLoaded:&numLoaded numAttached:&numAttached numTotal:&numTotal];
    printMemoryLine(numTotal * textureAtlasSize, [NSString stringWithFormat:@"%3d %3zd-byte texture atlas objects (direct storage)", numTotal, textureAtlasSize]);
    totalMemory += numTotal * textureAtlasSize;

    printMemoryLine(pendingSize, [NSString stringWithFormat:@"%3d loaded but unattached texture data arrays", numLoaded - numAttached]);
    totalMemory += pendingSize;
    
    printMemoryLine(attachedSize, [NSString stringWithFormat:@"%3d attached textures", numAttached]);
    totalMemory += attachedSize;

    printf("------------\n");
    printMemoryLine(totalMemory, @"Total memory");
    printf("\n");
}

static size_t beforeAttachedSize[2], beforePendingSize[2];
static int beforeNumLoaded[2], beforeNumAttached[2], beforeNumTotal[2];
+ (void)noteTextureMemoryBeforeOperation:(NSString *)description {
    int which = [NSThread isMainThread] ? 0 : 1;
    [ECGLTextureAtlas reportMemoryUsage:&beforeAttachedSize[which]
			    pendingSize:&beforePendingSize[which]
			      numLoaded:&beforeNumLoaded[which]
			    numAttached:&beforeNumAttached[which]
			       numTotal:&beforeNumTotal[which]];
//    printf("[         LOADED                   ATTACHED        ] %s START\n", [description UTF8String]);
}

+ (void)printTextureMemoryBeforeAfterOperation:(NSString *)description {
    int which = [NSThread isMainThread] ? 0 : 1;
    int afterNumLoaded;
    int afterNumAttached;
    int numTotal;
    size_t afterAttachedSize, afterPendingSize;
    [ECGLTextureAtlas reportMemoryUsage:&afterAttachedSize pendingSize:&afterPendingSize numLoaded:&afterNumLoaded numAttached:&afterNumAttached numTotal:&numTotal];
    printf("[%5s (%2d) => %5s (%2d)  %5s (%2d) => %5s (%2d)] %s\n",
	   [formattedSize(beforeAttachedSize[which] + beforePendingSize[which]) UTF8String],
	   beforeNumLoaded[which],
	   [formattedSize(afterAttachedSize + afterPendingSize) UTF8String],
	   afterNumLoaded,
	   [formattedSize(beforeAttachedSize[which]) UTF8String],
	   beforeNumAttached[which],
	   [formattedSize(afterAttachedSize) UTF8String],
	   afterNumAttached,
	   [description UTF8String]);
}

- (void)applicationWillTerminate:(UIApplication *)application {
#ifndef NDEBUG
    [ChronometerAppDelegate noteTimeAtPhase:"applicationWillTerminate..."];
#endif
    for (ECGLWatch *watch in glWatches) {
	[watch.mainTime saveStateForWatch:watch.name];
    }
#ifdef EC_STORE
    [ECStore cancelCurrentConnection];
#endif
    [[NSUserDefaults standardUserDefaults] synchronize];  // make sure we get written to disk even if we just changed something
#if 0
    [[ChronometerAppDelegate currentWatch] dumpVariableValues];
    bool captureOK = true;
    for (ECWatchController *watchCon in watches) {
	captureOK = captureOK & [watchCon willTerminate];
    }
    if (captureOK) {
	[ChronometerAppDelegate saveState];
    }
    [ChronometerAppDelegate writeState];
#endif
    [ECAppLog log:@"Application end"];
    //printf("Emerald Chronometer EOJ\n");
}

- (void)dealloc {
    // it seems that we never get here
    [glWatches removeAllObjects];
    [glWatches release];
//  [pager  release];
    [theTopLevelView release];
    [lastWatchName release];
    [documentDirectoryName release];
    [observers release];
    [super dealloc];
}

@end
