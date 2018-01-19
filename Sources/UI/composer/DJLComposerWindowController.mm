// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLComposerWindowController.h"

#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>
#import <MailCore/MailCore.h>
#import <GoogleAnalyticsTracker/GoogleAnalyticsTracker.h>

#import "DJLComposerWindow.h"
#import "DJLComposerWebView.h"
#import "DJLColoredView.h"
#import "DJLEmailField.h"
#import "DJLContactsCompletionWindowController.h"
#import "DJLAttachmentsCollectionView.h"
#import "DJLPathManager.h"
#import "DJLAssert.h"
#import "MCOCIDURLProtocol.h"
#import "DJLTextField.h"
#import "DJLComposerToolbarView.h"
#import "DJLGradientSeparatorLineView.h"
#import "NSString+DJL.h"
#import "DJLLog.h"
#import "DJLCreateLinkWindowController.h"
#import "WebResource+DJL.h"
#import "DJLAddressBookManager.h"

#include "Hermes.h"

typedef enum {
    DJLComposerWindowControllerTypeNew,
    DJLComposerWindowControllerTypeReply,
    DJLComposerWindowControllerTypeForward,
    DJLComposerWindowControllerTypeIndeterminate,
} DJLComposerWindowControllerType;

using namespace mailcore;
using namespace hermes;

#define ATTACHMENTSVIEW_HEIGHT 85
#define ATTACHMENT_HEIGHT 85
#define ATTACHMENT_WIDTH 150

@interface DJLAttachmentQLPreviewItem : NSObject <QLPreviewItem>

- (id) initWithFilename:(NSString *)filename rect:(NSRect)rect view:(NSView *)view;

@property (retain) NSURL * previewItemURL;

- (NSString *) previewItemTitle;
- (NSRect) frame;

@end

@interface DJLComposerWindowController () <DJLComposerWindowDelegate, NSTokenFieldDelegate,
NSCollectionViewDelegate, DJLComposerToolbarViewDelegate,
QLPreviewPanelDelegate, QLPreviewPanelDataSource, WebUIDelegate, WebFrameLoadDelegate,
WebPolicyDelegate, DJLCreateLinkWindowControllerDelegate>

@property (nonatomic, assign) hermes::Account * account;

- (void) _operationFinished:(Operation *)operation;
- (void) _notifyFetchSummaryDone:(int64_t)messageRowID error:(hermes::ErrorCode)error;
- (void) _notifyMessageSavedWithFolderID:(int64_t)folderID messageID:(NSString *)messageID;

@end

class DJLComposerWindowControllerCallback : public Object, public OperationCallback, public AccountObserver {

public:
    DJLComposerWindowControllerCallback(DJLComposerWindowController * controller)
    {
        mController = controller;
    }

    virtual void operationFinished(Operation * op)
    {
        [mController _operationFinished:op];
    }

    virtual void accountFetchSummaryDone(Account * account, hermes::ErrorCode error, int64_t messageRowID)
    {
        [mController _notifyFetchSummaryDone:messageRowID error:error];
    }

    virtual void accountMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID)
    {
        [mController _notifyMessageSavedWithFolderID:folderID messageID:MCO_TO_OBJC(messageID)];
    }

private:
    __weak DJLComposerWindowController * mController;

};

@implementation DJLComposerWindowController {
    DJLEmailField * _toField;
    DJLEmailField * _ccField;
    DJLEmailField * _bccField;
    DJLContactsCompletionWindowController * _completionWindowController;
    DJLComposerWebView * _webView;
    DJLColoredView * _titleSeparator;
    DJLColoredView * _subjectSeparator;
    DJLColoredView * _bodySeparator;
    DJLColoredView * _ccSeparator;
    DJLColoredView * _bccSeparator;
    NSTextField * _subjectField;
    //NSButton * _sendButton;
    //NSButton * _attachmentButton;
    NSTextField * _toLabel;
    NSTextField * _ccLabel;
    NSTextField * _bccLabel;
    NSTextField * _subjectLabel;
    NSString * _temporaryFolder;
    DJLAttachmentsCollectionView * _attachmentsView;
    NSScrollView * _attachmentsScrollView;
    NSMutableArray * _attachments;
    DJLColoredView * _attachmentSeparator;
    BOOL _needsAttachmentDropZone;
    //MCOAddress * _from;
    NSString * _messageID;
    Account * _account;
    NSString * _emailAlias;
    //MessageQueueSender * _sendQueue;
    AbstractMessage * _repliedMessage;
    BOOL _modified;
    BOOL _modifiedOnce; // modified at least once.
    BOOL _saveScheduled; // scheduled save for later.
    BOOL _localSaving; // saving on storage in progress.
    BOOL _pendingSave; // when trying to save while saving.
    BOOL _sendAfterSave; // should send the email after saving.
    __weak id<DJLComposerWindowControllerDelegate> _delegate;
    MailDBMessageInfoOperation * _renderOp;
    DJLComposerWindowControllerCallback * _callback;
    int64_t _repliedMessageRowID;
    int64_t _repliedFolderID;
    BOOL _repliedMessageRendered;
    DJLComposerWindowControllerType _type;
    BOOL _replyShowRecipientEditor;
    MailDBMessageInfoOperation * _messageInfoOp;
    NSMutableDictionary * _cidFiles;
    Array * _loadMessagesOp;
    Array * _loadConversationMessagesOp;
    Array * _loadImagesOp;
    NSMutableDictionary * _parametersForOp;
    int64_t _draftMessageToLoadRowID;
    int64_t _draftMessageToLoadFolderID;
    int64_t _draftMessageToLoadConversationID;
    NSDictionary * _draftMessageInfo;
    DJLComposerToolbarView * _toolbarView;
    Array * _downloaders;
    NSString * _quotedHeadString;
    NSArray * _inReplyTo;
    NSArray * _references;
    NSMutableArray * _quickLookPreviewItems;
    NSDictionary * _replyMetaInfo;
    Array * _fowardedAttachmentsDownloaders;
    NSDictionary * _forwardedMessageInfo;
    NSString * _urlHandlerTo;
    NSString * _urlHandlerCc;
    NSString * _urlHandlerBcc;
    NSString * _urlHandlerSubject;
    NSString * _urlHandlerHTMLBody;
    NSURL * _urlHandlerBaseURL;
    BOOL _urlHandler;
    DJLCreateLinkWindowController * _createLinkController;
    NSMutableDictionary * _mimeTypes;
    BOOL _showCcEnabled;
    NSMutableArray * _selfArray;
}

//@synthesize from = _from;
@synthesize delegate = _delegate;
@synthesize messageID = _messageID;

- (id) init
{
    DJLComposerWindow * window = [[DJLComposerWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 300)
                                                                      styleMask:NSTitledWindowMask | NSResizableWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                                        backing:NSBackingStoreBuffered defer:YES];

    NSRect frame;
    [window setMinSize:NSMakeSize(350, 300)];
    [window setTitlebarAppearsTransparent:YES];
    [window center];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setReleasedWhenClosed:NO];

    frame = [window frame];
    frame.origin = CGPointZero;
    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:frame];
    //[window setTitleBarHeight:34];
    [window setContentView:contentView];
    [contentView setWantsLayer:YES];
    [window setTitle:@"Composer"];
    [window setTitleVisibility:NSWindowTitleHidden];

    self = [super initWithWindow:window];

    [window setDelegate:self];

    NSString * frameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DJLComposerWindowFrame"];
    if (frameString != nil) {
        NSRect frame;
        frame = NSRectFromString(frameString);
        if ((frame.size.height != 0) && (frame.size.width != 0)) {
            [window setFrame:frame display:NO];
        }
    }

    _completionWindowController = [[DJLContactsCompletionWindowController alloc] init];
    [_completionWindowController setDeltaYPosition:-6];

    _attachments = [[NSMutableArray alloc] init];
    _repliedMessageRowID = -1;
    _repliedFolderID = -1;
    _draftMessageToLoadRowID = -1;
    _draftMessageToLoadFolderID = -1;
    _draftMessageToLoadConversationID = -1;
    _showCcEnabled = NO;

    [self _setupMessageID];

    [self _setup];

    _cidFiles = [[NSMutableDictionary alloc] init];

    _loadMessagesOp = new Array();
    _loadConversationMessagesOp = new Array();
    _callback = new DJLComposerWindowControllerCallback(self);
    _parametersForOp = [[NSMutableDictionary alloc] init];
    _downloaders = new Array();
    _loadImagesOp = new Array();
    _fowardedAttachmentsDownloaders = new Array();
    _selfArray = [[NSMutableArray alloc] init];

    _mimeTypes = [[NSMutableDictionary alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_addressBookLoaded) name:DJLADDRESSBOOKMANAGER_LOADED object:nil];

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"Opened" label:@"Opened a composer" value:@(0)];

    return self;
}

- (void) dealloc
{
    [self _cancelAll];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    MC_SAFE_RELEASE(_repliedMessage);
    MC_SAFE_RELEASE(_messageInfoOp);
    MC_SAFE_RELEASE(_renderOp);
    if (_account != NULL) {
        _account->removeObserver(_callback);
    }
    MC_SAFE_RELEASE(_callback);
    MC_SAFE_RELEASE(_fowardedAttachmentsDownloaders);
    MC_SAFE_RELEASE(_loadImagesOp);
    MC_SAFE_RELEASE(_downloaders);
    MC_SAFE_RELEASE(_loadMessagesOp);
    MC_SAFE_RELEASE(_loadConversationMessagesOp);
    [_toField setDelegate:nil];
    [_ccField setDelegate:nil];
    [_bccField setDelegate:nil];
    MC_SAFE_RELEASE(_account);
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_completionWindowController cancelCompletion];
}

- (void) _setupMessageID
{
    _messageID = [self _generateMessageID];
}

- (NSString *) _generateMessageID
{
    NSString * build = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleVersionKey];
    NSString * mailbox = _emailAlias;
    NSArray * components = [mailbox componentsSeparatedByString:@"@"];
    NSString * uuidString = [[[NSUUID UUID] UUIDString] lowercaseString];
    NSString * leftPart = nil;
    if (build != nil) {
        leftPart = [NSString stringWithFormat:@"dejalu-%@-%@", build, uuidString];
    }
    else {
        leftPart = [NSString stringWithFormat:@"dejalu-nil-%@", uuidString];
    }
    if ([components count] > 0) {
        return [leftPart stringByAppendingFormat:@"@%@", [components lastObject]];
    }
    else {
        return [leftPart stringByAppendingString:@"@localhost"];
    }
}

- (void) _cancelAll
{
    if (_renderOp != NULL) {
        _renderOp->cancel();
    }
    if (_messageInfoOp != NULL) {
        _messageInfoOp->cancel();
    }
    {
        mc_foreacharray(IMAPAttachmentDownloader, downloader, _fowardedAttachmentsDownloaders) {
            downloader->cancel();
        }
    }
    {
        mc_foreacharray(MailDBRetrievePartOperation, op, _loadImagesOp) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(IMAPAttachmentDownloader, downloader, _downloaders) {
            downloader->cancel();
        }
    }
    {
        mc_foreacharray(MailDBMessageInfoOperation, op, _loadMessagesOp) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(MailDBConversationMessagesOperation, op, _loadConversationMessagesOp) {
            op->cancel();
        }
    }
}

- (void) _setup
{
    NSView * contentView = [[self window] contentView];

    _toField = [[DJLEmailField alloc] initWithFrame:NSZeroRect];
    [_toField setAllowsEditingTextAttributes:NO];
    [_toField setBordered:NO];
    [_toField setFocusRingType:NSFocusRingTypeNone];
    [_toField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];
    [_toField setMaxHeight:100];
    [_toField setDelegate:self];
    [_toField setFont:[NSFont systemFontOfSize:15]];
    [contentView addSubview:_toField];

    _toLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_toLabel setEditable:NO];
    [_toLabel setBordered:NO];
    [_toLabel setFont:[NSFont systemFontOfSize:15]];
    [_toLabel setStringValue:@"To:"];
    [_toLabel setTextColor:[NSColor colorWithWhite:0.75 alpha:1.0]];
    [contentView addSubview:_toLabel];

    _ccField = [[DJLEmailField alloc] initWithFrame:NSZeroRect];
    [_ccField setAllowsEditingTextAttributes:NO];
    [_ccField setBordered:NO];
    [_ccField setFocusRingType:NSFocusRingTypeNone];
    [_ccField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];
    [_ccField setMaxHeight:100];
    [_ccField setDelegate:self];
    [_ccField setFont:[NSFont systemFontOfSize:15]];
    [contentView addSubview:_ccField];

    _ccLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_ccLabel setEditable:NO];
    [_ccLabel setBordered:NO];
    [_ccLabel setFont:[NSFont systemFontOfSize:15]];
    [_ccLabel setStringValue:@"Cc:"];
    [_ccLabel setTextColor:[NSColor colorWithWhite:0.75 alpha:1.0]];
    [contentView addSubview:_ccLabel];

    _bccField = [[DJLEmailField alloc] initWithFrame:NSZeroRect];
    [_bccField setAllowsEditingTextAttributes:NO];
    [_bccField setBordered:NO];
    [_bccField setFocusRingType:NSFocusRingTypeNone];
    [_bccField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];
    [_bccField setMaxHeight:100];
    [_bccField setDelegate:self];
    [_bccField setFont:[NSFont systemFontOfSize:15]];
    [contentView addSubview:_bccField];

    _bccLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_bccLabel setEditable:NO];
    [_bccLabel setBordered:NO];
    [_bccLabel setFont:[NSFont systemFontOfSize:15]];
    [_bccLabel setStringValue:@"Bcc:"];
    [_bccLabel setTextColor:[NSColor colorWithWhite:0.75 alpha:1.0]];
    [contentView addSubview:_bccLabel];

    _subjectField = [[DJLTextField alloc] initWithFrame:NSZeroRect];
    [_subjectField setAllowsEditingTextAttributes:NO];
    [_subjectField setBordered:NO];
    [_subjectField setFocusRingType:NSFocusRingTypeNone];
    [_subjectField setDelegate:self];
    [_subjectField setFont:[NSFont systemFontOfSize:15]];
    [contentView addSubview:_subjectField];

    _subjectLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_subjectLabel setEditable:NO];
    [_subjectLabel setBordered:NO];
    [_subjectLabel setFont:[NSFont systemFontOfSize:15]];
    [_subjectLabel setStringValue:@"Subject:"];
    [_subjectLabel setTextColor:[NSColor colorWithWhite:0.75 alpha:1.0]];
    [contentView addSubview:_subjectLabel];

    _webView = [[DJLComposerWebView alloc] initWithFrame:NSZeroRect];
    [_webView setPolicyDelegate:self];
    [_webView setEditingDelegate:(id<WebEditingDelegate>)self];
    [_webView setUIDelegate:self];
    [_webView setFrameLoadDelegate:self];
    [_webView setContinuousSpellCheckingEnabled:YES];
    [[_webView windowScriptObject] setValue:self forKey:@"Controller"];
    NSString * filename = [[NSBundle mainBundle] pathForResource:@"composer-view" ofType:@"html"];
    NSString * htmlString = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    [[_webView mainFrame] loadHTMLString:htmlString baseURL:[[NSBundle mainBundle] resourceURL]];
    NSScrollView * mainScrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    [mainScrollView setVerticalScrollElasticity:NSScrollElasticityAllowed];
    [contentView addSubview:_webView];

    _titleSeparator = [[DJLColoredView alloc] initWithFrame:NSZeroRect];
    _subjectSeparator = [[DJLColoredView alloc] initWithFrame:NSZeroRect];
    [_subjectSeparator setBackgroundColor:[NSColor colorWithWhite:0.9 alpha:1.0]];
    [contentView addSubview:_subjectSeparator];
    _bodySeparator = [[DJLColoredView alloc] initWithFrame:NSZeroRect];
    [_bodySeparator setBackgroundColor:[NSColor colorWithWhite:0.9 alpha:1.0]];
    [contentView addSubview:_bodySeparator];
    _ccSeparator = [[DJLColoredView alloc] initWithFrame:NSZeroRect];
    [_ccSeparator setBackgroundColor:[NSColor colorWithWhite:0.9 alpha:1.0]];
    [contentView addSubview:_ccSeparator];
    _bccSeparator = [[DJLColoredView alloc] initWithFrame:NSZeroRect];
    [_bccSeparator setBackgroundColor:[NSColor colorWithWhite:0.9 alpha:1.0]];
    [contentView addSubview:_bccSeparator];

    _toolbarView = [[DJLComposerToolbarView alloc] initWithFrame:NSMakeRect(0, [contentView bounds].size.height - 35, [contentView bounds].size.width, 35)];
    [_toolbarView setDelegate:self];
    [_toolbarView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [contentView addSubview:_toolbarView];

    _attachmentSeparator = [[DJLColoredView alloc] initWithFrame:NSZeroRect];
    [_attachmentSeparator setBackgroundColor:[NSColor colorWithWhite:0.9 alpha:1.0]];
    [contentView addSubview:_attachmentSeparator];

    _attachmentsScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_attachmentsScrollView setHorizontalScrollElasticity:NSScrollElasticityAutomatic];
    [_attachmentsScrollView setVerticalScrollElasticity:NSScrollElasticityNone];
    [_attachmentsScrollView setHasHorizontalScroller:YES];

    [contentView addSubview:_attachmentsScrollView];
    _attachmentsView = [[DJLAttachmentsCollectionView alloc] initWithFrame:NSZeroRect];
    [_attachmentsView setDelegate:self];
    [_attachmentsView setSelectable:YES];
    [_attachmentsView setAllowsMultipleSelection:YES];
    [_attachmentsView setMinItemSize:NSMakeSize(ATTACHMENT_WIDTH, ATTACHMENT_HEIGHT)];
    [_attachmentsView setMaxItemSize:NSMakeSize(ATTACHMENT_WIDTH, ATTACHMENT_HEIGHT)];
    [_attachmentsScrollView setDocumentView:_attachmentsView];
    [self _layoutWindow];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrolled) name:NSViewBoundsDidChangeNotification object:[mainScrollView contentView]];
    [self _scrolled];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
}

