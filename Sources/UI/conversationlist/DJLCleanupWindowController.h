// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLCleanupWindowControllerDelegate;

@interface DJLCleanupWindowController : NSWindowController

@property (nonatomic, retain) NSArray * conversations;

@property (nonatomic, retain, readonly) NSArray * selectedConversations;

@property (nonatomic, weak) id<DJLCleanupWindowControllerDelegate> delegate;

@end

@protocol DJLCleanupWindowControllerDelegate <NSObject>

- (void) DJLCleanupWindowControllerArchive:(DJLCleanupWindowController *)controller;
- (void) DJLCleanupWindowControllerDelete:(DJLCleanupWindowController *)controller;
- (void) DJLCleanupWindowControllerCancel:(DJLCleanupWindowController *)controller;

@end
