//
//  ECQView.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 5/21/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECQView.h"
#import "ECPartController.h"
#import "ECWatchPart.h"
#import "ECWatchTime.h"  // Hack for angularVelocity method
#import "ECErrorReporter.h"
#import "Constants.h"
#import "ECGlobals.h"

#define ECMinimumAnimationTime (0.05)

@implementation ECHoleHolder

@synthesize rect, borderWidth, strokeColor, type, endAngle, startAngle;

-(ECHoleHolder *)initWithType:(ECHoleType)typ x:(double)x y:(double)y w:(double)w h:(double)h startAngle:(double)sa endAngle:(double)ea borderWidth:(double)bw strokeColor:(UIColor *)clr {
    if (self = [super init]) {
	type = typ;
	rect.origin.x = x;
	rect.origin.y = y;
	rect.size.width = w;
	rect.size.height = h;
	startAngle = sa;
	endAngle = ea;
	strokeColor = [clr retain];
	borderWidth = bw;
    }
    return self;
}

-(void)dealloc {
    [strokeColor release];
    [super dealloc];
}

@end


static void printRect(CGRect rect) {
    printf("Rect @ (%5.1f, %5.1f) sz (%5.1f, %5.1f)",
	   rect.origin.x,
	   rect.origin.y,
	   rect.size.width,
	   rect.size.height);
}

static void printTransform(CGAffineTransform transform) {
    printf("  x' = %.1f*x + %.1f*y + %.1f\n",
	   transform.a, transform.c, transform.tx);
    printf("  y' = %.1f*x + %.1f*y + %.1f\n",
	   transform.b, transform.d, transform.ty);
}

@implementation ECQView

// ECQView coordinate systems:
//
// View coordinates are with respect to the anchor, except when there is no anchor as with
// the screen or a static view, in which case they are with respect to the center of that view

@synthesize boundsInView, boundsOnScreen, controller, dragType, dragAnimationType, norotate;

- (id)initWithBoundsInView:(CGRect)aBoundsInView boundsOnScreen:(CGRect)aBoundsOnScreen dragType:(ECDragType)aDragType dragAnimationType:(ECDragAnimationType)aDragAnimationType norotate:(bool)aNorotate {
    [super init];
    boundsInView = aBoundsInView;
    boundsOnScreen = aBoundsOnScreen;
    holes = [[NSMutableArray alloc]initWithCapacity:4];
    dragType = aDragType;
    dragAnimationType = aDragAnimationType;
    norotate = aNorotate;
    return self;
}

- (id)initWithBoundsInView:(CGRect)aBoundsInView boundsOnScreen:(CGRect)aBoundsOnScreen dragType:(ECDragType)aDragType dragAnimationType:(ECDragAnimationType)aDragAnimationType {
    return [self initWithBoundsInView:aBoundsInView boundsOnScreen:aBoundsOnScreen dragType:aDragType dragAnimationType:aDragAnimationType norotate:false];
}

- (void)clearHere:(ECHoleHolder *)win {
    [holes addObject:win];
    [win retain];
}

- (CGPoint)anchorPointOnScreen {
    double xscale = boundsOnScreen.size.width / boundsInView.size.width;
    double yscale = boundsOnScreen.size.height / boundsInView.size.height;
    return CGPointMake(boundsOnScreen.origin.x - boundsInView.origin.x * xscale,
		       boundsOnScreen.origin.y - boundsInView.origin.y * yscale);
}

- (CGRect)convertFromScreenToView:(CGRect)screenRect {
    double xScale = boundsOnScreen.size.width / boundsInView.size.width;
    double yScale = boundsOnScreen.size.height / boundsInView.size.height;
    return CGRectMake((screenRect.origin.x - boundsOnScreen.origin.x) / xScale + boundsInView.origin.x,
		      (screenRect.origin.y - boundsOnScreen.origin.y) / yScale + boundsInView.origin.y,
		      screenRect.size.width / xScale,
		      screenRect.size.height / yScale);
}

- (bool)phaseOnly {
    return false;
}

- (bool)flipX {
    return false;
}

- (bool)flipY {
    return false;
}

- (bool)skipMakingPNG {
    return false;
}

- (double)animSpeed {
    return 1.0;
}

- (ECAnimationDirection)animDir {
    return ECAnimationDirClosest;
}

- (void)clearHolesForBounds:(CGRect)bounds {	    // make a "window" with a border
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    // Holes are always specified in logical screen coordinates (320/480, centered)
    CGContextTranslateCTM(context, bounds.size.width/2, bounds.size.height/2);

    for (ECHoleHolder *win in holes) {
	double radius = win.rect.size.width / 2;	    		// portholes are always square
	[win.strokeColor set];
	CGContextSetLineWidth(context, win.borderWidth);
	switch (win.type) {
	    case ECHoleWind:
		CGContextStrokeRect(context, win.rect);
		CGContextClearRect(context, win.rect);
		break;
	    case ECHolePort:
		CGContextSaveGState(context);
		CGContextAddArc(context, win.rect.origin.x, win.rect.origin.y, radius, win.startAngle, win.endAngle, 1);
		CGContextClip (context);
		CGContextClearRect(context, CGRectOffset(win.rect, -radius, -radius));
		CGContextRestoreGState(context);
		CGContextAddArc(context, win.rect.origin.x, win.rect.origin.y, radius, win.startAngle, win.endAngle, 1);
		CGContextClosePath(context);
		CGContextStrokePath(context);
		break;
	    default:
		assert(false);
	}
    }
    CGContextRestoreGState(context);
}

- (void)clearHoles {	    // make a "window" with a border
    [self clearHolesForBounds:boundsOnScreen];
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    // subclasses override
}

- (void)drawInViewBounds:(CGRect)rect atZoomFactor:(double)zoomFactor {
    // subclasses override
}

- (void)setupTextTransform:(CGContextRef)context forRect:(CGRect)rect {
    CGAffineTransform transform;  // without transforming, text shows up mirrored about the center of the rect
    // x' = ax + cy + tx
    // y' = bx + dy + ty
    transform.a = 1;
    transform.b = 0;
    transform.c = 0;
    transform.d = -1;
    transform.tx = 0;
    transform.ty = 2 * CGRectGetMidY(rect);
    CGContextConcatCTM(context, transform);
}

- (void)drawText:(NSString *)text
	  inRect:(CGRect)rect
     withContext:(CGContextRef)context
	withFont:(UIFont *)font
       withColor:(UIColor *)color {
    CGContextSaveGState(context);
    [self setupTextTransform:context forRect:rect];
    static NSParagraphStyle *ourStyle = nil;
    if (!ourStyle) {
        assert([NSThread isMainThread]);
        NSMutableParagraphStyle *mutableStyle = [[NSMutableParagraphStyle alloc] init];
        mutableStyle.alignment = NSTextAlignmentCenter;
        mutableStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        ourStyle = mutableStyle;
    }
    // Deprecated iOS 7:  [text drawInRect:rect withFont:font lineBreakMode:UILineBreakModeMiddleTruncation alignment:UITextAlignmentCenter];
    if (text) {
        [text drawInRect:rect withAttributes:@{NSFontAttributeName:font, NSParagraphStyleAttributeName:ourStyle, NSForegroundColorAttributeName:color}];
    }
    CGContextRestoreGState(context);
}

- (void)drawDot:(double)radius x:(double)x y:(double)y {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), .1);
    CGContextAddArc(context, x, y, radius, 0, 2*M_PI, 0);
    CGContextFillPath(context);
}

- (void)drawCircle:(double)radius width:(double)width angle1:(double)a1 angle2:(double)a2 {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, width);
    CGContextAddArc(context, 0, 0, radius, M_PI/2-a2, M_PI/2-a1, 0);
    CGContextStrokePath(context);
}

- (void)drawFilledArcRing:(double)radius
		  radius2:(double)radius2
	     centerRadius:(double)rad
		   angle1:(double)angle1
		   angle2:(double)angle2 {

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // draw the face background
    CGContextAddArc(context, 0, 0, radius, angle1, angle2, 0);
    CGContextAddArc(context, 0, 0, radius2, angle2, angle1, 1);
//    CGContextClosePath(context);
    CGContextEOFillPath(context);

    // mark the center
    if (rad > 0) {
	[[UIColor blackColor] setFill];
	CGContextAddArc(context, 0, 0, rad, 0, 2*M_PI, 0);
	CGContextFillPath(context);
    }
}

- (void)drawFilledCircle:(double)radius radius2:(double)radius2 centerRadius:(double)rad {
    [self drawFilledArcRing:radius radius2:radius2 centerRadius:rad angle1:0 angle2:2*M_PI];
}

- (void)clearInside:(double)innerRadius {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextAddArc(context, 0, 0, innerRadius, 0, 2*M_PI, 1);
    CGContextClip (context);
    CGContextClearRect(context, CGRectMake(-innerRadius, -innerRadius, innerRadius * 2, innerRadius * 2));
    CGContextRestoreGState(context);
}

- (void)drawGuilloche:(ECDiskMarksMask)mask radius:(double)outerRadius radius2:(double)innerRadius nMarks:(double)n angle0:(double)a0 angle1:(double)a1 angle2:(double)a2 mSize:(double)ms mWidth:(double)mw strokeColor:(UIColor *)strokeColor fillColor1:(UIColor*)fillColor1 fillColor2:(UIColor*)fillColor2 {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, mw);
    for (int i=1; i<=n; i++) {
	if ((mask & ECDiskMarksMaskNo5s) && ((i % 5) == 1)) {
	    continue;
	}
	double th = (((double)(i-1))/n)*2*M_PI + a0;

	// draw arcs
	if (mask & ECDiskMarksMaskArc) {
	    CGContextAddArc(context, 0, 0, innerRadius + (outerRadius - innerRadius) *  i / (n + 1), a1-M_PI/2, a2-M_PI/2, 0);
	}

	// draw radial lines
	if (th >= a1 && th <= a2) {
	    th -= M_PI/2;
	    th = -th;
	    if (mask & ECDiskMarksMaskTickIn) {	// draw inner ticks: start from center and radiate outward
		CGContextMoveToPoint   (context, 0, 0);
		CGContextAddLineToPoint(context, ms * cos(th), ms * sin(th));
	    }
	    if (mask & ECDiskMarksMaskTickOut) {    // draw outer ticks: start from circumference and project inward
		double ir = fmax(innerRadius, outerRadius - ms);
		CGContextMoveToPoint   (context,        outerRadius * cos(th),        outerRadius * sin(th));
		CGContextAddLineToPoint(context, ir * cos(th), ir * sin(th));
	    }
	    if (mask & ECDiskMarksMaskDotRing) {    // draw dot ring
		if (mask & ECDiskMarksMaskOdd && ((i & 1) == 0)) {
		    // skip
		} else {
		    [strokeColor setFill];
		    [self drawDot:ms/2 x:outerRadius*cos(th) y:outerRadius*sin(th)];
		}
	    }
	}

	// draw parallel lines
	if (mask & ECDiskMarksMaskLine) {
	    double b = M_PI/2 - a1;
	    double x0, x1, ya, yb;
	    if (b == M_PI/2 || b == 3*M_PI/2) {
		x0 = outerRadius;
		x1 = -x0;
		ya = i * 2 * outerRadius  / (n + 1) - outerRadius;
		yb = ya;
	    } else if (b == 0 || b == M_PI) {
		ya = outerRadius;
		yb = -ya;
		x0 = i * 2 * outerRadius / (n + 1) - outerRadius;
		x1 = x0;
	    } else {
		double c, d, xi, yi;
		c = outerRadius * tan(b);
		d = outerRadius / tan(b);
		xi =  (c+d) * cos(b);
		yi = -(c+d) * sin(b);
		x0 = i * xi / (n + 1);
		x1 = x0 - xi;
		ya = i * yi / (n + 1);
		yb = ya - yi;
	    }
	    CGContextMoveToPoint   (context, x0, yb);
	    CGContextAddLineToPoint(context, x1, ya);
	}
	CGContextStrokePath(context);	
    }
    
    if (mask & ECDiskMarksMaskRose) {    // draw compass rose
	double deltaTheta = M_PI / n;
	for (int i=0; i<n; i++) {
	    double theta = 2 * i * deltaTheta;
	    CGContextMoveToPoint   (context, outerRadius * cos(theta)             , outerRadius * sin(theta));		    // outer point
	    CGContextAddLineToPoint(context, innerRadius * cos(theta-deltaTheta)  , innerRadius * sin(theta-deltaTheta));   // left inner point
	    CGContextAddLineToPoint(context, innerRadius * cos(theta)             , innerRadius * sin(theta));		    // center inner point
	    CGContextAddLineToPoint(context, outerRadius * cos(theta)             , outerRadius * sin(theta));		    // back to outer point
	    [fillColor1 setFill];
	    if (fillColor1 == [UIColor clearColor]) {
		CGContextDrawPath(context, kCGPathStroke);
	    } else {
		CGContextDrawPath(context, kCGPathFill);
	    }
	    
	    CGContextMoveToPoint   (context, outerRadius * cos(theta)             , outerRadius * sin(theta));		    // outer point
	    CGContextAddLineToPoint(context, innerRadius * cos(theta+deltaTheta)  , innerRadius * sin(theta+deltaTheta));   // right inner point
	    CGContextAddLineToPoint(context, innerRadius * cos(theta)             , innerRadius * sin(theta));		    // center inner point
	    CGContextAddLineToPoint(context, outerRadius * cos(theta)             , outerRadius * sin(theta));		    // back to outer point
	    [fillColor2 setFill];
	    if (fillColor2 == [UIColor clearColor]) {
		CGContextDrawPath(context, kCGPathStroke);
	    } else {
		CGContextDrawPath(context, kCGPathFill);
	    }
	}
    }
    
    if (mask & ECDiskMarksMaskTachy) {    // draw tachymeter ticks
	int inc = 1;
	for (int i=60; i<=600; i+=inc) {
	    double theta = 3600.0 / i * (2 * M_PI / 60);
	    CGContextRotateCTM(context, -theta);
	    CGContextMoveToPoint   (context, 0, outerRadius);
	    CGContextAddLineToPoint(context, 0, outerRadius - ms);
	    CGContextStrokePath(context);
	    CGContextRotateCTM(context, theta);		// back to starting position
	    if (i==100) {
		inc = 10;
	    } else if (i==250) {
		inc = 50;
	    }
	}
    }

    if (!(mask & ECDiskMarksMaskRose)) {
	[self clearInside:innerRadius];
    }
}

