//
//  ChronometerAppDelegate.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/16/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECWatchController.h"

#include "ESCalendar.h"  // For opaque ESTimeZone

extern size_t ECMaxLoadedTextureSize;

@class ECWatchController, ECGLWatch, ECGLPartBase;


@interface ChronometerAppDelegate: NSObject <UIActionSheetDelegate, UIApplicationDelegate, UIPopoverPresentationControllerDelegate> {
    // static UIWindow *theWindow;
    // static UIPageControl *pager;
}

+ (void)startOfMain;
+ (void)setDALForBatteryState;
+ (void)noteTimeAtPhase:(const char *)phaseName;
+ (void)noteTimeAtPhaseWithString:(NSString *)phaseName;
+ (void)noteTextureMemoryBeforeOperation:(NSString *)description;
+ (void)printTextureMemoryBeforeAfterOperation:(NSString *)description;
+ (void)listLocalNotifications;
#ifdef EC_HENRY
+ (bool)addWatch:(ECWatchController *)aWatchCon;	    // returns false if the name is a dup
+ (void)ensureWatchLoadedInHenry:(NSString *)watchName;
#endif
+ (ECGLWatch *)currentWatch;
+ (ECGLWatch *)adjacentWatch;
+ (int)currentWatchNumber;
+ (int)watchCount;
+ (int)availableWatchCount;
+ (NSArray *)indexPathsForInactiveWatches;
+ (NSString *)watchNameForIndex:(int)watchNumber;
+ (ECGLWatch *)activeWatchForIndex:(int)watchNumber;
+ (ECGLWatch *)activeWatchForIndex:(int)watchNumber availableIndex:(int *)availableIndex;
+ (ECGLWatch *)availableWatchForIndex:(int)watchNumber;
+ (ECGLWatch *)availableWatchForIndex:(int)watchNumber isActive:(bool *)isActive;
+ (ECGLWatch *)availableWatchWithName:(NSString *)nam;
+ (ECGLWatch *)backgroundWatch;
+ (bool)inBackground;
+ (void)setActiveForAllAvailableWatches:(bool)turnOn;
+ (void)moveWatchAtAvailableIndex:(int)fromIndex toIndex:(int)toIndex;
+ (void)setWatchActive:(bool)isActive forAvailableIndex:(int)availableIndex alreadyLocked:(bool)alreadyLocked;
+ (void)previousWatch;
+ (void)nextWatch;
+ (void)waitForWatchToLoad:(ECGLWatch *)watch;
+ (void)switchToWatchNumber:(int)watchNumber;
+ (void)switchToWatch:(ECGLWatch *)watch;
+ (bool)switchToNextActiveAlarmWatch;
+ (void)activateWatch:(ECGLWatch *)watch;
+ (void)deactivateWatch:(ECGLWatch *)watch;
+ (void)setTimeZone:(ESTimeZone *)newTZ;
+ (void)requestRedraw;
+ (bool)displayLocked;
+ (void)forceUpdateAllowingAnimation:(bool)allowAnimation dragType:(ECDragType)dragType;
+ (void)forceUpdateInMainThread;
+ (void)resetUpdateTime;
+ (void)willLayoutSubviews;
+ (void)willRotateToOrientation:(UIInterfaceOrientation)newOrient duration:(NSTimeInterval)duration;
+ (void)willAnimateRotationToOrientation:(UIInterfaceOrientation)newOrient duration:(NSTimeInterval)duration;
+ (void)didRotateFromOrientation:(UIInterfaceOrientation)fromOrient;
+ (bool)currentOrientationIsLandscape;
+ (bool)isFirstGenerationHardware;
+ (void)backFlip;
+ (void)nightFlip;
+ (void)dayFlip;
+ (void)infoFlip;
+ (void)optionFlip;
+ (void)gridFlip;
+ (void)dataFlip:(int)which;
+ (void)donePositionZoomAnimatingWhenAllWatchesFinishDrawing;
+ (void)forceUpdateWhenZoomStops;
+ (void)unGridifyFromPressAtPoint:(CGPoint)gridSelectionPoint;
+ (bool)inGridOrOptionMode;
+ (bool)inSpecialMode;
+ (bool)inGridMode;
+ (bool)displayingZ2:(int)z2;
+ (void)helpFlip:(NSString *)topic;
+ (bool)helping;
+ (void)infoDone:(NSString *)lastPage;
+ (void)infoSlideUp:(double)deltaY notify:(BOOL)notify;
+ (void)selectorFlip;
+ (void)selectorCancelAnimatingInGrid:(bool)animatingInGrid;
+ (void)selectorCancel;
+ (void)selectorChoose:(int)indx;
+ (void)optionToHelp:(NSString *)topic;
+ (void)optionDone;
+ (void)dataDone;
+ (void)needFactoryWork;
+ (void)setPartBeingEvaluated:(ECGLPartBase *)part;
+ (bool)thisButtonPressed;
+ (CGSize)applicationSize;  // area which includes safe area insets (notch and symmetric pseudo notch), in points
+ (CGSize)applicationSizePoints;  // excludes safe area insets
+ (CGRect)applicationBoundsPoints;  // excludes safe area insets, origin at bottom left
+ (CGSize)applicationSizePixels;  // excludes safe area insets
+ (CGRect)applicationBoundsPixels;  // excludes safe area insets, origin at bottom left
+ (CGSize)applicationSizeWatchCoordinates;
+ (CGSize)applicationViewSizePoints;  // area includes safe area insets (notch and symmetric pseudo notch), in points
+ (CGSize)applicationWindowSizePoints;  // same as applicationViewSizePoints but uses window (used to construct view)
+ (CGFloat)iPhoneScaleFactor;
+ (CGFloat)screenScale;
+ (CGFloat)nativeScale;
+ (int)screenScaleZoomTweak;
+ (void)translateCornerRelativeOrigin:(CGPoint *)origin;
+ (void)setNetworkActivityIndicator:(bool)active;
+ (void)showECTimeStatus;
+ (void)showAlarmStatus;
+ (void)updateAlarmStatus;
+ (void)showECLocationStatus;
+ (void)hideECTimeLocationStatus;
+ (void)showECStatusWarning:(NSString *)msg;
+ (void)showECStatusMessage:(NSString *)msg;
+ (void)setupDSTEventTimer;
+ (bool)doOneBackgroundLoad;
- (void)tryToIncreaseMemory:(NSTimer *)t;
+ (void)reserveBytesOfMemory:(unsigned int)bytes;
+ (void)releaseReservedMemory;
+ (float)batteryLevel;
+ (double)nogridZoom;

