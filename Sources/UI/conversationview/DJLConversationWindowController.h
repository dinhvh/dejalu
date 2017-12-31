// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#include "Hermes.h"

#import "DJLUIConstants.h"

@protocol DJLConversationWindowControllerDelegate;

@interface DJLConversationWindowController : NSWindowController

@property (nonatomic, assign) int64_t convID;
@property (nonatomic, assign) hermes::MailStorageView * storageView;
@property (nonatomic, assign) hermes::Account * account;
@property (nonatomic, weak) id <DJLConversationWindowControllerDelegate> delegate;

- (void) setup;

- (void) loadConversation;

- (IBAction) findInText:(id)sender;
- (IBAction) findNext:(id)sender;
- (IBAction) findPrevious:(id)sender;
- (IBAction) showLabelsPanel:(id)sender;
- (IBAction) showLabelsAndArchivePanel:(id)sender;

- (IBAction) deleteMessage:(id)sender;
- (IBAction) archiveMessage:(id)sender;

- (IBAction) saveAllAttachments:(id)sender;

- (IBAction) printDocument:(id)sender;

@end

@protocol DJLConversationWindowControllerDelegate <NSObject>

- (void) DJLConversationWindowControllerClose:(DJLConversationWindowController *)controller;
- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
                       replyMessageRowID:(int64_t)messageRowID
                                folderID:(int64_t)folderID
                               replyType:(DJLReplyType)replyType;
- (void) DJLConversationWindowControllerArchive:(DJLConversationWindowController *)controller;
- (void) DJLConversationWindowControllerDelete:(DJLConversationWindowController *)controller;

- (BOOL) DJLConversationWindowControllerShouldSave:(DJLConversationWindowController *)controller;
- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
                        editDraftMessage:(int64_t)messageRowID
                                folderID:(int64_t)folderID;

- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
                      composeWithAddress:(MCOAddress *)address;
- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
               showSourceForMessageRowID:(int64_t)messageRowID
                                folderID:(int64_t)folderID;

@end