- (void)drawTickMarks:(double)radius type:(ECDialTickType)tic {
    switch (tic) {
	case ECDialTick36:	// 12 / 3
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:12  angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.04 mWidth:1  strokeColor:nil fillColor1:nil fillColor2:nil];
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:36  angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.03 mWidth:.7 strokeColor:nil fillColor1:nil fillColor2:nil];
	    break;
	case ECDialTick96:	// 24 / 4
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:24  angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.04 mWidth:1  strokeColor:nil fillColor1:nil fillColor2:nil];
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:96  angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.03 mWidth:.7 strokeColor:nil fillColor1:nil fillColor2:nil];
	    break;
	case ECDialTick180:	// 12 / 3 / 5
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:12  angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.04 mWidth:1  strokeColor:nil fillColor1:nil fillColor2:nil];
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:36  angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.03 mWidth:.7 strokeColor:nil fillColor1:nil fillColor2:nil];
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:180 angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.02 mWidth:.5 strokeColor:nil fillColor1:nil fillColor2:nil];
	    break;
	case ECDialTick288:	// 24 / 2 / 6
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks: 24 angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.1  mWidth:.7 strokeColor:nil fillColor1:nil fillColor2:nil];
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks: 48 angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.07 mWidth:.7 strokeColor:nil fillColor1:nil fillColor2:nil];
	    [self drawGuilloche:ECDiskMarksMaskTickOut radius:radius radius2:0 nMarks:288 angle0:0 angle1:0 angle2:2*M_PI mSize:radius*0.04 mWidth:.7 strokeColor:nil fillColor1:nil fillColor2:nil];
	    break;
	default:
	    assert(false);
    }
}

/*
- (void)drawTickMarks:(double)radius type:(ECDialTickType)tic dot:(double)dotSize {
    CGContextRef context = UIGraphicsGetCurrentContext();
    int i;
    int n = (tic == ECDialTick4 ? 4 : tic == ECDialTick8 ? 8 : tic == ECDialTick16 ? 16 : tic == ECDialTick96 ? 16 : tic == ECDialTick10 ? 10 : tic == ECDialTick240 ? 24 : tic == ECDialTick288 ? 24 : 12);
    if (tic >= ECDialTick4) {
	for (i=0; i<n; i++) {
	    CGContextSetLineWidth(context, 2);
	    
	    // major ticks
	    double th = (((double)i)/n)*2*M_PI - M_PI/2;
	    if (dotSize != 0) {
		[self drawDot:dotSize/2 x:radius*cos(th) y:radius*sin(th)];
	    } else {
		CGContextMoveToPoint   (context, radius * cos(th),       radius * sin(th));
		CGContextAddLineToPoint(context, radius * cos(th) * .90, radius * sin(th) * .90);
	    }

	    // minor ticks
	    if (tic >= ECDialTick36) {
		CGContextSetLineWidth(context, 1);
		double d;
		double e = (tic == ECDialTick240 ? .5 : tic == ECDialTick288 ? .5 : tic == ECDialTick36 ? .3333 : tic == ECDialTick96 ? .25 : tic == ECDialTick72 ? .166667 : tic == ECDialTick360 ? .166667 : .2);	// == 1/(number of minor ticks)
		double h = (tic == ECDialTick240 ? 12 : tic == ECDialTick288 ? 12 : tic == ECDialTick96 ? 8 : 6);		// == n/2 ?
		for (d=i+e; d<i+1.1; d+=e) {
		    if (dotSize != 0) {
			[self drawDot:dotSize/2*0.7 x:radius*cos(d*M_PI/h) y:radius*sin(d*M_PI/h)];
		    } else {
			CGContextMoveToPoint   (context, radius * cos(d*M_PI/h),       radius * sin(d*M_PI/h));
			CGContextAddLineToPoint(context, radius * cos(d*M_PI/h) * .93, radius * sin(d*M_PI/h) * .93);
		    }

		    // micro ticks
		    if (tic >= ECDialTick240) {
			CGContextSetLineWidth(context, 0.5);
			double f;
			double g = (tic == ECDialTick240 ? .1 : tic == ECDialTick241 ? .05 : tic == ECDialTick288 ? 1.0/12 : .04);
			for (f=d+g; f<d+e; f+=g) {
			    if (dotSize != 0) {
				[self drawDot:dotSize/2*0.5 x:radius*cos(f*M_PI/h) y:radius*sin(f*M_PI/h)];
			    } else {
				CGContextMoveToPoint   (context, radius * cos(f*M_PI/h),       radius * sin(f*M_PI/h));
				CGContextAddLineToPoint(context, radius * cos(f*M_PI/h) * .95, radius * sin(f*M_PI/h) * .95);
			    }
			}
		    }
		}
	    }

	    CGContextStrokePath(context);	
	}
    }
}
*/

- (CGContextRef)archiveImageSetupAtZoomFactor:(double)zoomFactor {
    CGRect bounds = boundsOnScreen;
    size_t bitsPerComponent = 8;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    assert(colorSpace);
    assert(bounds.size.width > 0);
    assert(bounds.size.height > 0);
    int padding = ECTexturePartPadding;
    NSString *partName = [[controller model] name];
    if ([partName caseInsensitiveCompare:@"dim"] == NSOrderedSame ||
	[partName caseInsensitiveCompare:@"red banner"] == NSOrderedSame) { // HACK
	padding = 0;
    }
    //if (zoomFactor == 2) {
    //	printf("Creating bitmap context with size %f by %f for zoom factor %d\n", bounds.size.width*zoomFactor, bounds.size.height*zoomFactor, zoomFactor);
    //}
    CGFloat roundUpX = ceil(bounds.size.width) - bounds.size.width;
    CGFloat roundUpY = ceil(bounds.size.height) - bounds.size.height;
    CGContextRef context = CGBitmapContextCreate(NULL, (ceil(bounds.size.width) + padding * 2)*zoomFactor, (ceil(bounds.size.height) + padding * 2)*zoomFactor, bitsPerComponent, 0,
						 colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
    assert(context);
    if (zoomFactor != 1) {
	CGContextScaleCTM(context, zoomFactor, zoomFactor);
    }
    CGContextTranslateCTM(context, padding + roundUpX/2, padding + roundUpY/2);
    UIGraphicsPushContext(context);
    return context;
}

- (void)archiveImageFinishForContext:(CGContextRef)context andPath:(NSString *)path zoomFactor:(int)zoomFactor {
    UIGraphicsPopContext();
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    assert(cgImage);
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    assert(uiImage);
    NSData *imageData = UIImagePNGRepresentation(uiImage);
    assert(imageData);
    NSError *error;
    //if (zoomFactor == 2) {
    //	printf("Writing image of size %f by %f to file %s at zoom factor %d\n", uiImage.size.width, uiImage.size.height, [path UTF8String], zoomFactor);
    //}
    if (![imageData writeToFile:path options:NSAtomicWrite error:&error]) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Couldn't write PNG file to %@: %@", path, [error localizedDescription]]];
    }
    //CGImageRelease(cgImage);  // Fails under 3.0, Snow Leopard only
    CGColorSpaceRelease(CGBitmapContextGetColorSpace(context));
    CGContextRelease(context);
}

- (void)archiveImageToPathInternal:(NSString *)path atZoomFactor:(double)zoomFactor {
    CGContextRef context = [self archiveImageSetupAtZoomFactor:zoomFactor];
    [self drawAtZoomFactor:zoomFactor];
    [self archiveImageFinishForContext:context andPath:path zoomFactor:zoomFactor];
}

// The coordinate system used in the watch XML files is defined such
// that each unit of length used in a part definition is equivalent to
// a pixel on a 320x480 device (the size of the original iPhone).  For
// "zoomed" views (positive or negative), we scale those coordinates
// by a zoom factor.  Thus for a 2x zoom (Z1, or 2^1 = 2x), as is used
// on the first retina iPhone 4 (640x960), we double all of the
// coordinates listed in the XML file when creating each part.  For a
// 4x zoom (Z2, or 2^2 = 4x), for a retina iPad, we multiply each
// coordinate by 4.
//
// When creating parts for the Android Wear (and this would be true
// for an Apple Watch too), we do the same kind of scaling (matching
// the coordinates defined in the XML file to actual screen
// coordinates), but in this case we want only the watch face itself
// to fit exactly into the size of the output device.  Thus, for the
// original Huawei watch with its 400-pixel diameter screen, we want
// whatever the watch face diameter defined in the xml file (this varies
// from watch to watch) to scale exactly to 400 pixels.
//
// To accomplish this, we pass in the width of the XML-defined watch
// here.  This number is specified in the XML file by the author of
// that file to indicate the size of the face itself defined in that
// file.  For example, at this writing, Haleakala-Android defines
// the face to be 266 pixels in width.  Then to determine how much we
// need to scale the parts (where, as with zooming, numbers greater
// than one mean to make the parts bigger), we divide the desired
// width on the watch (e.g., 400 pixels for the Huawei 1) by the
// width defined in the xml file (266 pixels in this example).

// For iOS builds, the watchFaceWidth is ignored.
- (void)archiveImageToPath:(NSString *)path watchFaceWidthInXML:(int)watchFaceWidthInXML forDeviceWidth:(int)deviceWidth {
#if EC_HENRY_ANDROID
    if (deviceWidth == 0) {
        // Must be making the template for shadows.
        [self archiveImageToPathInternal:path atZoomFactor:1.0];
    } else {
        double zoomFactor = deviceWidth * 1.0 / watchFaceWidthInXML;
        [self archiveImageToPathInternal:path atZoomFactor:zoomFactor];
    }
#else
    assert(deviceWidth == 0);
    [self archiveImageToPathInternal:path atZoomFactor:1];
    for (int i = 1; i <= ECZoomMaxPower2; i++) {
        [self archiveImageToPathInternal:[path stringByReplacingOccurrencesOfString:@".png" withString:[NSString stringWithFormat:@"-Z%d.png", i]] atZoomFactor:(1 << i)];
    }
#ifdef HIRES_DUMP
    [self archiveImageToPathInternal:[path stringByReplacingOccurrencesOfString:@".png" withString:@"-hires.png"] atZoomFactor:HIRES_DUMP];
#endif  // HIRES_DUMP
#endif  // EC_HENRY_ANDROID
}

-(void)dealloc {
    [holes removeAllObjects];
    [holes release];
    [super dealloc];
}

- (void)print {
    printf("ECQView\n");
}

- (NSString *)className {
    return @"   ECQView";
}

@end


@implementation ECQStaticView

- (NSString *)className {
    return @" StaticView";
}

- (ECQView *)initForPieces:(int)nPieces {
    // Union all bounds of each piece in screen coordinates
    if (self = (id)[super initWithBoundsInView:CGRectMake(0, 0, 0, 0) boundsOnScreen:CGRectMake(0, 0, 0, 0) dragType:ECDragNormal dragAnimationType:ECDragAnimationNever]) {
       pieces = [[NSMutableArray alloc]initWithCapacity:nPieces];
   }
    return self;
}

- (void)addPiece:(ECQView *)aPiece {
    assert(aPiece);
    [pieces addObject:aPiece];
}

- (void)finishInit {
    // First get the union of the screen bounds
    bool firstPiece = true;
    for (ECQView *piece in pieces) {
	if (firstPiece) {
	    boundsOnScreen = [piece boundsOnScreen];
	    firstPiece = false;
	} else {
	    boundsOnScreen = CGRectUnion(boundsOnScreen, [piece boundsOnScreen]);
	}
    }
    // OK, now screen bounds are correct for entire static view.
    // The view bounds are centered at the center of the static view
    CGFloat width = boundsOnScreen.size.width;
    CGFloat height = boundsOnScreen.size.height;
    boundsInView = CGRectMake(-width/2, -height/2, width, height);

    // OK, now we re-translate each piece's boundsInView according to where its
    // screen bounds are.  Note that this ignores the specified boundsInView of each piece;
    // we don't allow scaling for pieces.
    for (ECQView *piece in pieces) {
	CGRect thisPieceViewBounds = [self convertFromScreenToView:[piece boundsOnScreen]];
	[piece setBoundsInView:thisPieceViewBounds];
    }

    if (firstPiece) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Static view with no pieces"]];
    }
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    // [self translateContextToCenter];
    for (ECQView *piece in pieces) {
	[piece drawInViewBounds:boundsInView atZoomFactor:zoomFactor];
    }
    [self clearHoles];
}

- (void)print {
    [super print];
    printf("base %lu pieces\t", (unsigned long)[pieces count]);
}

- (void)dealloc {
    [pieces release];
    [super dealloc];
}

@end

@implementation ECImageView

- (NSString *)className {
    return @" ImageView";
}

- (void) commonInit:(UIImage *)img img2x:(UIImage *)img2x img4x:(UIImage *)img4x {
    image = [img retain];
    image2x = [img2x retain];
    image4x = [img4x retain];
}

- (ECImageView *)       initWithImage:(UIImage *)img
			      image2x:(UIImage *)img2x
			      image4x:(UIImage *)img4x
	xAnchorOffsetFromScreenCenter:(double)xAnchorOffsetFromScreenCenter
	yAnchorOffsetFromScreenCenter:(double)yAnchorOffsetFromScreenCenter
		   xAnchorInViewSpace:(double)xAnchorInViewSpace
		   yAnchorInViewSpace:(double)yAnchorInViewSpace
			       xScale:(double)xScale
			       yScale:(double)yScale 
			    animSpeed:(double)animSp
			      animDir:(ECAnimationDirection)aanimDir
			     dragType:(ECDragType)aDragType
		    dragAnimationType:(ECDragAnimationType)aDragAnimationType {
    double wv = img.size.width;
    double hv = img.size.height;
    double xv = xAnchorInViewSpace;
    double yv = yAnchorInViewSpace;
    CGRect aBoundsInView = CGRectMake(-xv, -yv, wv, hv);
    double xs = xAnchorOffsetFromScreenCenter;
    double ys = yAnchorOffsetFromScreenCenter;
    double ws = wv * xScale;
    double hs = hv * yScale;
    CGRect aBoundsOnScreen = CGRectMake(xs - xv * xScale, ys - yv * yScale, ws, hs);
    assert(aBoundsOnScreen.size.width > 0);
    assert(aBoundsOnScreen.size.height > 0);
    if (self = [super initWithBoundsInView:aBoundsInView boundsOnScreen:aBoundsOnScreen dragType:aDragType dragAnimationType:aDragAnimationType]) {
	[self commonInit:img img2x:img2x img4x:img4x];
	alpha = 1;  //
	animSpeed = animSp;
	animDir = aanimDir;
	radius2 = 0;
    }
    return self;
}