- (void) _scrollerStyleChanged
{
    NSScrollView *mainScrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    [mainScrollView setScrollerStyle:NSScrollerStyleOverlay];
    [_attachmentsScrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (void) _unsetup
{
    [_webView setPolicyDelegate:nil];
    [_webView setEditingDelegate:nil];
    [_webView setUIDelegate:nil];
    [_webView setFrameLoadDelegate:nil];
    [[_webView windowScriptObject] setValue:nil forKey:@"Controller"];
    [_webView removeFromSuperview];
    _webView = nil;
}

- (void) setAccount:(hermes::Account *)account
{
    if (_account != NULL) {
        _account->removeObserver(_callback);
    }
    MC_SAFE_REPLACE_RETAIN(hermes::Account, _account, account);
    if (_account != NULL) {
        _account->addObserver(_callback);
    }
    //[_toolbarView setAccount:_account];
    //[self _setupMessageID];
}

- (hermes::Account *) account
{
    return _account;
}

- (hermes::Account *) _accountForEmailAlias:(NSString *)emailAlias
{
    hermes::Account * result = nil;
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        if ([emailAlias isEqualToString:MCO_TO_OBJC(account->accountInfo()->email())]) {
            result = account;
            break;
        }
        mc_foreacharray(Address, address, account->accountInfo()->aliases()) {
            if ([emailAlias isEqualToString:MCO_TO_OBJC(address->mailbox())]) {
                result = account;
            }
        }
    }
    return result;
}

- (void) setEmailAlias:(NSString *)emailAlias
{
    Account * account = [self _accountForEmailAlias:emailAlias];
    [self setAccount:account];
    _emailAlias = emailAlias;
    [_toolbarView setEmailAlias:emailAlias];
    [self _setupMessageID];
}

- (void) setDefaultEmailAliasForAccount:(hermes::Account *)account
{
    String * result = account->accountInfo()->defaultAlias();
    if (result == NULL) {
        result = account->accountInfo()->email();
    }
    [self setEmailAlias:MCO_TO_OBJC(result)];
}

- (void) loadDraftMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(hermes::Account *)account
{
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
    _draftMessageToLoadRowID = messageRowID;
    _draftMessageToLoadFolderID = folderID;
    _type = DJLComposerWindowControllerTypeIndeterminate;
    [self _updateSendButtonEnabled];
}

- (void) loadDraftMessageForConversationRowID:(int64_t)conversationRowID folderID:(int64_t)folderID account:(hermes::Account *)account
{
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
    _draftMessageToLoadConversationID = conversationRowID;
    _draftMessageToLoadFolderID = folderID;
    _type = DJLComposerWindowControllerTypeIndeterminate;
    [self _updateSendButtonEnabled];
}

- (void) _notifyFetchSummaryDone:(int64_t)messageRowID error:(hermes::ErrorCode)error
{
    if (messageRowID == _repliedMessageRowID) {
        if (error == hermes::ErrorNone) {
            [self _tryRenderRepliedMessage];
        }
        else {
            [self _showLoadRepliedMessageError];
        }
    }
    else if (messageRowID == _draftMessageToLoadRowID) {
        if (error == hermes::ErrorNone) {
            [self _tryLoadMessage];
        }
        else {
            [self _showLoadDraftError];
        }
    }
}

- (void) _showLoadDraftError
{
    if ([[self window] attachedSheet] != nil) {
        return;
    }

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Could not download draft message"];
    [alert addButtonWithTitle:@"OK"];

    __weak DJLComposerWindowController * weakSelf = self;
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        [weakSelf close];
    }];
}

- (void) _showLoadRepliedMessageError
{
    if ([[self window] attachedSheet] != nil) {
        return;
    }

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Could not download replied message"];
    [alert addButtonWithTitle:@"OK"];

    __weak DJLComposerWindowController * weakSelf = self;
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        [weakSelf close];
    }];
}

- (void) replyMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(hermes::Account *)account
{
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
    _type = DJLComposerWindowControllerTypeReply;
    [self _updateSendButtonEnabled];
    _messageInfoOp = _account->messageInfoOperation(messageRowID, false);
    MC_SAFE_RETAIN(_messageInfoOp);
    _messageInfoOp->setCallback(_callback);
    _messageInfoOp->start();
    _repliedMessageRowID = messageRowID;
    _repliedFolderID = folderID;

    NSString * frameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DJLComposerWindowFrameReply"];
    if (frameString != nil) {
        NSRect frame;
        frame = NSRectFromString(frameString);
        if ((frame.size.height != 0) && (frame.size.width != 0)) {
            [[self window] setFrame:frame display:NO];
        }
    }

    NSRect frame = [[self window] frame];
    if (frame.size.height < 500) {
        frame.size.height = 500;
    }
    [[self window] setFrame:frame display:NO];
    [[self window] center];
    [self _layoutWindow];
}

- (Address *) _address
{
    if (MCO_FROM_OBJC(String, [self emailAlias])->isEqual(_account->accountInfo()->email())) {
        return Address::addressWithDisplayName(_account->accountInfo()->displayName(), _account->accountInfo()->email());
    }
    else {
        Address * result = NULL;
        mc_foreacharray(Address, address, _account->accountInfo()->aliases()) {
            if (address->mailbox()->isEqual(MCO_FROM_OBJC(String, [self emailAlias]))) {
                result = address;
            }
        }
        return result;
    }
}

- (NSString *) _aliasForRepliedHeader:(MessageHeader *)header
{
    Set * recipients = Set::set();
    if (header != NULL) {
        {
            mc_foreacharray(Address, address, header->to()) {
                recipients->addObject(address->mailbox());
            }
        }
        {
            mc_foreacharray(Address, address, header->cc()) {
                recipients->addObject(address->mailbox());
            }
        }
        {
            mc_foreacharray(Address, address, header->bcc()) {
                recipients->addObject(address->mailbox());
            }
        }
    }
    String * result = NULL;
    mc_foreacharray(String, email, _account->emailSet()->allObjects()) {
        if (recipients->containsObject(email)) {
            result = email;
        }
    }
    if (result == NULL) {
        result = _account->accountInfo()->defaultAlias();
        if (result == NULL) {
            result = _account->accountInfo()->email();
        }
    }
    return MCO_TO_OBJC(result);
}

- (NSString *) _aliasForDraftHeader:(MessageHeader *)header
{
    String * result = NULL;
    mc_foreacharray(String, email, _account->emailSet()->allObjects()) {
        if (header->from() != NULL) {
            if (email->isEqual(header->from()->mailbox())) {
                result = email;
            }
        }
    }
    if (result == NULL) {
        result = _account->accountInfo()->defaultAlias();
        if (result == NULL) {
            result = _account->accountInfo()->email();
        }
    }
    return MCO_TO_OBJC(result);
}

- (NSString *) _defaultAlias
{
    return [self _aliasForRepliedHeader:NULL];
}

- (void) _replyMessage:(AbstractMessage *)message messageRowID:(int64_t)messageRowID folderID:(int64_t)folderID
{
    DateFormatter * dateFormatter = DateFormatter::dateFormatter();
    dateFormatter->setDateStyle(DateFormatStyleLong);
    dateFormatter->setTimeStyle(DateFormatStyleNone);
    DateFormatter * timeFormatter = DateFormatter::dateFormatter();
    timeFormatter->setDateStyle(DateFormatStyleNone);
    timeFormatter->setTimeStyle(DateFormatStyleShort);
    time_t date = message->header()->date();
    Address * from = message->header()->from();
    if (from == NULL) {
        from = message->header()->sender();
    }
    _quotedHeadString = [NSString stringWithFormat:@"On %@ at %@, %@ wrote:",
                         MCO_TO_OBJC(dateFormatter->stringFromDate(date)),
                         MCO_TO_OBJC(timeFormatter->stringFromDate(date)),
                         MCO_TO_OBJC(AddressDisplay::shortDisplayStringForAddress(from))];

    Array * addressesExcludedFromRecipient = Array::array();
    for(NSString * email in MCO_TO_OBJC(_account->emailSet()->allObjects())) {
        addressesExcludedFromRecipient->addObject(Address::addressWithMailbox([email mco_mcString]));
    }
    LOG_ERROR("reply with addresses: %s", MCUTF8(addressesExcludedFromRecipient));
    MessageHeader * header = message->header()->replyHeader(true, addressesExcludedFromRecipient);
    [self setEmailAlias:[self _aliasForRepliedHeader:message->header()]];
    Array * recipient = Array::array();
    recipient->addObjectsFromArray(header->to());
    recipient->addObjectsFromArray(header->cc());
    [_toField setAddresses:MCO_TO_OBJC(recipient)];
    _inReplyTo = MCO_TO_OBJC(header->inReplyTo());
    _references = MCO_TO_OBJC(header->references());
    NSString * subject = MCO_TO_OBJC(header->subject());
    if (subject == nil) {
        subject = @"";
    }
    [_subjectField setStringValue:subject];
    [self _updateWindowTitle];
    _repliedMessage = message;
    _repliedMessageRowID = messageRowID;
    _repliedFolderID = folderID;
    MC_SAFE_RETAIN(_repliedMessage);

    [self _tryRenderRepliedMessage];
}

- (void) _tryRenderRepliedMessage
{
    [_selfArray addObject:self];
    MailDBMessageInfoOperation * op = _account->messageInfoOperation(_repliedMessageRowID, false);
    op->setCallback(_callback);
    _renderOp = op;
    MC_SAFE_RETAIN(_renderOp);
    op->start();
}

- (BOOL) _hasSignatureChanged
{
    Data * data = _account->accountInfo()->signatureForEmail(MCO_FROM_OBJC(String, _emailAlias));
    if (data == NULL) {
        data = _account->accountInfo()->signatureForEmail(_account->accountInfo()->email());
    }
    WebArchive * archive = [[WebArchive alloc] initWithData:MCO_TO_OBJC(data)];
    NSString * htmlSignature = [[archive mainResource] djlString];
    if (htmlSignature == nil) {
        htmlSignature = @"";
    }

    NSNumber * result = [[_webView windowScriptObject] callWebScriptMethod:@"objcHasSignatureChanged" withArguments:@[htmlSignature]];
    return [result boolValue];
}

