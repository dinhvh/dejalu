// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLCreateLinkWindowControllerDelegate;

@interface DJLCreateLinkWindowController : NSWindowController

@property (nonatomic, assign) id <DJLCreateLinkWindowControllerDelegate> delegate;

- (void) beginSheetWithWindow:(NSWindow *)window url:(NSURL *)url;

@end

@protocol DJLCreateLinkWindowControllerDelegate

- (void) DJLCreateLinkWindowController:(DJLCreateLinkWindowController *)controller createLink:(NSURL *)url;
- (void) DJLCreateLinkWindowControllerCancelled:(DJLCreateLinkWindowController *)controller;

@end
