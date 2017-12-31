// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#define DJLWINDOW_FLAGS_CHANGED @"DJLWINDOW_FLAGS_CHANGED"

@interface DJLWindow : NSWindow

@property (nonatomic, assign, getter=isTrafficLightAlternatePositionEnabled) BOOL trafficLightAlternatePositionEnabled;

- (void) _layoutTrafficLightsAndContent;
- (void) _workaroundSheetLayoutTrafficLights;

@end

@protocol DJLWindowDelegate<NSWindowDelegate>

@optional
- (BOOL) DJLWindowSpaceKeyPressed:(DJLWindow *)window;
- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window;

@end