- (void) _setupSignature
{
    Data * data = _account->accountInfo()->signatureForEmail(MCO_FROM_OBJC(String, _emailAlias));
    if (data == NULL) {
        data = _account->accountInfo()->signatureForEmail(_account->accountInfo()->email());
    }
    WebArchive * archive = [[WebArchive alloc] initWithData:MCO_TO_OBJC(data)];
    NSString * htmlSignature = [[archive mainResource] djlString];
    if (htmlSignature == nil) {
        htmlSignature = @"";
    }

    NSMutableArray * files = [[NSMutableArray alloc] init];
    NSMutableDictionary * cids = [[NSMutableDictionary alloc] init];
    NSMutableArray * contentIDs = [[NSMutableArray alloc] init];
    if ([[archive subresources] count] > 0) {
        for(WebResource * resource in [archive subresources]) {
            if (([resource URL] != nil) && ([[[resource URL] scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame)) {
                continue;
            }
            if (([resource URL] != nil) && ([[[resource URL] scheme] caseInsensitiveCompare:@"data"] == NSOrderedSame)) {
                continue;
            }
            NSKeyedUnarchiver * unarchiver;
            unarchiver = nil;
            @try {
                unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[resource data]];
            }
            @catch (id e) {
                // do nothing
            }
            @finally {
            }
            if (unarchiver != nil) {
                NSDictionary * info = [unarchiver decodeObjectForKey:@"fileWrapper"];
                NSString * name;
                NSString * contentID;
                NSData * data;

                name = [info objectForKey:@"name"];
                if (name == nil) {
                    name = @"Untitled";
                }
                //contentID = [[resource URL] resourceSpecifier];
                contentID = [[NSUUID UUID] UUIDString];
                [contentIDs addObject:contentID];
                cids[[[resource URL] absoluteString]] = contentID;
                data = [info objectForKey:@"data"];
                //[files addObject:@{@"name": name, @"data": data}];
                NSString * copiedFilename = [self _attachmentPathWithName:name];
                [data writeToFile:copiedFilename atomically:NO];
                [files addObject:copiedFilename];
                _mimeTypes[copiedFilename] = [resource MIMEType];
            }
            else {
                //NSLog(@"exception");
                //NSLog(@"%@ %@", [resource MIMEType], [[resource URL] scheme]);
                NSString * name = [[[resource URL] path] lastPathComponent];
                if (name == nil) {
                    name = @"Untitled";
                }
                NSString * contentID = [[NSUUID UUID] UUIDString];
                [contentIDs addObject:contentID];
                cids[[[resource URL] absoluteString]] = contentID;
                //[files addObject:@{@"name": name, @"data": [resource data]}];
                NSString * copiedFilename = [self _attachmentPathWithName:name];
                [[resource data] writeToFile:copiedFilename atomically:NO];
                [files addObject:copiedFilename];
                _mimeTypes[copiedFilename] = [resource MIMEType];
            }
        }
    }
    //NSArray * filenames = [self _addFilesWithData:files];
    NSMutableDictionary * cidsFiles = [[NSMutableDictionary alloc] init];
    for(NSUInteger i = 0 ; i < [files count] ; i ++) {
        cidsFiles[files[i]] = contentIDs[i];
    }
    [self _addFilenames:files withContentIDs:cidsFiles];
    NSString * jsInfo = MCO_TO_OBJC(mailcore::JSON::objectToJSONString(MCO_FROM_OBJC(HashMap, cids)));
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSetSignature" withArguments:@[htmlSignature, jsInfo]];
}

- (void) _replyMessageRenderDone
{
    HashMap * info = _renderOp->messageInfo();
    if (info == NULL) {
        _type = DJLComposerWindowControllerTypeNew;
        [self _layoutWindow];
        MC_SAFE_RELEASE(_renderOp);

        [self _setupSignature];
        [[_webView window] makeFirstResponder:_webView];
        [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
        [_selfArray removeObject:self];
        return;
    }
    info->setObjectForKey(MCSTR("rowid"), Value::valueWithLongLongValue(_repliedMessageRowID));
    info->setObjectForKey(MCSTR("folderid"), Value::valueWithLongLongValue(_repliedFolderID));
    if (info->objectForKey(MCSTR("content")) == NULL) {
        _account->fetchMessageSummary(_repliedFolderID, _repliedMessageRowID, true);
    }

    String * addressesDisplayString = NULL;
    Array * addresses = MCO_FROM_OBJC(Array, [_toField addresses]);;
    if (addresses->count() == 1) {
        addressesDisplayString = AddressDisplay::shortDisplayStringForAddresses(addresses);
    }
    else {
        addressesDisplayString = AddressDisplay::veryShortDisplayStringForAddresses(addresses);
    }

    NSString * jsInfo;
    jsInfo = MCO_TO_OBJC(mailcore::JSON::objectToJSONString(info));
    //NSLog(@"reply done: %@", jsInfo);

    if (info->objectForKey(MCSTR("content")) != NULL) {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcSetRepliedContent" withArguments:@[jsInfo, MCO_TO_OBJC(addressesDisplayString), _quotedHeadString]];
        _repliedMessageRendered = YES;
        [self _updateSendButtonEnabled];
    }
    else {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcSetRepliedContent" withArguments:@[jsInfo, MCO_TO_OBJC(addressesDisplayString), _quotedHeadString]];
    }

    MC_SAFE_RELEASE(_renderOp);

    [self _setupSignature];
    [[_webView window] makeFirstResponder:_webView];
    [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
    [_selfArray removeObject:self];
}

- (void) forwardMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(hermes::Account *)account
{
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
    [self setEmailAlias:[self _defaultAlias]];

    _type = DJLComposerWindowControllerTypeForward;
    [self _updateSendButtonEnabled];
    _messageInfoOp = _account->messageInfoOperation(messageRowID, false);
    MC_SAFE_RETAIN(_messageInfoOp);
    _messageInfoOp->setCallback(_callback);
    _messageInfoOp->start();
    _repliedMessageRowID = messageRowID;
    _repliedFolderID = folderID;

    NSString * frameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DJLComposerWindowFrameReply"];
    if (frameString != nil) {
        NSRect frame;
        frame = NSRectFromString(frameString);
        if ((frame.size.height != 0) && (frame.size.width != 0)) {
            [[self window] setFrame:frame display:NO];
        }
    }

    NSRect frame = [[self window] frame];
    if (frame.size.height < 500) {
        frame.size.height = 500;
    }
    [[self window] setFrame:frame display:NO];
    [[self window] center];
    [self _layoutWindow];
}

- (void) _forwardMessage:(AbstractMessage *)message messageRowID:(int64_t)messageRowID folderID:(int64_t)folderID
{
    MessageHeader * header = message->header()->forwardHeader();
    NSString * subject = MCO_TO_OBJC(header->subject());
    if (subject == nil) {
        subject = @"";
    }
    [_subjectField setStringValue:subject];
    [self _updateWindowTitle];
    _repliedMessage = message;
    _repliedMessageRowID = messageRowID;
    _repliedFolderID = folderID;
    MC_SAFE_RETAIN(_repliedMessage);

    [self _tryRenderForwardedMessage];
}

- (void) _tryRenderForwardedMessage
{
    [_selfArray addObject:self];
    MailDBMessageInfoOperation * op = _account->messageInfoOperation(_repliedMessageRowID, false);
    op->setCallback(_callback);
    _renderOp = op;
    MC_SAFE_RETAIN(_renderOp);
    op->start();
}

static int compareAddresses(void * a, void * b, void * context)
{
    Address * addrA = (Address *) a;
    Address * addrB = (Address *) b;
    return addrA->mailbox()->caseInsensitiveCompare(addrB->mailbox());
}

- (void) _forwardMessageRenderDone
{
    HashMap * info = _renderOp->messageInfo();
    if (info == NULL) {
        _type = DJLComposerWindowControllerTypeNew;
        [self _layoutWindow];
        MC_SAFE_RELEASE(_renderOp);
        [self _setupSignature];
        [[_webView window] makeFirstResponder:_webView];
        [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
        [_selfArray removeObject:self];
        return;
    }

    NSString * jsInfo;
    jsInfo = MCO_TO_OBJC(mailcore::JSON::objectToJSONString(info));

    NSMutableDictionary * forwardedHeaders = [[NSMutableDictionary alloc] init];
    NSString * fromString = MCO_TO_OBJC(_repliedMessage->header()->from()->nonEncodedRFC822String());
    if (fromString == nil) {
        fromString = @"No sender";
    }
    Array * recipient = Array::array();
    recipient->addObjectsFromArray(_repliedMessage->header()->to());
    recipient->addObjectsFromArray(_repliedMessage->header()->cc());
    recipient->sortArray(compareAddresses, NULL);
    NSString * recipientString = MCO_TO_OBJC(Address::nonEncodedRFC822StringForAddresses(recipient));
    if (recipientString == nil) {
        recipientString = @"Undisclosed recipient";
    }
    NSString * subject = MCO_TO_OBJC(_repliedMessage->header()->subject());
    if (subject == nil) {
        subject = @"No suject";
    }
    NSString * dateStr = MCO_TO_OBJC(info->objectForKey(MCSTR("header-date")));
    if (dateStr == nil) {
        dateStr = @"No date";
    }
    forwardedHeaders[@"from"] = fromString;
    forwardedHeaders[@"to"] = recipientString;
    forwardedHeaders[@"subject"] = subject;
    forwardedHeaders[@"fulldate"] = dateStr;
    NSString * jsonForwardedHeaders = MCO_TO_OBJC(JSON::objectToJSONString(MCO_FROM_OBJC(HashMap, forwardedHeaders)));
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSetForwardedContent" withArguments:@[jsInfo, @"Forwarded message:", jsonForwardedHeaders]];
    if (info->objectForKey(MCSTR("content")) == NULL) {
        _account->fetchMessageSummary(_repliedFolderID, _repliedMessageRowID, true);
    }
    else {
        [[_webView window] makeFirstResponder:_toField];

        [self _loadForwardedMessageAttachments:MCO_TO_OBJC(info)];

        _repliedMessageRendered = YES;
        [self _updateSendButtonEnabled];
    }

    MC_SAFE_RELEASE(_renderOp);
    [self _setupSignature];
    [_selfArray removeObject:self];
}

- (void) _loadForwardedMessageAttachments:(NSDictionary *)info
{
    _forwardedMessageInfo = info;

    NSArray * attachments = info[@"all-attachments"];
    //NSLog(@"info: %@", info);
    //NSLog(@"load %@", attachments);

    for(NSDictionary * attachmentInfo in attachments) {
        IMAPAttachmentDownloader * downloader = _account->attachmentDownloader(); //new IMAPAttachmentDownloader();
        downloader->setFolderID(_repliedFolderID);
        downloader->setMessageRowID(_repliedMessageRowID);
        downloader->setUniqueID(MCO_FROM_OBJC(String, [attachmentInfo objectForKey:@"uniqueID"]));
        downloader->setDownloadFolder(MCO_FROM_OBJC(String, [self _temporaryFolder]));
        //downloader->setAccount(_account);
        downloader->setCallback(_callback);
        downloader->start();
        _fowardedAttachmentsDownloaders->addObject(downloader);
        //MC_SAFE_RELEASE(downloader);
    }

    [self _loadForwardedMessageSaveAttachmentsCheckFinished];
}

- (void) _loadForwardedMessageAttachmentsDownloaderFinished:(IMAPAttachmentDownloader *)downloader
{
    if (downloader->error() == hermes::ErrorNone) {
        BOOL foundInCID = NO;
        NSDictionary * mapping = _forwardedMessageInfo[@"cid-mapping"];
        for(NSString * key in mapping) {
            NSDictionary * value = mapping[key];
            NSString * uniqueID = value[@"uniqueID"];
            if ([uniqueID isEqualToString:MCO_TO_OBJC(downloader->uniqueID())]) {
                NSString * contentID = [[NSURL URLWithString:key] resourceSpecifier];
                [_cidFiles setObject:MCO_TO_OBJC(downloader->filename()) forKey:contentID];
                foundInCID = YES;
            }
        }

        if (!foundInCID) {
            [_attachments addObject:MCO_TO_OBJC(downloader->filename())];
        }
        _fowardedAttachmentsDownloaders->removeObject(downloader);
        [[_webView windowScriptObject] callWebScriptMethod:@"loadImages" withArguments:nil];
    }
    else {
        mc_foreacharray(IMAPAttachmentDownloader, curDownloader, _fowardedAttachmentsDownloaders) {
            if (curDownloader != downloader) {
                curDownloader->cancel();
            }
        }
        _fowardedAttachmentsDownloaders->removeAllObjects();
    }

    [self _loadForwardedMessageSaveAttachmentsCheckFinished];
}

- (void) _loadForwardedMessageSaveAttachmentsCheckFinished
{
    [self _updateAttachments];
}

- (void) setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject body:(NSString *)body
{
    NSString * htmlBody = [body mco_htmlEncodedString];
    [self setTo:to cc:cc bcc:bcc subject:subject htmlBody:htmlBody];
}

- (void) setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject htmlBody:(NSString *)htmlBody
{
    [self _setTo:to cc:cc bcc:bcc subject:subject htmlBody:htmlBody baseURL:nil];
    [self _layoutWindow];
}

- (void) setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject archive:(WebArchive *)archive
{
    NSURL * baseURL = [[archive mainResource] URL];
    NSString * htmlBody = [[archive mainResource] djlString];

    [self _setTo:to cc:cc bcc:bcc subject:subject htmlBody:htmlBody baseURL:baseURL];

    NSMutableArray * files = [[NSMutableArray alloc] init];
    if ([[archive subresources] count] > 0) {
        for(WebResource * resource in [archive subresources]) {
            if (([resource URL] != nil) && ([[[resource URL] scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame)) {
                continue;
            }
            if (([resource URL] != nil) && ([[[resource URL] scheme] caseInsensitiveCompare:@"data"] == NSOrderedSame)) {
                continue;
            }
            NSKeyedUnarchiver * unarchiver;
            unarchiver = nil;
            @try {
                unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[resource data]];
            }
            @catch (id e) {
                // do nothing
            }
            @finally {
            }
            if (unarchiver != nil) {
                NSDictionary * info = [unarchiver decodeObjectForKey:@"fileWrapper"];
                NSString * name;
                NSString * contentID;
                NSData * data;

                name = [info objectForKey:@"name"];
                if (name == nil) {
                    name = @"Untitled";
                }
                contentID = [[resource URL] resourceSpecifier];
                data = [info objectForKey:@"data"];
                [files addObject:@{@"name": name, @"data": data}];
            }
            else {
                NSLog(@"exception");
                NSLog(@"%@ %@", [resource MIMEType], [[resource URL] scheme]);
            }
        }
    }
    [self _addFilesWithData:files];
}

- (void) _setTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject htmlBody:(NSString *)htmlBody baseURL:(NSURL *)baseURL
{
    _urlHandler = YES;
    _urlHandlerTo = [to copy];
    _urlHandlerCc = [cc copy];
    _urlHandlerBcc = [bcc copy];
    _urlHandlerSubject = [subject copy];
    _urlHandlerHTMLBody = [htmlBody copy];
    _urlHandlerBaseURL = [baseURL copy];
    [self _setAddressesForURL];
}

- (void) _setAddressesForURL
{
    NSMutableArray * recipient = [[NSMutableArray alloc] init];

    if ([_urlHandlerTo length] > 0) {
        NSArray * addresses;

        addresses = [MCOAddress addressesWithRFC822String:[_urlHandlerTo djlURLDecode]];
        if (addresses == nil) {
            addresses = [MCOAddress addressesWithRFC822String:_urlHandlerTo];
        }
        if (addresses != nil) {
            [recipient addObjectsFromArray:addresses];
        }
    }

    if ([_urlHandlerCc length] > 0) {
        NSArray * addresses;

        addresses = [MCOAddress addressesWithRFC822String:[_urlHandlerCc djlURLDecode]];
        if (addresses == nil) {
            addresses = [MCOAddress addressesWithRFC822String:_urlHandlerCc];
        }
        if (addresses != nil) {
            [recipient addObjectsFromArray:addresses];
        }
    }

    [_toField setAddresses:recipient];

    if ([_urlHandlerBcc length] > 0) {
        NSArray * addresses;

        addresses = [MCOAddress addressesWithRFC822String:[_urlHandlerCc djlURLDecode]];
        if (addresses == nil) {
            addresses = [MCOAddress addressesWithRFC822String:_urlHandlerCc];
        }
        if ([addresses count] > 0) {
            [_bccField setAddresses:addresses];
            _showCcEnabled = YES;
            _replyShowRecipientEditor = YES;
        }
    }

    if (_urlHandlerSubject != nil) {
        [_subjectField setStringValue:_urlHandlerSubject];
        [self _updateWindowTitle];
    }

}

- (void) sendMessage:(id)sender
{
    [self _sendMessage];
}

- (void) saveDocument:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_saveNow) object:nil];
    _saveScheduled = NO;
    _modifiedOnce = NO;
    [self _saveAndPush:YES];
}

- (void) findInText:(id)sender
{
    [_toolbarView focusSearch];
    [self _search:[_toolbarView searchString]];
}

- (void) findNext:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcFocusNextSearchResult" withArguments:nil];
}

- (void) findPrevious:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcFocusPreviousSearchResult" withArguments:nil];
}

- (BOOL) _isSelectionEmpty
{
    return ([_webView selectedDOMRange] == nil) || [[_webView selectedDOMRange] collapsed];
}

- (IBAction) editAllContent:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcEditAllContent" withArguments:nil];
}

- (IBAction) createLink:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectCurrentLink" withArguments:nil];
    NSString * value = [[_webView windowScriptObject] callWebScriptMethod:@"objcLinkFromSelection" withArguments:nil];
    NSURL * url = [value djlURL];
    _createLinkController = [[DJLCreateLinkWindowController alloc] init];
    [_createLinkController setDelegate:self];
    [_createLinkController beginSheetWithWindow:[self window] url:url];
}

- (void) DJLCreateLinkWindowController:(DJLCreateLinkWindowController *)controller createLink:(NSURL *)url
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcAddLinkToSelection" withArguments:@[[url absoluteString]]];
    _createLinkController = nil;
}

- (void) DJLCreateLinkWindowControllerCancelled:(DJLCreateLinkWindowController *)controller
{
    _createLinkController = nil;
}

#pragma mark -
#pragma mark operation routing

