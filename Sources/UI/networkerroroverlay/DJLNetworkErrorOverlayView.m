// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLNetworkErrorOverlayView.h"

#import "NSImage+DJLColored.h"

@implementation DJLNetworkErrorOverlayView {
    NSImage * _image;
}

- (void) drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0 alpha:0.75] setFill];
    NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:20 yRadius:20];
    [path fill];

    NSRect bounds = [self bounds];
    if (_image == nil) {
        NSImage * originImage = [NSImage imageNamed:@"DejaLu_NetworkErrorOn_64"];
        NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
        _image = img;
    }
    NSSize imageSize = [_image size];
    NSRect rect = NSMakeRect((bounds.size.width - imageSize.width) / 2, (bounds.size.height - imageSize.height) / 2,
                             imageSize.width, imageSize.height);
    rect = NSIntegralRect(rect);
    [_image drawInRect:rect];
}

@end
