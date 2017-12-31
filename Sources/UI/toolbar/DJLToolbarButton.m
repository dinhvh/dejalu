// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLToolbarButton.h"

@interface DJLToolbarButtonCell : NSButtonCell

@end

@implementation DJLToolbarButtonCell

- (BOOL) acceptsFirstResponder
{
    return NO;
}

- (void) drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView
{
    frame.size = [image size];
    NSRect sourceFrame = NSZeroRect;
    sourceFrame.size = frame.size;
    if ([self isEnabled]) {
        if ([self isHighlighted]) {
            [image drawInRect:frame fromRect:sourceFrame operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
        }
        else {
            [image drawInRect:frame fromRect:sourceFrame operation:NSCompositeSourceOver fraction:0.75 respectFlipped:YES hints:nil];
        }
    }
    else {
        [image drawInRect:frame fromRect:sourceFrame operation:NSCompositeSourceOver fraction:0.2 respectFlipped:YES hints:nil];
    }
}

@end


@implementation DJLToolbarButton

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self setCell:[[DJLToolbarButtonCell alloc] init]];
    [self setBordered:NO];
    [[self cell] setHighlightsBy:NSContentsCellMask];
    return self;
}

@end
