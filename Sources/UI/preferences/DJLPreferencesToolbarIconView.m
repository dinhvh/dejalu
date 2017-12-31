// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPreferencesToolbarIconView.h"

#import "NSImage+DJLColored.h"

#define FONT_SIZE 11

@interface DJLPreferencesToolbarIconCell : NSButtonCell

@end

@implementation DJLPreferencesToolbarIconCell

- (BOOL) acceptsFirstResponder
{
    return NO;
}

- (void) drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView
{
    [image drawInRect:frame];
}

- (void) drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    if ([self state] == NSOnState) {
        frame.size.height -= 6;
        NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:frame xRadius:5 yRadius:5];
        [[NSColor colorWithWhite:0.9 alpha:1.0] setFill];
        [path fill];
    }
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [[NSColor whiteColor] setFill];
    NSRectFill(cellFrame);

    [self drawBezelWithFrame:cellFrame inView:controlView];

    NSImage * image = nil;
    if ([self state] == NSOnState) {
        image = [self alternateImage];
    }
    else {
        image = [self image];
    }
    NSRect rect = cellFrame;
    rect.origin.x += (cellFrame.size.width - [image size].width) / 2;
    rect.origin.y += 3 + 2;
    rect.size.width = [image size].width;
    rect.size.height = [image size].height;
    rect = NSIntegralRect(rect);
    [self drawImage:image withFrame:rect inView:controlView];

    NSColor * color = nil;
    if ([self state] == NSOnState) {
        color = [NSColor colorWithCalibratedWhite:0 alpha:1.0];
    }
    else {
        color = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    }
    NSAttributedString * attributedTitle = [[NSAttributedString alloc] initWithString:[self title]
                                                                           attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:FONT_SIZE],
                                                                                        NSForegroundColorAttributeName: color}];

    rect = cellFrame;
    rect.origin.x += 10;
    rect.origin.y = 32 + 6 + 2;
    rect.size.height = 15;
    [self drawTitle:attributedTitle withFrame:rect inView:controlView];
}

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSetShouldSmoothFonts(ctx, true);

    [title drawInRect:frame];
    NSRect result = NSZeroRect;
    result.size = [title size];
    return result;
}

- (NSSize) cellSize
{
    NSAttributedString * attributedTitle = [[NSAttributedString alloc] initWithString:[self title]
                                                                    attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:FONT_SIZE],
                                                                                 NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.6 alpha:1.0]}];
    NSSize size = [attributedTitle size];
    size.width += 20;
    size.height = 65;
    NSSize imageSize = [[self image] size];
    if (imageSize.width > size.width) {
        size.width = imageSize.width;
    }
    return size;
}

@end

@interface DJLPopoverButton : NSButton
@end

@implementation DJLPreferencesToolbarIconView

- (id) initWithIcon:(NSImage *)icon title:(NSString *)title
{
    self = [super initWithFrame:NSZeroRect];

    [self setCell:[[DJLPreferencesToolbarIconCell alloc] init]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appStateDidChange) name:NSApplicationDidBecomeActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appStateDidChange) name:NSApplicationDidResignActiveNotification object:NSApp];

    NSImage * originImage = icon;
    originImage = [originImage copy];
    [originImage setSize:NSMakeSize(32, 32)];
    NSImage * image = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
    NSImage * selectedImage = [originImage djl_imageWithColor:[NSColor blackColor]];

    [self setBordered:NO];
    [self setImage:image];
    [self setAlternateImage:selectedImage];
    [self setTitle:title];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) _appStateDidChange
{
    [self setNeedsDisplay:YES];
}

@end
