// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLAddAccountWindowControllerDelegate;

@interface DJLAddAccountWindowController : NSWindowController

@property (nonatomic, copy) NSString * hintEmail;
@property (nonatomic, copy) NSString * hintProviderIdentifier;
@property (nonatomic, retain) NSDictionary * accountProperties;
@property (nonatomic, weak) id<DJLAddAccountWindowControllerDelegate> delegate;

@end

@protocol DJLAddAccountWindowControllerDelegate

- (void) DJLAddAccountWindowControllerClosed:(DJLAddAccountWindowController *)controller;

@end