- (ECImageView *)initCenteredWithImage:(UIImage *)img
			       image2x:(UIImage *)img2x
			       image4x:(UIImage *)img4x
	 xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	 yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
			       radius2:(double)aradius2
			     animSpeed:(double)animSp
			       animDir:(ECAnimationDirection)aanimDir
			      dragType:(ECDragType)aDragType
		     dragAnimationType:(ECDragAnimationType)aDragAnimationType 
				 alpha:(double)aalpha
				xScale:(double)xScale
				yScale:(double)yScale
			      norotate:(bool)aNorotate {
    double wv = img.size.width;
    double hv = img.size.height;
    CGRect aBoundsInView = CGRectMake(-wv/2, -hv/2, wv, hv);
    double xs = xCenterOffsetFromScreenCenter;
    double ys = yCenterOffsetFromScreenCenter;
    double ws = wv * xScale;
    double hs = hv * yScale;
    CGRect aBoundsOnScreen = CGRectMake(-ws/2 + xs, -hs/2 + ys, ws, hs);
    assert(aBoundsOnScreen.size.width > 0);
    assert(aBoundsOnScreen.size.height > 0);
    if (self = [super initWithBoundsInView:aBoundsInView boundsOnScreen:aBoundsOnScreen dragType:aDragType dragAnimationType:aDragAnimationType norotate:aNorotate]) {
	[self commonInit:img img2x:img2x img4x:img4x];
	radius2 = aradius2;
	animSpeed = animSp;
	animDir = aanimDir;
	alpha = aalpha;
    }
    return self;
}

- (ECImageView *)initCenteredBlankWidth:(double)wv
				  height:(double)hv
				  color:(UIColor *)aColor
	 xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	 yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
				 panes:(double)aPanes
			     animSpeed:(double)animSp
			       dragType:(ECDragType)aDragType
		      dragAnimationType:(ECDragAnimationType)aDragAnimationType 
				 alpha:(double)aalpha
				xScale:(double)xScale
				yScale:(double)yScale {
    CGRect aBoundsInView = CGRectMake(-wv/2, -hv/2, wv, hv);
    double xs = xCenterOffsetFromScreenCenter;
    double ys = yCenterOffsetFromScreenCenter;
    double ws = wv * xScale;
    double hs = hv * yScale;
    CGRect aBoundsOnScreen = CGRectMake(-ws/2 + xs, -hs/2 + ys, ws, hs);
    assert(aBoundsOnScreen.size.width > 0);
    assert(aBoundsOnScreen.size.height > 0);
    if (self = [super initWithBoundsInView:aBoundsInView boundsOnScreen:aBoundsOnScreen dragType:aDragType dragAnimationType:aDragAnimationType]) {
	image = nil;
	image2x = nil;
	image4x = nil;
	radius2 = 0;
	panes = aPanes;
	animSpeed = animSp;
	animDir = ECAnimationDirClosest;
	alpha = aalpha;
	color = aColor;
    }
    return self;
}

- (double)animSpeed {
    return animSpeed;
}

- (ECAnimationDirection)animDir {
    return (ECAnimationDirection)animDir;
}

- (void)drawInViewBounds:(CGRect)bounds atZoomFactor:(double)zoomFactor {
    UIImage *imageToDraw = image;
    if (zoomFactor > 2.0) {
        if (image4x) {
            imageToDraw = image4x;
        } else if (image2x) {
            imageToDraw = image2x;
        }
    } else if (zoomFactor > 1.0) {
        if (image2x) {
            imageToDraw = image2x;
        } else if (image4x) {
            imageToDraw = image4x;
        }
    }
    assert(!image2x || image2x != image);
    assert(!image4x || (image4x != image && (!image2x || image4x != image2x)));
    //if (imageToDraw && imageToDraw == image2x) {
    //	printf("Drawing 2x image at %f by %f\n", imageToDraw.size.width, imageToDraw.size.height);
    //}
    assert(imageToDraw || color);
    assert(!(imageToDraw && color));
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGRect rect = CGRectMake(boundsInView.origin.x - bounds.origin.x,
			     boundsInView.origin.y - bounds.origin.y,
			     boundsInView.size.width, boundsInView.size.height);
    CGContextAddRect(context, rect);
    if (color) {
	[color set];
	CGContextFillPath(context);
	if (panes > 1 || panes < -1) {
	    if (color == [UIColor blackColor]) {
		[[UIColor whiteColor] setStroke];
	    } else {
		[[UIColor blackColor] setStroke];
	    }
	    CGContextSetLineWidth(context, 0.25);
	    double pane = 0;
	    if (panes > 0) {
		// center on the left
		while (++pane < panes) {
		    CGContextAddArc(context, rect.origin.x - rect.size.height*2.5 + rect.size.width*pane/panes, rect.origin.y + rect.size.height/2, rect.size.height*2.5, 0, 2*M_PI, 0);
		    CGContextStrokePath(context);
		}
	    } else {
		// center on the right
		panes = -panes;
		while (++pane < panes) {
		    CGContextAddArc(context, rect.origin.x + rect.size.width + rect.size.height*2.5 - rect.size.width*pane/panes, rect.origin.y + rect.size.height/2, rect.size.height*2.5, 0, 2*M_PI, 0);
		    CGContextStrokePath(context);
		}
	    }
	}
    }
    CGContextAddArc(context, rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2, radius2, 0, 2*M_PI, 0);
    CGContextEOClip(context);
    CGContextSetAlpha(context, alpha);
    if (imageToDraw) {
	CGContextDrawImage(context, rect, [imageToDraw CGImage]);
    }
    CGContextRestoreGState(context);
    [self clearHolesForBounds:bounds];
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    assert(boundsInView.size.width == boundsOnScreen.size.width);  // no scaling allowed
    assert(boundsInView.size.height == boundsOnScreen.size.height);  // no scaling allowed
    [self drawInViewBounds:boundsInView atZoomFactor:zoomFactor];
}

- (void)print {
    [super print];
    printf("image %3.0fx%3.0f\t", image.size.width, image.size.height);
}

- (void)dealloc {
    [image release];
    [image2x release];
    [image4x release];
    [super dealloc];
}

@end


static const char *quadrantName(ECTerminatorQuadrant quadrant) {
    switch (quadrant) {
      case ECTerminatorUpperLeft:
	return "upper left";
      case ECTerminatorLowerLeft:
	return "lower left";
      case ECTerminatorUpperRight:
	return "upper right";
      case ECTerminatorLowerRight:
	return "lower right";
    }
    return "???";
}

static double phaseAngleForInnerTerminatorEdgeForcingLowerRight(bool                 forceLowerRight,
								ECTerminatorQuadrant quadrant,
								int 		     indexWithinQuadrant,
								int 		     leavesPerQuadrant) {
    if (!forceLowerRight && ECTerminatorQuadrantIsLeft(quadrant)) { // left side, terminator decreasing from pi back to pi/2
	// First terminator will not be at pi, but last terminator *must* be at pi/2 to make quarter moon exact
	return M_PI - ((indexWithinQuadrant + 1.0) / leavesPerQuadrant) * (M_PI / 2);
    } else { // right side, terminator increasing from pi to 3pi/2
	// First terminator will not be at pi, but last terminator *must* be at 3pi/2 to make quarter moon exact
	return M_PI + ((indexWithinQuadrant + 1.0) / leavesPerQuadrant) * (M_PI / 2);
    }
}

static double phaseAngleForOuterTerminatorEdgeForcingLowerRight(bool                 forceLowerRight,
								ECTerminatorQuadrant quadrant,
								int 		     indexWithinQuadrant,
								int 		     leavesPerQuadrant) {
    if (!forceLowerRight && ECTerminatorQuadrantIsLeft(quadrant)) { // left side, terminator decreasing from 2pi back to 3pi/2
	// First terminator should be exact so new moon looks good
	return 2*M_PI - ((double)indexWithinQuadrant / leavesPerQuadrant) * (M_PI / 2);
    } else { // right side, terminator increasing from 0 to pi/2
	// First terminator should be exact so new moon looks good
	return 0      + ((double)indexWithinQuadrant / leavesPerQuadrant) * (M_PI / 2);
    }
}

@implementation ECTerminatorLeaf

- (NSString *)className {
    return @"TerminLeaf";
}

// Each leaf view is assumed to be at the static center of the terminator.  This allows the actual anchor-point offset to be
// specified with an offset angle and an offset radius, so that the terminator can rotate, and if the center of the terminator
// moves the expression for that offset can be just applied to the leaves.
// The angle of each leaf must be concatenated with the angle of the terminator as a whole, but that's not our problem here.
- (ECTerminatorLeaf *)initWithQuadrant:(ECTerminatorQuadrant)aQuadrant
		   indexWithinQuadrant:(int)anIndexWithinQuadrant
		     leavesPerQuadrant:(int)numLeavesPerQuadrant
				radius:(double)aRadius
			   incremental:(bool)anIncremental
		      anchorEdgeRadius:(double)anAnchorEdgeRadius
			 leafFillColor:(UIColor *)aLeafFillColor
		       leafBorderColor:(UIColor *)aLeafBorderColor
		      terminatorCenter:(CGPoint)terminatorCenter {

    CGRect aBoundsInView;
    CGRect aBoundsOnScreen;
    double paOuter = phaseAngleForOuterTerminatorEdgeForcingLowerRight(true/*forceLowerRight*/, aQuadrant, anIndexWithinQuadrant, numLeavesPerQuadrant);
    double paInner = phaseAngleForInnerTerminatorEdgeForcingLowerRight(true/*forceLowerRight*/, aQuadrant, anIndexWithinQuadrant, numLeavesPerQuadrant);
    double endCapRadius = aRadius * (cos(paOuter) + cos(paInner)) / 2;  // cos(paInner) is negative
    assert(endCapRadius >= 0);
    double phaseOffset = ceil(cos(paOuter)*aRadius);
    assert(phaseOffset >= 0);
    aBoundsInView.size.width  = phaseOffset + anAnchorEdgeRadius;
    aBoundsOnScreen.size.width  = aBoundsInView.size.width;
    aBoundsInView.size.height = ceil(aRadius + endCapRadius + anAnchorEdgeRadius);
    aBoundsOnScreen.size.height = aBoundsInView.size.height;
    if (ECTerminatorQuadrantIsUpper(aQuadrant)) {
	aBoundsInView.origin.y = -ceil(aRadius + endCapRadius);
	aBoundsOnScreen.origin.y = terminatorCenter.y - ceil(endCapRadius) - aRadius;
    } else {
	aBoundsInView.origin.y = - anAnchorEdgeRadius;
	aBoundsOnScreen.origin.y = terminatorCenter.y - anAnchorEdgeRadius;
    }
    if (ECTerminatorQuadrantIsLeft(aQuadrant)) {
	aBoundsInView.origin.x = -phaseOffset;
	aBoundsOnScreen.origin.x = terminatorCenter.x - phaseOffset;
    } else {
	aBoundsInView.origin.x = -anAnchorEdgeRadius;
	aBoundsOnScreen.origin.x = terminatorCenter.x - anAnchorEdgeRadius;
    }
    if (self = [super initWithBoundsInView:aBoundsInView boundsOnScreen:aBoundsOnScreen dragType:ECDragNormal dragAnimationType:ECDragAnimationAlways]) {
	quadrant = aQuadrant;
	indexWithinQuadrant = anIndexWithinQuadrant;
	leavesPerQuadrant = numLeavesPerQuadrant;
	radius = aRadius;
	incremental = anIncremental;
	anchorEdgeRadius = anAnchorEdgeRadius;
	leafFillColor = [aLeafFillColor retain];
	leafBorderColor = [aLeafBorderColor retain];
    }
    return self;
}

- (void)dealloc {
    [leafFillColor release];
    [leafBorderColor release];
    [super dealloc];
}

- (bool)flipX {
    switch (quadrant) {
      case ECTerminatorUpperLeft:
      case ECTerminatorLowerLeft:
	return true;
      case ECTerminatorUpperRight:
      case ECTerminatorLowerRight:
	return false;
    }
    assert(false);
    return false;
}

- (bool)flipY {
    switch (quadrant) {
      case ECTerminatorUpperLeft:
      case ECTerminatorUpperRight:
	return false;
      case ECTerminatorLowerLeft:
      case ECTerminatorLowerRight:
	return true;
    }
    assert(false);
    return false;
}

- (bool)skipMakingPNG {
    return quadrant != ECTerminatorUpperRight;
}

// The following two methods are replicated as static functions in ECVirtualMachineOps.m:

// The phase angle for which the inner terminator edge shape is correct for this leaf
// Index numbers always start on the outside and work inward
- (double)phaseAngleForInnerTerminatorEdgeForcingLowerRight:(bool)forceLowerRight {
    return phaseAngleForInnerTerminatorEdgeForcingLowerRight(forceLowerRight, quadrant, indexWithinQuadrant, leavesPerQuadrant);
}

// The phase angle for which the outer terminator edge shape is correct for this leaf
// Index numbers always start on the outside and work inward
- (double)phaseAngleForOuterTerminatorEdgeForcingLowerRight:(bool)forceLowerRight {
    return phaseAngleForOuterTerminatorEdgeForcingLowerRight(forceLowerRight, quadrant, indexWithinQuadrant, leavesPerQuadrant);
}

static void calculateTerminatorArcPoint(int    i,
					int    n,
					double xsign,
					double ysign,
					double xcenter,
					double ycenter,
					double radius,
					double phase,
					double *x,
					double *y) {
    double th = (M_PI / 2) * ((double)i / n);
    *x = xcenter + xsign * fabs(cos(phase) * cos(th) * radius);
    *y = ycenter + ysign * sin(th) * radius;
}