+ (void)cancelMainThreadRedrawUpdate;
+ (void)resumeMainThreadRedrawUpdate;

+ (void)alarmFiredInWatch:(ECGLWatch *)watch;
#ifdef ECDIMMER
+ (double)setDimmer:(double)val;
+ (double)dimmerValue;
+ (void)clearDimmerLabel;
#endif
+ (void)unloadAllTextures;
+ (bool)firstRun;

// Observers
+ (void)addObserver:(id)observer significantTimeChangeSelector:(SEL)significantTimeChangeSelector;
+ (void)removeObserver:(id)observer;
+ (void)addReallySignficantObserver:(id)observer significantTimeChangeSelector:(SEL)significantTimeChangeSelector;
+ (void)removeReallySignificantObserver:(id)observer;

// State saving
+ (void)saveState;  // save state in RAM (including image)
+ (UIImage *)savedImage;	// return a copy of a newly saved image
+ (void)writeStateImage:(UIImage *)stateImage ToPath:(NSString *)filename;
+ (void)writeState; // write state from RAM to disk

// User input
+ (void)touchBeganAtPoint:(CGPoint)point;
+ (void)touchMovedFromFirstTouch:(CGPoint)firstTouchPoint to:(CGPoint)currentPoint;
+ (void)touchEndedPossiblySwipingLeft:(bool)swipeLeft right:(bool)swipeRight press:(bool)press hold:(bool)hold at:(CGPoint)currentPoint count:(int)tapCount;
+ (NSTimeInterval)animationOverrideInterval;

// Debug print
+ (void)printMemoryUsage:(NSString*)msg;

@end

extern NSString *
orientationNameForOrientation(UIInterfaceOrientation orient);

// this "class" is just here to suppress a warning on the use of the undocumented "createApplicationDefaultPNG"
@interface UIApplicationHack : UIApplication {
}
- (CGImageRef)createApplicationDefaultPNG;
@end
