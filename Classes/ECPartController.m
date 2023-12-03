//
//  ECPartController.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/23/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ChronometerAppDelegate.h"
#import "ECPartController.h"
#import "ECWatchController.h"
#import "ECWatchTime.h"
#import "ECQView.h"
#import "ECWatchPart.h"
#import "ECDynamicUpdate.h"
#import "ECWatchArchive.h"
#import "EBVirtualMachine.h"
#import "AudioFX.h"
#import "Constants.h"

NSTimeInterval onEvenTime(double t, double interval, double offset) {
    NSTimeInterval nt = (((floor(t / interval)) * interval) + offset);
    if (nt < t) {
	nt += interval;
    }
    return nt;
}


@implementation ECPartController

@synthesize watchController, model, ecView, envSlot, specialness, cornerRelative;

- (ECPartController *)initWithModel:(ECWatchPart *)modelItem master:(ECWatchController *)theBoss grabPrio:(int)aGrabPrio envSlot:(int)anEnvSlot cornerRelative:(bool)aCornerRelative specialness:(int)aSpecialness specialParameter:(unsigned int)aSpecialParameter {
    assert(modelItem);
    assert(theBoss);
    if (self = [super init]) {
	model = [modelItem retain];
	watchController = theBoss;
	ecView = nil;
	grabPrio = aGrabPrio;
	envSlot = anEnvSlot;
        cornerRelative = aCornerRelative;
	specialness = aSpecialness;
	specialParameter = aSpecialParameter;
	xrayLevel = [watchController addSubController:self];	    // indirectly triggers view initialization and hence calls our subclasses' loadViews
    }
    return self;
}

- (bool)isVisual {
    return true;						    // parts with no views override and return false
}

- (ECPartRepeatStrategy)repeatStrategy {
    return ECPartDoesNotRepeat;
}

- (bool)immediate {
    return false;
}

- (bool)expanded {
    return false;
}

- (bool)flipOnBack {
    return false;
}

- (bool)flipX {
    return false;
}

- (bool)flipY {
    return false;
}

- (ECButtonEnabledControl)enabledControl {
    return ECButtonEnabledStemOutOnly;
}

- (int)grabPrio {
    return grabPrio;
}

