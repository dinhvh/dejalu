// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <MailCore/MailCore.h>
#import <WebKit/WebKit.h>
#import "HMConstants.h"

#include "Hermes.h"

@protocol DJLComposerWindowControllerDelegate;

@interface DJLComposerWindowController : NSWindowController

@property (nonatomic, weak) id<DJLComposerWindowControllerDelegate> delegate;

@property (nonatomic, copy) NSString * emailAlias;
@property (nonatomic, retain, readonly) NSString * messageID;

- (void) setDefaultEmailAliasForAccount:(hermes::Account *)account;

- (void) replyMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(hermes::Account *)account;
- (void) forwardMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(hermes::Account *)account;

- (void) loadDraftMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(hermes::Account *)account;
- (void) loadDraftMessageForConversationRowID:(int64_t)conversationRowID folderID:(int64_t)folderID account:(hermes::Account *)account;

- (void) setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject body:(NSString *)body;
- (void) setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject htmlBody:(NSString *)htmlBody;
- (void) setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject archive:(WebArchive *)archive;

- (IBAction) createLink:(id)sender;
- (IBAction) editAllContent:(id)sender;

@end

@protocol DJLComposerWindowControllerDelegate <NSObject>

- (void) DJLComposerWindowControllerWillClose:(DJLComposerWindowController *)controller;
- (BOOL) DJLComposerWindowControllerShouldSave:(DJLComposerWindowController *)controller;
// after draft is loaded, show the composer window.
- (void) DJLComposerWindowControllerShow:(DJLComposerWindowController *)controller;
- (DJLComposerWindowController *) DJLComposerWindowController:(DJLComposerWindowController *)controller hasMessageID:(NSString *)messageID;

@end