- (void) _operationFinished:(Operation *)operation
{
    if (operation == _renderOp) {
        if (_type == DJLComposerWindowControllerTypeForward) {
            [self _forwardMessageRenderDone];
        }
        else {
            [self _replyMessageRenderDone];
        }
    }
    else if (operation == _messageInfoOp) {
        if (_messageInfoOp->messageInfo() == NULL) {
            // Could not load message -> new message.
            _type = DJLComposerWindowControllerTypeNew;
            [self _layoutWindow];
            MC_SAFE_RELEASE(_messageInfoOp);

            [self _setupSignature];
            [[_webView window] makeFirstResponder:_webView];
            [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
            return;
        }

        DJLAssert(_messageInfoOp->messageInfo() != NULL);
        HashMap * serializedMessage = (HashMap *) _messageInfoOp->messageInfo()->objectForKey(MCSTR("msg"));
        DJLAssert(serializedMessage != NULL);
        AbstractMessage * msg = (AbstractMessage *) Object::objectWithSerializable(serializedMessage);
        DJLAssert(msg != NULL);
        if (_type == DJLComposerWindowControllerTypeForward) {
            [self _forwardMessage:msg messageRowID:_repliedMessageRowID folderID:_repliedFolderID];
        }
        else {
            [self _replyMessage:msg messageRowID:_repliedMessageRowID folderID:_repliedFolderID];
        }
        MC_SAFE_RELEASE(_messageInfoOp);
    }
    else if (_loadMessagesOp->containsObject(operation)) {
        [self _jsLoadDraftMessageFinished:(MailDBMessageInfoOperation *) operation];
    }
    else if (_loadConversationMessagesOp->containsObject(operation)) {
        [self _jsLoadMessagesFinished:(MailDBConversationMessagesOperation *) operation];
    }
    else if (_downloaders->containsObject(operation)) {
        [self _loadDraftSaveAttachmentsDownloaderFinished:(IMAPAttachmentDownloader *) operation];
    }
    else if (_fowardedAttachmentsDownloaders->containsObject(operation)) {
        [self _loadForwardedMessageAttachmentsDownloaderFinished:(IMAPAttachmentDownloader *) operation];
    }
#if 0
    else if (_loadImagesOp->containsObject(operation)) {
        [self _jsLoadImageFinished:(MailDBRetrievePartOperation *) operation];
    }
#endif
}

#pragma mark -
#pragma mark window delegate

- (void)windowDidResize:(NSNotification *)notification
{
    [self _savePosition];
    [self _layoutWindow];
}

#define MAX_WIDTH 624

- (void) _layoutWindow
{
    if (_webView == nil) {
        return;
    }

    NSView * contentView = [[self window] contentView];
    BOOL showAttachments = NO;
    if ([_attachments count] > 0) {
        showAttachments = YES;
    }
    if (_needsAttachmentDropZone) {
        showAttachments = YES;
    }
    CGFloat y = 35;
    if (_type == DJLComposerWindowControllerTypeReply) {
        if (_replyShowRecipientEditor && _showCcEnabled) {
            [_toLabel setHidden:NO];
            [_toField setHidden:NO];
            [_ccSeparator setHidden:NO];
            [_ccLabel setHidden:NO];
            [_ccField setHidden:NO];
            [_bccSeparator setHidden:NO];
            [_bccLabel setHidden:NO];
            [_bccField setHidden:NO];
            [_subjectSeparator setHidden:NO];
            [_subjectLabel setHidden:NO];
            [_subjectField setHidden:NO];
            [_bodySeparator setHidden:NO];
            [_webView setHidden:NO];
        }
        else if (_replyShowRecipientEditor) {
            [_toLabel setHidden:NO];
            [_toField setHidden:NO];
            [_ccSeparator setHidden:YES];
            [_ccLabel setHidden:YES];
            [_ccField setHidden:YES];
            [_bccSeparator setHidden:YES];
            [_bccLabel setHidden:YES];
            [_bccField setHidden:YES];
            [_subjectSeparator setHidden:NO];
            [_subjectLabel setHidden:NO];
            [_subjectField setHidden:NO];
            [_bodySeparator setHidden:NO];
            [_webView setHidden:NO];
        }
        else {
            [_toLabel setHidden:YES];
            [_toField setHidden:YES];
            [_ccSeparator setHidden:YES];
            [_ccLabel setHidden:YES];
            [_ccField setHidden:YES];
            [_bccSeparator setHidden:YES];
            [_bccLabel setHidden:YES];
            [_bccField setHidden:YES];
            [_subjectSeparator setHidden:YES];
            [_subjectLabel setHidden:YES];
            [_subjectField setHidden:YES];
            [_bodySeparator setHidden:YES];
            [_webView setHidden:NO];
        }
    }
    else if (_type == DJLComposerWindowControllerTypeIndeterminate) {
        [_toLabel setHidden:YES];
        [_toField setHidden:YES];
        [_ccSeparator setHidden:YES];
        [_ccLabel setHidden:YES];
        [_ccField setHidden:YES];
        [_bccSeparator setHidden:YES];
        [_bccLabel setHidden:YES];
        [_bccField setHidden:YES];
        [_subjectSeparator setHidden:YES];
        [_subjectLabel setHidden:YES];
        [_subjectField setHidden:YES];
        [_bodySeparator setHidden:YES];
        [_webView setHidden:YES];
    }
    else {
        if (_showCcEnabled) {
            [_toLabel setHidden:NO];
            [_toField setHidden:NO];
            [_ccSeparator setHidden:NO];
            [_ccLabel setHidden:NO];
            [_ccField setHidden:NO];
            [_bccSeparator setHidden:NO];
            [_bccLabel setHidden:NO];
            [_bccField setHidden:NO];
            [_subjectSeparator setHidden:NO];
            [_subjectLabel setHidden:NO];
            [_subjectField setHidden:NO];
            [_bodySeparator setHidden:NO];
            [_webView setHidden:NO];
        }
        else {
            [_toLabel setHidden:NO];
            [_toField setHidden:NO];
            [_ccSeparator setHidden:YES];
            [_ccLabel setHidden:YES];
            [_ccField setHidden:YES];
            [_bccSeparator setHidden:YES];
            [_bccLabel setHidden:YES];
            [_bccField setHidden:YES];
            [_subjectSeparator setHidden:NO];
            [_subjectLabel setHidden:NO];
            [_subjectField setHidden:NO];
            [_bodySeparator setHidden:NO];
            [_webView setHidden:NO];
        }
    }

    if (showAttachments) {
        [_attachmentSeparator setHidden:NO];
        [_attachmentsScrollView setHidden:NO];
    }
    else {
        [_attachmentSeparator setHidden:YES];
        [_attachmentsScrollView setHidden:YES];
    }

    if (![_toLabel isHidden]) {
        y += 5;
        [_toLabel sizeToFit];
        NSRect frame = [_toLabel frame];
        frame.origin.y = y;
        frame.origin.x = 20;
        [_toLabel setFrame:frame];

        [_toField sizeToFit];
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.origin.y = y;
        frame.origin.x = NSMaxX([_toLabel frame]) + 5;
        frame.size.width -= frame.origin.x + 20;
        frame.size.height = [_toField frame].size.height;
        [_toField setFrame:frame];

        y += [_toField frame].size.height;
        y += 5;
    }
    if (![_ccSeparator isHidden]) {
        NSRect frame;
        frame.origin.x = 20;
        frame.origin.y = y;
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.size.width -= 40;
        frame.size.height = 1;
        [_ccSeparator setFrame:frame];

        y += 1;
    }
    if (![_ccLabel isHidden]) {
        y += 5;
        [_ccLabel sizeToFit];
        NSRect frame = [_ccLabel frame];
        frame.origin.y = y;
        frame.origin.x = 20;
        [_ccLabel setFrame:frame];

        [_ccField sizeToFit];
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.origin.y = y;
        frame.origin.x = NSMaxX([_ccLabel frame]) + 5;
        frame.size.width -= frame.origin.x + 20;
        frame.size.height = [_ccLabel frame].size.height;
        [_ccField setFrame:frame];

        y += [_ccField frame].size.height;
        y += 5;
    }
    if (![_bccSeparator isHidden]) {
        NSRect frame;
        frame.origin.x = 20;
        frame.origin.y = y;
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.size.width -= 40;
        frame.size.height = 1;
        [_bccSeparator setFrame:frame];

        y += 1;
    }
    if (![_bccLabel isHidden]) {
        y += 5;
        [_bccLabel sizeToFit];
        NSRect frame = [_bccLabel frame];
        frame.origin.y = y;
        frame.origin.x = 20;
        [_bccLabel setFrame:frame];

        [_bccField sizeToFit];
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.origin.y = y;
        frame.origin.x = NSMaxX([_bccLabel frame]) + 5;
        frame.size.width -= frame.origin.x + 20;
        frame.size.height = [_bccLabel frame].size.height;
        [_bccField setFrame:frame];

        y += [_bccField frame].size.height;
        y += 5;
    }
    if (![_subjectSeparator isHidden]) {
        NSRect frame;
        frame.origin.x = 20;
        frame.origin.y = y;
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.size.width -= 40;
        frame.size.height = 1;
        [_subjectSeparator setFrame:frame];

        y += 1;
    }
    if (![_subjectLabel isHidden]) {
        y += 5;
        [_subjectLabel sizeToFit];
        NSRect frame = [_subjectLabel frame];
        frame.origin.y = y;
        frame.origin.x = 20;
        [_subjectLabel setFrame:frame];

        [_subjectField sizeToFit];
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.origin.y = y;
        frame.origin.x = NSMaxX([_subjectLabel frame]) + 5;
        frame.size.width -= frame.origin.x + 20;
        [_subjectField setFrame:frame];

        y += [_subjectField frame].size.height;
        y += 5;
    }
    if (![_bodySeparator isHidden]) {
        NSRect frame;
        frame.origin.x = 20;
        frame.origin.y = y;
        frame.size.width = [contentView bounds].size.width;
        if (frame.size.width > MAX_WIDTH) {
            frame.size.width = MAX_WIDTH;
        }
        frame.size.width -= 40;
        frame.size.height = 1;
        [_bodySeparator setFrame:frame];

        y += 1;
    }

    CGFloat attachmentsViewHeight = 0;
    if (showAttachments) {
        int countPerRow = ([contentView bounds].size.width - 10) / ATTACHMENT_WIDTH;
        if (countPerRow == 0) {
            countPerRow = 1;
        }
        int rows = (int) ([_attachments count] + countPerRow - 1) / countPerRow;
        if (rows == 0) {
            rows = 1;
        }

        attachmentsViewHeight = ATTACHMENT_HEIGHT * rows + 10;
        BOOL initial = YES;
        while (attachmentsViewHeight > [contentView bounds].size.height / 2) {
            initial = NO;
            rows --;
            attachmentsViewHeight = ATTACHMENT_HEIGHT * rows + 10;
        }
        if (rows == 0) {
            rows = 1;
            attachmentsViewHeight = ATTACHMENT_HEIGHT * rows + 10;
        }

        if (!initial) {
            [_attachmentsView setMaxNumberOfColumns:0];
            [_attachmentsView setMaxNumberOfRows:rows];
        }
        else {
            [_attachmentsView setMaxNumberOfColumns:countPerRow];
        }
    }

    if (![_webView isHidden]) {
        NSRect frame;
        if (showAttachments) {
            frame.origin.x = 0;
            frame.origin.y = y;
            frame.size.width = [contentView frame].size.width;
            frame.size.height = [contentView frame].size.height - attachmentsViewHeight - 1 - y;

            y += frame.size.height;
        }
        else {
            frame.origin.x = 0;
            frame.origin.y = y;
            frame.size.width = [contentView frame].size.width;
            frame.size.height = [contentView frame].size.height - y;

            y += frame.size.height;
        }

        [_webView setFrame:frame];
    }

    if (![_attachmentSeparator isHidden]) {
        NSRect frame;
        frame.origin.x = 20;
        frame.origin.y = y;
        frame.size.width = [contentView bounds].size.width;
        frame.size.width -= 40;
        frame.size.height = 1;
        [_attachmentSeparator setFrame:frame];

        y += 1;
    }

    if (![_attachmentsScrollView isHidden]) {
        NSRect frame;
        frame.origin.x = 0;
        frame.origin.y = y;
        frame.size.width = [contentView bounds].size.width;
        frame.size.height = attachmentsViewHeight;
        [_attachmentsScrollView setFrame:frame];

        y += 1;
    }

    CGFloat marginLeft = 0;
    if ([contentView bounds].size.width > MAX_WIDTH) {
        marginLeft = (int) (([contentView bounds].size.width - MAX_WIDTH) / 2);
    }

    NSArray * views = @[_toLabel, _toField, _ccSeparator, _ccLabel, _ccField, _bccSeparator, _bccLabel, _bccField,
                        _subjectSeparator, _subjectField, _subjectLabel, _bodySeparator];
    for(NSView * view in views) {
        NSRect frame = [view frame];
        frame.origin.x += marginLeft;
        [view setFrame:frame];
    }

    views = @[_toLabel, _toField, _ccSeparator, _ccLabel, _ccField, _bccSeparator, _bccLabel, _bccField,
              _subjectSeparator, _subjectField, _subjectLabel, _bodySeparator, _webView,
              _attachmentsScrollView, _attachmentSeparator];
    for(NSView * view in views) {
        NSRect frame = [view frame];
        frame.origin.y = [contentView frame].size.height - frame.origin.y - frame.size.height;
        [view setFrame:frame];
    }
}

- (void)windowDidMove:(NSNotification *)notification
{
    [self _savePosition];
}

- (void) _savePosition
{
    if ([self window] == nil) {
        return;
    }
    if (![[self delegate] DJLComposerWindowControllerShouldSave:self]) {
        return;
    }

    NSRect frame = [[self window] frame];
    NSString * frameString = NSStringFromRect(frame);
    if (_type == DJLComposerWindowControllerTypeIndeterminate) {
        // do nothing.
    }
    else if (_type == DJLComposerWindowControllerTypeNew) {
        [[NSUserDefaults standardUserDefaults] setObject:frameString forKey:@"DJLComposerWindowFrame"];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setObject:frameString forKey:@"DJLComposerWindowFrameReply"];
    }
}

- (void) windowWillClose:(NSNotification *)notification
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_saveNow) object:nil];
    [self _unsetup];
    [[self window] orderOut:nil];
    [_webView removeFromSuperview];
    [_webView setEditingDelegate:nil];
    [_webView setUIDelegate:nil];
    _webView = nil;

    [[self delegate] DJLComposerWindowControllerWillClose:self];
}

- (BOOL) windowShouldClose:(id)sender
{
    if (!_modifiedOnce) {
        return YES;
    }

    [self _saveNow];

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Do you want to keep this draft of the message?"];
    [alert setInformativeText:@"The message has been saved."];
    [alert addButtonWithTitle:@"Save Draft"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];

    __weak DJLComposerWindowController * weakSelf = self;
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        [weakSelf _handleCloseDialog:returnCode];
    }];

    return NO;
}

- (void) _handleCloseDialog:(NSModalResponse)returnCode
{
    switch (returnCode) {
        case NSAlertFirstButtonReturn:
            [self close];
            break;
        case NSAlertSecondButtonReturn:
            [[[self window] attachedSheet] close];
            break;
        case NSAlertThirdButtonReturn:
            _account->removeDraftForSentMessage(MCO_FROM_OBJC(String, _messageID));
            [self close];
            break;
    }
}

- (BOOL) DJLComposerWindowCommandEnterPressed:(DJLComposerWindow *)window
{
    [self sendMessage:nil];
    return YES;
}

#pragma mark -
#pragma mark MMEmailField delegate

- (void) _addressBookLoaded
{
    if ([[self window] fieldEditor:NO forObject:_toField] == [[self window] firstResponder]) {
        [self _showCompletionForField:_toField];
    }
    if ([[self window] fieldEditor:NO forObject:_ccField] == [[self window] firstResponder]) {
        [self _showCompletionForField:_ccField];
    }
    if ([[self window] fieldEditor:NO forObject:_bccField] == [[self window] firstResponder]) {
        [self _showCompletionForField:_bccField];
    }
}

- (void) DJLEmailField_shouldShowCompletion:(DJLEmailField *)field
{
    [self _showCompletionForField:field];
}

- (void) _showCompletionForField:(DJLEmailField *)field
{
    [_completionWindowController setField:field];
    [_completionWindowController complete];
}

- (void) DJLEmailField_sizeDidChange:(DJLEmailField *)field
{
    [self _layoutWindow];
}

- (void) DJLEmailField_enableCompletion:(DJLEmailField *)field
{
    [_completionWindowController setField:field];
}

- (void) DJLEmailField_disableCompletion:(DJLEmailField *)field
{
    [_completionWindowController setField:nil];
}

