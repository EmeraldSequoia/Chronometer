#ifndef NDEBUG
//
//  ECDebugView.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 3/7/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECMapGeneratorView.h"
#import "Constants.h"
#import "ECGlobals.h"
#import	"ChronometerAppDelegate.h"
#import "ECGLWatch.h"
#import "ECErrorReporter.h"
#import "ECWatchEnvironment.h"
#import "ECMapProjection.h"
#import "ECWatchTime.h"
#import "TSTime.h"



@implementation ECMapGeneratorView


- (ECMapGeneratorView *)initWithFrame:(CGRect)rect type:(int)typ forSlot:(int)slt inputFile:(NSString *)inpf outputFile:(NSString *)outf locDB:(ECGeoNames *)theLocDB {
    if (self = [super initWithFrame:rect]) {
        self.clearsContextBeforeDrawing = NO;
	self.opaque = NO;
	locDB = [theLocDB retain];
	inputFileName = [inpf retain];
    	outputFileName = [outf retain];
	slot = slt;
	opType = typ;
    }
    return self;
}

- (CGContextRef)setupFor:(NSString *)fileNam {
    CGContextRef context = UIGraphicsGetCurrentContext();
    assert(context);

/*  figure out the coordinate system
    [[UIColor redColor] set];
    CGContextAddArc(context, 160, 71, 50, 0, 2*M_PI, 0);
    CGContextDrawPath(context, kCGPathFillStroke);				    // origin is at upper left; y increases down, x increases left
    
    CGContextTranslateCTM(context, MAP_WIDTH_PIXELS/2, MAP_HEIGHT_PIXELS/2);	    // now origin is at the center, still goofy directions
 
    [[UIColor blueColor] set];		
    CGContextAddArc(context, 0, 0, 40, 0, 2*M_PI, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    
    [[UIColor yellowColor] set];
    CGContextFillRect(context, CGRectMake(50, 50, CITY_DOT_SIZE, CITY_DOT_SIZE));
    
    CGContextScaleCTM(context, 1, -1);						    // now y increases up; so (x,y) is customary directions
 
    [[UIColor greenColor] set];
    CGContextFillRect(context, CGRectMake(50, 50, CITY_DOT_SIZE, CITY_DOT_SIZE));
    

    CGContextScaleCTM(context, MAP_WIDTH_PIXELS/MAP_WIDTH_DEGREES, MAP_HEIGHT_PIXELS/MAP_HEIGHT_DEGREES);	// now (x,y) is scaled to maps's (longitude,latitude)
 
    [[UIColor whiteColor] set];
    CGContextFillRect(context, CGRectMake(-175, 75, CITY_DOT_SIZE, CITY_DOT_SIZE));
 */

    // load the base image
    NSString *srcImagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:fileNam];
    UIImage *anImage = [UIImage imageWithContentsOfFile:srcImagePath];
    assert(anImage);
    mapImageRef = anImage.CGImage;
    CGImageRetain(mapImageRef);
    mapWidthPixels =  CGImageGetWidth(mapImageRef);
    mapHeightPixels = CGImageGetHeight(mapImageRef);
    
    // flip the coordinate system upside down
    CGContextScaleCTM(context, 1, -1);									// now y increases up; so (x,y) is customary orientation
    
    // get screen sizes
    myWidth = self.frame.size.width;
    myHeight = self.frame.size.height;
    // draw the image in the center
    mapRect = CGRectMake((myWidth-mapWidthPixels)/2, -mapHeightPixels/2-myHeight/2, mapWidthPixels, mapHeightPixels);
    CGContextDrawImage(context, mapRect, mapImageRef);
    
    // transform to long/lat coordinates
    CGContextTranslateCTM(context, myWidth/2, -myHeight/2);			// now origin is at the center
    CGContextScaleCTM(context, mapWidthPixels/MAP_WIDTH_DEGREES, mapHeightPixels/MAP_HEIGHT_DEGREES);	// now (x,y) is scaled to maps's (longitude,latitude)
    
    return context;
}

- (void)drawSelectedCityDots:(CGContextRef)context {
    ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
    for (int i=watch.maxSeparateLoc+1; i<watch.numEnvironments; i++) {
	ECWatchEnvironment *env = [watch enviroWithIndex:i];
	double x, y;
	forwardRobinson(env.latitude, env.longitude, &x, &y);
	[[UIColor blueColor] set];
	CGContextAddArc(context, x, y, 1.5 * MAP_WIDTH_DEGREES / mapWidthPixels, 0, M_PI*2, 1);
	CGContextFillPath(context);
    }
}

