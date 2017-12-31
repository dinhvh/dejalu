// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "NSImage+DJLColored.h"

@implementation NSImage (DJLColored)

- (NSImage *) djl_imageWithColor:(NSColor *)color
{
    NSImage * resultImage = [[NSImage alloc] initWithSize:[self size]];
    [resultImage lockFocus];
    NSRect rect = NSZeroRect;
    rect.size = [self size];
    [color setFill];
    NSRectFill(rect);
    [self drawInRect:rect fromRect:rect operation:NSCompositeDestinationIn fraction:1.0];
    [resultImage unlockFocus];
    return resultImage;
}

@end
