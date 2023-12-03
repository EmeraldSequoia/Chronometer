//
//  ECGLView.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#define GLES_SILENCE_DEPRECATION
#import "ECGLView.h"

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "ChronometerAppDelegate.h"
#import "Constants.h"

#ifndef NDEBUG
# define  EC_CHECK_GL_ERROR { GLenum err = glGetError(); if (err != GL_NO_ERROR) { printf("OpenGL error %d\n", err); assert(false); } }
#else
# define  EC_CHECK_GL_ERROR { }
#endif


@interface ECGLView (EAGLViewPrivate)

- (bool)createFramebuffer;
- (void)destroyFramebuffer;

@end

@implementation ECGLView

// Required interface
+ (Class) layerClass {
    return [CAEAGLLayer class];
}

- (id) init {
    assert([NSThread isMainThread]);
    CGRect appBounds;
    appBounds.size = [ChronometerAppDelegate applicationWindowSizePoints];
    appBounds.origin.x = 0;
    appBounds.origin.y = 0;
    [super initWithFrame:appBounds];
    printf("glview frame size %.1f %.1f\n", appBounds.size.width, appBounds.size.height);
    if ([self respondsToSelector:@selector(contentScaleFactor)]) {
        printf("content scale factor was %.2f\n", self.contentScaleFactor);
	self.contentScaleFactor = [UIScreen mainScreen].nativeScale;
        printf("content scale factor is now %.2f\n", self.contentScaleFactor);
    }
    self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    self.contentMode = UIViewContentModeCenter;
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
						     [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
						     kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
						 nil];
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    if(!context || ![EAGLContext setCurrentContext:context]) {
	[self release];
	return nil;
    }

    [EAGLContext setCurrentContext:context];

    // Enable use of the texture
    glEnable(GL_TEXTURE_2D);
    // Set a blending function to use
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    // Enable blending
    glEnable(GL_BLEND);
    glEnable(GL_MULTISAMPLE);
    EC_CHECK_GL_ERROR;

    frameBufferCreateNeeded = true;
    return self;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)fixBogusViewBoundsIfNeeded {
    // CGRect viewBounds = self.bounds;
    // CGSize apSize = [ChronometerAppDelegate applicationSize];
    // if ((int)round(apSize.width) != (int)round(viewBounds.size.width) ||
    //     (int)round(apSize.height) != (int)round(viewBounds.size.height)) {
    //     printf("Bounds don't match! app %dx%d != view %dx%d\n",
    //            (int)round(apSize.width),
    //            (int)round(apSize.height),
    //            (int)round(viewBounds.size.width),
    //            (int)round(viewBounds.size.height));
    //     [ChronometerAppDelegate printBounds];
    //     //assert(false);
    //     viewBounds.size = apSize;
    //     viewBounds.origin.x = 0;
    //     viewBounds.origin.y = 0;
    //     self.frame = viewBounds;
    // }

#if 0
    GLint bw;
    GLint bh;

    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &bw);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &bh);

    CGSize apsize = [ChronometerAppDelegate applicationSize];
    CGFloat scale = [[UIScreen mainScreen] scale];
    int apw = (int)round(apsize.width * scale);
    int aph = (int)round(apsize.height * scale);
    int vbw = (int)round(self.bounds.size.width);
    int vbh = (int)round(self.bounds.size.height);
    CALayer *layer = self.layer;
    printf("startDraw 4: view bounds %.1f x %.1f\n", self.bounds.size.width, self.bounds.size.height);
    printf("startDraw bw %d bh %d,  appsiz %.1f %.1f apw %d aph %d vbw %d vbh %d, layer %.1f %.1f\n",
           bw, bh, apsize.width, apsize.height, apw, aph, vbw, vbh, layer.bounds.size.width, layer.bounds.size.height);
    assert(apw == bw);
    assert(aph == bh);
#endif
}

- (void)recreateFrameBuffer {
    // printf("gl view recreateFrameBuffer\n");
    assert(context);
    [EAGLContext setCurrentContext:context];
    [self fixBogusViewBoundsIfNeeded];
    if (frameBufferCreated) {
        [self destroyFramebuffer];
    }
    [self createFramebuffer];
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
	NSLog(@"failed to make reconstruct framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
    }
    // printf("recreate done\n");
    frameBufferCreateNeeded = false;
}

- (bool) startDraw {
    assert([NSThread isMainThread]);
    [EAGLContext setCurrentContext:context];
    if (frameBufferCreateNeeded) {
        [self recreateFrameBuffer];
    }
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
	NSLog(@"failed to make reconstruct framebuffer object %x, will retry...", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        // Try again shortly
        frameBufferCreateNeeded = true;
        return false;
    }
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    EC_CHECK_GL_ERROR;

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    EC_CHECK_GL_ERROR;

    return true;
}

- (void) finishDraw {
    assert([NSThread isMainThread]);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    EC_CHECK_GL_ERROR;
    [CATransaction flush];  // Required (apparently) to avoid startup hang
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
    EC_CHECK_GL_ERROR;
}

- (void) dealloc {
    if([EAGLContext currentContext] == context) {
	[EAGLContext setCurrentContext:nil];
    }
    [context release];
    [self destroyFramebuffer];
    [super dealloc];
}

- (bool)createFramebuffer
{
    glGenFramebuffersOES(1, &viewFramebuffer);
    glGenRenderbuffersOES(1, &viewRenderbuffer);
	
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    // CALayer *layer = self.layer;
    // printf("Creating render buffer storage from layer with bounds %.1f, %.1f\n", layer.bounds.size.width, layer.bounds.size.height);
    BOOL st = [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
    if (!st) {
        GLenum err = glGetError();
        NSLog(@"renderBufferStorage:fromDrawable: returned NO.  GL status is %d (0x%x)\n", err, err);
    }
    EC_CHECK_GL_ERROR;

    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    EC_CHECK_GL_ERROR;
    
//    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
//    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    EC_CHECK_GL_ERROR;
    
    frameBufferCreated = true;

    //printf("Created framebuffer with width %d and height %d\n", backingWidth, backingHeight);

//    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
//	NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
//	return false;
//    }
	
//    assert(backingWidth > 0 && backingHeight > 0);
//    printf("backingWidth %d, backingHeight %d\n", backingWidth, backingHeight);

    return true;
}

- (void)destroyFramebuffer
{
    BOOL st = [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:nil];
    if (!st) {
        printf("attempting to detach the render buffer from the drawable failed\n");
        EC_CHECK_GL_ERROR;
    }

    glDeleteFramebuffersOES(1, &viewFramebuffer);
    EC_CHECK_GL_ERROR;
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    EC_CHECK_GL_ERROR;
    viewRenderbuffer = 0;
    
    if(depthRenderbuffer) {
	glDeleteRenderbuffersOES(1, &depthRenderbuffer);
	depthRenderbuffer = 0;
    }
}

- (void)orientationChange {
    // printf("gl view orientationChange\n");
    frameBufferCreateNeeded = true;
}

@end
