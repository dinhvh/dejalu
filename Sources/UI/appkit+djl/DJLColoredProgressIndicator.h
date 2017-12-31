// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@class AMIndeterminateProgressIndicatorCell;

@interface DJLColoredProgressIndicator : NSView {
    AMIndeterminateProgressIndicatorCell * _cell;
    BOOL _animating;
    NSTimer * _timer;
    BOOL _usesThreadedAnimation;
    int _skippingAnimation;
}

@property (nonatomic, retain) NSColor * color;
@property (nonatomic, assign) BOOL usesThreadedAnimation;

- (void) startAnimation:(id)sender;
- (void) stopAnimation:(id)sender;

+ (void) coreAnimationStarted;
+ (void) coreAnimationEnded;
+ (BOOL) isCoreAnimationInProgress;

@end
