// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGradientView.h"

@implementation DJLGradientView {
    NSColor * _startColor;
    NSColor * _endColor;
    CGFloat _angle;
}

@synthesize startColor = _startColor;
@synthesize endColor = _endColor;
@synthesize angle = _angle;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    return self;
}

- (void) setStartColor:(NSColor *)startColor
{
    _startColor = startColor;
    [self setNeedsDisplay:YES];
}

- (void) setEndColor:(NSColor *)endColor
{
    _endColor = endColor;
    [self setNeedsDisplay:YES];
}

- (void) setAngle:(CGFloat)angle
{
    _angle = angle;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    //_startColor = [NSColor redColor];
    //_endColor = [NSColor redColor];
    NSGradient * gradient = [[NSGradient alloc] initWithStartingColor:_startColor endingColor:_endColor];
    [gradient drawInRect:[self bounds] angle:_angle];
}

@end
