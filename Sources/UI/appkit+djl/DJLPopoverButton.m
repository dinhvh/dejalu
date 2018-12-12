// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPopoverButton.h"

#import "DJLDarkMode.h"

#define FONT_SIZE 12
#define ACCOUNT_FONT_SIZE 8
#define ACCOUNT_SPACE 0

@interface DJLPopoverButtonCell : NSButtonCell

@property (nonatomic, assign) BOOL forceWhiteBackground;

@end

@implementation DJLPopoverButtonCell {
    BOOL _forceWhiteBackground;
}

@synthesize forceWhiteBackground = _forceWhiteBackground;

- (BOOL) acceptsFirstResponder
{
    return NO;
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSView * view = [self controlView];
    NSRect rect = [view convertRect:[view bounds] toView:nil];
    rect = [[view window] convertRectToScreen:rect];
    BOOL mouseOver = NSPointInRect([NSEvent mouseLocation], rect);

    if (!mouseOver) {
        return;
    }

    NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:frame xRadius:5 yRadius:5];
    if ([DJLDarkMode isDarkModeForView:[self controlView]] && !_forceWhiteBackground) {
        if ([self isHighlighted]) {
            [[NSColor colorWithWhite:0.3 alpha:1.0] setFill];
        }
        else {
            [[NSColor colorWithWhite:0.15 alpha:1.0] setFill];
        }
    } else {
        if ([self isHighlighted]) {
            [[NSColor colorWithWhite:0.7 alpha:1.0] setFill];
        }
        else {
            [[NSColor colorWithWhite:0.85 alpha:1.0] setFill];
        }
    }
    [path fill];
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSView * view = [self controlView];
    NSRect rect = [view convertRect:[view bounds] toView:nil];
    rect = [[view window] convertRectToScreen:rect];
    BOOL mouseOver = NSPointInRect([NSEvent mouseLocation], rect);

    NSRect originRect = NSZeroRect;
    originRect.size = NSMakeSize(12, 12);
    rect = frame;
    rect.origin.y = (frame.size.height - 12) / 2 + 1;
    rect.size = NSMakeSize(12, 12);
    rect = NSIntegralRect(rect);
    if (mouseOver) {
        [[self image] drawInRect:rect fromRect:originRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
    }
    else {
        [[self image] drawInRect:rect fromRect:originRect operation:NSCompositeSourceOver fraction:0.75 respectFlipped:YES hints:nil];
    }
}

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
    [style setLineBreakMode:NSLineBreakByTruncatingTail];
    NSSize size = [title size];

    NSColor * color;
    if ([DJLDarkMode isDarkModeForView:[self controlView]] && !_forceWhiteBackground) {
        color = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    } else {
        color = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
    }

    NSString * alternateTitle = [self alternateTitle];
    if ([alternateTitle length] == 0) {
        if (size.width > frame.size.width) {
            size.width = frame.size.width;
        }
        NSRect titleFrame;
        titleFrame.origin = frame.origin;
        titleFrame.origin.y += (frame.size.height - size.height) / 2;
        titleFrame.size = size;
        titleFrame = NSIntegralRect(titleFrame);
        NSMutableAttributedString * attributedTitle = [[self attributedTitle] mutableCopy];
        [attributedTitle addAttributes:@{NSForegroundColorAttributeName: color,
                                         NSParagraphStyleAttributeName: style} range:NSMakeRange(0, [attributedTitle length])];
        [attributedTitle drawInRect:titleFrame];
        return NSZeroRect;
    }
    else {
        NSAttributedString * subtitle = [[NSAttributedString alloc] initWithString:[@" - " stringByAppendingString:alternateTitle]
                                                                        attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:FONT_SIZE],
                                                                                     NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.6 alpha:1.0],
                                                                                     NSParagraphStyleAttributeName: style}];
        NSMutableAttributedString * attributedTitle = [[self attributedTitle] mutableCopy];
        [attributedTitle addAttributes:@{NSForegroundColorAttributeName: color,
                                         NSParagraphStyleAttributeName: style} range:NSMakeRange(0, [attributedTitle length])];
        NSMutableAttributedString * complete = [[NSMutableAttributedString alloc] init];
        [complete appendAttributedString:attributedTitle];
        [complete appendAttributedString:subtitle];
        size = [complete size];
        if (size.width > frame.size.width) {
            size.width = frame.size.width;
        }
        NSRect titleFrame;
        titleFrame.origin = frame.origin;
        titleFrame.origin.y += (frame.size.height - size.height) / 2;
        titleFrame.size = size;
        titleFrame = NSIntegralRect(titleFrame);
        [complete drawInRect:titleFrame];
        return NSZeroRect;
    }
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [[NSColor clearColor] setFill];
    NSRectFill(cellFrame);

    [self drawBezelWithFrame:cellFrame inView:controlView];

    if ([self image] != nil) {
        NSRect rect = cellFrame;
        rect.origin = cellFrame.origin;
        rect.origin.x += 10;
        rect.origin.y -= 1;
        rect.size = cellFrame.size;
        rect.size.width -= 12 + 20;
        [self drawTitle:[self attributedTitle] withFrame:rect inView:controlView];

        rect = cellFrame;
        rect.origin = cellFrame.origin;
        rect.origin.x = cellFrame.size.width - 12 - 5;
        rect.size.width = 12;
        [self drawImage:[self image] withFrame:rect inView:controlView];
    }
    else {
        NSRect rect = cellFrame;
        rect.origin = cellFrame.origin;
        rect.origin.x += 10;
        rect.origin.y -= 1;
        rect.size = cellFrame.size;
        [self drawTitle:[self attributedTitle] withFrame:rect inView:controlView];
    }
}

