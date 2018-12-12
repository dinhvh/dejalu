// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <AppKit/AppKit.h>

@interface DJLDarkMode : NSObject {
}

+ (BOOL) isDarkModeSupported;

+ (BOOL) isDarkModeForView:(NSView *)view;

@end
