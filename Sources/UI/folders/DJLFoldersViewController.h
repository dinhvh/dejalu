// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <MailCore/MailCore.h>

#import "Hermes.h"

@protocol DJLFoldersViewControllerDelegate;

@interface DJLFoldersViewController : NSViewController

@property (nonatomic, assign) id<DJLFoldersViewControllerDelegate> delegate;
@property (nonatomic, assign) BOOL filterAttachment;

@property (nonatomic, assign, readonly) hermes::UnifiedAccount * selectedAccount;
@property (nonatomic, copy, readonly) NSString * selectedPath;

- (void) reloadData;
- (void) makeFirstResponder;
- (void) prepareSize;

@end

@protocol DJLFoldersViewControllerDelegate <NSObject>

- (void) DJLFoldersViewControllerPathSelected:(DJLFoldersViewController *)controller;
- (void) DJLFoldersViewController:(DJLFoldersViewController *)controller openManager:(hermes::Account *)account;
- (void) DJLFoldersViewController:(DJLFoldersViewController *)controller hasHeight:(CGFloat)height;

@end
