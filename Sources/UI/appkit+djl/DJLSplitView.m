// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLSplitView.h"

#import "FBKVOController.h"
#import "DJLDarkMode.h"

@implementation DJLSplitView

- (NSColor *) dividerColor
{
    if ([DJLDarkMode isDarkModeForView:self]) {
        return [NSColor blackColor];
    } else {
        return [NSColor colorWithCalibratedRed:0.7863 green:0.8020 blue:0.85 alpha:1.0000];
    }
}

@end
