//
//  ECQView.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 5/21/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"
@class ECVisualController, ECWatchController;

extern void
ESCalculateCalendarWidth(UIFont *font,  // input
                         CGSize *overallSize, // output
                         CGSize *cellSize,    // output
                         CGSize *spacing);

@interface ECHoleHolder: NSObject {
    ECHoleType type;
    CGRect rect;
    double startAngle, endAngle;
    UIColor *strokeColor;
    double borderWidth;
}

@property (nonatomic, readonly) ECHoleType type;
@property (nonatomic, readonly) CGRect rect;
@property (nonatomic, readonly) UIColor *strokeColor;
@property (nonatomic, readonly) double borderWidth, startAngle, endAngle;

-(ECHoleHolder *)initWithType:(ECHoleType)typ x:(double)x y:(double)y w:(double)w h:(double)h startAngle:(double)sa endAngle:(double)ea borderWidth:(double)borderWidth strokeColor:(UIColor *)strokeColor;

@end


@interface ECQView : NSObject {
@protected
    CGRect             boundsInView;
    CGRect             boundsOnScreen;
    ECDragType         dragType;
    ECDragAnimationType dragAnimationType;
    bool               norotate;
@private
    NSMutableArray     *holes;		    // clear these regions after drawing our content
    ECVisualController *controller;
}

@property (nonatomic, readonly) CGRect boundsOnScreen;
@property (nonatomic) CGRect boundsInView;
@property (nonatomic, assign) ECVisualController *controller;
@property (nonatomic, readonly) bool norotate;
@property (nonatomic, readonly) ECDragType dragType;
@property (nonatomic, readonly) ECDragAnimationType dragAnimationType;

- (id)initWithBoundsInView:(CGRect)boundsInView boundsOnScreen:(CGRect)boundsOnScreen dragType:(ECDragType)dragType dragAnimationType:(ECDragAnimationType)dragAnimationType norotate:(bool)norotate;
- (id)initWithBoundsInView:(CGRect)boundsInView boundsOnScreen:(CGRect)boundsOnScreen dragType:(ECDragType)dragType dragAnimationType:(ECDragAnimationType)dragAnimationType;
- (void)drawAtZoomFactor:(double)zoomFactor;
- (void)clearHere:(ECHoleHolder *)win;
- (void)archiveImageToPath:(NSString *)path watchFaceWidthInXML:(int)watchFaceWidthInXML forDeviceWidth:(int)deviceWidth;
- (CGPoint)anchorPointOnScreen;
- (CGRect)convertFromScreenToView:(CGRect)screenCoords;
- (bool)phaseOnly;
- (ECDragType)dragType;
- (ECDragAnimationType)dragAnimationType;
- (bool)flipX;
- (bool)flipY;
- (bool)skipMakingPNG;
- (double)animSpeed;
- (ECAnimationDirection)animDir;

- (NSString *)className;

@end

@interface ECQStaticView : ECQView {
    NSMutableArray *pieces;
}

- (ECQView *)initForPieces:(int)nPieces;
- (void)addPiece:(ECQView *)aPiece;
- (void)finishInit;

@end

