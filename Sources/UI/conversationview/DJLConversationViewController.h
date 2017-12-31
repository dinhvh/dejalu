// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#include <MailCore/MailCore.h>
#include "Hermes.h"

#import "DJLUIConstants.h"

@protocol DJLConversationViewControllerDelegate;

@interface DJLConversationViewController : NSViewController

@property (nonatomic, assign) int64_t convID;
@property (nonatomic, assign) hermes::MailStorageView * storageView;
@property (nonatomic, assign) hermes::Account * account;
@property (nonatomic, weak) id<DJLConversationViewControllerDelegate> delegate;

- (void) setup;
- (void) unsetup;

- (void) loadConversation;

- (IBAction) replyMessage:(id)sender;
- (IBAction) forwardMessage:(id)sender;

- (BOOL) hasAttachmentSelection;

- (BOOL) isFirstResponder;

- (void) editDraft;

- (IBAction) findInText:(id)sender;
- (IBAction) findNext:(id)sender;
- (IBAction) findPrevious:(id)sender;

- (void) showLabelsPanel:(id)sender;
- (void) showLabelsAndArchivePanel:(id)sender;

- (IBAction) deleteMessage:(id)sender;
- (IBAction) archiveMessage:(id)sender;

- (IBAction) saveAllAttachments:(id)sender;

- (void) searchWithString:(NSString *)searchString;
- (void) cancelSearch;

- (void) printDocument:(id)sender;

@end


@protocol DJLConversationViewControllerDelegate <NSObject>

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                     replyMessageRowID:(int64_t)messageRowID
                              folderID:(int64_t)folderID
                             replyType:(DJLReplyType)replyType;
- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                   separatorAlphaValue:(CGFloat)alphaValue;
- (void) DJLConversationViewControllerArchive:(DJLConversationViewController *)controller;
- (void) DJLConversationViewControllerDelete:(DJLConversationViewController *)controller;
- (void) DJLConversationView:(DJLConversationViewController *)controller
                draftEnabled:(BOOL)draftEnabled;
- (void) DJLConversationView:(DJLConversationViewController *)controller
            editDraftMessage:(int64_t)messageRowID folderID:(int64_t)folderID;
- (void) DJLConversationViewSearch:(DJLConversationViewController *)controller;
- (void) DJLConversationViewShowLabelsPanel:(DJLConversationViewController *)controller
                                    archive:(BOOL)archive;
- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                    composeWithAddress:(MCOAddress *)address;
- (void) DJLConversationViewController:(DJLConversationViewController *)controller
             showSourceForMessageRowID:(int64_t)messageRowID
                              folderID:(int64_t)folderID;
- (void) DJLConversationViewDisableToolbar:(DJLConversationViewController *)controller;
- (void) DJLConversationViewValidateToolbar:(DJLConversationViewController *)controller;

@optional
- (void) DJLConversationViewControllerFocusConversationList:(DJLConversationViewController *)controller;
- (void) DJLConversationViewControllerClose:(DJLConversationViewController *)controller;
- (void) DJLConversationViewController:(DJLConversationViewController *)controller setFrom:(NSString *)from subject:(NSString *)subject;

@end