// The zero reference angle for the leaf is arbitrary.  But by convention we choose the zero angle to be when
// the inner edge is exactly on the terminator.  This means that the inner terminator edge is drawn unrotated,
// and the outer edge is drawn with the context rotated such that the outer edge is exactly on the terminator.
// The exact width of the leaf is somewhat arbitrary too.  But it should be the minimum size for which the given
// number of leaves can completely cover the the underlying object with no gaps.  This turns out to be exactly
// the width where the outer edge aligns exactly with the inner edge of the next outer leaf.  If the leaves are larger than that
// everything still works fine but it means that the outer covering ring will need to be bigger than otherwise necessary.
// Conveniently, this means that the entire leaf can be drawn at the same reference angle, by drawing both phases
// at once, and connecting the upper ones with a semicircular arc, so no context rotation is required between
// the inner and outer edges.
- (void)drawAtZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, -boundsInView.origin.x, -boundsInView.origin.y);  // move origin to anchor point

    [leafFillColor setFill];
    [leafBorderColor setStroke];

    double xsign;
    double ysign;

    // center of orb
    double xcenter = 0;
    double ycenter;

    bool clockwiseEndArc;

    switch (quadrant) {
      default:
	assert(false);
      case ECTerminatorUpperLeft:
	xsign = -1;
	ysign = 1;
	ycenter = - radius;
	clockwiseEndArc = true;
	break;
      case ECTerminatorLowerLeft:
	xsign = -1;
	ysign = -1;
	ycenter = radius;
	clockwiseEndArc = false;
	break;
      case ECTerminatorUpperRight:
	xsign = 1;
	ysign = 1;
	ycenter = -radius;
	clockwiseEndArc = false;
	break;
      case ECTerminatorLowerRight:
	xsign = 1;
	ysign = -1;
	ycenter = radius;
	clockwiseEndArc = true;
	break;
    }

    double paInner = EC_fmod([self phaseAngleForInnerTerminatorEdgeForcingLowerRight:false], 2*M_PI);
    double paOuter = EC_fmod([self phaseAngleForOuterTerminatorEdgeForcingLowerRight:false], 2*M_PI);

    // Calulate steps, but only just past the midpoint
    int n = 30;  // n steps per half
    int overlap = incremental ? 1 : 0;  // number of steps we go into the opposite side
    int i;
    // Draw inner terminator, from anchor point towards the center
    CGContextMoveToPoint(context, xcenter, ycenter + ysign*radius);
    double x, y;
    for (i = n - 1; i >= -overlap ; i--) {
	calculateTerminatorArcPoint(i, n, xsign, ysign, xcenter, ycenter, radius, paInner, &x, &y);
	CGContextAddLineToPoint(context, x, y);
    }
    // Draw end of leaf, a half-circle to the next point
    double nextX, nextY;
    calculateTerminatorArcPoint(-overlap, n, xsign, ysign, xcenter, ycenter, radius, paOuter, &nextX, &nextY);
    double midX = (x + nextX)/2;
    double midY = (y + nextY)/2;
    double deltaX = (x - nextX);
    double deltaY = (y - nextY);
    double endRadius = sqrt(deltaX*deltaX + deltaY*deltaY)/2.0;
    double startAngle = atan2(y - midY, x - midX);
    double endAngle = atan2(nextY - midY, nextX - midX);
    CGContextAddArc(context, midX, midY, endRadius, startAngle, endAngle, clockwiseEndArc);  // clockwise sense inverted for top-left views???

    // draw outer terminator, from end of end arc back down to anchor point
    for (i = -overlap; i <= n; i++) {
	calculateTerminatorArcPoint(i, n, xsign, ysign, xcenter, ycenter, radius, paOuter, &x, &y);
	CGContextAddLineToPoint(context, x, y);
    }
    CGContextDrawPath(context, kCGPathFillStroke);

    // Draw anchor edge circle (TBD)
}

+ (double)boundaryZoneHeightForRadius:(double)radius
		 leafAnchorEdgeRadius:(double)leafAnchorEdgeRadius
		    leavesPerQuadrant:(int)leavesPerQuadrant {
    return 50;
}

+ (double)boundaryZoneWidthForRadius:(double)radius
		leafAnchorEdgeRadius:(double)leafAnchorEdgeRadius
		   leavesPerQuadrant:(int)leavesPerQuadrant {
    return 50;
}

ECTerminatorQuadrant oddOrder[] = {
    ECTerminatorUpperLeft,
    ECTerminatorLowerLeft,
    ECTerminatorLowerRight,
    ECTerminatorUpperRight,
};

ECTerminatorQuadrant evenOrder[] = {
    ECTerminatorLowerLeft,
    ECTerminatorUpperLeft,
    ECTerminatorUpperRight,
    ECTerminatorLowerRight,
};

static ECTerminatorQuadrant ECTerminatorQuadrantOrder(int i, int q) {
    assert(q >= 0 && q < 4);
    assert(i >= 0);
    if ((i % 2) == 0) {
	return evenOrder[q];
    } else {
	return oddOrder[q];
    }
}

static EBVMInstructionStream *
compiledInstructionStreamOrNil(NSString         *expression,
			       EBVirtualMachine *vm) {
    if (expression) {
	return [vm compileInstructionStreamFromCExpression:expression errorReporter:ECtheErrorReporter];
    }
    return nil;
}

+ (void) createTerminatorLeavesForRadius:(double)radius
			terminatorCenter:(CGPoint)terminatorCenter
			     incremental:(bool)incremental
				modeMask:(int)modeMask
		      forWatchController:(ECWatchController *)watchController
				partName:(NSString *)partName
			  updateInterval:(double)updateInterval
		    updateIntervalOffset:(double)updateIntervalOffset
				 envSlot:(int)envSlot
			 phaseExpression:(NSString *)phaseExpression
	    terminatorRotationExpression:(NSString *)terminatorRotationExpression
       terminatorCenterXOffsetExpression:(NSString *)terminatorCenterXOffsetExpression
       terminatorCenterYOffsetExpression:(NSString *)terminatorCenterYOffsetExpression
		       leavesPerQuadrant:(int)leavesPerQuadrant
		    leafAnchorEdgeRadius:(double)leafAnchorEdgeRadius
			 leafBorderColor:(UIColor *)leafBorderColor
			   leafFillColor:(UIColor *)leafFillColor {
    ECWatch *watch = [watchController watch];
    EBVirtualMachine *vm = [watch vm];
    for (int i = 0; i < leavesPerQuadrant; i++) {
	for (int q = 0; q < 4; q++) {
	    ECTerminatorQuadrant quadrant = ECTerminatorQuadrantOrder(i, q);
	    ECTerminatorLeaf *leaf =
		[[ECTerminatorLeaf alloc] initWithQuadrant:quadrant
				       indexWithinQuadrant:i
					 leavesPerQuadrant:leavesPerQuadrant
						    radius:radius
					       incremental:incremental
					  anchorEdgeRadius:leafAnchorEdgeRadius
					     leafFillColor:leafFillColor
					   leafBorderColor:leafBorderColor
					  terminatorCenter:terminatorCenter];
	    NSString *angleExpression = [NSString stringWithFormat:@"terminatorAngle((%@), %d, %d, %d, %d)",
					      phaseExpression, (int)quadrant, i, leavesPerQuadrant, incremental];
	    if (!ECTerminatorQuadrantIsUpper(quadrant)) {
		angleExpression = [angleExpression stringByAppendingString:@"+pi"];
	    }
	    NSString *offsetAngleStream = ECTerminatorQuadrantIsUpper(quadrant) ? @"0" : @"pi";
	    if (terminatorRotationExpression) {
		offsetAngleStream = [NSString stringWithFormat:@"%@ + (%@)", offsetAngleStream, terminatorRotationExpression];
	    }
	    ECWatchHand *hand = [[ECWatchHand alloc] initWithName:[NSString stringWithFormat:@"%@-%d", partName, i]
							 forWatch:watch
							 modeMask:modeMask
							     kind:ECNotTimerZeroKind
						   updateInterval:updateInterval
					     updateIntervalOffset:updateIntervalOffset
						      updateTimer:ECMainTimer
						       masterPart:nil  // We may want to actually use master parts here at some point...
						      angleStream:[vm compileInstructionStreamFromCExpression:angleExpression errorReporter:ECtheErrorReporter]
						     actionStream:nil
								z:0
							thickness:3
						    xOffsetStream:compiledInstructionStreamOrNil(terminatorCenterXOffsetExpression, vm)
						    yOffsetStream:compiledInstructionStreamOrNil(terminatorCenterYOffsetExpression, vm)
						     offsetRadius:radius+leafAnchorEdgeRadius  // distance between leaf anchor and center of terminator, which is rotation axis
						offsetAngleStream:[vm compileInstructionStreamFromCExpression:offsetAngleStream errorReporter:ECtheErrorReporter] ];
	    [[ECHandController alloc] initWithModel:hand view:leaf master:watchController
					     opaque:false
					   grabPrio:ECGrabPrioDefault
					    envSlot:envSlot
					specialness:ECPartNotSpecial
				   specialParameter:0
                                     cornerRelative:false];
	    [watch addPart:hand];
	    [hand release];
	    [leaf release];
	}
    }
}

@end


@implementation ECQTextView

- (NSString *)className {
    return @" QTextView";
}

- (ECQTextView *)initCenteredWithText:(NSString *)str
	xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
			   cropBottom:(double)aCropBottom
			      cropTop:(double)aCropTop
			       radius:(double)aRadius
				angle:(double)anAngle
                            animSpeed:(double)anAnimSpeed
			  orientation:(ECDialOrientation)orient
 				 font:(UIFont*)aFont
				color:(UIColor *)acolor {
    assert(aFont);
    assert(str);
    assert(str.length > 0);
    // Deprecated iOS 7:  CGSize textSize = [str sizeWithFont:aFont];
    CGSize textSize = [str sizeWithAttributes:@{NSFontAttributeName:aFont}];
    if (aRadius > 0) {
	radius = aRadius;
	orientation = orient;
	angle= anAngle;
        animSpeed = anAnimSpeed;
	textSize.height = textSize.width = radius * 2;
    } else {
	radius = angle = 0;
        animSpeed = anAnimSpeed;
    }


    assert(textSize.width > 0 && textSize.height > 0);
    textSize.height = textSize.height - (aCropBottom + aCropTop);
    assert(textSize.width > 0 && textSize.height > 0);
    double cropOriginOffset = (aCropBottom - aCropTop) / 2;
    CGRect viewBounds = CGRectMake(-textSize.width/2, -textSize.height/2 + cropOriginOffset, textSize.width, textSize.height);
    CGRect screenBounds = CGRectMake(xCenterOffsetFromScreenCenter - textSize.width/2, yCenterOffsetFromScreenCenter - textSize.height/2,
				     textSize.width, textSize.height);
    if (self = [super initWithBoundsInView:viewBounds boundsOnScreen:screenBounds dragType:ECDragNormal dragAnimationType:ECDragAnimationNever]) {
	text = [str retain];
	color = [acolor retain];
	font = [aFont retain];
    }
    return self;
}

- (void)drawCircularText:(NSString *)str inRect:(CGRect)rect withContext:(CGContextRef)context withFont:(UIFont *)fnt withColor:(UIColor *)clr {
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, rect.size.width/2, rect.size.height/2);
    CGContextTranslateCTM(context, CGRectGetMidX(boundsOnScreen), CGRectGetMidY(boundsOnScreen));
    int n = [str length];
    if (n<1) {
	return;
    }
    // compute total angular length
    double len = 0;
    NSString *letter;
    CGSize s;
    double spaceing = 0;	// tried s.height * some factor but zero seems best
    for (int i=0; i<n; i++) {
	letter = [str substringWithRange:NSMakeRange(i, 1)];
	// Deprecated iOS 7:  s = [letter sizeWithFont:fnt];
        s = [letter sizeWithAttributes:@{NSFontAttributeName:fnt}];
	len += -2*M_PI*((s.width+spaceing*2)/(2*M_PI*radius));
    }
    if (orientation == ECDialOrientationDemiRadial && angle > M_PI/2 && angle < 3*M_PI/2) {
	CGContextRotateCTM(context, len/2+angle+M_PI);
    } else {
	CGContextRotateCTM(context, -len/2-angle);
    }
    for (int i=0; i<n; i++) {
	letter = [str substringWithRange:NSMakeRange(i, 1)];
	// Deprecated iOS 7:  s = [letter sizeWithFont:fnt];
        s = [letter sizeWithAttributes:@{NSFontAttributeName:fnt}];
	if (orientation == ECDialOrientationDemiRadial && angle > M_PI/2 && angle < 3*M_PI/2) {
	    CGContextRotateCTM(context, 2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	    CGRect r = CGRectMake(-s.width/2, -radius, s.width, s.height);
	    [self drawText:letter inRect:r withContext:context withFont:fnt withColor:clr];
	    CGContextRotateCTM(context, 2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	} else {
	    CGContextRotateCTM(context, -2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	    CGRect r = CGRectMake(-s.width/2, radius-s.height, s.width, s.height);
	    [self drawText:letter inRect:r withContext:context withFont:fnt withColor:clr];
	    CGContextRotateCTM(context, -2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	}
    }
    CGContextRestoreGState(context);
}

- (void)drawInViewBounds:(CGRect)bounds atZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    [color set];
    if (color == [UIColor clearColor]) {
	CGContextSetBlendMode(context, kCGBlendModeClear);
    }
    CGRect rect = CGRectMake(boundsInView.origin.x - bounds.origin.x,
			     boundsInView.origin.y - bounds.origin.y,
			     boundsInView.size.width, boundsInView.size.height);
    if (radius > 0) {
	[self drawCircularText:text inRect:bounds withContext:context withFont:font withColor:color];
    } else {
	[self drawText:text inRect:rect withContext:context withFont:font withColor:color];
    }
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, boundsInView.size.width/2, boundsInView.size.height/2);
    [color set];
    if (color == [UIColor clearColor]) {
	CGContextSetBlendMode(context, kCGBlendModeClear);
    }
    if (radius > 0) {
	[self drawCircularText:text inRect:boundsInView withContext:context withFont:font withColor:color];
    } else {
	[self drawText:text inRect:boundsInView withContext:context withFont:font withColor:color];
    }
}

- (double)animSpeed {
    return animSpeed;
}

- (void)print {
    [super print];
    printf("\t\t'%s'\t", [text UTF8String]);
}

- (void)dealloc {
    [font release];
    [text release];
    [color release];
    [super dealloc];
}

@end


@implementation ECQWedgeHandView

- (NSString *)className {
    return @"QWedgeView";
}

- (ECQWedgeHandView *)initWithOuterRadius:(double)anOuterRadius
	    xAnchorOffsetFromScreenCenter:(double)xAnchorOffsetFromScreenCenter
	    yAnchorOffsetFromScreenCenter:(double)yAnchorOffsetFromScreenCenter
			      innerRadius:(double)anInnerRadius
				angleSpan:(double)anAngleSpan
				animSpeed:(double)anAnimSpeed
				 dragType:(ECDragType)aDragType
			dragAnimationType:(ECDragAnimationType)aDragAnimationType 
				   scolor:(UIColor*)asColor
				   fcolor:(UIColor*)afColor 
				  fcolor2:(UIColor*)afColor2
				     font:(UIFont*)aFont
				     text:(NSString*)aText
			      orientation:(ECWheelOrientation)anOrientation
				    ticks:(double)aTicks
				tickWidth:(double)aTickWidth
			      borderWidth:(double)aBorderWidth
			      halfAndHalf:(bool)isHalfAndHalf {
    assert(anOuterRadius > 0);
    assert(anInnerRadius >= 0);
    assert(anOuterRadius > anInnerRadius);
    assert(anAngleSpan > 0);
    double aHalfSpan = anAngleSpan / 2;
    double aWidth = 2 * anOuterRadius * sin(aHalfSpan);
    double lowY = anInnerRadius*cos(aHalfSpan);
    double height = anOuterRadius - lowY;
    CGRect viewBounds = CGRectMake(-aWidth/2, lowY, ceil(aWidth), height);
    CGRect screenBounds = CGRectMake(xAnchorOffsetFromScreenCenter - aWidth/2,
				     yAnchorOffsetFromScreenCenter + lowY,
				     ceil(aWidth), height);
    if (self = (id)[super initWithBoundsInView:viewBounds boundsOnScreen:screenBounds dragType:aDragType dragAnimationType:aDragAnimationType]) {
	innerRadius = anInnerRadius;
	outerRadius = anOuterRadius;
	halfSpan = aHalfSpan;
	width = aWidth;
	tickWidth = aTickWidth;
	orientation = anOrientation;
	nTicks = aTicks;
	scolor = [asColor retain];
	fcolor = [afColor retain];
	fcolor2 = [afColor2 retain];
	font = [aFont retain];
	theText = [aText retain];
	halfAndHalf = isHalfAndHalf;
	borderWidth = aBorderWidth;
	animSpeed = anAnimSpeed;
    }
    return self;
}

- (double)animSpeed {
    return animSpeed;
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, -boundsInView.origin.x, -boundsInView.origin.y);  // move origin to anchor point
    [fcolor setFill];
    if (borderWidth > 0) {
	[scolor setStroke];
	CGContextSetLineWidth(context, borderWidth);
    } else {
    	[fcolor setStroke];
	CGContextSetLineWidth(context, 1);
    }


    // border/fill
    if (halfAndHalf) {
	CGContextAddArc(context, 0, 0, outerRadius, M_PI/2, M_PI/2+halfSpan, 0);
	CGContextAddArc(context, 0, 0, innerRadius, M_PI/2+halfSpan, M_PI/2, 1);
	CGContextAddLineToPoint(context, 0, outerRadius);
	CGContextDrawPath(context, kCGPathFillStroke);
	[fcolor2 set];
	CGContextAddArc(context, 0, 0, outerRadius, M_PI/2, M_PI/2-halfSpan, 1);
	CGContextAddArc(context, 0, 0, innerRadius, M_PI/2-halfSpan, M_PI/2, 0);
	CGContextDrawPath(context, kCGPathFillStroke);
    } else {
	CGContextAddArc(context, 0, 0, outerRadius, M_PI/2-halfSpan, M_PI/2+halfSpan, 0);
	CGContextAddArc(context, 0, 0, innerRadius, M_PI/2+halfSpan, M_PI/2-halfSpan, 1);
	CGContextAddLineToPoint(context, width/2, outerRadius*cos(halfSpan));
	CGContextDrawPath(context, kCGPathFillStroke);
    }
    
    // text
    double h = outerRadius - innerRadius;
    double w = outerRadius * halfSpan * 2;
    CGContextSetLineWidth(context, 1);
    [scolor set];
    CGContextSetBlendMode(context, kCGBlendModeDifference);
    switch (orientation) {
	case ECWheelOrientationTwelve:
	    [self drawText:theText inRect:CGRectMake(-w/2,  innerRadius-(nTicks>0 ? 2 : 0), w, h) withContext:context withFont:font withColor:scolor];
	    break;
	case ECWheelOrientationSix:
	    CGContextRotateCTM(context,  M_PI);
	    [self drawText:theText inRect:CGRectMake(-w/2, -outerRadius+(nTicks>0 ? 2 : 0), w, h) withContext:context withFont:font withColor:scolor];
	    CGContextRotateCTM(context,  M_PI);
	    break;
	case ECWheelOrientationThree:
	    CGContextRotateCTM(context,  M_PI/2);
	    [self drawText:theText inRect:CGRectMake( innerRadius, -w*3/4, h, w) withContext:context withFont:font withColor:scolor];
	    CGContextRotateCTM(context, -M_PI/2);
	    break;
	case ECWheelOrientationNine:
	    CGContextRotateCTM(context, -M_PI/2);
	    [self drawText:theText inRect:CGRectMake(-outerRadius, -w*3/4, h, w) withContext:context withFont:font withColor:scolor];
	    CGContextRotateCTM(context,  M_PI/2);
	    break;
	default:
	    break;
    }

    // ticks
    CGContextRotateCTM(context, -halfSpan);
    for (int i=0; i<=nTicks; i++) {
	CGContextMoveToPoint(context, 0, outerRadius);
	if (i == nTicks/2) {
	    CGContextSetLineWidth(context, tickWidth*2);
	    CGContextAddLineToPoint(context, 0, outerRadius - 4);
	} else {
	    CGContextSetLineWidth(context, tickWidth);
	    CGContextAddLineToPoint(context, 0, outerRadius - 2);
	}
	CGContextStrokePath(context);
	CGContextRotateCTM(context, 2*halfSpan/nTicks);
    }
    CGContextRotateCTM(context, -(nTicks+1)*halfSpan/nTicks);
    CGContextStrokePath(context);
}	    

