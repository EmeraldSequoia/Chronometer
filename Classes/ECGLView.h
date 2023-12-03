//
//  ECGLView.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "ECControllerView.h"

@interface ECGLView : ECControllerView {
@private
    EAGLContext *context;
	
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    GLuint viewRenderbuffer, viewFramebuffer;
	
    /* OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist) */
    GLuint depthRenderbuffer;

    /* The pixel dimensions of the backbuffer */
//    GLint backingWidth;
//    GLint backingHeight;

    bool frameBufferCreated;
    bool frameBufferCreateNeeded;
}

- (id) init;
- (bool) startDraw;
- (void) finishDraw;
- (void) dealloc;
- (void) orientationChange;

@end
