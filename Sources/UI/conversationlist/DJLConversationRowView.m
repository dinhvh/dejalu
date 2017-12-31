// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationRowView.h"

@implementation DJLConversationRowView {
    BOOL _lastSelectedRow;
}

@synthesize firstSelectedRow = _firstSelectedRow;
@synthesize lastSelectedRow = _lastSelectedRow;

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    return self;
}

- (void) setSelected:(BOOL)selected
{
    [super setSelected:selected];
    //[self setNeedsDisplay:YES];
}

- (void) setLastSelectedRow:(BOOL)lastSelectedRow
{
    _lastSelectedRow = lastSelectedRow;
    //[self setNeedsDisplay:YES];
}

- (void) setFirstSelectedRow:(BOOL)firstSelectedRow
{
    _firstSelectedRow = firstSelectedRow;
    //[self setNeedsDisplay:YES];
}

#if 0
- (void)drawBackgroundInRect:(NSRect)dirtyRect
{
#if 0
    if (![self isSelected]) {
        /*
        [[NSColor clearColor] setFill];
        NSRectFill(rect);
         */
        NSRect rect = [self bounds];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.6] setFill];
        NSRectFill(rect);
    }
    else {
        NSRect rect = [self bounds];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.6] setFill];
        NSRectFill(rect);
#if 0
        NSRect rect = [self bounds];
        [[NSColor clearColor] setFill];
        NSRectFill(rect);
#endif
    }
#endif
}

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
    /*
    NSRect rect = [self bounds];
    [[NSColor clearColor] setFill];
    NSRectFill(rect);
     */
    /*
    NSRect rect = [self bounds];
    //[[NSColor colorWithCalibratedRed:0.8863 green:0.9020 blue:0.95 alpha:1.0000] setFill];
    [[NSColor colorWithCalibratedWhite:0.95 alpha:1.0000] setFill];
    NSRectFill(rect);
    
    [[NSColor colorWithCalibratedRed:0.7863 green:0.8020 blue:0.85 alpha:1.0000] setFill];
    if (_firstSelectedRow) {
        rect = [self bounds];
        rect.size.height = 1;
        NSRectFill(rect);
    }
    if (_lastSelectedRow) {
        rect = [self bounds];
        rect.origin.y = rect.size.height - 1;
        rect.size.height = 1;
        NSRectFill(rect);
    }
     */
}
#endif

#if 0
- (void)drawSeparatorInRect:(NSRect)dirtyRect
{
    NSRect bounds = [self bounds];
    NSBezierPath * path = [[NSBezierPath alloc] init];
    [path moveToPoint:NSMakePoint(60, 0)];
    [path lineToPoint:NSMakePoint(bounds.size.width, 0)];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.15] setStroke];
    [path stroke];
}
#endif

@end