- (void)dealloc {
    [scolor release];
    [fcolor release];
    [fcolor2 release];
    [theText release];
    [font release];
    [super dealloc];
}

@end


void
ESCalculateCalendarWidth(UIFont *font,  // input
                         CGSize *overallSize, // output
                         CGSize *cellSize,    // output
                         CGSize *spacing) {  // output
    // Spacing of cell text only (for largest string in a cell)
    CGFloat cellWidth = 0;
    CGFloat cellHeight = 0;
    for (int d = 1; d <= 31; d++) {
        NSString *dayString = [[NSString stringWithFormat:@"%d", d] retain];  // Retain so we can release right away (below)
        // Deprecated iOS 7:  CGSize daySize = [dayString sizeWithFont:font];
	CGSize daySize = [dayString sizeWithAttributes:@{NSFontAttributeName:font}];
        [dayString release];
        if (daySize.width > cellWidth) {
            cellWidth = daySize.width;
        }
        if (daySize.height > cellHeight) {
            cellHeight = daySize.height;
        }
    }
    cellSize->width = cellWidth;
    cellSize->height = cellHeight;
    spacing->width = cellWidth / 2;   // heuristic
    spacing->height = cellHeight / 4; // heuristic

    // Overall width includes 7 days and 6 spaces, and half a space on each side
    overallSize->width = (7 * cellWidth) + (7 * spacing->width);
    // Height is 5 or 6 rows, but size for 6
    overallSize->height = (6 * cellHeight) + (5 * spacing->height);
}

@implementation ECQHandView

- (NSString *)className {
    return @" QHandView";
}

- (ECQHandView *)   initWithType:(ECQHandType)typ
   xAnchorOffsetFromScreenCenter:(double)xAnchorOffsetFromScreenCenter
   yAnchorOffsetFromScreenCenter:(double)yAnchorOffsetFromScreenCenter
			   width:(double)aWidth
			  oWidth:(double)aoWidth
			  length:(double)aLength
			 length2:(double)aLength2
			    text:(NSString *)aText
			    font:(UIFont*)aFont
               calendarWheelType:(ECCalendarWheelType)aCalendarWheelType
                calendarStartDay:(int)aCalendarStartDay
			 oLength:(double)aoLength
			    tail:(double)aTail
			   oTail:(double)aoTail
			 oCenter:(double)aoCenter
			   nRays:(double)anRays
		       animSpeed:(double)anAnimSpeed
			 animDir:(ECAnimationDirection)anAnimDir
			dragType:(ECDragType)aDragType
	       dragAnimationType:(ECDragAnimationType)aDragAnimationType 
			 oRadius:(double)aoRadius
			oRadiusX:(double)aoRadiusX
		       lineWidth:(double)aLineWidth
		      oLineWidth:(double)aoLineWidth
			  scolor:(UIColor*)asColor
			  fcolor:(UIColor*)afColor
			 oscolor:(UIColor*)aosColor
			 ofcolor:(UIColor*)aofColor
		      tLineWidth:(double)atLineWidth
			 tscolor:(UIColor*)atsColor
			 tfcolor:(UIColor*)atfColor
			 blender:(UIImage*)aBlender
		       blender2x:(UIImage*)aBlender2x
		       blender4x:(UIImage*)aBlender4x {
    assert(aLength > 0);
    assert(aWidth > 0);
    // Deprecated iOS 7:  CGSize textSize = [aText sizeWithFont:aFont];
    CGSize textSize = aText ? [aText sizeWithAttributes:@{NSFontAttributeName:aFont}] : CGSizeMake(0, 0);
    double wv, hv, ycenter;
    circularArrow = (aoWidth < 0);
    aoWidth = fabs(aoWidth);
    if (typ == ECQHandSpoke && aCalendarWheelType != ECNotCalendarWheel) {
        assert(aFont);
        calendarStartDay = aCalendarStartDay;
        CGSize overallSize;  // size of entire month
        CGSize cellSize;     // size of single cell text only
        CGSize spacing;      // spacing between cells (h and v)
        ESCalculateCalendarWidth(aFont, &overallSize, &cellSize, &spacing);
        wv = overallSize.width;
        hv = overallSize.height;
        assert(wv > 0);
        assert(hv > 0);
        hv += ECCalendarWheelSpokeExtension;
        hv += fmod(hv, 2);
        ycenter = -overallSize.height;
        ycenter += fmod(ycenter, 2);
    } else if (typ == ECQHandGear) {
	wv = aWidth*2+1;
	hv = aWidth*2+1;
	ycenter = -wv/2;
    } else if (textSize.width > 0 ) {
	wv = textSize.width;
	wv += fmod(wv,2);
	wv = fmax(wv, oRadiusX*2*M_PI/24);
	hv = textSize.height;
	hv += fmod(hv,2);
	ycenter = -textSize.height/2;
	ycenter += fmod(ycenter,2);
    } else {
	if (aoRadiusX == 0) {
	    aoRadiusX = aoRadius;
	}
	wv = fmax(fmax(fmax(fmax(aWidth,fabs(aoWidth)),aoRadiusX*2),aoCenter*2),aoLength*0.16);
	hv = aLength + fmax(aoCenter,aTail) + aoLength + aoRadius*2 - aLength2;
        if (anRays > 0) {
	    wv = fmax(wv, aLength-aLength2);
	}
	ycenter = aLength2 - fmax(aoCenter,aTail) - aoRadius*2;
    }
    CGRect viewBounds = CGRectMake(-wv/2, ycenter, wv, hv);
    CGRect screenBounds = CGRectMake(xAnchorOffsetFromScreenCenter - wv/2,
				     yAnchorOffsetFromScreenCenter + ycenter,
				     wv, hv);
    if (self = [super initWithBoundsInView:viewBounds boundsOnScreen:screenBounds dragType:aDragType dragAnimationType:aDragAnimationType]) {
	handType = typ;
	animSpeed = anAnimSpeed;
	animDir = anAnimDir;
	width = aWidth;
	length = aLength;
	length2 = aLength2;
	font = [aFont retain];
        calendarWheelType = aCalendarWheelType;
	text = [aText retain];
	tail = aTail;
	scolor = [asColor retain];
	fcolor = [afColor retain];
	lineWidth = aLineWidth == 0 ? (fcolor == [UIColor clearColor] ? ECHandLineWidthOutline : ECHandLineWidthFill) : aLineWidth;
	oWidth = aoWidth;
	oLength = aoLength;
	oTail = aoTail;
	oCenter= aoCenter;
	nRays = anRays;
	oscolor = [aosColor retain];
	ofcolor = [aofColor retain];
        tscolor = [atsColor retain];
        tfcolor = [atfColor retain];
    	oLineWidth = aoLineWidth == 0 ? (fcolor == [UIColor clearColor] ? ECHandLineWidthOutline : ECHandLineWidthFill) : aoLineWidth;
        tLineWidth = atLineWidth == 0 ? oLineWidth : atLineWidth;
	oRadius = aoRadius;
	oRadiusX = aoRadiusX;
	blender = [aBlender retain];
	blender2x = [aBlender2x retain];
	blender4x = [aBlender4x retain];
    }
    return self;
}

- (double)animSpeed {
    return animSpeed;
}

- (ECAnimationDirection)animDir {
    return (ECAnimationDirection)animDir;
}

- (void)drawCenter {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (oCenter > 0) {  // draw the center
	CGContextSetLineWidth(context, oLineWidth);
	[oscolor setFill];
	[oscolor setStroke];
	CGContextAddArc(context, 0, 0, oCenter, 0, 2*M_PI, 0);
	CGContextDrawPath(context,  kCGPathFillStroke);
    }
}

- (void)drawOrnaments {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (circularArrow) {	// draw a circle instead of an arrow
	CGContextAddEllipseInRect(context, CGRectMake(-oWidth/2, length-oWidth+1, oWidth, oWidth));
	CGContextDrawPath(context,  kCGPathFillStroke);
    } else if (oLength > 0) {	    // draw the arrow head
	CGContextSetLineWidth(context, oLineWidth);
	[ofcolor setFill];
	[oscolor setStroke];
	CGContextMoveToPoint   (context, 0,         length - oLineWidth*3 + oLength);
	CGContextAddLineToPoint(context, oWidth/2,  length - oLineWidth*3);
	CGContextAddLineToPoint(context, 0,         length - oTail);
	CGContextAddLineToPoint(context, -oWidth/2, length - oLineWidth*3);
	CGContextAddLineToPoint(context, 0,         length - oLineWidth*3 + oLength);
	CGContextDrawPath(context,  kCGPathFillStroke);
	if (oLineWidth > 0) {
	    // draw an extra little triangle at the point
	    CGContextSetLineWidth(context, 0);
	    [oscolor setFill];
	    CGContextMoveToPoint   (context,  oLineWidth/2, length + oLength - oLineWidth*3);
	    CGContextAddLineToPoint(context,  0,            length + oLength);
	    CGContextAddLineToPoint(context, -oLineWidth/2, length + oLength - oLineWidth*3);
	    CGContextAddLineToPoint(context,  oLineWidth/2, length + oLength - oLineWidth*3);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	}
    }
    if (oRadius > 0) {	// draw the end circle
	CGContextSetLineWidth(context, tLineWidth);
	[tfcolor setFill];
	[tscolor setStroke];

        // CGFloat fr, fg, fb, fa, sr, sg, sb, sa;
        // [tfcolor getRed:&fr green:&fg blue:&fb alpha:&fa];
        // [tscolor getRed:&sr green:&sg blue:&sb alpha:&sa];

        // printf("tLineWidth: %g, tfcolor %g %g %g %g, tscolor %g %g %g %g\n",
        //        tLineWidth, fr, fg, fb, fa, sr, sg, sb, sa);

        // [ofcolor getRed:&fr green:&fg blue:&fb alpha:&fa];
        // [oscolor getRed:&sr green:&sg blue:&sb alpha:&sa];

        // printf("oLineWidth: %g, ofcolor %g %g %g %g, oscolor %g %g %g %g\n",
        //        oLineWidth, fr, fg, fb, fa, sr, sg, sb, sa);

//	CGContextAddArc(context, 0, -tail-oRadius, oRadius, 0, 2*M_PI, 0);
	CGContextAddEllipseInRect(context, CGRectMake(-oRadiusX, -tail-2*oRadius, oRadiusX*2, oRadius*2));
	CGContextDrawPath(context,  kCGPathFillStroke);
    }
    [self drawCenter];
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    assert(context);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, -boundsInView.origin.x, -boundsInView.origin.y);  // move origin to anchor point
    [fcolor setFill];
    [scolor setStroke];
