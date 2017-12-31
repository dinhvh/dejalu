// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLColoredProgressIndicator.h"

#import "AMIndeterminateProgressIndicatorCell.h"

static int s_coreAnimationInProgress = 0;

@implementation DJLColoredProgressIndicator

@synthesize usesThreadedAnimation = _usesThreadedAnimation;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    _cell = [[AMIndeterminateProgressIndicatorCell alloc] init];
    [_cell setAnimationDelay:2.5/60.0];
    
    return self;
}

- (void) dealloc
{
    [self stopAnimation:nil];
}

- (void) setColor:(NSColor *)color
{
    [_cell setColor:color];
}

- (NSColor *) color
{
    return [_cell color];
}

- (void) startAnimation:(id)sender
{
    if (_animating)
        return;
    
    _animating = YES;
    
    [_cell setSpinning:YES];
    
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:[_cell animationDelay]
                                              target:self
                                            selector:@selector(_animate:)
                                            userInfo:NULL
                                             repeats:YES];
}

- (void) stopAnimation:(id)sender
{
    if (!_animating)
        return;
    
    [_cell setSpinning:NO];
    [_timer invalidate];
    _timer = nil;
    
    _animating = NO;
}

- (void) _animate:(NSTimer *)timer
{
    double value = fmod(([_cell doubleValue] + (5.0/60.0)), 1.0);
    [_cell setDoubleValue:value];
    
    if (s_coreAnimationInProgress > 0) {
        return;
    }
    
    if ([self superview] == nil) {
        [self stopAnimation:nil];
    }
    
    [self setNeedsDisplay:YES];
}

- (void) drawRect:(NSRect)rect
{
    [_cell drawInteriorWithFrame:[self bounds] inView:self];
}

+ (void) coreAnimationStarted
{
    s_coreAnimationInProgress ++;
}

+ (void) coreAnimationEnded
{
    s_coreAnimationInProgress --;
}

+ (BOOL) isCoreAnimationInProgress
{
    return (s_coreAnimationInProgress > 0);
}

@end