- (void) DJLEmailField_didEndEditing:(DJLEmailField *)field
{
    [_completionWindowController acceptCompletion];
    [_completionWindowController cancelCompletion];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
    NSString * email = representedObject;
    MCOAddress * address = [MCOAddress addressWithNonEncodedRFC822String:email];
    if (address == nil) {
        return email;
    }
    String * result = AddressDisplay::shortDisplayStringForAddress((Address *) [address mco_mcObject]);
    return MCO_TO_OBJC(result);
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject
{
    NSString * email = representedObject;
    return email;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject
{
    return YES;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject
{
    NSMenu * menu = [[NSMenu alloc] init];
    NSString * email = representedObject;
    MCOAddress * address = [MCOAddress addressWithNonEncodedRFC822String:email];
    if ([address mailbox] != nil) {
        [menu addItemWithTitle:[address mailbox] action:nil keyEquivalent:@""];
    }
    return menu;
}

#pragma mark -
#pragma mark textfield delegate

- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
    if (_subjectField == [notification object]) {
        NSTextView *textView = (NSTextView *)[self.window firstResponder];
        [textView setContinuousSpellCheckingEnabled:YES];
    }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    if (_toField == [aNotification object]) {
        [self _updateSendButtonEnabled];
    }
    if (_ccField == [aNotification object]) {
        [self _updateSendButtonEnabled];
    }
    if (_bccField == [aNotification object]) {
        [self _updateSendButtonEnabled];
    }
    else if (_subjectField == [aNotification object]) {
        [self _updateWindowTitle];
        [self _updateSendButtonEnabled];
    }
    [self _messageModified];
}

- (void) _updateWindowTitle
{
    NSString * title = @"Composer";
    if ([[_subjectField stringValue] length] > 0) {
        title = [NSString stringWithFormat:@"Composer - %@", [_subjectField stringValue]];
    }
    [[self window] setTitle:title];
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
    return nil;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    if ((control == _toField) || (control == _ccField) || (control == _bccField) || (control == _subjectField)) {
        DJLEmailField * field;

        //MMLog(@"%@", NSStringFromSelector(command));

        field = (DJLEmailField *) [_completionWindowController field];
        if (field == nil) {
            if (command == @selector(insertNewline:)) {
                NSView * view;
                BOOL tokenized;

                tokenized = NO;
                if ([control isKindOfClass:[DJLEmailField class]]) {
                    if ([(DJLEmailField *) control acceptTokenization]) {
                        [(DJLEmailField *) control tokenize];
                        tokenized = YES;
                    }
                }

                if (!tokenized) {
                    view = [control nextValidKeyView];
                    if (view != nil) {
                        [[self window] makeFirstResponder:view];
                        if ([view isKindOfClass:[WebView class]]) {
                            [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
                        }
                    }
                }

                return YES;
            }
            return NO;
        }
        else {
            if ([_completionWindowController control:control textView:textView doCommandBySelector:command]) {
                return YES;
            }
        }

        return NO;
    }
    else {
        return NO;
    }
}

#pragma mark -
#pragma mark WebView delegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [self _scrollerStyleChanged];

    if (_draftMessageToLoadRowID != -1) {
        [self _tryLoadMessage];
    }
    else if (_draftMessageToLoadConversationID != -1) {
        [self _tryLoadConversation];
    }
    else if (_urlHandler) {
        [self _loadHTMLBody];
    }
    else if (_type == DJLComposerWindowControllerTypeNew) {
        [self _setupSignature];
    }

    if (_account->draftsFolderPath() == NULL) {
        [self _showAlertDraftAndClose:YES];
    }
}

- (void)webViewDidChange:(NSNotification *)notification
{
    [self _messageModified];
}

- (BOOL)webView:(WebView *)webView shouldChangeSelectedDOMRange:(DOMRange *)currentRange toDOMRange:(DOMRange *)proposedRange affinity:(NSSelectionAffinity)selectionAffinity stillSelecting:(BOOL)flag
{
    DOMNode * node;
    NSNumber * nb;

    node = [proposedRange commonAncestorContainer];
    if (node == nil)
        return YES;

    nb = [[_webView windowScriptObject] callWebScriptMethod:@"objcIsNodeTextContents" withArguments:[NSArray arrayWithObject:node]];
    return [nb boolValue];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(id)dataSource
{
    NSString * scheme = [[request URL] scheme];
    if ([scheme isEqualTo:@"https"] || [scheme isEqualTo:@"http"] || [scheme isEqualTo:@"file"] || [scheme isEqualTo:@"data"]) {
        return request;
    }
    return [NSURLRequest requestWithURL:[NSURL fileURLWithPath:@"/dev/null"]];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    NSMutableArray * filteredMenu = [[NSMutableArray alloc] init];
    for(NSMenuItem * item in defaultMenuItems) {
        //NSLog(@"%i %@", (int) [item tag], [item title]);
        switch ([item tag]) {
            case WebMenuItemTagCopyLinkToClipboard:
            case WebMenuItemTagCopyImageToClipboard:
            case WebMenuItemTagCopy:
            case WebMenuItemTagCut:
            case WebMenuItemTagPaste:
            case WebMenuItemTagSpellingGuess:
            case WebMenuItemTagNoGuessesFound:
            case WebMenuItemTagIgnoreSpelling:
            case WebMenuItemTagLearnSpelling:
            case WebMenuItemTagSearchInSpotlight:
            case WebMenuItemTagLookUpInDictionary:
            case 2024:
                [filteredMenu addObject:item];
                break;
            case WebMenuItemTagSearchWeb:
            {
                NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[item title]
                                                                   action:@selector(_searchInGoogle:)
                                                            keyEquivalent:[item keyEquivalent]];
                [menuItem setTarget:self];
                [filteredMenu addObject:menuItem];
                break;
            }

            default:
                if ([item isSeparatorItem]) {
                    if (![(NSMenuItem *) [filteredMenu lastObject] isSeparatorItem]) {
                        [filteredMenu addObject:item];
                    }
                }
                break;
        }
    }
    if (![(NSMenuItem *) [filteredMenu lastObject] isSeparatorItem]) {
        [filteredMenu addObject:[NSMenuItem separatorItem]];
    }
    {
        NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:@"Show Source of Message"
                                                           action:@selector(_showSource:)
                                                    keyEquivalent:@""];
        [menuItem setTarget:self];
        [filteredMenu addObject:menuItem];
    }
    return filteredMenu;
}

- (void) _searchInGoogle:(id)sender
{
    NSString * value;

    value = [[_webView selectedDOMRange] toString];

    if ([value length] > 0) {
        NSString * urlString = [NSString stringWithFormat:@"http://www.google.com/search?q=%@&ie=UTF-8&oe=UTF-8", [value djlURLEncode]];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    }
}

- (void) _showSource:(id)sender
{
    NSString * downloadFolder = [@"~/Downloads" stringByExpandingTildeInPath];
    NSString * basename = [NSString stringWithFormat:@"%@.eml", [[NSUUID UUID] UUIDString]];
    NSString * downloadFile = MCO_TO_OBJC(hermes::uniquePath(MCO_FROM_OBJC(String, downloadFolder), MCO_FROM_OBJC(String, basename)));

    HashMap * msgInfo = [self _messageDataWithUseDraftMessageID:NO];
    Data * data = (Data *) msgInfo->objectForKey(MCSTR("data"));
    data->writeToFile(MCO_FROM_OBJC(String, downloadFile));
    [[NSWorkspace sharedWorkspace] selectFile:downloadFile inFileViewerRootedAtPath:@""];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
    NSInteger modifierKeys = [[actionInformation objectForKey:WebActionModifierFlagsKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            [listener ignore];
            break;

        case WebNavigationTypeOther:
        default:
            [listener use];
            break;
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)newFrameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
    NSInteger modifierKeys = [[actionInformation objectForKey:WebActionModifierFlagsKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            [listener ignore];
            break;

        case WebNavigationTypeOther:
        default:
            [listener use];
            break;
    }
}

#pragma mark -
#pragma mark drag and drop management for WebView

- (BOOL) DJLComposerWebView_wantsPeriodicDraggingUpdates:(DJLComposerWebView *)webView
{
    return YES;
}

- (BOOL) _isInAttachmentDropZone:(id < NSDraggingInfo >)sender
{
    NSPoint location;

    location = [sender draggingLocation];
    location = [[[self window] contentView] convertPoint:location fromView:nil];
    NSRect bounds = [[[self window] contentView] bounds];
    return (location.y >= 10) && (location.y < ATTACHMENT_HEIGHT) && (location.x >= 10) && (location.x < bounds.size.width - 10);

}

- (NSDragOperation) _updateDragForWebView:(DJLComposerWebView *)webView draggingInfo:(id < NSDraggingInfo >)sender
{
    BOOL oldValue = _needsAttachmentDropZone;
    _needsAttachmentDropZone = [self _isInAttachmentDropZone:sender];
    if (![self _draggingInfoIsImage:sender]) {
        _needsAttachmentDropZone = YES;
    }
    if (oldValue != _needsAttachmentDropZone) {
        [self _layoutWindow];
    }
    if (_needsAttachmentDropZone) {
        [_webView removeDragCaret];
    }
    return _needsAttachmentDropZone ? NSDragOperationCopy : NSDragOperationNone;
}

- (NSDragOperation) DJLComposerWebView:(DJLComposerWebView *)webView draggingEntered:(id < NSDraggingInfo >)sender
{
    return [self _updateDragForWebView:webView draggingInfo:sender];
}

- (NSDragOperation) DJLComposerWebView:(DJLComposerWebView *)webView draggingUpdated:(id < NSDraggingInfo >)sender
{
    return [self _updateDragForWebView:webView draggingInfo:sender];
}

- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView draggingEnded:(id < NSDraggingInfo >)sender
{
    _needsAttachmentDropZone = NO;
    [self _layoutWindow];
    return NO;
}

- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView draggingExited:(id < NSDraggingInfo >)sender
{
    [self _updateDragForWebView:webView draggingInfo:sender];
    return NO;
}

- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView performDragOperation:(id < NSDraggingInfo >)sender
{
    NSArray * files;
    NSPasteboard * pasteboard;

    if (!_needsAttachmentDropZone) {
        return NO;
    }
    /*
    if (![self _isFileAttachmentDraggingInfo:sender inWebView:(webView != nil)])
        return NO;
     */

    pasteboard = [sender draggingPasteboard];

    files = [pasteboard propertyListForType:NSFilenamesPboardType];
    if ([files count] > 0) {
        [self _addFilenames:files];
    }
    else if ([[pasteboard types] containsObject:NSFilesPromisePboardType]) {
        [self _addPromiseFilenamesWithDragInfo:sender];
    }

    return YES;
}

- (BOOL) _draggingInfoIsImage:(id < NSDraggingInfo >)sender
{
    NSPasteboard * pasteboard;
    NSArray * files;
    BOOL isImage;

    pasteboard = [sender draggingPasteboard];
    files = [pasteboard propertyListForType:NSFilenamesPboardType];
    isImage = NO;
    if ([files count] > 0) {
        isImage = YES;
    }
    for(NSString * filename in files) {
        if (![self _filenameIsImage:filename]) {
            isImage = NO;
        }
    }
    if (isImage) {
        return YES;
    }

    return NO;
}

- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    if ([self _draggingInfoIsImage:sender]) {
        NSMutableArray * filenames;
        NSPasteboard * pasteboard;
        NSString * markupString;

        pasteboard = [sender draggingPasteboard];
        filenames = [[pasteboard propertyListForType:NSFilenamesPboardType] mutableCopy];
        if ([filenames count] == 0) {
            return NO;
        }

        markupString = [self _markupStringForImages:filenames];

        if (markupString != nil) {
            [pasteboard declareTypes:[NSArray arrayWithObject:NSHTMLPboardType] owner:nil];
            [pasteboard setString:markupString forType:NSHTMLPboardType];
        }
    }
    return NO;
}

#pragma mark -
#pragma mark drag and drop management for attachment view

- (BOOL) DJLAttachmentsCollectionView_wantsPeriodicDraggingUpdates:(DJLAttachmentsCollectionView *)view
{
    return YES;
}

- (NSDragOperation) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingEntered:(id < NSDraggingInfo >)sender
{
    return [self DJLComposerWebView:nil draggingEntered:sender];
}

- (NSDragOperation) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingUpdated:(id < NSDraggingInfo >)sender
{
    return [self DJLComposerWebView:nil draggingUpdated:sender];
}

- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingEnded:(id < NSDraggingInfo >)sender
{
    return [self DJLComposerWebView:nil draggingEnded:sender];
}

- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingExited:(id < NSDraggingInfo >)sender
{
    return [self DJLComposerWebView:nil draggingExited:sender];
}

- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view performDragOperation:(id < NSDraggingInfo >)sender
{
    return [self DJLComposerWebView:nil performDragOperation:sender];
}

- (BOOL)DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view keyPress:(NSEvent *)event
{
    if ([event keyCode] == 51) {
        [[_attachmentsView selectionIndexes] enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL * stop) {
            NSString * filename = [_attachments objectAtIndex:idx];
            [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
            [_attachments removeObjectAtIndex:idx];
        }];
        [self _updateAttachments];
        [self _messageModified];
        return YES;
    }
    else if ([[event characters] isEqualToString:@" "]) {
        [self _quicklook];
        return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark toolbar delegate

- (void) _scrolled
{
    if (_type == DJLComposerWindowControllerTypeNew) {
        return;
    }

    CGFloat alpha = 0.0;
    NSScrollView * mainScrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    if ([[mainScrollView contentView] bounds].origin.y > 50.) {
        alpha = 1.0;
    }
    else if ([[mainScrollView contentView] bounds].origin.y < 0) {
        alpha = 0.0;
    }
    else {
        alpha = [[mainScrollView contentView] bounds].origin.y / 50.;
    }
    [_toolbarView setSeparatorAlphaValue:alpha];
}

- (void) _updateSendButtonEnabled
{
    if (_type == DJLComposerWindowControllerTypeIndeterminate) {
        [_toolbarView setSendButtonEnabled:NO];
        return;
    }

    if ((_type == DJLComposerWindowControllerTypeReply) && !_repliedMessageRendered) {
        [_toolbarView setSendButtonEnabled:NO];
        return;
    }

    [_toolbarView setSendButtonEnabled:YES];
}

- (void) DJLComposerToolbarViewSendMessage:(DJLComposerToolbarView *)view
{
    [self _sendMessage];
}

- (void) DJLComposerToolbarViewAddAttachment:(DJLComposerToolbarView *)view
{
    [self _addAttachment];
}

- (void) DJLComposerToolbarViewFocusWebView:(DJLComposerToolbarView *)view
{
    //[[self window] makeFirstResponder:_webView];
}

- (void) DJLComposerToolbarViewCancelSearch:(DJLComposerToolbarView *)view
{
    [self _cancelSearch];
    //[[self window] makeFirstResponder:_webView];
}

- (void) DJLComposerToolbarViewSearch:(DJLComposerToolbarView *)view
{
    [self _search:[_toolbarView searchString]];
}

- (void) DJLComposerToolbarViewToggleCc:(DJLComposerToolbarView *)view
{
    _showCcEnabled = !_showCcEnabled;
    if (!_showCcEnabled) {
        [_ccField setAddresses:nil];
        [_bccField setAddresses:nil];
    }
    else {
        if (!_replyShowRecipientEditor) {
            _replyShowRecipientEditor = YES;
            [[_webView windowScriptObject] callWebScriptMethod:@"objcHideStaticRecipient" withArguments:nil];
        }
    }
    [self _layoutWindow];
}

- (void) DJLComposerToolbarView:(DJLComposerToolbarView *)view accountSelected:(hermes::Account *)account emailAlias:(NSString *)emailAlias
{
    _account->removeDraftForSentMessage(MCO_FROM_OBJC(String, _messageID));
    BOOL signatureChanged = [self _hasSignatureChanged];
    [self setEmailAlias:emailAlias];
    if (!signatureChanged) {
        [self _setupSignature];
    }
    [self _saveAfterDelay];
}

- (void) DJLComposerToolbarView:(DJLComposerToolbarView *)view giphySelected:(NSDictionary *)item
{
    NSString * urlString = item[@"images"][@"downsized_medium"][@"url"];
    NSNumber * width = item[@"images"][@"downsized_medium"][@"width"];
    NSNumber * height = item[@"images"][@"downsized_medium"][@"height"];
    [[_webView windowScriptObject] callWebScriptMethod:@"objcAddGiphyImage" withArguments:@[urlString, width, height]];
}

- (void) _cancelSearch
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcClearSearchResult" withArguments:nil];
}

- (void) _search:(NSString *)searchString
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcHighlightSearchResult" withArguments:@[searchString]];
}

#pragma mark -
#pragma mark attachment management

- (void) _addAttachment
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:YES];
    __weak typeof(self) weakSelf = self;
    [(DJLWindow *) [self window] _workaroundSheetLayoutTrafficLights];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton) {
            return;
        }

        NSMutableArray * files = [NSMutableArray array];
        for(NSURL * url in [panel URLs]) {
            [files addObject:[url path]];
        }
        [weakSelf _addFilenames:files];
    }];
}

