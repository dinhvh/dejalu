// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "Hermes.h"

@protocol DJLLabelsViewControllerDelegate;

@interface DJLLabelsViewController : NSViewController

@property (nonatomic, assign) id<DJLLabelsViewControllerDelegate> delegate;
@property (nonatomic, assign) hermes::Account * account;
@property (nonatomic, retain) NSArray * conversations;
@property (nonatomic, copy) NSString * folderPath;
@property (nonatomic, assign) hermes::MailStorageView * storageView;
@property (nonatomic, assign, getter=archiveEnabled) BOOL archiveEnabled;

- (void) reloadData;

@end

@protocol DJLLabelsViewControllerDelegate <NSObject>

- (void) DJLLabelsViewControllerClose:(DJLLabelsViewController *)controller;

@end
