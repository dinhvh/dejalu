// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLActivityCellView.h"

#include "HMActivityItem.h"

@implementation DJLActivityCellView {
    hermes::ActivityItem * _activityItem;
}

- (void) dealloc
{
    if (_activityItem != NULL) {
        _activityItem->release();
        _activityItem = NULL;
    }
}

- (void) setActivityItem:(hermes::ActivityItem *)activityItem
{
    if (_activityItem != NULL) {
        _activityItem->release();
        _activityItem = NULL;
    }
    _activityItem = activityItem;
    _activityItem->retain();
}

- (void)drawRect:(NSRect)dirtyRect {
    NSString * progressString = MCO_TO_OBJC(_activityItem->progressString());

    NSDictionary * attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:14],
                            NSForegroundColorAttributeName: [NSColor blackColor]};
    NSRect rect = [self bounds];
    rect.origin.y = 20;
    rect.size.height = 20;
    [progressString drawInRect:rect withAttributes:attr];
    
    progressString = [NSString stringWithFormat:@"%i", _activityItem->progressValue()];
    rect = [self bounds];
    rect.origin.y = 0;
    rect.size.height = 20;
    [progressString drawInRect:rect withAttributes:attr];
}

@end