- (void) _updateAttachments
{
    NSMutableArray * items = [NSMutableArray array];
    for(NSString * filename in _attachments) {
        [items addObject:filename];
    }
    [_attachmentsView setContent:items];
    [self _layoutWindow];
}

- (void) _addFilenames:(NSArray *)filenames
{
    NSMutableArray * copiedFiles = [NSMutableArray array];
    for(NSString * filename in filenames) {
        NSString * copiedFilename = [self _attachmentPathWithName:[filename lastPathComponent]];
        [[NSFileManager defaultManager] copyItemAtPath:filename toPath:copiedFilename error:NULL];
        [copiedFiles addObject:copiedFilename];
    }
    [_attachments addObjectsFromArray:copiedFiles];
    [self _updateAttachments];
    [self _messageModified];
}

- (NSArray *) _addFilesWithData:(NSArray *)filesWithData
{
    NSMutableArray * copiedFiles = [NSMutableArray array];
    for(NSDictionary * info in filesWithData) {
        NSString * name = info[@"name"];
        if (name == nil) {
            name = @"Untitled";
        }
        NSData * data = info[@"data"];
        NSString * copiedFilename = [self _attachmentPathWithName:name];
        [data writeToFile:copiedFilename atomically:NO];
        [copiedFiles addObject:copiedFilename];
    }
    [_attachments addObjectsFromArray:copiedFiles];
    [self _updateAttachments];
    [self _messageModified];
    return copiedFiles;
}

- (NSString *) _temporaryFolder
{
    if (_temporaryFolder != nil) {
        return _temporaryFolder;
    }

    _temporaryFolder = [[DJLPathManager sharedManager] temporaryFolder];
    return _temporaryFolder;
}

- (void) _addPromiseFilenamesWithDragInfo:(id < NSDraggingInfo >)sender
{
    NSString * tmpDir = [self _temporaryFolder];
    NSArray * names = [sender namesOfPromisedFilesDroppedAtDestination:[NSURL fileURLWithPath:tmpDir]];

    for(NSString * name in names) {
        NSString * path;

        path = [tmpDir stringByAppendingPathComponent:name];
        [_attachments addObject:path];
    }

    [self _updateAttachments];
    [self _messageModified];
}

- (NSBitmapImageRep*) _mmGenerateBitmapRepForImage:(NSImage *)image
{
    CGImageRef cgImage;

    cgImage =  [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage != NULL) {
        return [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    }

    NSSize size = [image size];

    int rowBytes = ((int)(ceil(size.width)) * 4 + 0x0000000F) & ~0x0000000F; // 16-byte aligned

    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                         pixelsWide:size.width
                                                                         pixelsHigh:size.height
                                                                      bitsPerSample:8
                                                                    samplesPerPixel:4
                                                                           hasAlpha:YES
                                                                           isPlanar:NO
                                                                     colorSpaceName:NSCalibratedRGBColorSpace
                                                                       bitmapFormat:0
                                                                        bytesPerRow:rowBytes
                                                                       bitsPerPixel:32];
    
    if ( imageRep == nil )
    return nil;
    
    NSGraphicsContext* imageContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:imageContext];
    
    [image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    
    [NSGraphicsContext restoreGraphicsState];
    // returns a 32-bit bitmap rep of the receiver, whatever its original format. The image rep is not added to the image.
    
    return imageRep;
}

- (CGImageRef) _cgImageForImage:(NSImage *)image
{
    NSImage * imageCopy = [image copy];

    for(NSImageRep * rep in [imageCopy representations]) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            NSBitmapImageRep * bitmapRep;

            bitmapRep = (NSBitmapImageRep *) rep;

            return [bitmapRep CGImage];
        }
    }

    [imageCopy addRepresentation:[self _mmGenerateBitmapRepForImage:imageCopy]];
    CGImageRef result = [(NSBitmapImageRep *) [[imageCopy representations] lastObject] CGImage];

    return result;
}

- (NSString *) _pngFilenameFromFilename:(NSString *)filename
{
    NSImage * image = [[NSImage alloc] initWithContentsOfFile:filename];

    NSString * basename = [filename lastPathComponent];
    basename = [basename stringByDeletingPathExtension];
    basename = [basename stringByAppendingPathExtension:@"png"];

    NSString * tmpFilename = [self _attachmentPathWithName:basename];

    NSURL * fileURL = [[NSURL alloc] initFileURLWithPath:tmpFilename];
    CGImageDestinationRef destinationRef = CGImageDestinationCreateWithURL((CFURLRef)fileURL, (CFStringRef)@"public.png" , 1, NULL);
#warning TODO: there's probably a more efficient way to convert an image
    CGImageDestinationAddImage(destinationRef, [self _cgImageForImage:image], NULL);
    CGImageDestinationFinalize(destinationRef);
    CFRelease(destinationRef);

    return tmpFilename;
}

- (BOOL) _filenameIsImage:(NSString *)filename
{
    NSString * ext;
    static NSMutableArray * imageExts = nil;
    if (imageExts == nil) {
        imageExts = [[NSMutableArray alloc] init];
        [imageExts addObject:@"jpg"];
        [imageExts addObject:@"jpeg"];
        [imageExts addObject:@"png"];
        [imageExts addObject:@"gif"];
        [imageExts addObject:@"tiff"];
        [imageExts addObject:@"tif"];
    }

    ext = [[filename pathExtension] lowercaseString];
    for(NSString * currentExt in imageExts) {
        if ([ext isEqualToString:currentExt])
        return YES;
    }

    return NO;
}

- (NSSize) _imageSizeWithFilename:(NSString *)filename
{
    NSImage * image;
    CGImageRef cgImage;
    NSSize size;

    image = [[NSImage alloc] initWithContentsOfFile:filename];
#warning TODO: there's probably a more efficient way to get the size of an image
    cgImage = [self _cgImageForImage:image];
    size.width = CGImageGetWidth(cgImage);
    size.height = CGImageGetHeight(cgImage);

    return size;
}

- (NSSize) _fitImageSizeWithFilename:(NSString *)filename
{
    NSSize size;
    CGFloat height;
    CGFloat width;

    size = [self _imageSizeWithFilename:filename];
    width = 460;
    if (size.width < width) {
        width = size.width;
    }
    height = width * size.height / size.width;

    return NSMakeSize(width, height);
}

- (NSString *) _markupStringForImages:(NSArray *)imagesFilenames
{
    NSMutableArray * filenames;
    NSMutableArray * imageFilenames;
    NSMutableDictionary * contentIDs;
    NSMutableArray * tiffToPngFilenames;
    NSMutableArray * filenamesToRemove;

    filenames = [NSMutableArray arrayWithArray:imagesFilenames];
    imageFilenames = [NSMutableArray array];

    contentIDs = [[NSMutableDictionary alloc] init];

    tiffToPngFilenames = [NSMutableArray array];
    filenamesToRemove = [NSMutableArray array];

    for(NSString * filename in filenames) {
        // detect tiff filenames
        if ([[MCOAttachment mimeTypeForFilename:filename] isEqualToString:@"image/tiff"]) {
            [filenamesToRemove addObject:filename];
        }
    }

    [filenames removeObjectsInArray:filenamesToRemove];

    for(NSString * filename in filenamesToRemove) {
        // replaced tiff files by png
        NSString * newFilename = [self _pngFilenameFromFilename:filename];
        [tiffToPngFilenames addObject:newFilename];
        [filenames addObject:newFilename];
    }

    for(NSString * filename in filenames) {
        if ([self _filenameIsImage:filename]) {
            [imageFilenames addObject:filename];
            [contentIDs setObject:[[NSUUID UUID] UUIDString] forKey:filename];
        }
    }

    [self _addFilenames:filenames withContentIDs:contentIDs];

    NSMutableString * markupString;

    markupString = nil;
    for(NSString * filename in filenames) {
        NSString * cid;

        cid = [contentIDs objectForKey:filename];
        if (cid == nil) {
            continue;
        }

        if (markupString == nil) {
            markupString = [NSMutableString string];
        }

        NSSize size;
        size = [self _fitImageSizeWithFilename:filename];
        [markupString appendFormat:@"<img x-dejalu-original-src=\"cid:%@\" width=\"%u\" height=\"%u\"/>\n", cid, (unsigned int) size.width, (unsigned int) size.height];
    }

    return markupString;
}

- (void) _addFilenames:(NSArray *)filenames withContentIDs:(NSDictionary *)contentIDs
{
    for(NSString * filename in filenames) {
        NSString * contentID = contentIDs[filename];
        [_cidFiles setObject:filename forKey:contentID];
    }
}

- (NSString *) _attachmentPathWithName:(NSString *)name
{
    NSString * folder = [self _temporaryFolder];
    return MCO_TO_OBJC(hermes::uniquePath(MCO_FROM_OBJC(String, folder), MCO_FROM_OBJC(String, name)));
}

#pragma mark -
#pragma mark message saving

- (void) _messageModified
{
    [self setDocumentEdited:YES];
    _modified = YES;
    _modifiedOnce = YES;

    [self _saveAfterDelay];
}

- (void) _saveAfterDelay
{
    if (_saveScheduled) {
        return;
    }
    if (_localSaving) {
        _pendingSave = YES;
        return;
    }

    //NSLog(@"scheduled save");
    _saveScheduled = YES;
    [self performSelector:@selector(_saveNow) withObject:nil afterDelay:2.];
}

- (void) _saveNow
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_saveNow) object:nil];
    _saveScheduled = NO;
    [self _saveAndPush:NO];
}

- (NSString *) _userAgent
{
    return nil;

//    NSString * shortVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
//    NSString * name = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
//    NSString * build = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleVersionKey];
//    return [NSString stringWithFormat:@"%@ %@ (build %@)", name, shortVersion, build];
}

- (HashMap *) _messageDataWithUseDraftMessageID:(BOOL)useDraftMessageID
{
    MessageBuilder * builder = new MessageBuilder();
    builder->header()->setUserAgent(MCO_FROM_OBJC(String, [self _userAgent]));
    builder->header()->setInReplyTo(MCO_FROM_OBJC(Array, _inReplyTo));
    builder->header()->setReferences(MCO_FROM_OBJC(Array, _references));
    Address * address = [self _address];
    builder->header()->setFrom(address);
    builder->header()->setTo(MCO_FROM_OBJC(Array, [_toField addresses]));
    builder->header()->setCc(MCO_FROM_OBJC(Array, [_ccField addresses]));
    if ([[_bccField addresses] count] > 0) {
        builder->header()->setBcc(MCO_FROM_OBJC(Array, [_bccField addresses]));
    }
    else {
        builder->header()->setBcc(NULL);
    }
    builder->header()->setSubject([[_subjectField stringValue] mco_mcString]);
    if (useDraftMessageID) {
        builder->header()->setMessageID([_messageID mco_mcString]);
    }
    else {
        builder->header()->setMessageID([[self _generateMessageID] mco_mcString]);
    }
    NSDictionary * content = nil;
    if (!useDraftMessageID) {
        content = [self _htmlMessageContentAndClean:YES];
    }
    else {
        content = [self _htmlMessageContentAndClean:NO];
    }
    DJLAssert(content != nil);
    NSString * html = [content objectForKey:@"html"];
    NSArray * cidUrls = [content objectForKey:@"cid-urls"];
    NSDictionary * fakeUrls = [content objectForKey:@"fake-urls"];
    NSDictionary * headerMeta = [content objectForKey:@"header-meta"];
    if (useDraftMessageID && (headerMeta != nil)) {
        NSData * data = [NSJSONSerialization dataWithJSONObject:headerMeta options:0 error:NULL];
        NSString * headerValue = [data base64EncodedStringWithOptions:0];
        if (headerValue != nil) {
            builder->header()->setExtraHeader(MCSTR("X-DejaLu-Reply"), MCO_FROM_OBJC(String, headerValue));
        }
    }

    builder->setHTMLBody([html mco_mcString]);
    for(NSString * filename in _attachments) {
        builder->addAttachment(Attachment::attachmentWithContentsOfFile([filename mco_mcString]));
    }
    for(NSString * urlString in cidUrls) {
        NSURL * url = [NSURL URLWithString:urlString];
        if (url == nil) {
            continue;
        }
        NSString * contentID = [url resourceSpecifier];
        if (contentID == nil) {
            continue;
        }
        NSString * filename = [_cidFiles objectForKey:contentID];
        if (filename == nil) {
            continue;
        }
        if ([[MCOAttachment mimeTypeForFilename:filename] isEqualToString:@"image/tiff"]) {
            // convert to PNG.
            filename = [self _pngFilenameFromFilename:filename];
        }
        Attachment * attachment = Attachment::attachmentWithContentsOfFile([filename mco_mcString]);
        NSString * mimeType = _mimeTypes[filename];
        if (mimeType != nil) {
            attachment->setMimeType(MCO_FROM_OBJC(String, mimeType));
        }
        attachment->setContentID(MCO_FROM_OBJC(String, contentID));
        builder->addRelatedAttachment(attachment);
    }
    for(NSString * fakeUrl in fakeUrls) {
        WebResource * res = [[[_webView mainFrame] dataSource] subresourceForURL:[NSURL URLWithString:fakeUrl]];
        NSString * mimeType = [res MIMEType];
        Attachment * attachment = NULL;
        if ([mimeType isEqualToString:@"image/tiff"]) {
            NSString * tmpFilename = [self _attachmentPathWithName:@"Untitled.tif"];
            [[res data] writeToFile:tmpFilename atomically:NO];
            tmpFilename = [self _pngFilenameFromFilename:tmpFilename];
            attachment = Attachment::attachmentWithContentsOfFile([tmpFilename mco_mcString]);
            mimeType = @"image/png";
        }
        else {
            attachment = Attachment::attachmentWithData(MCSTR("Untitled"),  MCO_FROM_OBJC(Data, [res data]));
        }
        if (mimeType != nil) {
            attachment->setMimeType(MCO_FROM_OBJC(String, mimeType));
        }
        attachment->setContentID(MCO_FROM_OBJC(String, fakeUrls[fakeUrl]));
        builder->addRelatedAttachment(attachment);
    }

    Data * resultData = builder->data();
    HashMap * result = HashMap::hashMap();
    result->setObjectForKey(MCSTR("data"), resultData);
    result->setObjectForKey(MCSTR("messageid"), builder->header()->messageID());

    MC_SAFE_RELEASE(builder);

    return result;
}

