// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "Hermes.h"

@protocol DJLConversationSelectionViewControllerDelegate;

@interface DJLConversationSelectionViewController : NSViewController

@property (nonatomic, assign) id<DJLConversationSelectionViewControllerDelegate> delegate;
@property (nonatomic, retain) NSArray * conversations;
@property (nonatomic, assign) hermes::UnifiedAccount * unifiedAccount;
@property (nonatomic, assign) hermes::UnifiedMailStorageView * unifiedStorageView;
@property (nonatomic, copy) NSString * folderPath;

- (void) setup;
- (void) unsetup;

- (void) setSelectionCount:(int)count;

@end

@protocol DJLConversationSelectionViewControllerDelegate <NSObject>

- (void) DJLConversationSelectionViewControllerArchive:(DJLConversationSelectionViewController *)controller;
- (void) DJLConversationSelectionViewControllerTrash:(DJLConversationSelectionViewController *)controller;
- (void) DJLConversationSelectionViewControllerToggleRead:(DJLConversationSelectionViewController *)controller;
- (void) DJLConversationSelectionViewControllerToggleStar:(DJLConversationSelectionViewController *)controller;

@optional
- (void) DJLConversationSelectionViewControllerFocusConversationList:(DJLConversationSelectionViewController *)controller;

@end
