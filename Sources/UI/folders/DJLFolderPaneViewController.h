// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#include "Hermes.h"

@protocol DJLFolderPaneViewControllerDelegate;

@interface DJLFolderPaneViewController : NSViewController

@property (nonatomic, assign) hermes::UnifiedAccount * unifiedAccount;
@property (nonatomic, copy) NSString * folderPath;
@property (nonatomic, assign) id<DJLFolderPaneViewControllerDelegate> delegate;

- (NSView *) view;

@end

@protocol DJLFolderPaneViewControllerDelegate

#ifdef __cplusplus
- (void) DJLFolderPaneViewController:(DJLFolderPaneViewController *)controller didSelectPath:(NSString *)path unifiedAccount:(hermes::UnifiedAccount *)account;
#endif

- (void) DJLFolderPaneViewControllerCollapseDetails:(DJLFolderPaneViewController *)controller;
- (void) DJLFolderPaneViewControllerFocusConversationList:(DJLFolderPaneViewController *)controller;
- (void) DJLFolderPaneViewControllerScrollToTop:(DJLFolderPaneViewController *)controller;

@end
