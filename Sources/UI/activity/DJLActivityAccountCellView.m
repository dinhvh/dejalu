// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLActivityAccountCellView.h"

#import "DJLDarkMode.h"

@implementation DJLActivityAccountCellView

- (void)drawRect:(NSRect)dirtyRect {
    NSColor * color;
    if ([DJLDarkMode isDarkModeForView:self]) {
        color = [NSColor whiteColor];
    } else {
        color = [NSColor blackColor];
    }
    NSDictionary * attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:14],
                            NSForegroundColorAttributeName: color};
    NSRect rect = [self bounds];
    rect.origin.x = 10;
    rect.size.width -= 10;
    rect.origin.y = 5;
    rect.size.height = 25;
    [[self email] drawInRect:rect withAttributes:attr];
}

@end