#if 0
    // fill in the whole bounds rectangle so we can see where it is
    [[UIColor lightGrayColor] setFill];
    CGContextAddArc(context, 0, 0, 200, 0, 2*M_PI, 0);
    CGContextFillPath(context);
    [fcolor setFill];
#endif
    switch (handType) {
	case ECQHandWire:
	    // single line
	    CGContextSetLineWidth(context, lineWidth);
	    CGContextMoveToPoint(context, -width/2,  length2);   // FIX FIX FIX:  This offsets the line by -width/2 but changing it to zero makes the line fat
	    CGContextAddLineToPoint(context, -width/2, length-(oTail<0 ? oTail : 0));   // FIX FIX FIX
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    [self drawOrnaments];
	    break;
	    
	case ECQHandRect:
	    // rectangular
	    CGContextSetLineWidth(context, lineWidth);
	    CGContextAddRect(context, CGRectMake(-width/2, length2-tail, width, length+tail-oTail));
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    [self drawOrnaments];
	    break;
	    
	case ECQHandGear:
	    // gear with teeth, pinion and spokes
	    CGContextSetLineWidth(context, lineWidth);
	{
	    // parameter mapping:
	    double tipRadius = width;		// outermost radius (tips of teeth)
	    double rimOuterRadius = oWidth;	// radius of bottoms of teeth
	    double rimInnerRadius = length;	// radius of inner edge of rim
	    double hubRadius = length2;		// radius of hub
	    double leafRadius = oLength;	// radius of tips of leaves (pinion gear teeth)
	    double nTeeth = tail;		// number of teeth
	    double nLeaves = oTail;		// number of leaves
	    double nSpokes = oCenter;		// number of leaves
	    assert(tipRadius > 0);
	    assert(rimOuterRadius >= 0 && rimOuterRadius <= tipRadius);
	    assert(rimInnerRadius >= 0 && rimInnerRadius <= rimOuterRadius);
	    assert(hubRadius >= 0 && hubRadius <= rimInnerRadius);
	    assert(leafRadius >= 0 && leafRadius <= hubRadius);
	    assert(nTeeth >= 0);
	    assert(nLeaves >= 0);
	    assert(nSpokes >= 0);

	    // teeth
	    if (nTeeth > 0) {
	    [fcolor setStroke];
		double pitch = M_PI * 2 * rimOuterRadius / nTeeth;
		double ab = (tipRadius - rimOuterRadius) / 2;
		double ao = pitch/4;
		double deltaTheta = 2*M_PI/nTeeth;
		for (double i=0; i<nTeeth; i++) {
		    CGContextMoveToPoint   (context, - ao*2, rimOuterRadius       );
		    CGContextAddLineToPoint(context, - ao  , rimOuterRadius       );
		    CGContextAddLineToPoint(context, - ao  , rimOuterRadius + ab  );
		    CGContextAddLineToPoint(context, - ao/2, rimOuterRadius + ab*2);
		    CGContextAddLineToPoint(context,   ao/2, rimOuterRadius + ab*2);
		    CGContextAddLineToPoint(context,   ao  , rimOuterRadius + ab  );
		    CGContextAddLineToPoint(context,   ao  , rimOuterRadius       );
		    CGContextAddLineToPoint(context,   ao*2, rimOuterRadius       );
		    CGContextRotateCTM(context, deltaTheta);
		}
		CGContextDrawPath(context,  kCGPathFillStroke);
	    }

	    // rim
	    CGContextAddArc(context,  0, 0, rimOuterRadius+lineWidth, 0, 2*M_PI, 0);
	    CGContextAddArc(context,  0, 0, rimInnerRadius, 0, 2*M_PI, 0);
	    CGContextDrawPath(context,  kCGPathEOFillStroke);

	    // spokes
	    if (nSpokes > 0) {
		[fcolor setStroke];
		CGContextSetLineWidth(context, (tipRadius-rimInnerRadius)*.8);
		for (double i=0; i<nSpokes; i++) {
		    double theta = 2 * M_PI * i / nSpokes;
		    CGContextMoveToPoint   (context,      hubRadius * cos(theta),      hubRadius * sin(theta));
		    CGContextAddLineToPoint(context, rimInnerRadius * cos(theta), rimInnerRadius * sin(theta));
		}
	    }
	    CGContextDrawPath(context,  kCGPathStroke);

	    // hub
	    CGContextAddArc(context,  0, 0, hubRadius, 0, 2*M_PI, 0);
	    CGContextDrawPath(context,  kCGPathFillStroke);

	    // leaves
	    if (nLeaves == 1) {
		// special case: just make a single dot
		[ofcolor setStroke];
		CGContextSetLineWidth(context, 2);
		CGContextMoveToPoint   (context, 0, leafRadius);
		CGContextAddLineToPoint(context, 0, leafRadius-2);
		CGContextDrawPath(context,  kCGPathStroke);
	    } else if (nLeaves > 1) {
		[ofcolor setStroke];
		[ofcolor setFill];
		CGContextSetLineWidth(context, M_PI*leafRadius/2/nLeaves);
		for (double i=0; i<nLeaves; i++) {
		    double theta = 2 * M_PI * i / nLeaves;
		    CGContextMoveToPoint   (context, leafRadius   * cos(theta), leafRadius   * sin(theta));
		    CGContextAddLineToPoint(context, leafRadius/2 * cos(theta), leafRadius/2 * sin(theta));
		}
		CGContextDrawPath(context,  kCGPathStroke);
	    }

	    // center of pinion
	    [ofcolor setStroke];
	    [ofcolor setFill];
	    CGContextAddArc(context,  0, 0, leafRadius/2, 0, 2*M_PI, 0);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    [[UIColor blackColor] setStroke];
	    CGContextSetLineWidth(context, 2);
	    CGContextMoveToPoint   (context, -1, 0);
	    CGContextAddLineToPoint(context,  1, 0);
	    CGContextDrawPath(context,  kCGPathStroke);
	}
    break;
	    
	case ECQHandSet:
	    // counterclockwise pointing partial sun
	    CGContextSetLineWidth(context, .25);
	    {
		// length2, as always, is distance from axis of rotation to nearest point of visible sun (tail is ignored)
		// length is distance from axis of rotation to furthest point of visible sun
		// width/2 is twice the amount the sun is peeking out from horizon (that puts the horizon at x=0)
		//   half of the width is empty, wasting some space in the atlas (but not much)
		double halfWidth = width/2;
		double halfHeight = (length - length2)/2;
		double arcRadius = (halfWidth*halfWidth + halfHeight*halfHeight)/width;
		double theta = asin(halfHeight / arcRadius);
		CGContextAddArc(context, arcRadius - width/2, length2 + halfHeight, arcRadius, M_PI-theta, M_PI + theta, 0);
	    }
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    break;

	case ECQHandRise:
	    // clockwise pointing partial sun
	    CGContextSetLineWidth(context, .25);
	{
	    double halfWidth = width/2;
	    double halfHeight = (length - length2)/2;
	    double arcRadius = (halfWidth*halfWidth + halfHeight*halfHeight)/width;
	    double theta = asin(halfHeight / arcRadius);
	    CGContextAddArc(context,  width/2 - arcRadius, length2 + halfHeight, arcRadius, -theta, theta, 0);
	}
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    break;
	    
	case ECQHandSun:
	case ECQHandSun2:
	    // "sun" with rays
	    // length2, as always, is distance from axis of rotation to nearest point of visible sun
	    // length is distance from axis of rotation to furthest point of visible sun
	    // oCenter is the radius of the sun (excluding the rays)
	    // nRays is the number of rays; rays extend an extra width/4
	    CGContextSetLineWidth(context, lineWidth);
	    double rayRad = (length-length2) / 2;
	    double raysRad = (length-length2) / 3;
	    double cen = length2 + raysRad;
	    if (oCenter == 0) {
		oCenter = raysRad/2;
	    }
	    if (handType == ECQHandSun2) {
		rayRad = raysRad;
	    }
	    for (double i=0; i<nRays; i++) {
		double theta = M_PI/2 + 2 * M_PI * i / nRays;
		CGContextMoveToPoint   (context, rayRad * cos(theta)             , cen + rayRad * sin(theta));		    // far point
		CGContextAddLineToPoint(context, oCenter* cos(theta + M_PI/nRays), cen + oCenter* sin(theta + M_PI/nRays));   // at the "solar surface"
	    	CGContextAddLineToPoint(context, oCenter* cos(theta - M_PI/nRays), cen + oCenter* sin(theta - M_PI/nRays));
		CGContextAddLineToPoint(context, rayRad * cos(theta)             , cen + rayRad * sin(theta));		    // back to far point
		rayRad = raysRad;			    // first one is longer than the others
	    }
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    [fcolor setStroke];
	    CGContextAddArc(context, 0, cen, oCenter, 0, 2*M_PI, 1);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    break;
	    
	case ECQHandTri:
	    // triangular
	    CGContextSetLineWidth(context, lineWidth);
	    CGContextMoveToPoint(context, -width/2,  length2);
	    CGContextAddLineToPoint(context, 0, length-(oTail<0 ? oTail : 0));
	    CGContextAddLineToPoint(context, width/2, length2);
	    if (oRadius == 0) {
		CGContextAddLineToPoint(context, 0, length2 - tail);
	    } else {
		CGContextAddLineToPoint(context, .5, length2 - tail);
		CGContextAddLineToPoint(context, -.5, length2 - tail);
	    }
	    CGContextAddLineToPoint(context, -width/2,  length2);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    [self drawOrnaments];
	    break;
	    
	case ECQHandBreguet:
	    // Breguet style pomme hand
	    CGContextSetLineWidth(context, lineWidth);
	    double widthScaler	  = width / (length * 0.16);
	    double lengthScaler	  = (length-81)/10;
	    double armWidth       = length * 0.04  * widthScaler;
	    double centerRadius   = oCenter ? oCenter : (length * 0.08 * widthScaler);
	    double breOuterCenter = length * 0.71  + lengthScaler;
	    double breInnerCenter = length * 0.725 + lengthScaler * 0.8;
	    double breOuterRadius = length * 0.075 * widthScaler;
	    double breInnerRadius = length * 0.05  * widthScaler;
	    double breBase	  = breOuterCenter - breOuterRadius;
	    double tipBase	  = breOuterCenter + breOuterRadius;
	    double tipWidth	  = length * 0.045 * widthScaler;
	    // filled circle at the hub
	    CGContextAddArc(context, 0, 0, centerRadius, 0, 2*M_PI, 1);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    // inner arm trapezoid
	    CGContextMoveToPoint(context, -armWidth/2, centerRadius);
	    CGContextAddLineToPoint(context, -armWidth/10, breBase);
	    CGContextAddLineToPoint(context,  armWidth/10, breBase);
	    CGContextAddLineToPoint(context, armWidth/2, centerRadius);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    // Breguet thingie:  filled circle with an offset circle removed
	    CGContextAddArc(context, 0, breOuterCenter, breOuterRadius, 0, 2*M_PI, 1);
	    CGContextMoveToPoint(context, breInnerRadius, breInnerCenter);
	    CGContextAddArc(context, 0, breInnerCenter, breInnerRadius, -2*M_PI, 0, 0);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    // fatter triangle at the end
	    CGContextMoveToPoint(context, -tipWidth/2, tipBase);
	    CGContextAddLineToPoint(context, 0, length);
	    CGContextAddLineToPoint(context, tipWidth/2, tipBase);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    break;
	    
	case ECQHandSpoke:
	    // arc with text (part of a wheel)

          {
            const char *textStr = [text UTF8String];
            double w;
            double h;

            // Used only in calendar mode:
            CGSize overallSize;  // size of entire month
            CGSize cellSize;     // size of single cell text only
            CGSize spacing;      // spacing between cells (h and v)
            int calendarStartColumn = -1;

            // check for calendar page
            if (calendarWheelType != ECNotCalendarWheel) {
                assert(strncmp(textStr, "%%Calendar%%", 12) == 0);
                int st = sscanf(textStr+12, "%d", &calendarStartColumn);
                if (st != 1) {
                    [[ECErrorReporter theErrorReporter]
                        reportError:[NSString stringWithFormat:@"String appears to be calendar month specifier but didn't find weekday number:\n%@", text]];
                    break;
                }
                assert(calendarStartColumn >= 0);
                assert(calendarStartColumn <= 15);
                ESCalculateCalendarWidth(font, &overallSize, &cellSize, &spacing);
                w = overallSize.width;
                h = overallSize.height;
                //printf("calendarStartColumn is %d, overall size is %.1f %.1f, cell size is %.1f %.1f, spacing is %.1f %.1f\n",
                //       calendarStartColumn, w, h, cellSize.width, cellSize.height, spacing.width, spacing.height);
                CGContextTranslateCTM(context, 0, -h/2 + ECCalendarWheelSpokeExtension);  // hack;
            } else {
                // Just a normal string
                // Deprecated iOS 7:  CGSize textSize = [text sizeWithFont:font];
                CGSize textSize = [text sizeWithAttributes:@{NSFontAttributeName:font}];
                w = textSize.width;
                h = textSize.height;
            }
            // Clear the background
	    [ofcolor setFill];	    // for the background
	    CGContextAddRect(context, CGRectMake(-w/2, -h/2 - 2 - ECCalendarWheelSpokeExtension, w, h + 2 + ECCalendarWheelSpokeExtension));
	    CGContextFillPath(context);
	    CGContextSetLineWidth(context, lineWidth);
	    [fcolor setFill];

            // Now draw the text
            if (calendarStartColumn >= 0) {
                if (calendarStartColumn == 8) {  // Special hack:  Just clear entire area
                    CGContextClearRect(context, CGRectMake(-w, -h, w*2, h*2));
                } else {
                    // Now clear out last column of last row to avoid overlap issue
                    if (calendarStartColumn < 8) {  // Not October 1582 wheel, which doesn't need this
                        CGContextClearRect(context, CGRectMake(w/2 - cellSize.width - 4, -h/2-3-ECCalendarWheelSpokeExtension, cellSize.width + 6, cellSize.height + 3 + ECCalendarWheelSpokeExtension));
                    }
                    int dayNumber = 1;
                    bool isOctober1582Hack = false;
                    int weekdayStart = calendarStartDay;
                    if (calendarStartColumn >= 9) {
                        isOctober1582Hack = true;
                        weekdayStart = calendarStartColumn - 9;
                        calendarStartColumn = (8 - weekdayStart) % 7;  // October 1582 started on a Monday
                    }
                    int saturdayColumn = (13 - weekdayStart) % 7;
                    int sundayColumn = (7 - weekdayStart) % 7;
                    for (int row = 0; dayNumber <= 31; row++) {
                        for (int column = 0; column < 7 && dayNumber <= 31; column++) {
                            if (calendarStartColumn > 0) {
                                while (calendarStartColumn) {
                                    column++;
                                    calendarStartColumn--;  // Don't put this in the condition expr; we only want to do it the first time
                                }
                                CGContextClearRect(context, CGRectMake(-w/2, h/2 - cellSize.height - spacing.height / 2,
                                                                       column * (cellSize.width + spacing.width),
                                                                       cellSize.height + spacing.height));
                            }
                            CGFloat centerX = -w/2 + column * (cellSize.width + spacing.width) + (cellSize.width / 2) + (spacing.width / 2);
                            CGFloat centerY = h/2 - row * (cellSize.height + spacing.height) - (cellSize.height / 2);
                            centerY -= (1 - row/5.0);  // hack
                            // if (row == 0) {
                            //     centerY -= 1;  // hack
                            // }
                            NSString *str = [NSString stringWithFormat:@"%d", dayNumber++];
                            if (isOctober1582Hack && dayNumber == 5) {
                                dayNumber += 10;  // Jump to 15
                            }
                            [self drawText:str
                                    inRect:CGRectMake(centerX - cellSize.width/2,
                                                      centerY - cellSize.height/2,
                                                      cellSize.width,
                                                      cellSize.height)
                               withContext:context
                                  withFont:font
                                 withColor:((column == saturdayColumn || column == sundayColumn) ? oscolor : fcolor)];
                            //printf("Drawing text %s in rect [%.1f %.1f %.1f %.1f]\n",
                            //       [str UTF8String],
                            //       centerX - cellSize.width/2,
                            //       centerY - cellSize.height/2,
                            //       cellSize.width,
                            //       cellSize.height);
                        }
                    }
                }
            } else {
                // Just a normal string
                [self drawText:text inRect:CGRectMake(-w/2, -h/2, w, h) withContext:context withFont:font withColor:fcolor];
            }
          }
	  break;
	    
	case ECQHandQuad:
	    // bezier curve with a filled triangle at the end
	    CGContextSetLineWidth(context, lineWidth);
	    CGContextMoveToPoint(context,                                                   -oWidth/12, oCenter);
	    CGContextAddQuadCurveToPoint(context, -oWidth*.45,			  oLength/2, -oWidth/4, oLength);
	    CGContextMoveToPoint(context,                                                     oWidth/4, oLength);
	    CGContextAddQuadCurveToPoint(context,  oWidth*.45,			  oLength/2, oWidth/12, oCenter);
	    CGContextDrawPath(context,  kCGPathFillStroke);
	    [scolor setFill];
	    CGContextSetLineWidth(context, 0);
	    CGContextMoveToPoint(context,     oWidth/4+lineWidth/2, oLength);
	    CGContextAddLineToPoint(context,  			 0, length);
	    CGContextAddLineToPoint(context, -oWidth/4-lineWidth/2, oLength);
	    CGContextAddLineToPoint(context, -oWidth/4+lineWidth/2, oLength);
	    CGContextAddLineToPoint(context,		         0, oLength*1.2);
	    CGContextAddLineToPoint(context,  oWidth/4-lineWidth/2, oLength);
	    CGContextDrawPath(context,  kCGPathFill);
	    [self drawCenter];
	    break;

	case ECQHandCube:
	default:
	    assert(false);
    }
    UIImage *blenderImg = blender;
    if (zoomFactor == 4) {
        if (blender4x) {
            blenderImg = blender4x;
        } else if (blender2x) {
            blenderImg = blender2x;
        }
    } else if (zoomFactor == 2) {
        if (blender2x) {
            blenderImg = blender2x;
        } else if (blender4x) {
            blenderImg = blender4x;
        }
    }
    [blenderImg drawInRect:boundsInView blendMode:kCGBlendModeLuminosity alpha:1.0];
    CGContextRestoreGState(context);
}