- (NSSize) cellSize
{
    NSString * alternateTitle = [self alternateTitle];
    if ([self image] != nil) {
        if ([alternateTitle length] == 0) {
            NSSize size = [[self attributedTitle] size];
            size.width += 20 + 12;
            size.height += 6;
            return size;
        }
        else {
            NSAttributedString * subtitle = [[NSAttributedString alloc] initWithString:[@" - " stringByAppendingString:alternateTitle]
                                                                            attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:FONT_SIZE],
                                                                                         NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.6 alpha:1.0]}];
            NSMutableAttributedString * complete = [[NSMutableAttributedString alloc] init];
            [complete appendAttributedString:[self attributedTitle]];
            [complete appendAttributedString:subtitle];
            NSSize size = [complete size];
            size.width += 20 + 12;
            size.height += 6;
            return size;
        }
    }
    else {
        if ([alternateTitle length] == 0) {
            NSSize size = [[self attributedTitle] size];
            size.width += 20;
            size.height += 6;
            return size;
        }
        else {
            NSAttributedString * subtitle = [[NSAttributedString alloc] initWithString:[@" - " stringByAppendingString:alternateTitle]
                                                                            attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:FONT_SIZE],
                                                                                         NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.6 alpha:1.0]}];
            NSMutableAttributedString * complete = [[NSMutableAttributedString alloc] init];
            [complete appendAttributedString:[self attributedTitle]];
            [complete appendAttributedString:subtitle];
            NSSize size = [complete size];
            size.width += 20;
            size.height += 6;
            return size;
        }
    }
}

@end

@implementation DJLPopoverButton

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self setCell:[[DJLPopoverButtonCell alloc] init]];
    [self setFont:[NSFont systemFontOfSize:FONT_SIZE]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appStateDidChange) name:NSApplicationDidBecomeActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appStateDidChange) name:NSApplicationDidResignActiveNotification object:NSApp];
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

- (void) setForceWhiteBackground:(BOOL)forceWhiteBackground
{
    [[self cell] setForceWhiteBackground:forceWhiteBackground];
}

- (BOOL) forceWhiteBackground
{
    return [[self cell] forceWhiteBackground];
}

@end