- (void)drawAllCityDots:(CGContextRef)context {
    [locDB searchForCityNameFragment:@"" withProximity:false];
    int ub = [locDB numMatches];
    for (int i=0; i<ub; i++) {
	[locDB selectNthTopCity:i];
	ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([[locDB selectedCityTZName] UTF8String]);
	double off = ESCalendar_tzOffsetForTimeInterval(estz, [TSTime currentTime]);
	ESCalendar_releaseTimeZone(estz);
	if (fmod(off, 3600) != 0) {
	    [[UIColor redColor] set];
	} else if (fmod(off, 7200) == 0) {
	    [[UIColor blueColor] set];
	} else {
	    [[UIColor yellowColor] set];
	}
	double lat = [locDB selectedCityLatitude];
    	double lng = [locDB selectedCityLongitude];
	double x, y;
	forwardRobinson(lat, lng, &x, &y);
	CGContextAddArc(context, x, y, 0.5, 0, M_PI*2, 1);
	CGContextFillPath(context);
    }
}

- (void)drawCityDotsForZone:(int)zone context:(CGContextRef)context {
    [locDB searchForCityNameFragment:@"" appropriateForNominalTZSlot:zone];
    int ub = [locDB numMatches];
    //printf("%%2D = +02d: %d\n", zone, zone<13 ? zone : zone-24, ub);
    for (int i=0; i<ub; i++) {
	[locDB selectNthTopCity:i];
	assert([locDB selectedCityValidForSlotAtOffsetHour:zone]);
	switch ([locDB selectedCityInclusionClassForSlotAtOffsetHour:zone]) {
	    case normalHasDST:		    // 1    fills the slot exactly						    Los Angeles
	    case normalNoDSTRight:	    // 2    on the boundary between this slot and the next one west		    Phoenix
		[[UIColor blueColor] set];
		break;
	    case normalNoDSTLeft:	    // 2    on the boundary between this slot and the next one east		    Phoenix
		[[UIColor cyanColor] set];
		break;
	    case halfHasDSTLeft:	    // 2    evenly splits the boundary between this slot and the one to the east    Adelaide
	    case halfHasDSTRight:	    // 2    evenly splits the boundary between this slot and the one to the west    Adelaide
	    case halfNoDST:		    // 1    in the middle of a slot						    Mumbai
	    case oddNoDST:		    // 1    off center of slot							    Kathmandu
		[[UIColor redColor] set];
		break;
	    case oddHasDST:		    // 1    off center of a slot						    <none as of 2010>
	    case notIncluded:		    // 0    doesnt fit in this slot
	    default:
		assert(false);
		break;
	}
	double lat = [locDB selectedCityLatitude];
	double lng = [locDB selectedCityLongitude];
	double x, y;
	forwardRobinson(lat, lng, &x, &y);
	double sz = (ub < 100 ? 1 : ub < 1000 ? 1 : 0.5) * MAP_WIDTH_DEGREES / mapWidthPixels;
	CGContextAddArc(context, x, y, sz, 0, M_PI*2, 1);
	CGContextFillPath(context);
    }
}

- (void)writeOut:(CGContextRef)context {
    // dump context into a file
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    assert(cgImage);
//    CGRect invmapRect = CGRectMake(myWidth/2-mapWidthPixels/2, sHeight/2-mapHeightPixels/2-kToolbarHeight, mapWidthPixels, mapHeightPixels);
//    CGImageRef cgImageCropped = CGImageCreateWithImageInRect(cgImage, invmapRect);
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];	// uiImage is not owned;  don't release it
    assert(uiImage);
    NSData *imageData = UIImagePNGRepresentation(uiImage);
    assert(imageData);
    NSError *error;
    NSString *outputPath = [ECDocumentDirectory stringByAppendingString:outputFileName];
    if (![imageData writeToFile:outputPath options:NSAtomicWrite error:&error]) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Couldn't write PNG file to %@: %@", outputPath, [error localizedDescription]]];
    }
//    CGImageRelease(cgImage);
//    CGImageRelease(cgImageCropped);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupFor:inputFileName];
    switch (opType) {
	case 0:
	    [self drawAllCityDots:context];
	    break;
	case 1:
	    CGContextAddArc(context, 0, 0, 86  * MAP_WIDTH_DEGREES / mapWidthPixels, 0, M_PI*2, 0);
	    CGContextStrokePath(context);
	    [self drawSelectedCityDots:context];
	    break;
	case 2:
	    [self drawCityDotsForZone:slot context:context];
	    break;
	default:
	    assert(false);
	    break;
    }
#if TARGET_IPHONE_SIMULATOR
    if (outputFileName) {
	[self writeOut:context];
    }
#endif

    // should get here only once
    assert(locDB);
    [locDB release];
    locDB = nil;
}

- (void)dealloc {
    [super dealloc];
    CGImageRelease(mapImageRef);
    assert(!locDB);
    [inputFileName release];
    [outputFileName release];
}

@end

#endif
