// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGradientSeparatorLineView.h"

@implementation DJLGradientSeparatorLineView

- (void)drawRect:(NSRect)dirtyRect
{
    NSColor * leftColor = [NSColor clearColor];
    NSColor * middleColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.1];
    NSColor * rightColor = [NSColor clearColor];
    NSGradient * gradient = [[NSGradient alloc] initWithColorsAndLocations:leftColor, (CGFloat) 0.0, middleColor, (CGFloat) 0.2, middleColor, (CGFloat) 0.8, rightColor, (CGFloat) 1.0, nil];
    NSRect rect = [self bounds];
    rect.origin.x = 10;
    rect.size.width -= 20;
    [gradient drawInRect:rect angle:0];
}

@end