@interface ECImageView : ECQView {
@protected
    UIImage *image;
    UIImage *image2x;
    UIImage *image4x;
    double animSpeed;
    ECAnimationDirection animDir;
    double alpha;
    double radius2;	// clip away everything inside this
    UIColor *color;
    double panes;
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
			    animSpeed:(double)animSpeed
			      animDir:(ECAnimationDirection)aanimDir
			     dragType:(ECDragType)dragType
		    dragAnimationType:(ECDragAnimationType)dragAnimationType;
    

- (ECImageView *)initCenteredWithImage:(UIImage *)img
			       image2x:(UIImage *)img2x
			       image4x:(UIImage *)img4x
	 xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	 yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
			       radius2:(double)aradius2
			     animSpeed:(double)animSpeed
			       animDir:(ECAnimationDirection)animDir
			      dragType:(ECDragType)dragType
		     dragAnimationType:(ECDragAnimationType)dragAnimationType
				 alpha:(double)alpha
				xScale:(double)xScale
				yScale:(double)yScale
			      norotate:(bool)norotate;

- (ECImageView *)initCenteredBlankWidth:(double)wv
				 height:(double)hv
				  color:(UIColor*)color
	  xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	  yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
				  panes:(double)aradius2
			      animSpeed:(double)animSp
			       dragType:(ECDragType)dragType
		      dragAnimationType:(ECDragAnimationType)dragAnimationType
				  alpha:(double)aalpha
				 xScale:(double)xScale
				 yScale:(double)yScale;

@end


@interface ECTerminatorLeaf : ECQView {
    ECTerminatorQuadrant quadrant;
    int                  indexWithinQuadrant;
    int                  leavesPerQuadrant;
    double               radius;
    double               anchorEdgeRadius;
    UIColor              *leafFillColor;
    UIColor              *leafBorderColor;
    bool                 incremental;
    
}

- (ECTerminatorLeaf *)initWithQuadrant:(ECTerminatorQuadrant)quadrant
		   indexWithinQuadrant:(int)indexWithinQuadrant
		     leavesPerQuadrant:(int)numLeavesPerQuadrant
				radius:(double)aRadius
			   incremental:(bool)incremental
		      anchorEdgeRadius:(double)anchorEdgeRadius
			 leafFillColor:(UIColor *)aLeafFillColor
		       leafBorderColor:(UIColor *)aLeafBorderColor
		      terminatorCenter:(CGPoint)terminatorCenter;

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
			   leafFillColor:(UIColor *)leafFillColor;
@end


@interface ECQTextView : ECQView {
@private
    UIFont *font;
    NSString *text;
    UIColor *color;
    ECDialOrientation orientation;
    double radius;
    double angle;
    double animSpeed;
}

- (ECQTextView *)initCenteredWithText:(NSString *)str
	xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
	yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
			   cropBottom:(double)cropBottom
			      cropTop:(double)cropTop
			       radius:(double)aRadius
				angle:(double)anAngle
                            animSpeed:(double)anAnimSpeed
			  orientation:(ECDialOrientation)orient
				 font:(UIFont*)aFont
				color:(UIColor *)acolor;

@end


@interface ECQHandView : ECQView {
@private
    ECQHandType handType;
    double width, length, length2;
    double oWidth, oLength, oLineWidth, oTail, oRadius, oRadiusX, oCenter, nRays, tLineWidth;
    UIColor *fcolor, *scolor;
    UIColor *ofcolor, *oscolor;
    UIColor *tfcolor, *tscolor;
    double animSpeed;
    ECAnimationDirection animDir;
    double lineWidth, tail;
    NSString *text;
    UIFont *font;
    UIImage *blender, *blender2x, *blender4x;
    ECCalendarWheelType calendarWheelType;
    int calendarStartDay;
    bool circularArrow;
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
		       animSpeed:(double)animSpeed
			 animDir:(ECAnimationDirection)animDir
			dragType:(ECDragType)dragType
	       dragAnimationType:(ECDragAnimationType)dragAnimationType
			 oRadius:(double)aoRadius
			oRadiusX:(double)aoRadius
		       lineWidth:(double)aLineWidth
		      oLineWidth:(double)aoLineWidth
			  scolor:(UIColor*)asColor
			  fcolor:(UIColor*)afColor
			 oscolor:(UIColor*)asColor
			 ofcolor:(UIColor*)afColor
		      tLineWidth:(double)atLineWidth
			 tscolor:(UIColor*)atsColor
			 tfcolor:(UIColor*)atfColor
			 blender:(UIImage*)aBlender
		       blender2x:(UIImage*)aBlender2x
		       blender4x:(UIImage*)aBlender4x;
	    
@end


@interface ECQWedgeHandView : ECQView {
@private
    double innerRadius, outerRadius, halfSpan, width;
    UIColor *fcolor;
    UIColor *fcolor2;
    UIColor *scolor;
    ECWheelOrientation orientation;
    double borderWidth;
    double tickWidth;
    double animSpeed;
    double nTicks;
    NSString *theText;
    UIFont *font;
    bool halfAndHalf;
}

- (ECQWedgeHandView *)initWithOuterRadius:(double)outerRadius
            xAnchorOffsetFromScreenCenter:(double)xAnchorOffsetFromScreenCenter
	    yAnchorOffsetFromScreenCenter:(double)yAnchorOffsetFromScreenCenter
			      innerRadius:(double)innerRadius
				angleSpan:(double)angleSpan
				animSpeed:(double)animSpeed
				 dragType:(ECDragType)dragType
			dragAnimationType:(ECDragAnimationType)dragAnimationType
				   scolor:(UIColor*)asColor
				   fcolor:(UIColor*)afColor
				   fcolor2:(UIColor*)afColor2
				     font:(UIFont*)aFont
				     text:(NSString*)theText
			      orientation:(ECWheelOrientation)anOrientation
				    ticks:(double)ticks
				tickWidth:(double)aTickWidth
			      borderWidth:(double)aBorderWidth
			      halfAndHalf:(bool)isHalfAndHalf;
@end


@interface ECQDialView : ECQView {
@private
    double radius, radius2, clipRadius, mSize, nMarks, angle0, angle1, angle2, markWidth, demiTweak;
    ECDialOrientation orientation;
    bool reverseNumbers;
    NSString *text;
    UIFont *font;
    ECDialTickType tick;
    UIColor *color1, *color2;
    UIColor *bgColor;
    UIColor *strokeColor;
    ECDiskMarksMask markMask;
}

- (ECQDialView *)initWithOrientation:(ECDialOrientation)anOrientation
    xCenterOffsetFromScreenCenter:(double)xCenterOffsetFromScreenCenter
    yCenterOffsetFromScreenCenter:(double)yCenterOffsetFromScreenCenter
		      reverseNumbers:(bool)aReverseNumbers
			      radius:(double)aRadius
			     radius2:(double)aRadius2
			  clipRadius:(double)cRadius
			   demiTweak:(double)cdt
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
			     bgColor:(UIColor*)abgColor;

@end


@interface ECQWheelView : ECQView {
@private
    double radius, radius2, tradius, radius3, tradius3;
    ECWheelOrientation orientation;
    NSString *text, *text3;
    ECDialTickType tick;
    UIFont *font, *font3;
    UIColor *strokeColor;
    UIColor *bgColor;
    double mSize, nMarks, angle1, angle2, markWidth;
    double animSpeed;
    ECDiskMarksMask markMask;
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
			     dragType:(ECDragType)dragType
		    dragAnimationType:(ECDragAnimationType)dragAnimationType
			    animSpeed:(double)animSpeed
			  strokeColor:(UIColor *)scolor
			      bgColor:(UIColor *)color;

@end


@interface ECQCalendarRowCoverView : ECQView {
@private
    UIFont                 *font;
    UIColor                *fontColor;
    UIColor                *bgColor;
    double                 animSpeed;
    ECCalendarRowCoverType coverType;
}

- (ECQCalendarRowCoverView *)initWithRowCoverType:(ECCalendarRowCoverType)coverType
                                        calendarX:(double)calendarX
                                             rowY:(double)rowY
                                             font:(UIFont *)font
					  bgColor:(UIColor *)bgColor
                                        fontColor:(UIColor *)fColor;

@end