// The ordering of the writes in this method must correspond to the ordering of the reads in ECGLPart::initFromArchive
- (void)archivePartToImagePath:(NSString *)imagePath
	usingTextureSlotNumber:(int)textureSlot
	       needToSaveImage:(bool)needToSaveImage
		   masterIndex:(int)masterIndex
	     usingWatchArchive:(ECWatchArchive *)watchArchive
	   usingVirtualMachine:(EBVirtualMachine *)vm {
    ECQView *view = [self ecView];
    bool isDimPart = ([[model name] caseInsensitiveCompare:@"dim"] == NSOrderedSame);
    bool isRedBannerPart = ([[model name] caseInsensitiveCompare:@"red banner"] == NSOrderedSame);
    if (view) {
	assert(imagePath);
	CGRect bounds = [view boundsOnScreen];
        CGFloat roundUpX = ceil(bounds.size.width) - bounds.size.width;
        CGFloat roundUpY = ceil(bounds.size.height) - bounds.size.height;
	CGRect aBoundsOnScreen = CGRectMake(bounds.origin.x - ECTexturePartPadding - roundUpX/2, bounds.origin.y - ECTexturePartPadding - roundUpY/2, bounds.size.width + roundUpX + ECTexturePartPadding * 2, bounds.size.height + roundUpY + ECTexturePartPadding * 2);
	CGSize screenSize = [ChronometerAppDelegate applicationSizePoints];
	if (isDimPart) {
	    aBoundsOnScreen = CGRectMake(-screenSize.width/2, -screenSize.height/2, screenSize.width, screenSize.height);
	}
#if 0
        if ([[watchController name] caseInsensitiveCompare:@"Terra"] == NSOrderedSame &&
            [[model name] caseInsensitiveCompare:@"sec"] == NSOrderedSame) {
            printf("Archiving second-hand part, boundsOnScreen = (%.1f, %.1f), w=%.1f, h=%.1f, anchor = (%.1f, %.1f), direct bounds (%.2f, %.2f), w=%.2f, h=%.2f\n",
                   aBoundsOnScreen.origin.x, 
                   aBoundsOnScreen.origin.y,
                   aBoundsOnScreen.size.width,
                   aBoundsOnScreen.size.height,
                   [view anchorPointOnScreen].x,
                   [view anchorPointOnScreen].y,
                   bounds.origin.x, 
                   bounds.origin.y,
                   bounds.size.width,
                   bounds.size.height
                   );
        }
#endif
	[watchArchive writeWatchPartDataWithFrontTextureSlot:textureSlot
					     backTextureSlot:textureSlot
					    nightTextureSlot:textureSlot
					      boundsOnScreen:aBoundsOnScreen
					      anchorOnScreen:[view anchorPointOnScreen]
					      updateInterval:[model updateInterval]
					updateIntervalOffset:[model updateIntervalOffset]
						 updateTimer:[model updateTimer]
						    modeMask:[model modeMask]
						    handKind:[model handKind]
						    dragType:[ecView dragType]
					   dragAnimationType:[ecView dragAnimationType]
						   animSpeed:[ecView animSpeed]
						     animDir:[ecView animDir]
						    grabPrio:[self grabPrio]
						     envSlot:envSlot
						 specialness:specialness
					    specialParameter:specialParameter
						    norotate:[ecView norotate]
					      cornerRelative:[self cornerRelative]
						  flipOnBack:[self flipOnBack]
						       flipX:[self flipX]
						       flipY:[self flipY]
					     centerPixelOnly:(isDimPart || isRedBannerPart)
					 usingVirtualMachine:vm
				      angleInstructionStream:[model angleInstructionStream]
				    xOffsetInstructionStream:[model xOffsetInstructionStream]
				    yOffsetInstructionStream:[model yOffsetInstructionStream]
						offsetRadius:[model offsetRadius]
				offsetAngleInstructionStream:[model offsetAngleInstructionStream]
				     actionInstructionStream:[model actionInstructionStream]
					      repeatStrategy:[self repeatStrategy]
						   immediate:[self immediate]
						    expanded:[self expanded]
						 masterIndex:masterIndex
					      enabledControl:[self enabledControl]];
    } else {
	assert(!imagePath);
	assert([model actionInstructionStream]);
	[watchArchive writeRect:CGRectMake(boundsOnScreen.origin.x - ECTexturePartPadding,
					   boundsOnScreen.origin.y - ECTexturePartPadding,
					   boundsOnScreen.size.width + ECTexturePartPadding * 2,
					   boundsOnScreen.size.height + ECTexturePartPadding * 2)];
	[watchArchive writeInteger:(int)[self enabledControl]];
	[watchArchive writeInteger:[model modeMask]];
	[watchArchive writeInstructionStream:[model actionInstructionStream] usingVirtualMachine:vm];
	[watchArchive writeInteger:[self repeatStrategy]];
	[watchArchive writeInteger:[self immediate]];
	[watchArchive writeInteger:[self expanded]];
	[watchArchive writeInteger:[self grabPrio]];
	[watchArchive writeInteger:envSlot];
        [watchArchive writeInteger:[self flipOnBack]];
        [watchArchive writeInteger:[self cornerRelative]];
    }
}

- (void)lastMinuteViewPrep {
    // do nothing; some subclasses override
}

- (NSTimeInterval)intervalThreshold {
    return 0;  // subclasses can override
}

- (void)willTerminate {
}

- (void)printTimer {
    if (xrayLevel == 0) {
	printf("\t\t[  ] %8s:'%-15s'\t",             [[[watchController watch] name]UTF8String], [[model name]UTF8String]);
    } else {
	printf("\t\t[%2d] %8s:'%-15s'\t", xrayLevel, [[[watchController watch] name]UTF8String], [[model name]UTF8String]);
    }
}

- (NSString *)className {
    return @"-PART-";
}

- (void)print {
    printf("\t%s\t",[[self className]UTF8String]);
    if (xrayLevel == 0) {
	printf("[  ] %8s:'%-15s'\t",             [[[watchController watch] name]UTF8String], [[model name]UTF8String]);
    } else {
	printf("[%2d] %8s:'%-15s'\t", xrayLevel, [[[watchController watch] name]UTF8String], [[model name]UTF8String]);
    }
    printf("modeMask=%d %s ", [model modeMask], [self isVisual] ? "vis" : "not");
    if ([self isKindOfClass:[ECVisualController class]]) {
#ifdef NDEBUG
	printf("bar\t");
#else
	printf("%s\t", [[(ECQView *)[self ecView]className]UTF8String]);
#endif
	[(id)[self ecView] print];
    }
}
	
