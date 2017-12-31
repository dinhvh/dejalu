// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLPreferencesViewController : NSViewController

- (NSImage *) icon;
- (NSString *) title;
- (CGFloat) height;

- (void) viewDidShow;
- (void) viewDidHide;

@end