- (void)print {
    [super print];
    printf("w=%2.0f, l=%3.0f\t", width, length);
}

- (void)dealloc {
    [scolor release];
    [fcolor release];
    [oscolor release];
    [ofcolor release];
    [font release];
    [text release];
    [blender release];
    [blender2x release];
    [blender4x release];
    [super dealloc];
}

@end


@implementation ECQDialView

- (NSString *)className {
    return @" QDialView";
}

- (ECQDialView *)initWithOrientation:(ECDialOrientation)anOrientation
       xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
       yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
		      reverseNumbers:(bool)aReverseNumbers
			      radius:(double)aRadius
			     radius2:(double)aRadius2
			  clipRadius:(double)cRadius		// < 0 means center on x,y; > 0 means center on 0,0
			   demiTweak:(double)cdt		// increase radius by this much for the anti-radial half of demi dials
				text:(NSString *)aText
				font:(UIFont*)aFont
				tick:(ECDialTickType)tic
			      nMarks:(double)nmks
			       mSize:(double)siz
			      angle0:(double)a0
			      angle1:(double)a1
			      angle2:(double)a2
			       marks:(ECDiskMarksMask)marks
			   markWidth:(double)width
			  fillColor1:(UIColor*)aColor1
			  fillColor2:(UIColor*)aColor2
			 strokeColor:(UIColor*)asColor
			     bgColor:(UIColor*)abgColor {
    assert(aFont || text == nil);
    CGRect viewBounds = CGRectMake(-aRadius, -aRadius, aRadius * 2, aRadius * 2);
    CGRect screenBounds = CGRectMake(xCenterOffsetFromScreenCenter - aRadius, yCenterOffsetFromScreenCenter - aRadius,
				     aRadius * 2, aRadius * 2);
    if (self = [super initWithBoundsInView:viewBounds boundsOnScreen:screenBounds dragType:ECDragNormal dragAnimationType:ECDragAnimationNever]) {
	radius = aRadius;
	radius2 = aRadius2;
	clipRadius = cRadius;
	orientation = anOrientation;
	demiTweak = cdt;
	reverseNumbers = aReverseNumbers;
	markMask = marks;
	markWidth = width;
	text = [aText retain];
	font = [aFont retain];
	tick = tic;
	color1 = [aColor1 retain];
	color2 = [aColor2 retain];
	strokeColor = [asColor retain];
	bgColor = [abgColor retain];
	mSize = siz;
	nMarks = nmks;
	angle0 = a0;
	angle1 = a1;
	angle2 = a2;
    }
    return self;
}

- (void)drawDialTachy {
    int i;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 2);

    // break the comma delimited text into an array of labels
    NSArray *labels = [text componentsSeparatedByString:@","];
    int n = [labels count];
    if (n<1) {
	return;
    }
    
    double x;
    double y;
    CGSize s;

    // draw the labels
    [strokeColor set];		// text needs both stroke and fill
    NSString *label;
    for (i=0; i<n; i++) {
	int iLogical = reverseNumbers ? (i == n ? n : n - i) : i;
	label = [labels objectAtIndex:iLogical];
	x = 3600.0 / [label doubleValue] * (2 * M_PI / 60);
	// Deprecated iOS 7:  s = [label sizeWithFont:font];
        s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	// rotate to proper position for this one: tachy is always demi
	if (x > M_PI/2 && x < 3*M_PI/2) {
	    x += M_PI;
	    CGContextRotateCTM(context, -x);
	    y = -radius * ECDialRadiusFactor - demiTweak;
	    CGRect r = CGRectMake(-s.width/2, y, s.width, s.height);
	    [self drawText:label inRect:r withContext:context withFont:font withColor:strokeColor];
	} else {
	    CGContextRotateCTM(context, -x);
	    y = radius * ECDialRadiusFactor - s.height;
	    CGRect r = CGRectMake(-s.width/2, y, s.width, s.height);
	    [self drawText:label inRect:r withContext:context withFont:font withColor:strokeColor];
	}
	CGContextStrokePath(context);
	CGContextRotateCTM(context, x);		// back to starting position
    }
}

// A full cycle of the dial is always 366 days.
static int monthDayCount[12] = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

- (void)drawDialYear:(int)daysPerTick {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 0.6);  // 1.5 for Android Wear
    int yearDay = 0;
    double dayAngle = M_PI / 183;
    printf("Drawing extra part\n");
    // Comment out next four lines for Android Wear
    CGContextAddArc(context, 0, 0, radius, 0, 2 * M_PI, 1);
    CGContextStrokePath(context);
    CGContextAddArc(context, 0, 0, radius2, 0, 2 * M_PI, 1);
    CGContextStrokePath(context);
    for (int mo = 0; mo < 12; mo++) {
	for (int dy = 1; dy <= monthDayCount[mo]; ) {
	    double angle = yearDay * dayAngle;
#if 0
	    if ((dy % 10) == 1) {
#else
	    if (dy == 1) {
#endif
		double r2 = (dy == 1) ? radius2 : (radius - markWidth * 2);
		CGContextMoveToPoint   (context,  radius*sin(angle),  radius*cos(angle));
 		CGContextAddLineToPoint(context,      r2*sin(angle),      r2*cos(angle));
		CGContextStrokePath(context);
	    }
            // For night mode:  if ((dy % 10) == 0) {
	    if ((dy % 2) == 0) {
		//double arcAngle = M_PI/2 - angle;  // not archangel
		double nextAngle = (yearDay+1) * dayAngle;
		double r2 = radius - markWidth;
		if ((dy % 10) == 0) {
		    r2 = radius - 1.5*markWidth;
		}
		CGContextMoveToPoint   (context, radius*sin(angle), radius*cos(angle));
		CGContextAddLineToPoint(context,     r2*sin(angle),     r2*cos(angle));
		//CGContextAddArc(context, 0, 0, r2, arcAngle, arcAngle-dayAngle, 1);
		CGContextAddLineToPoint(context, r2*sin(nextAngle), r2*cos(nextAngle));
		CGContextAddLineToPoint(context, radius*sin(nextAngle), radius*cos(nextAngle));
		//CGContextAddArc(context, 0, 0, radius, arcAngle-dayAngle, arcAngle, 0);
		//CGContextAddLineToPoint(context, radius*sin(angle), radius*cos(angle));
		CGContextFillPath(context);
	    }
	    dy++;
	    yearDay++;
	}
    }
}

- (void)drawDialRadial:(bool)rotated {
    int i;
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // break the comma delimited text into an array of labels
    NSArray *labels = [text componentsSeparatedByString:@","];
    int n = [labels count];
    if (n<1) {
	return;
    }
    if (rotated) {
	CGContextRotateCTM(context, M_PI/2);
    }
	    
    [strokeColor set];		// text needs both stroke and fill
    NSString *label;
    for (i=0; i<n; i++) {
	int iLogical = reverseNumbers ? (i == n ? n : n - i) : i;
	label = [labels objectAtIndex:iLogical];
	// Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
        CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	CGRect r;
	if (rotated) {
	    r = CGRectMake(radius * ECDialRadiusFactor - s.height, -s.width/2, s.width, s.height);
	} else {
	    r = CGRectMake( -s.width/2, radius * ECDialRadiusFactor - s.height, s.width, s.height);
	}
	[self drawText:label inRect:r withContext:context withFont:font withColor:strokeColor];
	
	CGContextStrokePath(context);
	CGContextRotateCTM(context, -M_PI*2/n);
    }
}

- (void)drawDialDemiRadial {
    int i;
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // break the comma delimited text into an array of labels
    NSArray *labels = [text componentsSeparatedByString:@","];
    double n = [labels count];
    if (n<=1) {			// if text is empty there's still one label
	return;
    }
    
    [strokeColor set];		// text needs both stroke and fill
    // draw radial text:
    for (i=0; i<n; i++) {
	if (i > n/4 && i < 3*n/4) {
	    // done in following loop
	} else {
	    int iLogical = reverseNumbers ? (i == n ? n : n - i) : i;
	    NSString *label = [labels objectAtIndex:iLogical];
	    // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
            CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	    double r = radius * (tick==ECDialTickNone ? 1 : ECDialRadiusFactor);
	    CGRect rect = CGRectMake(-s.width/2, r - s.height, s.width, s.height);
	    [self drawText:label inRect:rect withContext:context withFont:font withColor:strokeColor];
	}
	CGContextStrokePath(context);
	CGContextRotateCTM(context, -M_PI*2/n);
    }
    // draw antiradial text:
    CGContextRotateCTM(context, M_PI);
    for (i=0; i<n; i++) {
	if (i > n/4 && i < 3*n/4) {
	    int iLogical = reverseNumbers ? (i == n ? n : n - i) : i;
	    NSString *label = [labels objectAtIndex:iLogical];
	    // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
            CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	    double r = radius * (tick==ECDialTickNone ? 1 : ECDialRadiusFactor) + demiTweak;
	    CGRect rect = CGRectMake(-s.width/2, -r, s.width, s.height);
	    [self drawText:label inRect:rect withContext:context withFont:font withColor:strokeColor];
	} else {
	    // done in previous loop
	}
	CGContextStrokePath(context);
	CGContextRotateCTM(context, -M_PI*2/n);
    }
}

- (void)drawDialUpright {
    CGContextRef context = UIGraphicsGetCurrentContext();
    assert (font || text == nil);
    [bgColor setFill];
    
    // break the comma delimited text into an array of labels
    NSArray *labels = [text componentsSeparatedByString:@","];
    int n = [labels count];
    if (n<1) {
	return;
    }
    
    [strokeColor set];		// text needs both stroke and fill
    NSString *label;
    int i;
    double radiusFactor = (radius < ECDialSmallRadiusCutoff ? ECDialRadiusFactor + ECDialSmallRadiusFactor * (ECDialSmallRadiusCutoff - radius) : ECDialRadiusFactor);
    for (i=0; i<n; i++) {
	// draw the number
	int iLogical = reverseNumbers ? (i == n ? n : n - i) : i;
	label = [labels objectAtIndex:iLogical];
        // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
        CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	double h = radius * radiusFactor - sqrt(s.width * s.width + s.height * s.height)/2;
	double th = -(((double)i)/n)*2*M_PI + M_PI/2;
	CGRect r = CGRectMake(h * cos(th)-s.width/2, h * sin(th)-s.height/2, s.width, s.height);
	[self drawText:label inRect:r withContext:context withFont:font withColor:strokeColor];
	CGContextStrokePath(context);	
    }
}