- (void) _saveAndPush:(BOOL)push
{
    if (_account->draftsFolderPath() == NULL) {
        [self _showAlertDraftAndClose:NO];
        return;
    }

    if (_localSaving) {
        _pendingSave = YES;
        return;
    }

    _localSaving = YES;

    [self setDocumentEdited:NO];
    _modified = NO;

    //NSLog(@"save document");
    HashMap * msgInfo = [self _messageDataWithUseDraftMessageID:YES];
    Data * data = (Data *) msgInfo->objectForKey(MCSTR("data"));
    String * messageID = (String *) msgInfo->objectForKey(MCSTR("messageid"));
    _account->saveMessageToDraft(messageID, data, push);
}

- (void) _messageSaved
{
    _localSaving = NO;

    if (_pendingSave) {
        _pendingSave = NO;
        [self _saveAfterDelay];
        return;
    }

    if (_sendAfterSave) {
        _sendAfterSave = NO;
        [self _sendMessageAfterSave];
    }
}

#pragma mark -
#pragma mark message send

- (void) _sendMessage
{
    if (_account->draftsFolderPath() == NULL) {
        [self _showAlertDraftAndClose:NO];
        return;
    }

    if (([[_toField addresses] count] == 0) && ([[_ccField addresses] count] == 0) && ([[_bccField addresses] count] == 0)) {
        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please enter at least one recipient"];
        [alert addButtonWithTitle:@"OK"];

        [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
            // do nothing.
        }];
        return;
    }

    NSString * actionString = [NSString stringWithFormat:@"%u", (unsigned int) [_cidFiles count]];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"ComposerSendInlineAttachments" action:actionString label:@"Number of inline attachments in sent message" value:@(0)];
    actionString = [NSString stringWithFormat:@"%u", (unsigned int) [_attachments count]];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"ComposerSendAttachments" action:actionString label:@"Number of attachments in sent message" value:@(0)];
    actionString = [NSString stringWithFormat:@"%u", (unsigned int) [[_toField addresses] count]];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"ComposerSendRecipients" action:actionString label:@"Number of recipients in sent message" value:@(0)];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"Send" label:@"Send a message" value:@(0)];

    for(MCOAddress * address in [_toField addresses]) {
        [[DJLAddressBookManager sharedManager] useAddress:address];
    }
    for(MCOAddress * address in [_ccField addresses]) {
        [[DJLAddressBookManager sharedManager] useAddress:address];
    }
    for(MCOAddress * address in [_bccField addresses]) {
        [[DJLAddressBookManager sharedManager] useAddress:address];
    }

    [[self window] orderOut:nil];
    
    if (_modified) {
        _sendAfterSave = YES;
        [self _saveNow];
    }
    else if (_localSaving) {
        _sendAfterSave = YES;
        // waiting for save to finish.
    }
    else {
        [self _sendMessageAfterSave];
    }
}

- (void) _sendMessageAfterSave
{
    HashMap * msgInfo = [self _messageDataWithUseDraftMessageID:NO];
    Data * data = (Data *) msgInfo->objectForKey(MCSTR("data"));
    _account->sendMessage([_messageID mco_mcString], data);

    [self close];
}

- (NSDictionary *) _htmlMessageContentAndClean:(BOOL)cleanForSend
{
    NSString * result = nil;
    if ((_type == DJLComposerWindowControllerTypeReply) || (_type == DJLComposerWindowControllerTypeForward)) {
        result = [[_webView windowScriptObject] callWebScriptMethod:@"objcReplyHTMLMessageContent" withArguments:@[[NSNumber numberWithBool:cleanForSend]]];
    }
    else {
        result = [[_webView windowScriptObject] callWebScriptMethod:@"objcHTMLMessageContent" withArguments:@[[NSNumber numberWithBool:cleanForSend]]];
    }
    DJLAssert(result != nil);
    NSDictionary * content = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    return content;
}

- (void) _notifyMessageSavedWithFolderID:(int64_t)folderID messageID:(NSString *)messageID
{
    if (folderID != _account->folderIDForPath(_account->draftsFolderPath())) {
        return;
    }
    if (![messageID isEqualToString:_messageID]) {
        return;
    }

    [self _messageSaved];
}

#pragma mark -
#pragma mark JS runtime

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel
{
    NSString * selectorName = NSStringFromSelector(sel);

    if ([selectorName isEqualToString:@"jsRunCommand:"])
        return NO;

    return YES;
}

- (void) jsRunCommand:(NSString *)jsonCommand
{
    static NSMutableSet * authorizedCommands = nil;
    if (authorizedCommands == nil) {
        authorizedCommands = [[NSMutableSet alloc] init];
        [authorizedCommands addObjectsFromArray:@[@"jsShowRecipientEditor",
                                                  @"jsShowSubjectEditor",
                                                  @"jsLoadImage",
                                                  @"jsLoadDraftMessage",
                                                  @"jsLoadDraftAttachments",
                                                  @"jsLoadMessages"]];
    }

    NSData * data = [jsonCommand dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary * commandInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSString * command = [commandInfo objectForKey:@"command"];

    if (![authorizedCommands containsObject:command]) {
        NSLog(@"call from JS not authorized - %@", command);
        return;
    }

    command = [command stringByAppendingString:@":"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(command) withObject:commandInfo];
#pragma clang diagnostic pop
}

- (void) jsShowRecipientEditor:(NSDictionary *)parameters
{
    _replyShowRecipientEditor = YES;
    [self _layoutWindow];
    [[self window] makeFirstResponder:_toField];
}

- (void) jsShowSubjectEditor:(NSDictionary *)parameters
{
    _replyShowRecipientEditor = YES;
    [self _layoutWindow];
    [[self window] makeFirstResponder:_subjectField];
}

- (void) jsLoadImage:(NSDictionary *)parameters
{
    NSString * uuid = [parameters objectForKey:@"uuid"];
    NSString * urlString = [parameters objectForKey:@"url"];
    NSURL * url = [NSURL URLWithString:urlString];

    NSString * contentID = [url resourceSpecifier];
    NSString * filename = [_cidFiles objectForKey:contentID];
    if (filename == nil) {
        NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
        return;
    }

    NSData * data = [NSData dataWithContentsOfFile:filename];
    NSData * base64Data = [data base64EncodedDataWithOptions:0];
    NSString * base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    result[@"base64"] = base64String;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
}

- (void) jsLoadMessages:(NSDictionary *)parameters
{
    HashMap * foldersScores = HashMap::hashMap();
    int64_t draftFolderID = _account->folderIDForPath(_account->draftsFolderPath());
    int64_t trashFolderID = _account->folderIDForPath(_account->trashFolderPath());
    if (draftFolderID != -1) {
        foldersScores->setObjectForKey(Value::valueWithLongLongValue(draftFolderID),
                                       Value::valueWithIntValue(2));
    }
    if (trashFolderID != -1) {
        foldersScores->setObjectForKey(Value::valueWithLongLongValue(trashFolderID),
                                       Value::valueWithIntValue(-1));
    }
    MailDBConversationMessagesOperation * op = _account->messagesForPeopleConversationOperation(_draftMessageToLoadConversationID, foldersScores);
    op->setCallback(_callback);
    op->start();

    _loadConversationMessagesOp->addObject(op);
    [_parametersForOp setObject:parameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
}

- (void) _jsLoadMessagesFinished:(MailDBConversationMessagesOperation *)op
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    String * json = JSON::objectToJSONString(op->messages());
    //NSLog(@"%@", MCO_TO_OBJC(json));
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, MCO_TO_OBJC(json)]];
    _loadConversationMessagesOp->removeObject(op);
    [_parametersForOp removeObjectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
}

#if 0
- (void) jsLoadImage:(NSDictionary *)parameters
{
    NSDictionary * info = [parameters objectForKey:@"messageinfo"];
    NSString * urlString = [parameters objectForKey:@"url"];
    NSURL * url = [NSURL URLWithString:urlString];
    NSMutableDictionary * opParameters = [parameters mutableCopy];

    AbstractPart * part = NULL;
    AbstractMessage * imapMsg = (IMAPMessage *) Object::objectWithSerializable(MCO_FROM_OBJC(HashMap, [info objectForKey:@"msg"]));
    if ([[url scheme] isEqualToString:@"x-dejalu-icon"]) {
        NSString * ext = [url resourceSpecifier];
        NSDictionary * iconInfo = GetIconInfo(ext);

        NSMutableDictionary * result = [NSMutableDictionary dictionary];
        NSData * imageData = iconInfo[@"data"];
        NSData * base64Data = [imageData base64EncodedDataWithOptions:0];
        NSString * base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        result[@"base64"] = base64String;
        result[@"height"] = iconInfo[@"height"];
        result[@"width"] = iconInfo[@"width"];
        result[@"uniqueID"] = parameters[@"uniqueID"];
        result[@"filename"] = parameters[@"filename"];

        NSString * uuid = [parameters objectForKey:@"uuid"];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
        return;
    }
    else if ([MCOCIDURLProtocol isCID:url]) {
        NSString * uuid = [parameters objectForKey:@"uuid"];
        NSString * contentID = [url resourceSpecifier];
        NSString * filename = [_cidFiles objectForKey:contentID];
        if (filename != nil) {
            NSData * data = [NSData dataWithContentsOfFile:filename];
            NSData * base64Data = [data base64EncodedDataWithOptions:0];
            NSString * base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
            NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
            result[@"base64"] = base64String;
            NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
            NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
        }

        part = imapMsg->partForContentID([[url resourceSpecifier] mco_mcString]);
    }
    else if ([MCOCIDURLProtocol isXMailcoreImage:url]) {
        part = imapMsg->partForUniqueID([[url resourceSpecifier] mco_mcString]);
    }
    if (part != NULL) {
        [opParameters setObject:MCO_TO_OBJC(part->mimeType()) forKey:@"mimeType"];
    }
    if (part == NULL) {
        NSMutableDictionary * result = [NSMutableDictionary dictionary];

        result[@"uniqueID"] = parameters[@"uniqueID"];
        result[@"filename"] = parameters[@"filename"];

        NSString * uuid = [parameters objectForKey:@"uuid"];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
        return;
    }

    if (part->className()->isEqual(MCSTR("mailcore::IMAPPart"))) {
        IMAPPart * imapPart = (IMAPPart *) part;
        String * partID = imapPart->partID();
        if (partID == NULL) {
            NSString * uuid = [parameters objectForKey:@"uuid"];
            [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
            [_parametersForOp removeObjectForKey:uuid];
            return;
        }
        NSNumber * nbRowID = info[@"rowid"];
        int64_t rowid = [nbRowID longLongValue];
        MailDBRetrievePartOperation * op = _imapSynchronizer->storage()->dataForPartOperation(rowid, partID);
        op->setUniqueID(imapPart->uniqueID());
        op->setFilename(imapPart->filename());
        op->setCallback(_callback);
        op->start();
        _loadImagesOp->addObject(op);
        [_parametersForOp setObject:opParameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    }
    else if (part->className()->isEqual(MCSTR("mailcore::Attachment"))) {
        Attachment * localPart = (Attachment *) part;
        String * uniqueID = localPart->uniqueID();
        if (uniqueID == NULL) {
            NSString * uuid = [parameters objectForKey:@"uuid"];
            [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
            [_parametersForOp removeObjectForKey:uuid];
            return;
        }
        NSNumber * nbRowID = info[@"rowid"];
        int64_t rowid = [nbRowID longLongValue];
        MailDBRetrievePartOperation * op = _imapSynchronizer->storage()->dataForLocalPartOperation(rowid, uniqueID);
        op->setFilename(localPart->filename());
        op->setCallback(_callback);
        op->start();
        _loadImagesOp->addObject(op);
        [_parametersForOp setObject:opParameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    }
}

#define ICONSIZE 64

static NSDictionary * GetIconInfo(NSString * ext)
{
    NSImage * icon = [[NSWorkspace sharedWorkspace] iconForFileType:ext];

    NSImage * scratch;
    scratch = [[NSImage alloc] initWithSize:NSMakeSize(ICONSIZE, ICONSIZE)];

    [scratch lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [icon drawInRect:NSMakeRect(0, 0, ICONSIZE, ICONSIZE) fromRect:NSMakeRect(0, 0, [icon size].width, [icon size].height) operation:NSCompositeSourceOver fraction:1.0];
    NSBitmapImageRep * output = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,ICONSIZE, ICONSIZE)];

    NSData * bitmapData;
    NSMutableDictionary * info = [[NSMutableDictionary alloc] init];
    //[info setObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    bitmapData = [output representationUsingType:NSPNGFileType
                                      properties:info];
    [scratch unlockFocus];

    NSDictionary * imageInfo = @{@"data": bitmapData, @"height": [NSNumber numberWithFloat:ICONSIZE], @"width": [NSNumber numberWithFloat:ICONSIZE]};
    return imageInfo;
}

static NSDictionary * GetImageInfo(NSData * data, BOOL allowResize)
{
    CGImageSourceRef imageSource;
    CGImageRef thumbnail;
    CGRect resizedRect;
    NSMutableDictionary * info;

    imageSource = CGImageSourceCreateWithData((CFDataRef) data, NULL);
    if (imageSource == NULL) {
        return nil;
    }

    info = [[NSMutableDictionary alloc] init];
    [info setObject:(id) kCFBooleanTrue forKey:(__bridge id) kCGImageSourceCreateThumbnailWithTransform];
    [info setObject:(id) kCFBooleanTrue forKey:(__bridge id) kCGImageSourceCreateThumbnailFromImageAlways];
    thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef) info);
    if (thumbnail == NULL) {
        CFRelease(imageSource);
        return NULL;
    }

    resizedRect = CGRectMake(0, 0, CGImageGetWidth(thumbnail), CGImageGetHeight(thumbnail));
    if ((resizedRect.size.width == 0.) || (resizedRect.size.height == 0.)) {
        if (thumbnail != NULL) {
            CFRelease(thumbnail);
        }
        CFRelease(imageSource);
        return nil;
    }

    if (allowResize) {
        if ((resizedRect.size.width > 170) && (resizedRect.size.height > 170)) {
            CGFloat ratio = resizedRect.size.width / resizedRect.size.height;
            if (ratio > 1.0) {
                resizedRect.size.height = 170;
                resizedRect.size.width = ceilf(resizedRect.size.height * ratio);
            }
            else {
                resizedRect.size.width = 170;
                resizedRect.size.height =  ceilf(resizedRect.size.width / ratio);
            }
        }
    }
    else {
        if ((resizedRect.size.width > 580) || (resizedRect.size.height > 400)) {
            CGFloat ratio = resizedRect.size.width / resizedRect.size.height;
            if (ratio > 1) {
                if (resizedRect.size.width > 580) {
                    resizedRect.size.width = 580;
                    resizedRect.size.height =  ceilf(resizedRect.size.width / ratio);
                }
            }
            else {
                if (resizedRect.size.height > 400) {
                    resizedRect.size.height = 400;
                    resizedRect.size.width = ceilf(resizedRect.size.height * ratio);
                }
            }
        }
    }

    NSImage * scratch;
    scratch = [[NSImage alloc] initWithSize:NSMakeSize(resizedRect.size.width, resizedRect.size.height)];

    [scratch lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    CGContextDrawImage([[NSGraphicsContext currentContext] CGContext], CGRectMake(0, 0, resizedRect.size.width, resizedRect.size.height), thumbnail);
    NSBitmapImageRep * output = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,resizedRect.size.width, resizedRect.size.height)];

    NSData * bitmapData;
    info = [[NSMutableDictionary alloc] init];
    //[info setObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    bitmapData = [output representationUsingType:NSPNGFileType
                                      properties:info];
    [scratch unlockFocus];

    CFRelease(thumbnail);
    CFRelease(imageSource);

    NSDictionary * imageInfo = @{@"data": bitmapData, @"height": [NSNumber numberWithFloat:resizedRect.size.height], @"width": [NSNumber numberWithFloat:resizedRect.size.width]};
    return imageInfo;
}

