// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <AppKit/AppKit.h>
#import "DJLWindow.h"

@interface DJLComposerWindow : DJLWindow

@end

@protocol DJLComposerWindowDelegate<NSWindowDelegate>

@optional
- (BOOL) DJLComposerWindowCommandEnterPressed:(DJLComposerWindow *)window;

@end
