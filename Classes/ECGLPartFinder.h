//
//  ECGLPartFinder.h
//  Emerald Chronometer
//
//  Created by Steve Pucci in August 2008
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@class ECGLWatch, ECGLPartBase;

@interface ECGLPartFinder : NSObject {
}

- (ECGLPartBase *)findClosestActivePartInWatch:(ECGLWatch *)watch
                                         andBG:(ECGLWatch *)bgWatch
                                       toPoint:(CGPoint)point;

@end