- (void)drawInViewBounds:(CGRect)bounds atZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, bounds.size.width/2, bounds.size.height/2);
    if (clipRadius > 0) {
	CGContextAddArc(context, 0, 0, clipRadius, 0, 2*M_PI, 0);
    }
    CGContextTranslateCTM(context, CGRectGetMidX(boundsOnScreen), CGRectGetMidY(boundsOnScreen));
    if (clipRadius < 0) {
	CGContextAddArc(context, 0, 0, -clipRadius, 0, 2*M_PI, 0);
    }
    [bgColor setFill];
    [strokeColor setStroke];
    if (orientation != ECDialOrientationYear) {
	CGContextClip (context);
	[self drawFilledCircle:radius radius2:radius2 centerRadius:((markMask & ECDiskMarksMaskCenter) ? markWidth : 0)];
	[self drawGuilloche:markMask radius:radius radius2:radius2 nMarks:nMarks angle0:angle0 angle1:angle1 angle2:angle2 mSize:mSize mWidth:markWidth strokeColor:strokeColor fillColor1:color1 fillColor2:color2];
    }
    
    switch (orientation) {
	case ECDialOrientationUpright:		[self drawDialUpright];		break;
	case ECDialOrientationRadial:		[self drawDialRadial:false];	break;
	case ECDialOrientationRotatedRadial:	[self drawDialRadial:true];	break;
	case ECDialOrientationDemiRadial:	[self drawDialDemiRadial];	break;
	case ECDialOrientationTachy:		[self drawDialTachy];		break;
        case ECDialOrientationYear:		[self drawDialYear:2];		break;
	default: assert(false);
    }
    
    [strokeColor setStroke];
    if (markMask & ECDiskMarksMaskOuter) {
	[self drawCircle:radius width:markWidth angle1:angle1 angle2:angle2];
    }
    if (markMask & ECDiskMarksMaskInner) {
	[self drawCircle:radius2 width:markWidth angle1:angle1 angle2:angle2];
    }
    [self clearHolesForBounds:bounds];
    CGContextRestoreGState(context);
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    [self drawInViewBounds:boundsInView atZoomFactor:zoomFactor];
}

- (void)print {
    [super print];
    printf("r=%3.0f, o=%d\t", radius, orientation);
}

- (void)dealloc {
    [font release];
    [text release];
    [strokeColor release];
    [bgColor release];
    [color1 release];
    [color2 release];
    [super dealloc];
}

@end  // ECQDialView




@implementation ECQWheelView

- (NSString *)className {
    return @"QWheelView";
}

- (ECQWheelView *)initWithOrientation:(ECWheelOrientation)anOrientation
	xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
			       radius:(double)aRadius
			      radius2:(double)aRadius2
			      tradius:(double)aTradius
			      radius3:(double)aRadius3
			      tradius3:(double)aTradius3
				 text:(NSString *)str
				 text3:(NSString *)str3
				 font:(UIFont*)aFont
				 font3:(UIFont*)aFont3
				 tick:(ECDialTickType)tic
			       nMarks:(double)nmks
				mSize:(double)siz
			       angle1:(double)a1
			       angle2:(double)a2
				marks:(ECDiskMarksMask)marks
			    markWidth:(double)width
                             dragType:(ECDragType)aDragType
                    dragAnimationType:(ECDragAnimationType)aDragAnimationType 
			    animSpeed:(double)animSp
			  strokeColor:(UIColor *)scolor
			      bgColor:(UIColor *)color {
    assert(aFont);
    assert(color);
    assert(str);
    assert(str.length > 0);
    double viewRadius = aRadius + 2 + markWidth;
    CGRect viewBounds = CGRectMake(-viewRadius, -viewRadius, viewRadius * 2, viewRadius * 2);
    CGRect screenBounds = CGRectMake(xCenterOffsetFromScreenCenter - viewRadius, yCenterOffsetFromScreenCenter - viewRadius,
				     viewRadius * 2, viewRadius * 2);
    if (self = [super initWithBoundsInView:viewBounds boundsOnScreen:screenBounds dragType:aDragType dragAnimationType:aDragAnimationType]) {
	radius = aRadius;
	radius2 = aRadius2;
	if (aTradius == 0) {
	    tradius = radius;
	} else {
	    tradius = aTradius;
	}
	radius3 = aRadius3;
	if (aTradius3 == 0) {
	    tradius3 = radius3;
	} else {
	    tradius3 = aTradius3;
	}
	orientation = anOrientation;
	animSpeed = animSp;
	markMask = marks;
	markWidth = width;
	font = [aFont retain];
	font3 = [aFont3 retain];
	tick = tic;
	text = [str retain];
	text3 = [str3 retain];
	strokeColor = [scolor retain];
	mSize = siz;
	nMarks = nmks;
	angle1 = a1;
	angle2 = a2;
    	bgColor = [color retain];
    }
    return self;
}

- (double)animSpeed {
    return animSpeed;
}

- (void)drawLabels:(CGContextRef)context text:(NSString *)txt radius:(double)rad tradius:(double)trad font:(UIFont *)fnt markMask:(ECDiskMarksMask)mask {
    // break the comma delimited text into an array of labels
    NSArray *labels = [txt componentsSeparatedByString:@","];
    int n = [labels count];
    if (n < 1) {
	return;
    }
    
    // compute the max bounding rect for all the strings
    double maxW = 0, maxH=0;
    for (NSString *lab in labels) {
	// Deprecated iOS 7:  CGSize labelSize = [lab sizeWithFont:fnt];
        CGSize labelSize = [lab sizeWithAttributes:@{NSFontAttributeName:fnt}];
	maxW = fmax(maxW, labelSize.width);
    	maxH = fmax(maxH, labelSize.height);
    }
    
    // draw the inner and outer marks
    if (mask & ECDiskMarksMaskOuter) {
	[self drawCircle:rad+1 width:markWidth angle1:angle1 angle2:angle2];
    }
    if (mask & ECDiskMarksMaskInner) {
	[self drawCircle:rad-maxH-1 width:markWidth angle1:angle1 angle2:angle2];
    }
    
    // draw the labels evenly around the dial
    // starting at angle1
    if (orientation != ECWheelOrientationStraight) {
	CGContextRotateCTM(context,  angle1);
    }
    int i=0;
    for (NSString *lab in labels) {
	// Deprecated iOS 7:  CGSize s = [lab sizeWithFont:fnt];
        CGSize s = [lab sizeWithAttributes:@{NSFontAttributeName:fnt}];
	CGRect r;
	switch (orientation) {
	    case ECWheelOrientationStraight:
		i=i;
		double h = trad - sqrt(s.width * s.width + s.height * s.height)/2;
		double th = (((double)i)/n)*(angle2-angle1) + M_PI/2 + angle1;
		r = CGRectMake(h * cos(th)-s.width/2,
			       h * sin(th)-s.height/2,
			       s.width, s.height);
		break;
	    case ECWheelOrientationSix:
		r = CGRectMake(-maxW/2, -trad, maxW, maxH);
		break;
	    case ECWheelOrientationThree:
		r = CGRectMake(trad-maxW, -s.height/2, maxW, maxH);
		break;
	    case ECWheelOrientationTwelve:
		r = CGRectMake(-maxW/2, trad-maxH, maxW, maxH);
		break;
	    case ECWheelOrientationNine:
		r = CGRectMake(-trad, -s.height/2, maxW, maxH);
		break;
	    default:
		assert(false);
	}
	[self drawText:lab inRect:r withContext:context withFont:fnt withColor:strokeColor];
	if (orientation != ECWheelOrientationStraight) {
	    CGContextRotateCTM(context, (angle2-angle1)/n);
	}
	++i;
    }
    if (orientation != ECWheelOrientationStraight) {
	CGContextRotateCTM(context,  2*M_PI-angle2);
    }    
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    assert(context);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, boundsOnScreen.size.width/2, boundsOnScreen.size.height/2);  // move origin to center of view

    [bgColor set];
    double arcAngle1 = angle1;
    if (angle1 != 0) {
	NSArray *labels = [text componentsSeparatedByString:@","];
	int n = [labels count];
	arcAngle1 = angle1 - (angle2 - angle1) / n;
    }
    [self drawFilledArcRing:radius+2 radius2:radius2 centerRadius:((markMask & ECDiskMarksMaskCenter) ? markWidth : 0) angle1:arcAngle1 angle2:angle2];
    
    [strokeColor set];
    // if this is a dynamic dial, draw the tick marks
    if (tick != ECDialTickNone) {
        [self drawTickMarks:radius type:tick];
    }

    // now the real main work
    [self drawLabels:context text:text radius:radius tradius:tradius font:font markMask:markMask];
    if (text3 != nil) {
	[self drawLabels:context text:text3 radius:radius3 tradius:tradius3 font:font3 markMask:0];
    }
    
    [self clearHoles];
    CGContextRestoreGState(context);
}

- (void)print {
    [super print];
    printf("r=%3.0f, o=%d\t", radius, orientation);
}

- (void)dealloc {
    [text release];
    [font release];
    [strokeColor release];
    [bgColor release];
    [super dealloc];
}

@end  // ECQWheelView

@implementation ECQCalendarRowCoverView

- (ECQCalendarRowCoverView *)initWithRowCoverType:(ECCalendarRowCoverType)aCoverType
                                        calendarX:(double)calendarX
                                             rowY:(double)rowY
                                             font:(UIFont *)aFont
					  bgColor:(UIColor *)bColor
                                        fontColor:(UIColor *)fColor {
    CGSize overallSize;  // size of entire month
    CGSize cellSize;     // size of single cell text only
    CGSize spacing;      // spacing between cells (h and v)
    ESCalculateCalendarWidth(aFont, &overallSize, &cellSize, &spacing);
    CGRect aBoundsInView;
    CGRect aBoundsOnScreen;
    if (aCoverType == ECCalendarCoverRow56Right) {  // Double height, incorporating previous week5[First] and week6Second
        aBoundsInView = CGRectMake(-overallSize.width/2, -cellSize.height/2 - spacing.height/2 - 2,
                                   overallSize.width, 2 * (cellSize.height + spacing.height) + 2);
        aBoundsOnScreen = CGRectMake(calendarX - overallSize.width/2, rowY - cellSize.height/2 - spacing.height / 2 - 2,
                                     overallSize.width, 2 * (cellSize.height + spacing.height) + 2);
    } else if (aCoverType == ECCalendarCoverRow6Left) {
        aBoundsInView = CGRectMake(-overallSize.width/2, -cellSize.height/2 - spacing.height/2 - 2,
                                   overallSize.width, cellSize.height + spacing.height + 2);
        aBoundsOnScreen = CGRectMake(calendarX - overallSize.width/2, rowY - cellSize.height/2 - spacing.height / 2 - 2,
                                     overallSize.width, cellSize.height + spacing.height + 2);
    } else {
        assert(aCoverType == ECCalendarCoverRow1Left || aCoverType == ECCalendarCoverRow1Right);
        int numCellsDrawn = aCoverType == ECCalendarCoverRow1Left ? 4 : 5;
        aBoundsInView = CGRectMake(-overallSize.width/2, -cellSize.height/2 - spacing.height/2 - 2,
                                   numCellsDrawn * (cellSize.width + spacing.width), cellSize.height + spacing.height + 2);
        aBoundsOnScreen = CGRectMake(calendarX - overallSize.width/2, rowY - cellSize.height/2 - spacing.height / 2 - 2,
                                     numCellsDrawn * (cellSize.width + spacing.width), cellSize.height + spacing.height + 2);
    }
    [super initWithBoundsInView:aBoundsInView
                 boundsOnScreen:aBoundsOnScreen
                       dragType:ECDragNormal
              dragAnimationType:ECDragAnimationAlways];
    font = [aFont retain];
    fontColor = [fColor retain];
    bgColor = [bColor retain];
    coverType = aCoverType;
    return self;
}

- (void)drawInViewBounds:(CGRect)bounds atZoomFactor:(double)zoomFactor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    UIColor *bgBorder = [UIColor colorWithRed:0.85 green:0.8 blue:0.8 alpha:1.0];
    [bgColor setFill];
    [bgBorder setStroke];

    CGSize overallSize;  // size of entire month
    CGSize cellSize;     // size of single cell text only
    CGSize spacing;      // spacing between cells (h and v)
    ESCalculateCalendarWidth(font, &overallSize, &cellSize, &spacing);

    CGFloat w = overallSize.width;
    CGFloat h = cellSize.height + spacing.height;

    CGContextTranslateCTM(context, w/2, h/2 + 2);  // move origin to center of view

    CGContextAddRect(context, boundsInView);
    CGContextFillPath(context);

    [fontColor setStroke];
    [fontColor setFill];

    bool isLeft = false;
    int last = 31;
    switch(coverType) {
      case ECCalendarCoverRow56Right:
        for (int row = 0; row < 2; row++) {
            for (int column = 0; column < 7; column++) {
                CGFloat centerX = -w/2 + column * (cellSize.width + spacing.width) + (cellSize.width / 2) + (spacing.width / 2);
                CGFloat centerY = -cellSize.height / 2 + row * (cellSize.height + spacing.height);
                int dayNumber = row == 1 ? column + 1 : column + 8;
                NSString *str = [NSString stringWithFormat:@"%d", dayNumber];
                [self drawText:str
                        inRect:CGRectMake(centerX - cellSize.width / 2,
                                          centerY,
                                          cellSize.width,
                                          cellSize.height)
                   withContext:context
                      withFont:font
                     withColor:fontColor];
            }
        }
        break;
      case ECCalendarCoverRow6Left:
        for (int column = 0; column < 7; column++) {
            CGFloat centerX = -w/2 + column * (cellSize.width + spacing.width) + (cellSize.width / 2) + (spacing.width / 2);
            CGFloat centerY = -cellSize.height / 2;
            int dayNumber = column + 1;
            NSString *str = [NSString stringWithFormat:@"%d", dayNumber];
            [self drawText:str
                    inRect:CGRectMake(centerX - cellSize.width / 2,
                                      centerY,
                                      cellSize.width,
                                      cellSize.height)
               withContext:context
                  withFont:font
                 withColor:fontColor];
        }
        break;
      case ECCalendarCoverRow1Left:
        isLeft = true;
        last = 26;
        // fallthru
      case ECCalendarCoverRow1Right:
        // 23-26, 27-31
        for (int column = 0; 1; column++) {
            CGFloat centerX = -w/2 + column * (cellSize.width + spacing.width) + (cellSize.width / 2) + (spacing.width / 2);
            CGFloat centerY = -cellSize.height / 2;
            int dayNumber = (isLeft ? 23 : 27) + column;
            NSString *str = [NSString stringWithFormat:@"%d", dayNumber];
            [self drawText:str
                    inRect:CGRectMake(centerX - cellSize.width / 2,
                                      centerY,
                                      cellSize.width,
                                      cellSize.height)
               withContext:context
                  withFont:font
                 withColor:fontColor];
            if (dayNumber == last) {
                break;
            }
        }
        break;
        // 27-31
        break;
      default:
        [[ECErrorReporter theErrorReporter]
                        reportError:[NSString stringWithFormat:@"Calendar row cover type %d unexpected in drawInViewBounds", coverType]];
        CGContextRestoreGState(context);
        return;
    }

    CGContextRestoreGState(context);
}

- (void)drawAtZoomFactor:(double)zoomFactor {
    assert(boundsInView.size.width == boundsOnScreen.size.width);  // no scaling allowed
    assert(boundsInView.size.height == boundsOnScreen.size.height);  // no scaling allowed
    [self drawInViewBounds:boundsInView atZoomFactor:zoomFactor];
}

-(void)dealloc {
    [font release];
    [fontColor release];
    [super dealloc];
}

@end  // ECQCalendarRowCoverView
