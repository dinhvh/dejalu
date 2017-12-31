// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLActivityFolderCellView.h"

@implementation DJLActivityFolderCellView

- (void)drawRect:(NSRect)dirtyRect {
    NSDictionary * attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:14],
                            NSForegroundColorAttributeName: [self syncing] ? [NSColor blackColor] : [NSColor colorWithCalibratedWhite:0.4 alpha:1.0]};
    NSRect rect = [self bounds];
    rect.origin.y = 35;
    rect.size.height = 20;
    [[self folderPath] drawInRect:[self bounds] withAttributes:attr];
    
    attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:12],
                            NSForegroundColorAttributeName: [self syncing] ? [NSColor blackColor] : [NSColor colorWithCalibratedWhite:0.4 alpha:1.0]};
    rect = [self bounds];
    rect.origin.y = 20;
    rect.size.height = 15;
    [[self syncState] drawInRect:rect withAttributes:attr];
    
    attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:12],
                            NSForegroundColorAttributeName: [self syncing] ? [NSColor blackColor] : [NSColor colorWithCalibratedWhite:0.4 alpha:1.0]};
    rect = [self bounds];
    rect.origin.y = 5;
    rect.size.height = 15;
    [[self urgentTask] drawInRect:rect withAttributes:attr];
}

@end
