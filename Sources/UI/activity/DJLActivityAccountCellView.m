// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLActivityAccountCellView.h"

@implementation DJLActivityAccountCellView

- (void)drawRect:(NSRect)dirtyRect {
    NSDictionary * attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:14],
                            NSForegroundColorAttributeName: [NSColor blackColor]};
    NSRect rect = [self bounds];
    rect.origin.x = 10;
    rect.size.width -= 10;
    rect.origin.y = 5;
    rect.size.height = 25;
    [[self email] drawInRect:rect withAttributes:attr];
}

@end