- (void)dealloc {
    [model release];
    [super dealloc];
}

@end


@implementation ECVisualController

- (ECVisualController *)initWithModel:(ECWatchPart *)modelItem
				 view:(ECQView *)aView
			       master:(ECWatchController *)theBoss
			       opaque:(bool)opaque
			     grabPrio:(int)aGrabPrio
			      envSlot:(int)anEnvSlot
			  specialness:(int)aSpecialness
		     specialParameter:(unsigned int)aSpecialParameter
                       cornerRelative:(bool)aCornerRelative {
    [aView setController:self];
    id tmp = (ECVisualController *)[self initWithModel:modelItem master:theBoss grabPrio:aGrabPrio envSlot:anEnvSlot cornerRelative:aCornerRelative specialness:aSpecialness  specialParameter:aSpecialParameter];
    assert(self == tmp);	tmp=tmp;  // shut up warning
    ecView = [aView retain];
    opaquePart = opaque;
    return self;
}

- (bool)flipX {
    return [ecView flipX];
}

- (bool)flipY {
    return [ecView flipY];
}

- (NSString *)className {
    return @"Visual";
}

@end


@implementation ECAnimationController

- (void)print {
    [super print];
}

- (NSString *)className {
    return @"Animat";
}

@end


@implementation ECHandController

- (ECHandController *)initWithModel:(ECWatchPart *)aModel
			       view:(ECQView *)view
			     master:(ECWatchController *)theBoss
			     opaque:(bool)opaque
			   grabPrio:(int)aGrabPrio
			    envSlot:(int)anEnvSlot
			specialness:(int)aSpecialness
		   specialParameter:(unsigned int)aSpecialParameter
                     cornerRelative:(bool)aCornerRelative {
    if (self = (id)[super initWithModel:aModel view:view master:theBoss opaque:opaque grabPrio:aGrabPrio envSlot:anEnvSlot specialness:aSpecialness specialParameter:aSpecialParameter cornerRelative:aCornerRelative]) {
    }
    return self;
}

- (void)print {
    [super print];
}

- (NSString *)className {
    return @" Hand ";
}

@end


@implementation ECBlinkerController

- (void)print {
    [super print];
}

- (NSString *)className {
    return @"Blinkr";
}

@end


@implementation ECTickController

- (bool)shouldTick {
    return watchController.audibleTicks;
}

#if 0
- (bool)enabled {
    return (model.modeMask & [model watch].mode) != 0;
}
#endif

- (bool)isVisual {
    return false;						    // no view
}

- (void)audibilize {
//    [AudioFX playAtPath:[(ECWatchTick *)model soundFile]];
}

- (NSTimeInterval)intervalThreshold {
    return 0.1;
}

- (void)print {
    [super print];
}

- (NSString *)className {
    return @" Tick ";
}

@end


static NSOperationQueue *tuneQ = nil;

@implementation ECTuneController

+ (void)initialize {
    tuneQ = [[NSOperationQueue alloc]init];
}

- (ECTuneController *)initWithModel:(ECWatchTune *)aModel master:(ECWatchController *)theBoss {
    if (self = (ECTuneController *)[super initWithModel:aModel master:theBoss grabPrio:ECGrabPrioDefault envSlot:0 cornerRelative:false specialness:0 specialParameter:0]) {
        assert(model.updateInterval != 0);	// otherwise what are we supposed to do?
	assert(tuneQ);
	assert(tuneOp == nil);
    }
    return self;
}

- (bool)isVisual {
    return false;						    // no view
}

- (NSTimeInterval)intervalThreshold {
    return 40.0;
}

- (void)playTune {
    assert(tuneOp);
    NSString *toneseq = [(ECWatchTune *)model tones];
    int i, n = [toneseq length];
    for (i=0; i<n; i++) {
	if (tuneOp.isCancelled)
	    break;
	if ([toneseq characterAtIndex:i] != ' ')
//	    [AudioFX playAtPath:[NSString stringWithFormat:@"%c.wav", [toneseq characterAtIndex:i]]];
	[NSThread sleepForTimeInterval:((ECWatchTune *)model).delay];
    }
    [tuneOp release];		
    tuneOp = nil;
}