- (void) _jsLoadImageFinished:(MailDBRetrievePartOperation *)op
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    NSNumber * allowResize = [parameters objectForKey:@"allowResize"];

    NSDictionary * msg = [parameters objectForKey:@"msg"];
    NSNumber * nbRowID = msg[@"rowid"];
    Data * data = op->content();
    if (data == NULL) {
        NSNumber * nbFolderID = msg[@"folderid"];
        _imapSynchronizer->fetchMessagePart([nbFolderID longLongValue], [nbRowID longLongValue], op->partID(), true);
    }

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    //    NSString * mimeType = [parameters objectForKey:@"mimeType"];
    //    if (mimeType != nil) {
    //        [result setObject:mimeType forKey:@"mimeType"];
    //    }
    if (data != NULL) {
        NSDictionary * imageInfo = GetImageInfo([NSData mco_dataWithMCData:data], [allowResize boolValue]);
        if (imageInfo != nil) {
            NSData * imageData = imageInfo[@"data"];
            NSData * base64Data = [imageData base64EncodedDataWithOptions:0];
            NSString * base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
            result[@"base64"] = base64String;
            result[@"height"] = imageInfo[@"height"];
            result[@"width"] = imageInfo[@"width"];
        }
    }
    //result[@"rowid"] = nbRowID;
    result[@"uniqueID"] = MCO_TO_OBJC(op->uniqueID());
    result[@"filename"] = MCO_TO_OBJC(op->filename());
    //NSLog(@"%@", result);
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
    _loadImagesOp->removeObject(op);
    [_parametersForOp removeObjectForKey:uuid];
}
#endif

- (void) jsLoadDraftMessage:(NSDictionary *)parameters
{
    NSNumber * nbMessageRowID = [parameters objectForKey:@"messagerowid"];
    int64_t rowid = [nbMessageRowID longLongValue];
    _draftMessageToLoadRowID = rowid;
    MailDBMessageInfoOperation * op = _account->messageInfoOperation(rowid, Set::set());
    op->setCallback(_callback);
    op->start();

    _loadMessagesOp->addObject(op);
    [_parametersForOp setObject:parameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
}

- (void) _jsLoadDraftMessageFinished:(MailDBMessageInfoOperation *)op
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    NSString * uuid = [parameters objectForKey:@"uuid"];

    HashMap * info = op->messageInfo();
    if (info == NULL) {
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
        _loadMessagesOp->removeObject(op);
        [_parametersForOp removeObjectForKey:uuid];
        [self _loadDraftDoneWithError:hermes::ErrorMessageNotFound];
        return;
    }

    HashMap * serializedMsg = (HashMap *) info->objectForKey(MCSTR("msg"));
    AbstractMessage * msg = (AbstractMessage *) Object::objectWithSerializable(serializedMsg);
    [self setEmailAlias:[self _aliasForDraftHeader:msg->header()]];

    NSNumber * nbMessageRowID = [parameters objectForKey:@"messagerowid"];
    if (info->objectForKey(MCSTR("content")) == NULL) {
        NSNumber * nbFolderID = [parameters objectForKey:@"folderid"];
        _account->fetchMessageSummary([nbFolderID longLongValue], [nbMessageRowID longLongValue], true);
    }

    [self _setupReplyProperties:MCO_TO_OBJC(op->messageInfo())];
    DJLComposerWindowController * otherComposer = [[self delegate] DJLComposerWindowController:self hasMessageID:_messageID];
    if (otherComposer != nil) {
        [[otherComposer window] makeKeyAndOrderFront:nil];
        [self close];
        return;
    }

    if (_replyMetaInfo[@"type"] != nil) {
        NSString * frameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DJLComposerWindowFrameReply"];
        if (frameString != nil) {
            NSRect frame;
            frame = NSRectFromString(frameString);
            if ((frame.size.height != 0) && (frame.size.width != 0)) {
                [[self window] setFrame:frame display:NO animate:NO];
            }
        }
    }
    [[self delegate] DJLComposerWindowControllerShow:self];

    String * json = JSON::objectToJSONString(op->messageInfo());
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, MCO_TO_OBJC(json)]];
    _loadMessagesOp->removeObject(op);
    [_parametersForOp removeObjectForKey:uuid];
}

- (void) _setupReplyProperties:(NSDictionary *)info
{
    NSDictionary * msgInfo = info[@"msg"];
    NSDictionary * headerInfo = msgInfo[@"header"];
    _inReplyTo = headerInfo[@"inReplyTo"];
    _references = headerInfo[@"references"];

    HashMap * serializedMsg = MCO_FROM_OBJC(HashMap, msgInfo);
    AbstractMessage * msg = (AbstractMessage *) Object::objectWithSerializable(serializedMsg);

    if (msg->header()->subject() == NULL) {
        [_subjectField setStringValue:@""];
    }
    else {
        [_subjectField setStringValue:MCO_TO_OBJC(msg->header()->subject())];
    }
    [self _updateWindowTitle];
    _messageID = MCO_TO_OBJC(msg->header()->messageID());
    Array * recipient = Array::array();
    recipient->addObjectsFromArray(msg->header()->to());
    recipient->addObjectsFromArray(msg->header()->cc());
    [_toField setAddresses:MCO_TO_OBJC(recipient)];
    if ((msg->header()->bcc() != NULL) && (msg->header()->bcc()->count() > 0)) {
        [_bccField setAddresses:MCO_TO_OBJC(msg->header()->bcc())];
        _showCcEnabled = YES;
        _replyShowRecipientEditor = YES;
    }
    String * replyMetaHeaderValue = msg->header()->extraHeaderValueForName(MCSTR("X-DejaLu-Reply"));
    if (replyMetaHeaderValue != NULL) {
        Data * jsonData = replyMetaHeaderValue->stripWhitespace()->decodedBase64Data();
        _replyMetaInfo = MCO_TO_OBJC(JSON::objectFromJSONData(jsonData));
    }
    else {
        _replyMetaInfo = @{};
    }
}

- (void) jsLoadDraftAttachments:(NSDictionary *)parameters
{
    NSDictionary * info = [parameters objectForKey:@"info"];
    [self _loadDraftSaveAttachments:info];
}

- (void) _tryLoadMessage
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcLoadDraftMessage" withArguments:@[[NSNumber numberWithLongLong:_draftMessageToLoadRowID]]];
}

- (void) _tryLoadConversation
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcLoadDraftConversation" withArguments:@[[NSNumber numberWithLongLong:_draftMessageToLoadConversationID], [NSNumber numberWithLongLong:_draftMessageToLoadFolderID]]];
}

- (void) _loadHTMLBody
{
    if (_urlHandlerHTMLBody != NULL) {
        if (_urlHandlerBaseURL != nil) {
            [[_webView windowScriptObject] callWebScriptMethod:@"objcLoadHTMLBody" withArguments:@[_urlHandlerHTMLBody, _urlHandlerBaseURL]];
        }
        else {
            [[_webView windowScriptObject] callWebScriptMethod:@"objcLoadHTMLBody" withArguments:@[_urlHandlerHTMLBody]];
        }
    }
    if ([[_toField addresses] count] > 0) {
        if ([[_subjectField stringValue] length] > 0) {
            [[self window] makeFirstResponder:_webView];
            [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
        }
        else {
            [[self window] makeFirstResponder:_subjectField];
        }
    }
    else {
        [[self window] makeFirstResponder:_toField];
    }
    [self _setupSignature];
}

- (void) _loadDraftSaveAttachments:(NSDictionary *)info
{
    _draftMessageInfo = info;

    NSArray * attachments = info[@"all-attachments"];
    //NSLog(@"info: %@", info);

    for(NSDictionary * attachmentInfo in attachments) {
        //IMAPAttachmentDownloader * downloader = new IMAPAttachmentDownloader();
        IMAPAttachmentDownloader * downloader = _account->attachmentDownloader();
        downloader->setFolderID(_draftMessageToLoadFolderID);
        downloader->setMessageRowID(_draftMessageToLoadRowID);
        downloader->setUniqueID(MCO_FROM_OBJC(String, [attachmentInfo objectForKey:@"uniqueID"]));
        downloader->setDownloadFolder(MCO_FROM_OBJC(String, [self _temporaryFolder]));
        //downloader->setAccount(_account);
        downloader->setCallback(_callback);
        downloader->start();
        _downloaders->addObject(downloader);
        //MC_SAFE_RELEASE(downloader);
    }

    [self _loadDraftSaveAttachmentsCheckFinished];
}

- (void) _loadDraftSaveAttachmentsDownloaderFinished:(IMAPAttachmentDownloader *)downloader
{
    if (downloader->error() == hermes::ErrorNone) {
        BOOL foundInCID = NO;
        NSDictionary * mapping = _draftMessageInfo[@"cid-mapping"];
        for(NSString * key in mapping) {
            NSDictionary * value = mapping[key];
            NSString * uniqueID = value[@"uniqueID"];
            if ([uniqueID isEqualToString:MCO_TO_OBJC(downloader->uniqueID())]) {
                NSString * contentID = [[NSURL URLWithString:key] resourceSpecifier];
                [_cidFiles setObject:MCO_TO_OBJC(downloader->filename()) forKey:contentID];
                foundInCID = YES;
            }
        }

        if (!foundInCID) {
            [_attachments addObject:MCO_TO_OBJC(downloader->filename())];
        }
        _downloaders->removeObject(downloader);

        [self _loadDraftSaveAttachmentsCheckFinished];
    }
    else {
        mc_foreacharray(IMAPAttachmentDownloader, curDownloader, _downloaders) {
            if (curDownloader != downloader) {
                curDownloader->cancel();
            }
        }
        _downloaders->removeAllObjects();

        [self _loadDraftDoneWithError:downloader->error()];
    }
}

- (void) _loadDraftSaveAttachmentsCheckFinished
{
    if (_downloaders->count() != 0) {
        return;
    }

    [self _loadDraftDoneWithError:hermes::ErrorNone];
}

- (void) _loadDraftDoneWithError:(hermes::ErrorCode)error
{
    if (error != hermes::ErrorNone) {
        [self _showLoadDraftError];
        return;
    }

    String * addressesDisplayString = NULL;
    Array * addresses = MCO_FROM_OBJC(Array, [_toField addresses]);;
    if (addresses->count() == 1) {
        addressesDisplayString = AddressDisplay::shortDisplayStringForAddresses(addresses);
    }
    else {
        addressesDisplayString = AddressDisplay::veryShortDisplayStringForAddresses(addresses);
    }

    NSString * content = _draftMessageInfo[@"content"];
    NSString * subject = _draftMessageInfo[@"subject"];
    if (subject == nil) {
        subject = @"";
    }
    NSString * jsonReplyMetaInfo = MCO_TO_OBJC(JSON::objectToJSONString(MCO_FROM_OBJC(HashMap, _replyMetaInfo)));
    NSNumber * nbIsReply = [[_webView windowScriptObject] callWebScriptMethod:@"objcSetHTMLMessageContent" withArguments:@[subject, MCO_TO_OBJC(addressesDisplayString), jsonReplyMetaInfo, content]];
    DJLAssert(![[nbIsReply className] isEqualToString:@"WebUndefined"]);
    [self _updateAttachments];

    if ([nbIsReply boolValue]) {
        if ([_replyMetaInfo[@"type"] isEqualToString:@"forward"]) {
            _type = DJLComposerWindowControllerTypeForward;
        }
        else {
            _type = DJLComposerWindowControllerTypeReply;
        }
        _repliedMessageRendered = YES;
    }
    else {
        _type = DJLComposerWindowControllerTypeNew;
    }
    [self _updateSendButtonEnabled];
    [self _layoutWindow];

    [[_webView window] makeFirstResponder:_webView];
    [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
}

#if 0
- (void) jsPrepareUndoDone
{
    [[_webView undoManager] enableUndoRegistration];

    [self webViewDidChange:nil];
}

- (void) jsPrepareUndoForAddLink
{
    [self _prepareUndoWithTitle:@"Add Link"];
}
#endif

#pragma mark quicklook

- (void) _quicklook
{
    NSResponder * aNextResponder = [[self window] nextResponder];
    if (aNextResponder != self) {
        [[self window] setNextResponder:self];
        [self setNextResponder:aNextResponder];
    }
    [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel
{
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    [panel setDataSource:self];
    [panel setDelegate:self];

    [panel setCurrentPreviewItemIndex:[[_attachmentsView selectionIndexes] firstIndex]];
    [panel reloadData];

    // prepare preview items
    _quickLookPreviewItems = [[NSMutableArray alloc] init];
    for(NSUInteger i = 0 ; i < [_attachments count] ; i ++) {
        NSString * filename = [_attachments objectAtIndex:i];
        NSRect rect = [_attachmentsView frameForItemAtIndex:i];
        DJLAttachmentQLPreviewItem * item = [[DJLAttachmentQLPreviewItem alloc] initWithFilename:filename rect:rect view:_attachmentsView];
        [_quickLookPreviewItems addObject:item];
    }
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
    _quickLookPreviewItems = nil;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return [_quickLookPreviewItems count];
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    return [_quickLookPreviewItems objectAtIndex:index];
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id<QLPreviewItem>)item
{
    DJLAttachmentQLPreviewItem * concreteItem = item;
    return [concreteItem frame];
}

#pragma mark menuvalidation

- (BOOL) isWebViewFirstResponder
{
    if (![[[self window] firstResponder] isKindOfClass:[NSView class]]) {
        return NO;
    }

    NSView * view = (NSView *) [[self window] firstResponder];
    while (view != nil) {
        if (view == _webView) {
            return YES;
        }
        view = [view superview];
    }

    return NO;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(createLink:)) {
        if ([self isWebViewFirstResponder]) {
            return YES;
        }
        else {
            return NO;
        }
    }
    else if ([menuItem action] == @selector(sendMessage:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(saveDocument:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(findInText:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(findNext:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(findPrevious:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(_searchInGoogle:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(_showSource:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(editAllContent:)) {
        NSNumber * nb = [[_webView windowScriptObject] callWebScriptMethod:@"objcCanEditAllContent" withArguments:nil];
        return [nb boolValue];
    }
    else {
        return NO;
    }
}

#pragma Missing drafts folder

- (void) _showAlertDraftAndClose:(BOOL)closeAfterAlert
{
    NSAlert * alert = [[NSAlert alloc] init];
    NSString * title = [NSString stringWithFormat:@"Drafts folder is required for %@", MCO_TO_OBJC(_account->accountInfo()->email())];
    [alert setMessageText:title];
    if (([self account]->accountInfo()->providerIdentifier() != NULL) && ([self account]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail")))) {
        [alert setInformativeText:@"DejaLu needs the Drafts folder to compose emails. You can enable it in Gmail settings on the web > Labels > Check 'Show in IMAP' for Drafts."];
    }
    else {
        [alert setInformativeText:@"DejaLu needs the Drafts folder to compose emails. You need to create it."];
    }
    [alert addButtonWithTitle:@"OK"];

    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        if (([self account]->accountInfo()->providerIdentifier() != NULL) && [self account]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://mail.google.com/mail/u/0/#settings/labels"]];
        }
        if (closeAfterAlert) {
            [self close];
        }
    }];
}

@end

@implementation DJLAttachmentQLPreviewItem {
    NSString * _filename;
    NSRect _frame;
}

@synthesize previewItemURL = _previewItemURL;

- (id) initWithFilename:(NSString *)filename rect:(NSRect)rect view:(NSView *)view
{
    self = [super init];
    _filename = filename;
    [self setPreviewItemURL:[NSURL fileURLWithPath:_filename]];
    NSRect absoluteRect;
    absoluteRect = [view convertRect:rect toView:nil];
    absoluteRect = [[view window] convertRectToScreen:absoluteRect];
    _frame = absoluteRect;

    return self;
}

- (NSString *) previewItemTitle
{
    return [_filename lastPathComponent];
}

- (NSRect) frame
{
    return _frame;
}

@end
