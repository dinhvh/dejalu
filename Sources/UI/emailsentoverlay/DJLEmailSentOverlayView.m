// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLEmailSentOverlayView.h"

#import "NSImage+DJLColored.h"

@implementation DJLEmailSentOverlayView {
    NSImage * _image;
    NSImage * _failedImage;
}

@synthesize count = _count;
@synthesize failed = _failed;

- (NSString *) _text
{
    if (_failed) {
        return @"Email not sent";
    }

    if (_count == 1) {
        return @"Email Sent";
    }
    else {
        return [NSString stringWithFormat:@"%i Emails Sent", _count];
    }
}

- (void) drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0 alpha:0.75] setFill];
    NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:20 yRadius:20];
    [path fill];
    
    NSDictionary * attr = @{NSFontAttributeName: [NSFont systemFontOfSize:18], NSForegroundColorAttributeName: [NSColor whiteColor]};
    NSSize size = [[self _text] sizeWithAttributes:attr];
    
    NSPoint point = NSMakePoint(([self bounds].size.width - size.width) / 2, [self bounds].size.height - 40);
    [[self _text] drawAtPoint:point withAttributes:attr];

    NSImage * image = nil;
    CGFloat top = 0;
    if (_failed) {
        if (_failedImage == nil) {
            NSImage * originImage = [NSImage imageNamed:@"DejaLu_FailedOn_64"];
            NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
            _failedImage = img;
        }
        image = _failedImage;
        top = 30;
    }
    else {
        if (_image == nil) {
            NSImage * originImage = [NSImage imageNamed:@"DejaLu_MailSent_64"];
            NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
            _image = img;
        }
        image = _image;
        top = 30;
    }
    NSRect bounds = [self bounds];
    NSSize imageSize = [image size];
    NSRect rect = NSMakeRect((bounds.size.width - imageSize.width) / 2, top, imageSize.width, imageSize.height);
    rect = NSIntegralRect(rect);
    [image drawInRect:rect];
}

@end
