// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLColoredView.h"

@implementation DJLColoredView {
    NSColor * _bgColor;
}

@synthesize backgroundColor = _backgroundColor;

- (void) setBackgroundColor:(NSColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
    [self setNeedsDisplay:YES];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    _backgroundColor = [NSColor whiteColor];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    _backgroundColor = [NSColor whiteColor];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
    if (_backgroundColor != nil) {
        [_backgroundColor setFill];
        NSRectFill([self bounds]);
    }
}

- (BOOL) acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

@end
