// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrefsButtonCell.h"

#import "DJLDarkMode.h"
#import "NSImage+DJLColored.h"

@implementation DJLPrefsButtonCell

- (BOOL) acceptsFirstResponder
{
    return NO;
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSSize imageSize = [image size];
    frame = [controlView bounds];
    frame.origin.x = (frame.size.width - imageSize.width) / 2;
    frame.origin.y = (frame.size.height - imageSize.height) / 2;
    frame.size = imageSize;
    NSRect originRect = NSZeroRect;
    originRect.size = imageSize;
    frame = NSIntegralRect(frame);
    NSImage * img;
    if ([DJLDarkMode isDarkModeForView:[self controlView]]) {
        img = [image djl_imageWithColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
    } else {
        img = [image djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
    }
    [img drawInRect:frame fromRect:originRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
}

@end
