// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLWhiteView.h"

@implementation DJLWhiteView

#define HEIGHT 50
#define LINE_POSITION 34.5

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
    NSColor * backgroundColor = nil;
    NSColor * lineColor = nil;
    backgroundColor = [NSColor colorWithWhite:1.0 alpha:1.0];
    lineColor = [NSColor colorWithWhite:0.90 alpha:1.0];
    [backgroundColor setFill];
    NSBezierPath * path = [NSBezierPath bezierPath];
    NSRect rect = [self bounds];
    rect.origin.y = rect.size.height - HEIGHT;
    rect.size.height = HEIGHT;
    [path appendBezierPathWithRoundedRect:rect xRadius:5 yRadius:5];
    [path fill];
}

@end