- (void)audibilize {
    assert(tuneQ);
    if (tuneOp == nil) {	// play only one at a time for this part (though there may be other parts playing simultaneously)
	tuneOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(playTune) object:nil];
	assert(tuneOp);
	[tuneQ addOperation:tuneOp];
    }
}

- (void)willTerminate {
    [tuneOp cancel];
    [super willTerminate];
}

- (void)print {
    [super print];
}

- (void)dealloc {
    [tuneOp cancel];
    [super dealloc];
}

- (NSString *)className {
    return @" Tune ";
}

@end

@implementation ECButtonController

- (ECButtonController *)initWithModel:(ECWatchButton *)part
			       master:(ECWatchController *)container
				image:(UIImage *)img
			      image2x:(UIImage *)img2x
			      image4x:(UIImage *)img4x
			      opacity:(double)op
				    x:(double)x
				    y:(double)y
				width:(double)w
			       height:(double)h
		       enabledControl:(ECButtonEnabledControl)anEnableControl
		       repeatStrategy:(ECPartRepeatStrategy)aRepeatStrategy
			    immediate:(bool)imm
			     expanded:(bool)expd
			   flipOnBack:(bool)aFlipOnBack
			       xScale:(double)xs
			       yScale:(double)ys
			    animSpeed:(double)animSpeed
			     grabPrio:(int)aGrabPrio
			      envSlot:(int)anEnvSlot
			  specialness:(int)aSpecialness
		     specialParameter:(unsigned int)aSpecialParameter
		       cornerRelative:(bool)aCornerRelative
			     rotation:(double)rot
			      xMotion:(double)xm
			      yMotion:(double)ym {
    xOffset = x;	    // hack: out of order initialization
    yOffset = y;
    width = w;
    height = h;
    xScale = xs;
    yScale = ys;
    enableControl = anEnableControl;
    opacity = op;
    xMotion = xm;
    yMotion = ym;
    rotation = rot;
    repeatStrategy = aRepeatStrategy;
    immediate = imm;
    expanded = expd;
    flipOnBack = aFlipOnBack;
    image = [img retain];
    image2x = [img2x retain];
    image4x = [img4x retain];
    id tmp = [super initWithModel:part master:container grabPrio:aGrabPrio envSlot:anEnvSlot cornerRelative:aCornerRelative specialness:aSpecialness specialParameter:aSpecialParameter];
    assert(tmp == self);	    tmp=tmp; // shut up warning
    if (image) {
	ecView = [[ECImageView alloc] initCenteredWithImage:image
						    image2x:image2x
						    image4x:image4x
			      xCenterOffsetFromScreenCenter:xOffset
			      yCenterOffsetFromScreenCenter:yOffset
						    radius2:0
						  animSpeed:animSpeed
						    animDir:ECAnimationDirClosest
						   dragType:ECDragNormal      
					  dragAnimationType:ECDragAnimationAlways  // buttons always animate
						      alpha:1
						     xScale:1
						     yScale:1
						   norotate:false];
	[ecView setController:self];
	assert([self ecView] == ecView);
    }
    boundsOnScreen.origin.x = x;
    boundsOnScreen.origin.y = y;
    boundsOnScreen.size.width = w;
    boundsOnScreen.size.height = h;
    return self;
}

- (ECPartRepeatStrategy)repeatStrategy {
    return repeatStrategy;
}

- (bool)immediate {
    return immediate;
}

- (bool)expanded {
    return expanded;
}

- (bool)flipOnBack {
    return flipOnBack;
}

- (ECButtonEnabledControl)enabledControl {
    return enableControl;
}

- (void)lastMinuteViewPrep {
}

- (void)dealloc {
    [repeater invalidate];
    [image release];
    [image2x release];
    [image4x release];
    [super dealloc];
}

- (void)print {
#ifndef NDEBUG
    [super print];
#ifdef FIXFIXFIX
    printf("%s\tUIE: %s\t%s, opacity:%5.2f %s\t@(%4.0f,%4.0f)(%4.0f,%4.0f)", [[(ECQView *)[self view]className]UTF8String], [[self view] isUserInteractionEnabled] ? "YES" : "NO", [self view].isHidden ? "hidden" : "visible",
	   [[self view] layer].opacity, [(id)[self view] isEnabled] ? "enabled" : "disabled", xOffset, yOffset, [[self view]center].x, [[self view]center].y);
#endif
#endif
}

- (NSString *)className {
    return @"Button";
}

@end
