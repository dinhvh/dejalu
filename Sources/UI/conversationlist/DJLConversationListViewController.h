// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#import <MailCore/MailCore.h>

#import "Hermes.h"
#import "DJLUIConstants.h"

@interface DJLUnifiedConversationID : NSObject

@property (nonatomic, assign) int64_t convID;
@property (nonatomic, assign) unsigned int accountIndex;

@end

@protocol DJLConversationListViewControllerDelegate;

@interface DJLConversationListViewController : NSViewController

@property (nonatomic, assign) hermes::UnifiedAccount * unifiedAccount;
@property (nonatomic, copy) NSString * folderPath;
@property (nonatomic, retain) NSArray * /* DJLUnifiedConversationID */ selectedConversationsIDs;
@property (nonatomic, assign) id<DJLConversationListViewControllerDelegate> delegate;
@property (nonatomic, assign) CGFloat vibrancy;

@property (nonatomic, assign, getter=isRefreshing) BOOL refreshing;

- (void) accountStateUpdated;
- (IBAction) search:(id)sender;
- (IBAction) showLabelsPanel:(id)sender;
- (IBAction) showLabelsAndArchivePanel:(id)sender;
- (void) toggleSearch;

//- (void) archiveSelection;
//- (void) trashSelection;
//- (void) toggleReadSelection;
//- (void) toggleStarSelection;

- (void) updateFirstResponderState;

//- (void) replyMessage;
//- (void) forwardMessage;

//- (void) archiveMessage;
//- (void) deleteMessage;

- (IBAction) toggleRead:(id)sender;
- (IBAction) toggleStar:(id)sender;
- (IBAction) deleteMessage:(id)sender;
- (IBAction) archiveMessage:(id)sender;
- (IBAction) markAsSpam:(id)sender;
- (void) replyMessage:(id)sender;
- (void) forwardMessage:(id)sender;

- (void) refresh;

- (NSArray *) selectedConversationsInfos;
- (hermes::MailStorageView *) storageViewForSingleSelection;
- (hermes::Account *) accountForSingleSelection;
- (hermes::Account *) uniqueAccountForSelection;

- (void) makeFirstResponder;

- (void) refreshAndScrollToTop;

- (hermes::UnifiedMailStorageView *) currentUnifiedStorageView;

@end

@protocol DJLConversationListViewControllerDelegate <NSObject>

- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller
                                   account:(hermes::Account *)account
                         replyMessageRowID:(int64_t)rowID
                                  folderID:(int64_t)folderID
                                 replyType:(DJLReplyType)replyType;
- (void) DJLConversationListViewControllerOpenConversationWindow:(DJLConversationListViewController *)controller;
- (void) DJLConversationListViewControllerSelectionChanged:(DJLConversationListViewController *)controller;
- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller separatorAlphaValue:(CGFloat)alphaValue;
- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller setRefreshFeedbackVisible:(BOOL)visible;
- (void) DJLConversationListViewControllerConfirmRefresh:(DJLConversationListViewController *)controller;
- (void) DJLConversationListViewControllerNotifyRefreshError:(DJLConversationListViewController *)controller
                                                     account:(hermes::Account *)account;
- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller
                                   account:(hermes::Account *)account
                     editDraftConversation:(int64_t)conversationRowID folderID:(int64_t)folderID;
- (void) DJLConversationListViewControllerExpandDetails:(DJLConversationListViewController *)controller;
- (void) DJLConversationListViewControllerCollapseDetails:(DJLConversationListViewController *)controller;
- (void) DJLConversationListViewControllerCancelSearch:(DJLConversationListViewController *)controller;

@end
