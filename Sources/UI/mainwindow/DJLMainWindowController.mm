// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLMainWindowController.h"

#import <QuartzCore/QuartzCore.h>
#include <MailCore/MailCore.h>
#import <GoogleAnalyticsTracker/GoogleAnalyticsTracker.h>

#import "FBKVOController.h"
#import "NPReachability.h"

#import "DJLConversationCellView.h"
#import "DJLConversationRowView.h"
#import "DJLConversationViewController.h"
#import "DJLConversationWindowController.h"
#import "DJLWhiteView.h"
#import "DJLColoredView.h"
#import "FXKeychain.h"
#import "DJLWindow.h"
#import "DJLAssert.h"
#import "DJLLog.h"
#import "DJLConversationListToolbarView.h"
#import "DJLSyncProgressView.h"
#import "DJLConversationLoadMoreCellView.h"
#import "DJLActivityWindowController.h"
#import "DJLConversationListViewController.h"
#import "DJLSplitView.h"
#import "DJLComposerWindowController.h"
#import "DJLPathManager.h"
#import "DJLConversationToolbarView.h"
#import "DJLConversationSelectionViewController.h"
#import "DJLEmailSentOverlayView.h"
#import "DJLHUDWindow.h"
#import "DJLLabelsViewController.h"
#import "DJLURLHandler.h"
#import "DJLAddressBookManager.h"
#import "DJLFolderPaneViewController.h"
#import "DJLDarkMode.h"
#import "FBKVOController.h"
#import "DJLCleanupWindowController.h"

#include "Hermes.h"

#define LOG_IDLE(...) DJLLogWithID("idle", __VA_ARGS__)
#define LOG_STORAGE(...) DJLLogWithID("storage", __VA_ARGS__)
#define LOG_STACK_STORAGE(...) DJLLogStackWithID("storage", __VA_ARGS__)
#define LOG_STACK_ERROR(...) DJLLogStackWithID("error", __VA_ARGS__)

#define DISABLE_TABLEVIEW_ANIMATION 0

#define RESET_MESSAGES_TO_LOAD_TIMEOUT 300

#define ANALYTICS_DELAY 5

#define SIDEBAR_MIN_WIDTH 120
#define SIDEBAR_MAX_WIDTH 500
#define LEFT_MIN_WIDTH 300
#define LEFT_MAX_WIDTH 600
#define CONVERSATION_MIN_WIDTH 350

using namespace mailcore;
using namespace hermes;

@interface WebFrameView (Private)

- (NSScrollView *) _scrollView;

@end

@interface DJLMainWindowController () <NSWindowDelegate, NSTextFieldDelegate,
      DJLConversationListToolbarViewDelegate, DJLConversationViewControllerDelegate, DJLConversationListViewControllerDelegate,
      NSSplitViewDelegate, DJLConversationToolbarViewDelegate,
      DJLConversationSelectionViewControllerDelegate, DJLComposerWindowControllerDelegate,
      DJLConversationWindowControllerDelegate, DJLLabelsViewControllerDelegate, DJLURLHandlerDelegate,
      DJLToolbarViewValidationDelegate, DJLFolderPaneViewControllerDelegate, DJLCleanupWindowControllerDelegate>

- (void) _gotFolders:(Account *)account;
- (void) _foldersUpdated;
- (void) _accountStateUpdated;
- (void) _accountSyncDone:(hermes::ErrorCode)error folderPath:(NSString *)folderPath account:(Account *)account;
- (void) _notifyAuthenticationError:(hermes::ErrorCode)error account:(Account *)account;
- (void) _notifyConnectionError:(hermes::ErrorCode)error account:(Account *)account;
- (void) _notifyFatalError:(hermes::ErrorCode)error account:(Account *)account;
- (void) _notifyCopyError:(hermes::ErrorCode)error account:(Account *)account;
- (void) _notifyAppendError:(hermes::ErrorCode)error account:(Account *)account;
- (void) _imapAccountInfoChanged:(Account *)account;
- (void) _senderStateChanged:(Account *)account;
- (void) _senderMessageSent:(MessageParser *)message account:(Account *)account;
- (void) _senderAccountInfoChanged:(Account *)account;
- (void) _senderNotifyAuthenticationError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account;
- (void) _senderNotifyConnectionError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account;
- (void) _senderNotifyFatalError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account;
- (void) _senderNotifySendError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account;
- (void) _senderProgress:(Account *)account;
- (void) _senderDone:(Account *)account;
- (void) _updateAccountsRegistration;
- (void) _reselectAccountIfNeeded;
- (void) _hasConversationID:(int64_t)conversationID forMessageID:(NSString *)messageID account:(Account *)account;
- (void) _messageSourceFetchedWithError:(hermes::ErrorCode)error folderID:(int64_t)folderID messageRowID:(int64_t)messageRowID messageData:(NSData *)messageData account:(Account *)account;

@end

class DJLMainWindowControllerCallback : public Object, public AccountObserver, public AccountManagerObserver, public UnifiedAccountManagerObserver {
public:
    DJLMainWindowControllerCallback(DJLMainWindowController * controller) {
        mController = controller;
    }

    virtual ~DJLMainWindowControllerCallback() {}

    // Account observer

    virtual void accountGotFolders(Account * account)
    {
        [mController _gotFolders:account];
    }

    virtual void accountFoldersUpdated(Account * account)
    {
        [mController _foldersUpdated];
    }

    virtual void accountStateUpdated(Account * account)
    {
        [mController _accountStateUpdated];
    }

    virtual void accountSyncDone(Account * account, hermes::ErrorCode error, mailcore::String * folderPath)
    {
        [mController _accountSyncDone:error folderPath:MCO_TO_OBJC(folderPath) account:account];
    }

    virtual void accountNotifyAuthenticationError(Account * account, hermes::ErrorCode error)
    {
        [mController _notifyAuthenticationError:error account:account];
    }

    virtual void accountNotifyConnectionError(Account * account, hermes::ErrorCode error)
    {
        [mController _notifyConnectionError:error account:account];
    }

    virtual void accountNotifyFatalError(Account * account, hermes::ErrorCode error)
    {
        [mController _notifyFatalError:error account:account];
    }

    virtual void accountNotifyCopyError(Account * account, hermes::ErrorCode error)
    {
        [mController _notifyCopyError:error account:account];
    }

    virtual void accountNotifyAppendError(Account * account, hermes::ErrorCode error)
    {
        [mController _notifyAppendError:error account:account];
    }

    virtual void accountIMAPInfoChanged(Account * account)
    {
        [mController _imapAccountInfoChanged:account];
    }

    virtual void accountSendDone(Account * account)
    {
        [mController _senderDone:account];
    }

    virtual void accountSendingStateChanged(Account * account)
    {
        [mController _senderStateChanged:account];
    }

    virtual void accountMessageSent(Account * account, mailcore::MessageParser * parsedMessage)
    {
        [mController _senderMessageSent:parsedMessage account:account];
    }

    virtual void accountSMTPInfoChanged(Account * account)
    {
        [mController _senderAccountInfoChanged:account];
    }

    virtual void accountSenderProgress(Account * account)
    {
        [mController _senderProgress:account];
    }

    virtual void accountSenderNotifyAuthenticationError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
    {
        [mController _senderNotifyAuthenticationError:error message:parsedMessage account:account];
    }

    virtual void accountSenderNotifyConnectionError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
    {
        [mController _senderNotifyConnectionError:error message:parsedMessage account:account];
    }

    virtual void accountSenderNotifyFatalError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
    {
        [mController _senderNotifyFatalError:error message:parsedMessage account:account];
    }

    virtual void accountSenderNotifySendError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
    {
        [mController _senderNotifySendError:error message:parsedMessage account:account];
    }

    virtual void accountHasConversationIDForMessageID(Account * account, mailcore::String * messageID, int64_t conversationID)
    {
        [mController _hasConversationID:conversationID forMessageID:MCO_TO_OBJC(messageID) account:account];
    }

    virtual void accountMessageSourceFetched(Account * account, hermes::ErrorCode error, int64_t folderID, int64_t messageRowID,
                                             mailcore::Data * messageData)
    {
        [mController _messageSourceFetchedWithError:error folderID:folderID messageRowID:messageRowID messageData:MCO_TO_OBJC(messageData) account:account];
    }

    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mController _updateAccountsRegistration];
    }

    virtual void unifiedAccountManagerChanged(UnifiedAccountManager * manager)
    {
        [mController _reselectAccountIfNeeded];
    }

    __weak DJLMainWindowController * mController;
};

@implementation DJLMainWindowController {
    NSSplitView * _splitView;
    DJLMainWindowControllerCallback * _callback;
    //Account * _account;
    BOOL _initDone;
    NSUInteger _logMessageIndex;
    IMAPFetchContentOperation * _logFetchMessageOp;
    MailDBConversationMessagesOperation * _logMessagesUidsOp;
    NSArray * _logMessagesUids;
    NSMutableArray * _convWindowControllers;
    FBKVOController * _kvoController;
    DJLConversationListToolbarView * _toolbarView;
    DJLConversationToolbarView * _conversationToolbarView;
    BOOL _windowButtonsReplaceDone;
    DJLActivityWindowController * _debugActivityWindowController;
    DJLConversationListViewController * _conversationListViewController;
    DJLConversationViewController * _conversationViewController;
    DJLConversationSelectionViewController * _selectionViewController;
    NSRect _savedSmallWindowFrame;
    NSRect _savedBigWindowFrame;
    NSMutableArray * _composers;
    NSView * _conversationPanel;
    NSVisualEffectView * _leftContainerView;
    BOOL _refreshActionInProgress;
    BOOL _refreshConfirmation;
    BOOL _showingErrorDialog;
    NSMutableDictionary * _accountsErrors;
    NSMutableDictionary * _accountsSendErrors;
    NSMutableSet * _shownAccountsError;
    NSPopover * _labelsPopOver;
    NSMutableArray * _foldersManagerControllers;
    __weak id <DJLMainWindowControllerDelegate> _delegate;
    Array * /* Account */ _accounts;
    int64_t _urlMessageIDFound;
    int _urlMessageIDCount;
    Account * _urlMessageAccount;
    int _currentAccountsNumber;
    BOOL _togglingDetails;
    BOOL _conversationToolbarEnabled;
    DJLFolderPaneViewController * _folderPaneViewController;
    NSVisualEffectView * _folderContainerView;
    BOOL _splitViewAllowResize[3];
    CGFloat _splitViewInitialWidth[3];
    BOOL _splitViewInitialWidthScheduled;
    BOOL _restoringWindowSize;
    NSSound * _mailSentSound;
    DJLCleanupWindowController * _cleanupWindowController;
}

@synthesize delegate = _delegate;

- (id) init
{
    DJLWindow * window = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 500)
                                                      styleMask: NSTitledWindowMask | NSResizableWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                        backing:NSBackingStoreBuffered defer:YES];
    [window setReleasedWhenClosed:NO];
    [window setTitlebarAppearsTransparent:YES];
    [window setTitle:@"DejaLu"];
    [window setTitleVisibility:NSWindowTitleHidden];
    [window center];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setIdentifier:@"DejaLu Main Window"];
    
    NSRect frame = [window frame];
    frame.origin = CGPointZero;
    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:frame];
    [window setContentView:contentView];
    [contentView setWantsLayer:YES];

    self = [self initWithWindow:window];
    
    [window setDelegate:self];
    
    _convWindowControllers = [[NSMutableArray alloc] init];

    _splitView = [[DJLSplitView alloc] initWithFrame:[contentView bounds]];
    [_splitView setVertical:YES];
    [_splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [_splitView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_splitView setDelegate:self];
    [contentView addSubview:_splitView];

    _folderContainerView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
    if ([DJLDarkMode isDarkModeSupported]) {
        [_folderContainerView setMaterial:NSVisualEffectMaterialSidebar];
    } else {
        [_folderContainerView setMaterial:NSVisualEffectMaterialLight];
    }
    _folderPaneViewController = [[DJLFolderPaneViewController alloc] init];
    [_folderPaneViewController setDelegate:self];
    [[_folderPaneViewController view] setFrame:NSMakeRect(0, 0, 200, 165)];
    [_folderContainerView addSubview:[_folderPaneViewController view]];

    _leftContainerView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
    if ([DJLDarkMode isDarkModeSupported]) {
        [_leftContainerView setMaterial:NSVisualEffectMaterialSidebar];
    } else {
        [_leftContainerView setMaterial:NSVisualEffectMaterialLight];
    }
    _toolbarView = [[DJLConversationListToolbarView alloc] initWithFrame:NSMakeRect(0, 165, 200, 35)];
    [_toolbarView setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
    [_toolbarView setDelegate:self];
    [_toolbarView setValidationDelegate:self];
    [_leftContainerView addSubview:_toolbarView];
    _conversationListViewController = [[DJLConversationListViewController alloc] init];
    [_conversationListViewController setDelegate:self];
    [[_conversationListViewController view] setFrame:NSMakeRect(0, 0, 200, 165)];
    [_leftContainerView addSubview:[_conversationListViewController view]];
    _conversationPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];

    _conversationViewController = [[DJLConversationViewController alloc] init];
    [_conversationViewController setDelegate:self];
    [[_conversationViewController view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[_conversationViewController view] setFrame:NSMakeRect(0, 0, 200, 165)];
    [_conversationPanel addSubview:[_conversationViewController view]];
    [_conversationViewController setup];

    _selectionViewController = [[DJLConversationSelectionViewController alloc] init];
    [[_selectionViewController view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_selectionViewController setDelegate:self];
    [_selectionViewController setup];

    frame = NSMakeRect(0, 165, 200, 35);
    _conversationToolbarView = [[DJLConversationToolbarView alloc] initWithFrame:frame];
    [_conversationToolbarView setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
    [_conversationToolbarView setDelegate:self];
    [_conversationToolbarView setValidationDelegate:self];
    [_conversationToolbarView setVibrancy:0];
    [_conversationPanel addSubview:_conversationToolbarView];

    [self _restoreWindowSize];

    [_splitView adjustSubviews];

    [self _setup];
    [self _updateConversationPanel];
    [self _updateFirstResponderState];

    [[self window] setAutorecalculatesKeyViewLoop:NO];
    [[self window] recalculateKeyViewLoop];
    if ([self window] == [[self window] firstResponder]) {
        [[self window] selectNextKeyView:nil];
    }
    [[self window] setAutorecalculatesKeyViewLoop:YES];

    [_conversationListViewController makeFirstResponder];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appStateDidChange) name:NSApplicationDidBecomeActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appStateDidChange) name:NSApplicationDidResignActiveNotification object:NSApp];

    _composers = [[NSMutableArray alloc] init];
    _foldersManagerControllers = [[NSMutableArray alloc] init];
    _accountsErrors = [[NSMutableDictionary alloc] init];
    _accountsSendErrors = [[NSMutableDictionary alloc] init];
    _shownAccountsError = [[NSMutableSet alloc] init];
    _urlMessageIDFound = -1;

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"App" action:@"Start" label:@"Start the app" value:@(0)];
    // Wait before collecting the first analytics
    [self performSelector:@selector(_loopAnalytics) withObject:nil afterDelay:ANALYTICS_DELAY];

    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:[self window] keyPath:@"effectiveAppearance" options:0 block
                           :^(id observer, id object, NSDictionary *change) {
                               [weakSelf _applyDarkMode];
                           }];
    [self _applyDarkMode];

    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_urlMessageAccount);
    UnifiedAccountManager::sharedManager()->removeObserver(_callback);
    AccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (void) _applyDarkMode
{
    DJLColoredView * contentView = [[self window] contentView];
    if ([DJLDarkMode isDarkModeForView:contentView]) {
        [contentView setBackgroundColor:[NSColor blackColor]];
    } else {
        [contentView setBackgroundColor:[NSColor whiteColor]];
    }
}

- (void) awakeFromNib
{
    [self _setup];
}

- (void) _setup
{
    if (_initDone)
        return;

    _initDone = YES;

    _callback = new DJLMainWindowControllerCallback(self);

    NSString * folder = [[DJLPathManager sharedManager] accountsFolder];
    AccountManager::sharedManager()->setPath(MCO_FROM_OBJC(String, folder));
    AccountManager::sharedManager()->load();
    AccountManager::sharedManager()->addObserver(_callback);
    UnifiedAccountManager::sharedManager()->addObserver(_callback);
    _currentAccountsNumber = AccountManager::sharedManager()->accounts()->count();
    [self _updateAccountsRegistration];

    UnifiedAccount * account = NULL;
    if (_currentAccountsNumber == 1) {
        account = (UnifiedAccount *) UnifiedAccountManager::sharedManager()->accounts()->objectAtIndex(0);
    }
    else {
        // 0 accounts or multiple
        account = UnifiedAccountManager::sharedManager()->unifiedAccount();
    }
    [_conversationListViewController setUnifiedAccount:account];
    [_folderPaneViewController setUnifiedAccount:account];

    [[DJLURLHandler sharedManager] setDelegate:self];
    [[DJLURLHandler sharedManager] setReady:YES];
}

- (void) _updateAccountsRegistration
{
    {
        mc_foreacharray(Account, account, _accounts) {
            account->removeObserver(_callback);
        }
    }
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            account->addObserver(_callback);
        }
    }
    MC_SAFE_RELEASE(_accounts);
    _accounts = (Array *) AccountManager::sharedManager()->accounts()->copy();
    [self _cleanupAccountsErrors];

    [_toolbarView validate];
}

- (void) _cleanupAccountsErrors
{
    NSMutableSet * existing = [[NSMutableSet alloc] init];
    mc_foreacharray(Account, account, _accounts) {
        [existing addObject:MCO_TO_OBJC(account->accountInfo()->email())];
    }

    for(NSString * email in [_accountsErrors allKeys]) {
        if (![existing containsObject:email]) {
            [_accountsErrors removeObjectForKey:email];
        }
    }
}

- (void)windowDidResize:(NSNotification *)notification
{
    if (!_togglingDetails) {
        [self _savePosition];
    }
}

- (void)windowDidMove:(NSNotification *)notification
{
    if (!_togglingDetails) {
        [self _savePosition];
    }
}

- (void) _restorePosition
{
    CGFloat width = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLFolderWidth"];
    NSRect frame = [_folderContainerView frame];
    frame.size.width = width;
    [_folderContainerView setFrame:frame];

    width = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLConversationViewWidth"];
    frame = [_conversationPanel frame];
    frame.size.width = width;
    [_conversationPanel setFrame:frame];

    width = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLConversationListWidth"];
    frame = [_leftContainerView frame];
    frame.size.width = width;
    [_leftContainerView setFrame:frame];
}

- (void) _restoreWindowSize
{
    _restoringWindowSize = YES;
    NSRect frame = [[self window] frame];
    NSString * frameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DJLMainWindowFrame"];
    if (frameString != nil) {
        frame = NSRectFromString(frameString);
    }
    BOOL hasSidebar = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLMainWindowHasFolderView"];
    BOOL hasConversation = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLMainWindowHasConversationView"];
    [self _restorePosition];
    CGFloat width = [self _totalWidthWithSidebar:hasSidebar conversation:hasConversation];
    frame.size.width = width;
    if (hasSidebar) {
        [_splitView addSubview:_folderContainerView];
        [_toolbarView setLeftMargin:5];
    }
    else {
        [_toolbarView setLeftMargin:71];
    }
    [_splitView addSubview:_leftContainerView];
    if (hasConversation) {
        [_splitView addSubview:_conversationPanel];
    }
    [self _fixPanelSizes];

    [[self window] setFrame:frame display:NO];
    if (hasSidebar) {
        [_conversationListViewController setVibrancy:0];
        [_toolbarView setVibrancy:0];
        CGFloat folderWidth = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLFolderWidth"];
        [_splitView setPosition:0 ofDividerAtIndex:folderWidth];
        if (hasConversation) {
            CGFloat leftWidth = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLConversationListWidth"];
            [_splitView setPosition:1 ofDividerAtIndex:folderWidth + [_splitView dividerThickness] + leftWidth];
        }
    }
    else {
        if (hasConversation) {
            CGFloat leftWidth = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLConversationListWidth"];
            [_splitView setPosition:0 ofDividerAtIndex:leftWidth];
            [_conversationListViewController setVibrancy:1];
            [_toolbarView setVibrancy:1];
        }
        else {
            [_conversationListViewController setVibrancy:0];
            [_toolbarView setVibrancy:0];
        }
    }

    [self _applyWindowMinMaxSize];

    _restoringWindowSize = NO;
}

- (void) _savePosition
{
    if (!_initDone) {
        return;
    }
    if ([self window] == nil) {
        return;
    }
    NSRect frame = [[self window] frame];
    NSString * frameString = NSStringFromRect(frame);
    [[NSUserDefaults standardUserDefaults] setObject:frameString forKey:@"DJLMainWindowFrame"];
    if ([self _hasFolderPanel]) {
        [[NSUserDefaults standardUserDefaults] setFloat:[_folderContainerView frame].size.width forKey:@"DJLFolderWidth"];
    }
    if ([self _hasConversationPanel]) {
        [[NSUserDefaults standardUserDefaults] setFloat:[_conversationPanel frame].size.width forKey:@"DJLConversationViewWidth"];
    }
    [[NSUserDefaults standardUserDefaults] setFloat:[_leftContainerView frame].size.width forKey:@"DJLConversationListWidth"];
    [[NSUserDefaults standardUserDefaults] setBool:[self _hasConversationPanel] forKey:@"DJLMainWindowHasConversationView"];
    [[NSUserDefaults standardUserDefaults] setBool:[self _hasFolderPanel] forKey:@"DJLMainWindowHasFolderView"];
}

- (void) _openConversationWindow
{
    if ([[_conversationListViewController selectedConversationsIDs] count] != 1) {
        return;
    }

    DJLUnifiedConversationID * convIDContainer = [[_conversationListViewController selectedConversationsIDs] objectAtIndex:0];
    int64_t convID = [convIDContainer convID];

    Account * account = [_conversationListViewController accountForSingleSelection];
    for(DJLConversationWindowController * existingController in _convWindowControllers) {
        if (([existingController account] == account) && ([existingController convID] == convID)) {
            [existingController showWindow:nil];
            return;
        }
    }
    
    DJLConversationWindowController * controller = [[DJLConversationWindowController alloc] init];
    [controller setup];
    [controller setAccount:account];
    [controller setStorageView:[_conversationListViewController storageViewForSingleSelection]];
    [controller setConvID:convID];
    [controller loadConversation];
    [controller setDelegate:self];
    // cascade.
    if ([_convWindowControllers count] > 0) {
        DJLConversationWindowController * lastController = [_convWindowControllers lastObject];
        NSRect lastWindowFrame = [[lastController window] frame];
        lastWindowFrame.origin.x += 30;
        lastWindowFrame.origin.y -= 30;
        [[controller window] setFrame:lastWindowFrame display:NO];
    }
    [controller showWindow:nil];
    [_convWindowControllers addObject:controller];
}

- (void) composeMessage
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"New" label:@"Open a new composer" value:@(0)];

    UnifiedAccount * unifiedAccount = [_conversationListViewController unifiedAccount];
    Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
    DJLComposerWindowController * controller = [[DJLComposerWindowController alloc] init];
    [controller setDefaultEmailAliasForAccount:account];
    [controller setDelegate:self];
    [self _cascadeComposer:controller];
    [controller showWindow:nil];
    [_composers addObject:controller];
}

- (BOOL) _hasConversationPanel {
    return [[_splitView subviews] containsObject:_conversationPanel];
}

- (BOOL) _hasFolderPanel {
    return [[_splitView subviews] containsObject:_folderContainerView];
}

- (IBAction) showLabelsPanel:(id)sender
{
    if ([self _hasConversationPanel]) {
        [_conversationViewController showLabelsPanel:nil];
    }
    else {
        [_conversationListViewController showLabelsPanel:nil];
    }
}

- (IBAction) showLabelsAndArchivePanel:(id)sender
{
    if ([self _hasConversationPanel]) {
        [_conversationViewController showLabelsAndArchivePanel:nil];
    }
    else {
        [_conversationListViewController showLabelsAndArchivePanel:nil];
    }
}

- (void) toggleDetails:(id)sender
{
    [self _setDetailsVisible:![self _hasConversationPanel] animated:YES];
}

- (void) _fixPanelSizes
{
    if ([_conversationPanel frame].size.width < CONVERSATION_MIN_WIDTH) {
        NSRect viewFrame = [_conversationPanel frame];
        viewFrame.size.width = CONVERSATION_MIN_WIDTH;
        [_conversationPanel setFrame:viewFrame];
    }
    if ([_leftContainerView frame].size.width < LEFT_MIN_WIDTH) {
        NSRect viewFrame = [_conversationPanel frame];
        viewFrame.size.width = LEFT_MIN_WIDTH;
        [_leftContainerView setFrame:viewFrame];
    }
    if ([_leftContainerView frame].size.width > LEFT_MAX_WIDTH) {
        NSRect viewFrame = [_conversationPanel frame];
        viewFrame.size.width = LEFT_MAX_WIDTH;
        [_leftContainerView setFrame:viewFrame];
    }
    if ([_folderContainerView frame].size.width < SIDEBAR_MIN_WIDTH) {
        NSRect viewFrame = [_conversationPanel frame];
        viewFrame.size.width = SIDEBAR_MIN_WIDTH;
        [_folderContainerView setFrame:viewFrame];
    }
    if ([_folderContainerView frame].size.width > SIDEBAR_MAX_WIDTH) {
        NSRect viewFrame = [_folderContainerView frame];
        viewFrame.size.width = SIDEBAR_MAX_WIDTH;
        [_folderContainerView setFrame:viewFrame];
    }
}

- (void) _willStartResizingPanel
{
    [self _fixPanelSizes];

    _togglingDetails = YES;
    [_splitView setAutoresizingMask:0];
    [_folderContainerView setAutoresizingMask:0];
    [_conversationPanel setAutoresizingMask:0];
    [_leftContainerView setAutoresizingMask:0];
    [[self window] setMinSize:NSMakeSize(LEFT_MIN_WIDTH, 400)];
    [[self window] setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
}

- (void) _didEndResizingPanel
{
    [_splitView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_folderContainerView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_conversationPanel setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_leftContainerView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [self _applyWindowMinMaxSize];
    [self _savePosition];
    _togglingDetails = NO;

    [[self window] recalculateKeyViewLoop];
    if ([self window] == [[self window] firstResponder]) {
        [[self window] selectNextKeyView:nil];
    }
}

- (void) _applyWindowMinMaxSize
{
    CGFloat minWidth = LEFT_MIN_WIDTH;
    CGFloat maxWidth = LEFT_MAX_WIDTH;
    if ([self _hasFolderPanel]) {
        minWidth += [_splitView dividerThickness];
        maxWidth += [_splitView dividerThickness];
        minWidth += SIDEBAR_MIN_WIDTH;
        maxWidth += SIDEBAR_MAX_WIDTH;
    }
    if ([self _hasConversationPanel]) {
        minWidth += [_splitView dividerThickness];
        maxWidth += [_splitView dividerThickness];
        minWidth += CONVERSATION_MIN_WIDTH;
        maxWidth = FLT_MAX;
    }

    [[self window] setMinSize:NSMakeSize(minWidth, 400)];
    [[self window] setMaxSize:NSMakeSize(maxWidth, FLT_MAX)];
}

- (CGFloat) _totalWidthWithSidebar:(BOOL)hasSidebar conversation:(BOOL)hasConversation
{
    CGFloat result = [_leftContainerView frame].size.width;
    if (hasSidebar) {
        result += [_splitView dividerThickness] + [_folderContainerView frame].size.width;
    }
    if (hasConversation) {
        result += [_splitView dividerThickness] + [_conversationPanel frame].size.width;
    }
    return result;
}

- (void) _setDetailsVisible:(BOOL)visible animated:(BOOL)animated
{
    [self _willStartResizingPanel];
    if (visible) {
        CGFloat targetVibrancy = 1.0;
        if ([self _hasFolderPanel]) {
            targetVibrancy = 0.0;
        }
        NSRect frame = [[self window] frame];
        frame.size.width = [self _totalWidthWithSidebar:[self _hasFolderPanel] conversation:YES];
        NSRect splitViewFrame = [[self window] contentRectForFrameRect:frame];
        splitViewFrame.size.height = [_splitView frame].size.height;
        splitViewFrame.origin = NSZeroPoint;
        if ([_conversationPanel superview] == nil) {
            [_splitView addSubview:_conversationPanel];
        }
        [_splitView setFrame:splitViewFrame];
        if ([self _hasFolderPanel]) {
            [_splitView setPosition:[_folderContainerView frame].size.width + [_splitView dividerThickness] + [_leftContainerView frame].size.width ofDividerAtIndex:1];
        }
        else {
            [_splitView setPosition:[_leftContainerView frame].size.width ofDividerAtIndex:0];
        }

        NSRect viewFrame = [_conversationPanel bounds];
        viewFrame.origin.y = viewFrame.size.height - 35;
        viewFrame.size.height = 35;
        [_conversationToolbarView setFrame:viewFrame];

        [self _updateConversationPanel];
        if (animated) {
            [self _animatedShowDetailsWithWindowFrame:frame vibrancy:targetVibrancy];
        }
        else {
            [[self window] setFrame:frame display:NO];
            [_toolbarView setVibrancy:targetVibrancy];
            [_conversationListViewController setVibrancy:targetVibrancy];
        }
    }
    else {
        CGFloat targetVibrancy = 0.0;
        NSRect frame = [[self window] frame];
        frame.size.width = [self _totalWidthWithSidebar:[self _hasFolderPanel] conversation:NO];
        if (animated) {
            [self _animatedShowDetailsWithWindowFrame:frame vibrancy:targetVibrancy];
        }
        else {
            [[self window] setFrame:frame display:NO];
            [_toolbarView setVibrancy:targetVibrancy];
            [_conversationListViewController setVibrancy:targetVibrancy];
        }
        [_conversationPanel removeFromSuperview];
        [_splitView setFrame:[[[self window] contentView] bounds]];
        if ([self window] == [[self window] firstResponder]) {
            [_conversationListViewController makeFirstResponder];
        }
    }
    [self _didEndResizingPanel];
}

- (void) _animatedShowDetailsWithWindowFrame:(NSRect)frame vibrancy:(CGFloat)vibrancy
{
    // will let expensive operations run and prevent a lag in the following animation.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1. / 120.]];

    NSRect initialFrame = [[self window] frame];
    CGFloat sourceVibrancy = [_toolbarView vibrancy];

    NSTimeInterval startDate = [NSDate timeIntervalSinceReferenceDate];
    while (1) {
        NSTimeInterval timeInterval = [NSDate timeIntervalSinceReferenceDate] - startDate;
        CGFloat alpha = timeInterval / 0.15;
        if (alpha < 0.) {
            alpha = 0.;
        }
        if (alpha > 1.) {
            alpha = 1.;
        }
        NSRect currentFrame;
        currentFrame.origin.x = (frame.origin.x - initialFrame.origin.x) * alpha + initialFrame.origin.x;
        currentFrame.origin.y = (frame.origin.y - initialFrame.origin.y) * alpha + initialFrame.origin.y;
        currentFrame.size.width = (frame.size.width - initialFrame.size.width) * alpha + initialFrame.size.width;
        currentFrame.size.height = (frame.size.height - initialFrame.size.height) * alpha + initialFrame.size.height;
        currentFrame.origin.x = (int) currentFrame.origin.x;
        currentFrame.origin.y = (int) currentFrame.origin.y;
        currentFrame.size.width = (int) currentFrame.size.width;
        currentFrame.size.height = (int) currentFrame.size.height;
        [[self window] setFrame:currentFrame display:YES];
        if (alpha >= 1.) {
            break;
        }
        CGFloat currentVibrancy = (vibrancy - sourceVibrancy) * alpha + sourceVibrancy;
        [_toolbarView setVibrancy:currentVibrancy];
        [_conversationListViewController setVibrancy:currentVibrancy];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1. / 120.]];
    }
    [[self window] setFrame:frame display:YES];
    [_toolbarView setVibrancy:vibrancy];
    [_conversationListViewController setVibrancy:vibrancy];
}

- (void) _setSidebarVisible:(BOOL)visible animated:(BOOL)animated
{
    [self _willStartResizingPanel];
    if (visible) {
        CGFloat initialLeftWidth = [_leftContainerView frame].size.width;

        CGFloat targetVibrancy = 0.0;
        NSRect frame = [[self window] frame];
        NSRect viewFrame = [_folderContainerView frame];
        viewFrame.size.width = [[NSUserDefaults standardUserDefaults] floatForKey:@"DJLFolderWidth"];
        [_folderContainerView setFrame:viewFrame];
        frame.size.width = [self _totalWidthWithSidebar:YES conversation:[self _hasConversationPanel]];
        NSRect splitViewFrame = [[self window] contentRectForFrameRect:frame];
        splitViewFrame.size.height = [_splitView frame].size.height;
        splitViewFrame.origin = NSZeroPoint;
        NSRect folderFrame = splitViewFrame;
        folderFrame.size.width = 0;
        [_folderContainerView setFrame:folderFrame];
        if ([_folderContainerView superview] == nil) {
            [_splitView addSubview:_folderContainerView positioned:NSWindowBelow relativeTo:_leftContainerView];
        }
        [_splitView setPosition:0 ofDividerAtIndex:0];
        [_splitView setPosition:initialLeftWidth ofDividerAtIndex:1];

        if (animated) {
            [self _animatedShowSidebarWithWindowFrame:frame vibrancy:targetVibrancy];
        }
        else {
            [_splitView setFrame:splitViewFrame];
            [_splitView setPosition:[_folderContainerView frame].size.width ofDividerAtIndex:0];
            if ([self _hasConversationPanel]) {
                [_splitView setPosition:[_folderContainerView frame].size.width + [_splitView dividerThickness] + [_leftContainerView frame].size.width ofDividerAtIndex:1];
            }
            [[self window] setFrame:frame display:NO];
            [_toolbarView setVibrancy:targetVibrancy];
            [_conversationListViewController setVibrancy:targetVibrancy];
            [_toolbarView setLeftMargin:5];
        }
    }
    else {
        CGFloat targetVibrancy = 1.0;
        if (![self _hasConversationPanel]) {
            targetVibrancy = 0.0;
        }
        NSRect frame = [[self window] frame];
        //frame.size.width = [_leftContainerView frame].size.width;
        frame.size.width = [self _totalWidthWithSidebar:NO conversation:[self _hasConversationPanel]];
        if (animated) {
            [self _animatedShowSidebarWithWindowFrame:frame vibrancy:targetVibrancy];
        }
        else {
            [[self window] setFrame:frame display:NO];
            [_toolbarView setVibrancy:targetVibrancy];
            [_conversationListViewController setVibrancy:targetVibrancy];
            [_toolbarView setLeftMargin:71];
        }

        [_folderContainerView removeFromSuperview];
        [_splitView setFrame:[[[self window] contentView] bounds]];
        [_splitView setPosition:[_leftContainerView frame].size.width ofDividerAtIndex:0];

        if ([self window] == [[self window] firstResponder]) {
            [_conversationListViewController makeFirstResponder];
        }
    }
    [self _didEndResizingPanel];
    [_splitView adjustSubviews];
}

#warning this animation is too slow
- (void) _animatedShowSidebarWithWindowFrame:(NSRect)frame vibrancy:(CGFloat)vibrancy
{
    BOOL hasConversation = [self _hasConversationPanel];

    CGFloat initialLeftWidth = [_leftContainerView frame].size.width;
    CGFloat initialConversationWidth = [_conversationPanel frame].size.width;

    [_splitView removeFromSuperview];
    [_leftContainerView removeFromSuperview];
    if (hasConversation) {
        [_conversationPanel removeFromSuperview];
    }
    [_folderContainerView removeFromSuperview];

    NSRect viewFrame = [_splitView frame];
    if (viewFrame.size.width < frame.size.width) {
        viewFrame.size.width = frame.size.width;
    }
    DJLColoredView * animationContainerView = [[DJLColoredView alloc] initWithFrame:viewFrame];
    if ([DJLDarkMode isDarkModeForView:[[self window] contentView]]) {
        [animationContainerView setBackgroundColor:[NSColor blackColor]];
    } else {
        [animationContainerView setBackgroundColor:[NSColor colorWithCalibratedRed:0.7863 green:0.8020 blue:0.85 alpha:1.0000]];
    }
    viewFrame = [_folderContainerView frame];
    viewFrame.origin = NSZeroPoint;
    viewFrame.size.height = [animationContainerView bounds].size.height;
    [_folderContainerView setFrame:viewFrame];
    [animationContainerView addSubview:_folderContainerView];
    viewFrame = [_leftContainerView frame];
    viewFrame.origin = NSZeroPoint;
    viewFrame.origin.x = NSMaxX([_folderContainerView frame]) + [_splitView dividerThickness];
    viewFrame.size.height = [animationContainerView bounds].size.height;
    [_leftContainerView setFrame:viewFrame];
    [animationContainerView addSubview:_leftContainerView];
    if (hasConversation) {
        viewFrame = [_conversationPanel frame];
        viewFrame.origin = NSZeroPoint;
        viewFrame.origin.x = NSMaxX([_leftContainerView frame]) + [_splitView dividerThickness];
        [_conversationPanel setFrame:viewFrame];
        [animationContainerView addSubview:_conversationPanel];
    }
    [[[self window] contentView] addSubview:animationContainerView];

    // will let expensive operations run and prevent a lag in the following animation.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1. / 120.]];

    NSRect initialFrame = [[self window] frame];
    CGFloat initialFolderContainerWidth;
    if (hasConversation) {
        initialFolderContainerWidth = initialFrame.size.width - (initialLeftWidth + initialConversationWidth + 2 * [_splitView dividerThickness]);
    }
    else {
        initialFolderContainerWidth = initialFrame.size.width - (initialLeftWidth + [_splitView dividerThickness]);
    }
    CGFloat sourceVibrancy = [_toolbarView vibrancy];

    NSTimeInterval startDate = [NSDate timeIntervalSinceReferenceDate];
    while (1) {
        NSTimeInterval timeInterval = [NSDate timeIntervalSinceReferenceDate] - startDate;
        CGFloat alpha = timeInterval / 0.15;
        if (alpha < 0.) {
            alpha = 0.;
        }
        if (alpha > 1.) {
            alpha = 1.;
        }
        if (alpha >= 1.) {
            break;
        }

        NSRect currentFrame;

        currentFrame = [_folderContainerView frame];
        currentFrame.origin.x = 0;
        currentFrame.size.width = (frame.size.width - initialFrame.size.width) * alpha + initialFolderContainerWidth;
        currentFrame.size.height = [animationContainerView bounds].size.height;
        currentFrame = NSIntegralRect(currentFrame);
        [_folderContainerView setFrame:currentFrame];
        NSRect folderFrame = [_folderContainerView bounds];
        folderFrame.origin = NSZeroPoint;
        if (initialFrame.size.width > frame.size.width) {
            folderFrame.size.width = initialFolderContainerWidth;
        }
        else {
            folderFrame.size.width = frame.size.width - initialFrame.size.width + initialFolderContainerWidth;
        }
        folderFrame.size.height = [animationContainerView frame].size.height;
        folderFrame.size.height -= 35;
        if (!NSEqualRects([[_folderPaneViewController view] frame], folderFrame)) {
            [[_folderPaneViewController view] setFrame:folderFrame];
        }
        currentFrame = [_leftContainerView frame];
        currentFrame.origin.x = NSMaxX([_folderContainerView frame]) + [_splitView dividerThickness];
        currentFrame.size.width = initialLeftWidth;
        currentFrame.size.height = [animationContainerView bounds].size.height;
        currentFrame = NSIntegralRect(currentFrame);
        [_leftContainerView setFrame:currentFrame];
        NSRect leftFrame = [_leftContainerView bounds];
        leftFrame.size.height = [animationContainerView frame].size.height;
        leftFrame.size.height -= 35;
        if (!NSEqualRects([[_conversationListViewController view] frame], leftFrame)) {
            [[_conversationListViewController view] setFrame:leftFrame];
        }
        if (hasConversation) {
            currentFrame = [_conversationPanel frame];
            currentFrame.size.width = initialConversationWidth;
            currentFrame.origin.x = NSMaxX([_leftContainerView frame]) + [_splitView dividerThickness];
            currentFrame = NSIntegralRect(currentFrame);
            [_conversationPanel setFrame:currentFrame];
        }

        if (initialFrame.size.width > frame.size.width) {
            [_toolbarView setLeftMargin:5 + (71 - 5) * alpha];
        }
        else {
            [_toolbarView setLeftMargin:5 + (71 - 5) * (1 - alpha)];
        }

        CGFloat currentVibrancy = (vibrancy - sourceVibrancy) * alpha + sourceVibrancy;
        [_toolbarView setVibrancy:currentVibrancy];
        [_conversationListViewController setVibrancy:currentVibrancy];

        currentFrame.origin.x = (frame.origin.x - initialFrame.origin.x) * alpha + initialFrame.origin.x;
        currentFrame.origin.y = (frame.origin.y - initialFrame.origin.y) * alpha + initialFrame.origin.y;
        currentFrame.size.width = (frame.size.width - initialFrame.size.width) * alpha + initialFrame.size.width;
        currentFrame.size.height = (frame.size.height - initialFrame.size.height) * alpha + initialFrame.size.height;
        currentFrame.origin.x = (int) currentFrame.origin.x;
        currentFrame.origin.y = (int) currentFrame.origin.y;
        currentFrame.size.width = (int) currentFrame.size.width;
        currentFrame.size.height = (int) currentFrame.size.height;
        currentFrame = NSIntegralRect(currentFrame);
        [[self window] setFrame:currentFrame display:YES];

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1. / 120.]];
    }
    [[self window] setFrame:frame display:NO];

    [animationContainerView removeFromSuperview];
    [_leftContainerView removeFromSuperview];
    [_conversationPanel removeFromSuperview];
    if (hasConversation) {
        [_folderContainerView removeFromSuperview];
    }
    [_splitView addSubview:_folderContainerView];
    [_splitView addSubview:_leftContainerView];
    if (hasConversation) {
        [_splitView addSubview:_conversationPanel];
    }
    [_splitView setPosition:(frame.size.width - initialFrame.size.width) + initialFolderContainerWidth ofDividerAtIndex:0];
    if (hasConversation) {
        [_splitView setPosition:(frame.size.width - initialFrame.size.width) + initialFolderContainerWidth + initialLeftWidth ofDividerAtIndex:1];
    }
    [_splitView setFrame:[[[self window] contentView] bounds]];

    NSRect folderFrame = [_folderContainerView bounds];
    folderFrame.size.height = [animationContainerView frame].size.height;
    folderFrame.size.height -= 35;
    if (!NSEqualRects([[_folderPaneViewController view] frame], folderFrame)) {
        [[_folderPaneViewController view] setFrame:folderFrame];
    }
    NSRect leftFrame = [_leftContainerView bounds];
    leftFrame.size.height = [animationContainerView frame].size.height;
    leftFrame.size.height -= 35;
    if (!NSEqualRects([[_conversationListViewController view] frame], leftFrame)) {
        [[_conversationListViewController view] setFrame:leftFrame];
    }

    [[[self window] contentView] addSubview:_splitView];

    if (initialFrame.size.width > frame.size.width) {
        [_toolbarView setLeftMargin:71];
    }
    else {
        [_toolbarView setLeftMargin:5];
    }

    [[self window] displayIfNeeded];

    [_toolbarView setVibrancy:vibrancy];
    [_conversationListViewController setVibrancy:vibrancy];
}

- (void) _search
{
    [_conversationListViewController toggleSearch];
}

- (void) refresh
{
    [_conversationListViewController refresh];
}

- (IBAction)saveAllAttachments:(id)sender
{
    [_conversationViewController saveAllAttachments:sender];
}

- (IBAction)printDocument:(id)sender
{
    [_conversationViewController printDocument:sender];
}

- (IBAction) toggleSidebar:(id)sender
{
    [self _setSidebarVisible:![self _hasFolderPanel] animated:YES];
}

- (void) _selectAccountOffset:(int)offset
{
    UnifiedAccount * account = [_conversationListViewController unifiedAccount];
    int idx = -1;
    if (account == UnifiedAccountManager::sharedManager()->unifiedAccount()) {
        idx = 0;
    }
    else {
        idx = UnifiedAccountManager::sharedManager()->accounts()->indexOfObject(account);
        if (idx != -1) {
            idx ++;
        }
    }
    if (idx == -1) {
        return;
    }

    idx += offset;
    idx %= (UnifiedAccountManager::sharedManager()->accounts()->count() + 1);

    if (idx == 0) {
        account = UnifiedAccountManager::sharedManager()->unifiedAccount();
    }
    else {
        account = (UnifiedAccount *) UnifiedAccountManager::sharedManager()->accounts()->objectAtIndex(idx - 1);
    }
    [_conversationListViewController setUnifiedAccount:account];
    [_conversationListViewController setFolderPath:MCO_TO_OBJC(account->inboxFolderPath())];
    [_toolbarView setFolderPath:MCO_TO_OBJC(account->inboxFolderPath())];
}

- (IBAction) selectNextAccount:(id)sender
{
    [self _selectAccountOffset:1];
}

- (IBAction) selectPreviousAccount:(id)sender
{
    [self _selectAccountOffset:-1];
}

#pragma mark -
#pragma mark account synchronizer delegate

- (void) _gotFolders:(Account *)account
{
    BOOL refresh = NO;
    if ([_conversationListViewController unifiedAccount]->accounts()->count() >= 2) {
        refresh = YES;
    }
    else {
        Account * singleAccount = (Account *) [_conversationListViewController unifiedAccount]->accounts()->objectAtIndex(0);
        refresh = (singleAccount == account);
    }
    if (refresh) {
        NSString * folderPath = nil;
        if ([_conversationListViewController unifiedAccount] != NULL) {
            folderPath = MCO_TO_OBJC([_conversationListViewController unifiedAccount]->inboxFolderPath());
        }
        [_conversationListViewController setFolderPath:folderPath];
        [_toolbarView setFolderPath:folderPath];
        [_folderPaneViewController setUnifiedAccount:[_conversationListViewController unifiedAccount]];
        [_folderPaneViewController setFolderPath:folderPath];
    }
}

- (void) _foldersUpdated
{
    if ([_conversationListViewController unifiedAccount] == NULL) {
        return;
    }

    if ([_conversationListViewController unifiedAccount]->folderIDForPath(MCO_FROM_OBJC(String, [_conversationListViewController folderPath])) == -1) {
        [self _reselectAccountIfNeeded];
    }
}

- (void) _accountStateUpdated
{
    [_debugActivityWindowController update];
    [_conversationListViewController accountStateUpdated];
}

- (void) _accountSyncDone:(hermes::ErrorCode)error folderPath:(NSString *)folderPath account:(Account *)account
{
    if (error != hermes::ErrorCode::ErrorNone) {
        return;
    }
    [self _clearCurrentErrorForAccount:account];
}

- (void) _updateToolbarError
{
    if ([_accountsErrors count] == 0 && [_accountsSendErrors count] == 0) {
        [_toolbarView setError:DJLConversationListToolbarViewErrorKindNone];
    }
    else {
        BOOL onlyConnectionError = YES;
        for(NSDictionary * currentError in [_accountsErrors allValues]) {
            hermes::ErrorCode code = (hermes::ErrorCode) [(NSNumber *) currentError[@"code"] intValue];
            if (code != hermes::ErrorConnection) {
                onlyConnectionError = NO;
            }
        }
        for(NSDictionary * currentError in [_accountsSendErrors allValues]) {
            hermes::ErrorCode code = (hermes::ErrorCode) [(NSNumber *) currentError[@"code"] intValue];
            if (code != hermes::ErrorConnection) {
                onlyConnectionError = NO;
            }
        }

        if (onlyConnectionError) {
            [_toolbarView setError:DJLConversationListToolbarViewErrorKindOffline];
        }
        else {
            [_toolbarView setError:DJLConversationListToolbarViewErrorKindError];
        }
    }
}

- (void) _showCurrentErrorWithOnlyAuthError:(BOOL)showOnlyAuthError
{
    if (_showingErrorDialog) {
        return;
    }

    [_toolbarView setError:DJLConversationListToolbarViewErrorKindNone];
    _showingErrorDialog = YES;
    int errorCount = (int) [_accountsErrors count];
    mc_foreacharray(Account, account, _accounts) {
        BOOL showThisError = NO;

        if (showOnlyAuthError) {
            if (![_shownAccountsError containsObject:MCO_TO_OBJC(account->accountInfo()->email())]) {
                if ([self _errorCodeForAccount:account] == hermes::ErrorAuthentication) {
                    showThisError = YES;
                }
            }
        }
        else if ([self _hasErrorForAccount:account]) {
            showThisError = YES;
        }

        if (showThisError) {
            [_shownAccountsError addObject:MCO_TO_OBJC(account->accountInfo()->email())];

            NSDictionary * currentError = [self _errorForAccount:account];
            NSAlert * alert = [[NSAlert alloc] init];
            [alert setMessageText:currentError[@"title"]];
            [alert setInformativeText:currentError[@"description"]];
            if (errorCount > 1) {
                [alert addButtonWithTitle:@"Next"];
            }
            [alert addButtonWithTitle:@"OK"];
            if ([self _errorCodeForAccount:account] == hermes::ErrorAuthentication) {
                [alert addButtonWithTitle:@"Open Account Settings..."];
            }

            NSModalResponse response = [alert runModal];
            BOOL stop = NO;
            BOOL openAccountSetting = NO;
            if (errorCount > 1) {
                switch (response) {
                    case 1000:
                        // next
                        break;
                    case 1001:
                        // ok
                        stop = YES;
                        break;
                    case 1002:
                        // open account settings
                        openAccountSetting = YES;
                        stop = YES;
                        break;
                }
            }
            else {
                switch (response) {
                    case 1000:
                        // ok
                        stop = YES;
                        break;
                    case 1001:
                        // open account settings
                        openAccountSetting = YES;
                        stop = YES;
                        break;
                }
            }
            if (([self _errorCodeForAccount:account] != hermes::ErrorConnection) &&
                ([self _errorCodeForAccount:account] != hermes::ErrorAuthentication)) {
                [self _clearCurrentErrorForAccount:account];
            }
            if (openAccountSetting) {
                [[self delegate] DJLMainWindowController:self openAccountPrefs:account];
                break;
            }
            if (stop) {
                break;
            }
            errorCount --;
        }
    }

    {
        BOOL hasConnectionErrorsOnly = YES;
        mc_foreacharray(Account, account, _accounts) {
            if (([self _errorCodeForAccount:account] != hermes::ErrorConnection) && ([self _errorCodeForAccount:account] != hermes::ErrorNone)) {
                hasConnectionErrorsOnly = NO;
            }
        }
        if (hasConnectionErrorsOnly) {
            [self refresh];
        }
    }

    _showingErrorDialog = NO;
    [self _updateToolbarError];
}

- (BOOL) _hasErrorForAccount:(Account *)account
{
    return [self _errorCodeForAccount:account] != hermes::ErrorNone;
}

- (hermes::ErrorCode) _errorCodeForAccount:(Account *)account
{
    NSDictionary * currentError = [self _errorForAccount:account];
    if (currentError == nil) {
        return hermes::ErrorNone;
    }
    return (hermes::ErrorCode) [(NSNumber *) currentError[@"code"] intValue];
}

- (void) _clearCurrentErrorForAccount:(Account *)account
{
    [_shownAccountsError removeObject:MCO_TO_OBJC(account->accountInfo()->email())];
    [_accountsErrors removeObjectForKey:MCO_TO_OBJC(account->accountInfo()->email())];
    [self _updateToolbarError];
}

- (void) _clearCurrentSendErrorForAccount:(Account *)account
{
    [_accountsSendErrors removeObjectForKey:MCO_TO_OBJC(account->accountInfo()->email())];
    [self _updateToolbarError];
}

- (NSDictionary *) _errorForAccount:(Account *)account
{
    if (_accountsSendErrors[MCO_TO_OBJC(account->accountInfo()->email())] != nil) {
        return _accountsSendErrors[MCO_TO_OBJC(account->accountInfo()->email())];
    }
    return _accountsErrors[MCO_TO_OBJC(account->accountInfo()->email())];
}

- (void) _setErrorCode:(hermes::ErrorCode)code
                 title:(NSString *)title
           description:(NSString *)description
            forAccount:(Account *)account
{
    NSDictionary * currentError = @{@"code": [NSNumber numberWithInt:(int)code],
                                    @"title": title,
                                    @"description": description};
    _accountsErrors[MCO_TO_OBJC(account->accountInfo()->email())] = currentError;
}

- (void) _setSendErrorCode:(hermes::ErrorCode)code
                     title:(NSString *)title
               description:(NSString *)description
                forAccount:(Account *)account
{
    NSDictionary * currentError = @{@"code": [NSNumber numberWithInt:(int)code],
                                    @"title": title,
                                    @"description": description};
    _accountsSendErrors[MCO_TO_OBJC(account->accountInfo()->email())] = currentError;
}

- (void) _notifyAuthenticationError:(hermes::ErrorCode)error account:(Account *)account
{
    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setErrorCode:error
                  title:[NSString stringWithFormat:@"Authentication error (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:@"DejaLu could not authenticate against the server. Please check that the password is correct."
             forAccount:account];
    [self _updateToolbarError];

    [self performSelector:@selector(_showAuthenticationError) withObject:nil afterDelay:0 inModes:@[NSRunLoopCommonModes]];
}

- (void) _showAuthenticationError
{
    [self _showCurrentErrorWithOnlyAuthError:YES];
}

- (void) _notifyConnectionError:(hermes::ErrorCode)error account:(Account *)account
{
    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setErrorCode:error
                  title:[NSString stringWithFormat:@"Connection error (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:@"DejaLu could not connect to the server. Please retry later."
             forAccount:account];
    [self _updateToolbarError];
}

- (void) _notifyFatalError:(hermes::ErrorCode)error account:(Account *)account
{
    if ([self _errorCodeForAccount:account] == hermes::ErrorConnection) {
        [self _clearCurrentErrorForAccount:account];
    }
    if ([self _hasErrorForAccount:account]) {
        return;
    }

    if (error == hermes::ErrorGmailTooManySimultaneousConnections) {
        [self _setErrorCode:error
                      title:[NSString stringWithFormat:@"Too many connections (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
                description:@"DejaLu could not connect to the server because there are too many simultaneous connections to the server. Please retry later."
                 forAccount:account];
    }
    else {
        [self _setErrorCode:error
                      title:[NSString stringWithFormat:@"Fatal error (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
                description:[NSString stringWithFormat:@"DejaLu failed to perform the operation (%i).", (int) error]
                 forAccount:account];
    }
    [self _updateToolbarError];
}

- (void) _notifyCopyError:(hermes::ErrorCode)error account:(Account *)account
{
    if ([self _errorCodeForAccount:account] == hermes::ErrorConnection || [self _errorCodeForAccount:account] == hermes::ErrorAuthentication) {
        [self _clearCurrentErrorForAccount:account];
    }
    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setErrorCode:error
                  title:[NSString stringWithFormat:@"Error while copying messages (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:@"DejaLu could not perform the copy. Please retry later."
             forAccount:account];
    [self _updateToolbarError];
}

- (void) _notifyAppendError:(hermes::ErrorCode)error account:(Account *)account
{
    if ([self _errorCodeForAccount:account] == hermes::ErrorConnection || [self _errorCodeForAccount:account] == hermes::ErrorAuthentication) {
        [self _clearCurrentErrorForAccount:account];
    }
    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setErrorCode:error
                  title:[NSString stringWithFormat:@"Error while saving a message (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:@"DejaLu could not save a message. Please retry later."
             forAccount:account];
    [self _updateToolbarError];
}

- (void) _imapAccountInfoChanged:(Account *)account
{
    account->save();
}

- (void) _senderDone:(Account *)account
{
    [self _clearCurrentSendErrorForAccount:account];

    DJLEmailSentOverlayView * view = [[DJLEmailSentOverlayView alloc] initWithFrame:NSMakeRect(0,0, 150, 150)];
    [view setCount:account->totalMessagesCount()];
    [DJLHUDWindow windowWithView:view];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SoundEnabled"]) {
        if (_mailSentSound == nil) {
            _mailSentSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"mailsent" ofType:@"m4a"] byReference:YES];
        }
        [_mailSentSound play];
    }
}

- (void) _senderFailed:(Account *)account
{
    DJLEmailSentOverlayView * view = [[DJLEmailSentOverlayView alloc] initWithFrame:NSMakeRect(0,0, 150, 150)];
    [view setFailed:YES];
    [view setCount:account->totalMessagesCount()];
    [DJLHUDWindow windowWithView:view];
}

- (void) _senderStateChanged:(Account *)account
{
    [self _senderProgress:account];
}

- (void) _senderMessageSent:(MessageParser *)message account:(Account *)account
{
    [self _senderProgress:account];
}

- (void) _senderProgress:(Account *)account
{
    /*
    NSLog(@"progress while sending %i / %i, %i / %i",
          _account->currentMessageIndex(),
          _account->totalMessagesCount(),
          _account->currentMessageProgress(),
          _account->currentMessageProgressMax());
     */
    [_debugActivityWindowController update];
    [_conversationListViewController accountStateUpdated];
}

- (void) _senderAccountInfoChanged:(Account *)account
{
    account->save();
}

- (void) _senderNotifyAuthenticationError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account
{
    [self _senderProgress:account];
    [self _senderFailed:account];

    // Always show authentication error.
    [self _setSendErrorCode:error
                  title:[NSString stringWithFormat:@"Authentication error (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:@"DejaLu could not send a message because it could not authenticate against the server. Please check that the password is correct."
             forAccount:account];
    [self _updateToolbarError];
    
    [self _showCurrentErrorWithOnlyAuthError:YES];
}

- (void) _senderNotifyConnectionError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account
{
    [self _senderProgress:account];
    [self _senderFailed:account];

    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setSendErrorCode:error
                  title:[NSString stringWithFormat:@"Connection error (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:@"DejaLu could not send a message because it could not connect to the server. The emails will be sent automatically when the connection is back."
             forAccount:account];
    [self _updateToolbarError];
}

- (void) _senderNotifyFatalError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account
{
    [self _senderProgress:account];
    [self _senderFailed:account];

    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setSendErrorCode:error
                  title:[NSString stringWithFormat:@"Fatal error (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
            description:[NSString stringWithFormat:@"DejaLu failed to perform the operation (%i).", (int) error]
             forAccount:account];
    [self _updateToolbarError];
}

- (void) _senderNotifySendError:(hermes::ErrorCode)error message:(MessageParser *)parsedMessage account:(Account *)account
{
    [self _senderProgress:account];
    [self _senderFailed:account];

    if ([self _hasErrorForAccount:account]) {
        return;
    }

    [self _setSendErrorCode:error
                      title:[NSString stringWithFormat:@"Error with this message (%@)", MCO_TO_OBJC(account->accountInfo()->email())]
                description:[NSString stringWithFormat:@"DejaLu failed to perform the operation (%i).", (int) error]
                 forAccount:account];
    [self _updateToolbarError];
}

- (void) _hasConversationID:(int64_t)conversationID forMessageID:(NSString *)messageID account:(Account *)account
{
    if (conversationID != -1) {
        _urlMessageIDFound = conversationID;
        MC_SAFE_RELEASE(_urlMessageAccount);
        _urlMessageAccount = account;
        MC_SAFE_RETAIN(account);
    }
    _urlMessageIDCount --;
    if (_urlMessageIDCount == 0) {
        if (_urlMessageIDFound != -1) {
            int64_t folderID = _urlMessageAccount->folderIDForPath(_urlMessageAccount->inboxFolderPath());
            _urlMessageAccount->openViewForFolder(folderID);
            MailStorageView * storageView = _urlMessageAccount->viewForFolder(folderID);

            DJLConversationWindowController * controller = [[DJLConversationWindowController alloc] init];
            [controller setup];
            [controller setAccount:_urlMessageAccount];
            [controller setStorageView:storageView];
            [controller setConvID:_urlMessageIDFound];
            [controller loadConversation];
            [controller setDelegate:self];
            // cascade.
            if ([_convWindowControllers count] > 0) {
                DJLConversationWindowController * lastController = [_convWindowControllers lastObject];
                NSRect lastWindowFrame = [[lastController window] frame];
                lastWindowFrame.origin.x += 30;
                lastWindowFrame.origin.y -= 30;
                [[controller window] setFrame:lastWindowFrame display:NO];
            }
            [controller showWindow:nil];
            [_convWindowControllers addObject:controller];

            _urlMessageAccount->closeViewForFolder(folderID);

            MC_SAFE_RELEASE(_urlMessageAccount);
            _urlMessageIDFound = -1;
        }
    }
}

- (void) _messageSourceFetchedWithError:(hermes::ErrorCode)error folderID:(int64_t)folderID messageRowID:(int64_t)messageRowID messageData:(NSData *)messageData account:(Account *)account
{
    NSString * downloadFolder = [@"~/Downloads" stringByExpandingTildeInPath];
    NSString * basename = [NSString stringWithFormat:@"%lli.eml", (long long int) messageRowID];
    NSString * downloadFile = MCO_TO_OBJC(hermes::uniquePath(MCO_FROM_OBJC(String, downloadFolder), MCO_FROM_OBJC(String, basename)));
    [messageData writeToFile:downloadFile atomically:NO];
    [[NSWorkspace sharedWorkspace] selectFile:downloadFile inFileViewerRootedAtPath:@""];
}

- (void) _editDraftMessage:(int64_t)messageRowID folderID:(int64_t)folderID account:(Account *)account
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"EditDraft" label:@"Open an existing draft" value:@(0)];

    DJLComposerWindowController * controller = [[DJLComposerWindowController alloc] init];
    [controller setDefaultEmailAliasForAccount:account];
    [controller setDelegate:self];
    [controller loadDraftMessageRowID:messageRowID folderID:folderID account:account];
    [_composers addObject:controller];
}

- (void) _composeWithAddress:(MCOAddress *)address account:(Account *)account
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"OpenWithRecipient" label:@"Open a composer by using context menu on an address" value:@(0)];
    DJLComposerWindowController * controller = [[DJLComposerWindowController alloc] init];
    [controller setDefaultEmailAliasForAccount:account];
    [controller setDelegate:self];
    [controller setTo:[address RFC822String] cc:nil bcc:nil subject:nil htmlBody:nil];
    [self _cascadeComposer:controller];
    [controller showWindow:nil];
    [_composers addObject:controller];
}

- (void) _showSourceForMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID account:(Account *)account
{
    account->fetchMessageSource(folderID, messageRowID);
}

#pragma mark -
#pragma mark debug methods

- (void) debugOpenAccountFolder
{
    NSString * path = [[DJLPathManager sharedManager] accountsFolder];
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
}

- (void) debugActivity
{
    if (_debugActivityWindowController == nil) {
        _debugActivityWindowController = [[DJLActivityWindowController alloc] init];
    }
    if ([[_debugActivityWindowController window] isVisible]) {
        [_debugActivityWindowController close];
    }
    else {
        [_debugActivityWindowController showWindow:nil];
    }
}

#pragma mark -
#pragma mark toolbar delegate

- (void) DJLConversationListToolbarViewCompose:(DJLConversationListToolbarView *)toolbar
{
    [self composeMessage];
}

- (void) DJLConversationListToolbarViewSearch:(DJLConversationListToolbarView *)toolbar
{
    [self _search];
}

- (hermes::UnifiedAccount *) DJLConversationListToolbarViewAccount:(DJLConversationListToolbarView *)toolbar
{
    return [_conversationListViewController unifiedAccount];
}

- (void) DJLConversationListToolbarView:(DJLConversationListToolbarView *)toolbar
                        selectedAccount:(hermes::UnifiedAccount *)account
                           selectedPath:(NSString *)path
{
    [_conversationListViewController setUnifiedAccount:account];
    [_conversationListViewController setFolderPath:path];
    [_folderPaneViewController setUnifiedAccount:account];
    [_folderPaneViewController setFolderPath:path];
    [_toolbarView setFolderPath:path];
    [_toolbarView validate];
}

- (void) DJLConversationListToolbarViewShowError:(DJLConversationListToolbarView *)toolbar
{
    [self _showCurrentErrorWithOnlyAuthError:NO];
}

- (void) DJLConversationListToolbarView:(DJLConversationListToolbarView *)toolbar openFoldersManager:(hermes::Account *)account
{
    [[self delegate] DJLMainWindowController:self openLabelsPrefsForAccount:account];
}

- (void) DJLConversationListToolbarViewCleanup:(DJLConversationListToolbarView *)toolbar;
{
    _cleanupWindowController = [[DJLCleanupWindowController alloc] init];
    [_cleanupWindowController setUnifiedAccount:[_conversationListViewController unifiedAccount]];
    [_cleanupWindowController setUnifiedStorageView:[_conversationListViewController currentUnifiedStorageView]];
    [_cleanupWindowController setDelegate:self];

    NSArray * conversationsInfos = [_conversationListViewController allConversationsInfos];
    NSMutableArray * recentConversationsInfos = [[NSMutableArray alloc] init];
    time_t current_time = time(NULL);
    for(NSDictionary * conversation in conversationsInfos) {
        time_t date = [(NSNumber *) [conversation objectForKey:@"timestamp"] longLongValue];
        if (current_time - date > 30 * 86400) {
            continue;
        }
        [recentConversationsInfos addObject:conversation];
    }
    [_cleanupWindowController setConversations:recentConversationsInfos];

    if ([[_cleanupWindowController conversations] count] == 0) {
        _cleanupWindowController = nil;

        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Clean up notifications"];
        [alert setInformativeText:@"No notifications were found in the last 30 days."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];

        return;
    }

    [_cleanupWindowController showWindow:nil];
}

#pragma mark -
#pragma mark conversation list delegate

- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller separatorAlphaValue:(CGFloat)alphaValue
{
    [_toolbarView setSeparatorAlphaValue:alphaValue];
}

- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller setRefreshFeedbackVisible:(BOOL)visible
{
    _refreshActionInProgress = visible;
    [self _updateRefreshFeedback];
}

- (void) DJLConversationListViewControllerConfirmRefresh:(DJLConversationListViewController *)controller
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_refreshConfirmationDone) object:nil];
    _refreshConfirmation = YES;
    [self performSelector:@selector(_refreshConfirmationDone) withObject:nil afterDelay:1.5];
    [self _updateRefreshFeedback];
}

- (void) _refreshConfirmationDone
{
    _refreshConfirmation = NO;
    [self _updateRefreshFeedback];
}

- (void) _updateRefreshFeedback
{
    [_conversationListViewController setRefreshing:_refreshConfirmation];
}

- (void) DJLConversationListViewControllerSelectionChanged:(DJLConversationListViewController *)controller
{
    [self _updateConversationPanel];
    [_conversationToolbarView validate];
}

- (void) _updateConversationPanel
{
    if (![self _hasConversationPanel]) {
        return;
    }

    switch ([[_conversationListViewController selectedConversationsIDs] count]) {
        case 0:
        default:
        {
            [_conversationToolbarView setDraft:NO];
            NSRect frame = [_conversationPanel bounds];
            frame.size.height -= 35;
            [[_selectionViewController view] setFrame:frame];
            if (![[_conversationPanel subviews] containsObject:[_selectionViewController view]]) {
                [[_conversationViewController view] removeFromSuperview];
                [_conversationPanel addSubview:[_selectionViewController view]];
            }

            [_selectionViewController setFolderPath:nil];
            if ([_conversationListViewController unifiedAccount] != NULL) {
                if ([_conversationListViewController unifiedAccount]->searchKeywords() == NULL) {
                    [_selectionViewController setFolderPath:[_conversationListViewController folderPath]];
                }
            }
            
            [_selectionViewController setUnifiedAccount:[_conversationListViewController unifiedAccount]];
            [_selectionViewController setUnifiedStorageView:[_conversationListViewController currentUnifiedStorageView]];
            [_selectionViewController setConversations:[_conversationListViewController selectedConversationsInfos]];
            [_selectionViewController setSelectionCount:(int) [[_conversationListViewController selectedConversationsIDs] count]];
            break;
        }
        case 1:
        {
            NSRect frame = [_conversationPanel bounds];
            frame.size.height -= 35;
            [[_conversationViewController view] setFrame:frame];
            if (![[_conversationPanel subviews] containsObject:[_conversationViewController view]]) {
                [[_selectionViewController view] removeFromSuperview];
                [_conversationPanel addSubview:[_conversationViewController view]];
            }
            DJLUnifiedConversationID * convIDContainer = [_conversationListViewController selectedConversationsIDs][0];
            MailStorageView * storageView = [_conversationListViewController storageViewForSingleSelection];
            if (([_conversationViewController convID] == [convIDContainer convID]) &&
                ([_conversationViewController storageView] == storageView)) {
                // No change. Don't reload.
                return;
            }
            [_conversationViewController setAccount:[_conversationListViewController accountForSingleSelection]];
            [_conversationViewController setConvID:[convIDContainer convID]];
            [_conversationViewController setStorageView:storageView];
            [_conversationViewController loadConversation];
            break;
        }
    }
}

- (void) DJLConversationListViewControllerOpenConversationWindow:(DJLConversationListViewController *)controller
{
    [self _openConversationWindow];
}

- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller
                                   account:(Account *)account
                         replyMessageRowID:(int64_t)rowID
                                  folderID:(int64_t)folderID
                                 replyType:(DJLReplyType)replyType
{
    [self _replyMessageRowID:rowID folderID:folderID replyType:replyType account:account];
}

- (void) DJLConversationListViewController:(DJLConversationListViewController *)controller
                                   account:(Account *)account
                     editDraftConversation:(int64_t)conversationRowID folderID:(int64_t)folderID
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"EditDraft" label:@"Open an existing draft" value:@(0)];

    DJLComposerWindowController * composerController = [[DJLComposerWindowController alloc] init];
    [composerController setDefaultEmailAliasForAccount:account];
    [composerController setDelegate:self];
    [composerController loadDraftMessageForConversationRowID:conversationRowID folderID:folderID account:account];
    [_composers addObject:composerController];
}

- (void) DJLConversationListViewControllerNotifyRefreshError:(DJLConversationListViewController *)controller account:(hermes::Account *)account
{
    [self _notifyConnectionError:hermes::ErrorConnection account:account];
}

- (void) DJLConversationListViewControllerExpandDetails:(DJLConversationListViewController *)controller
{
    if ([self _hasConversationPanel]) {
        if ([[_conversationViewController view] superview] != nil) {
            [[self window] makeFirstResponder:[_conversationViewController view]];
        }
        else {
            [[self window] makeFirstResponder:[_selectionViewController view]];
        }
    }
    else {
        [self toggleDetails:nil];
        if ([[_conversationViewController view] superview] != nil) {
            [[self window] makeFirstResponder:[_conversationViewController view]];
        }
        else {
            [[self window] makeFirstResponder:[_selectionViewController view]];
        }
    }
}

- (void) DJLConversationListViewControllerCollapseDetails:(DJLConversationListViewController *)controller
{
    if ([self _hasConversationPanel]) {
        [self toggleDetails:nil];
    }
}

- (void) DJLConversationListViewControllerSearchStateChanged:(DJLConversationListViewController *)controller
{
    [_toolbarView validate];
}

- (void) DJLFolderPaneViewControllerScrollToTop:(DJLFolderPaneViewController *)controller
{
    [_conversationListViewController refreshAndScrollToTop];
}

#pragma mark -
#pragma mark splitview delegate

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
    if (!_togglingDetails) {
        [self _savePosition];
    }
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    if (_togglingDetails) {
        return FLT_MAX;
    }

    if ([self _hasFolderPanel]) {
        if (dividerIndex == 0) {
            CGFloat maxWidth = SIDEBAR_MAX_WIDTH;
            CGFloat remainingWidth = [_splitView frame].size.width;
            if ([self _hasConversationPanel]) {
                //remainingWidth -= CONVERSATION_MIN_WIDTH + [_splitView dividerThickness];
                remainingWidth -= [_conversationPanel frame].size.width + [_splitView dividerThickness];
            }
            remainingWidth -= LEFT_MIN_WIDTH + [_splitView dividerThickness];
            if (remainingWidth < maxWidth) {
                maxWidth = remainingWidth;
            }
            return maxWidth;
        }
        else {
            CGFloat x = NSMinX([_leftContainerView frame]) + LEFT_MAX_WIDTH;
            CGFloat x2 = [_splitView frame].size.width - (CONVERSATION_MIN_WIDTH + [_splitView dividerThickness]);
            if (x2 < x) {
                x = x2;
            }
            return x;
        }
    }
    else {
        CGFloat maxWidth = LEFT_MAX_WIDTH;
        CGFloat remainingWidth = [_splitView frame].size.width - (CONVERSATION_MIN_WIDTH + [_splitView dividerThickness]);
        if (remainingWidth < maxWidth) {
            maxWidth = remainingWidth;
        }
        return maxWidth;
    }
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    if (_togglingDetails) {
        return 0;
    }

    if ([self _hasFolderPanel]) {
        if (dividerIndex == 0) {
            CGFloat minWidth = SIDEBAR_MIN_WIDTH;
            CGFloat x = NSMaxX([_leftContainerView frame]);
            x -= LEFT_MAX_WIDTH;
            if (minWidth > x) {
                x = minWidth;
            }
            return x;
        }
        else {
            CGFloat x = NSMinX([_leftContainerView frame]);
            x += LEFT_MIN_WIDTH;
            return x;
        }
    }
    else {
        CGFloat x = NSMinX([_leftContainerView frame]);
        x += LEFT_MIN_WIDTH;
        return x;
    }
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    _splitViewAllowResize[0] = NO;
    _splitViewAllowResize[1] = NO;
    _splitViewAllowResize[2] = NO;
    if (oldSize.width > [splitView frame].size.width) {
        // size decreasing
        if ([self _hasConversationPanel]) {
            if ([_conversationPanel frame].size.width <= CONVERSATION_MIN_WIDTH) {
                if ([self _hasFolderPanel]) {
                    if ([_folderContainerView frame].size.width <= SIDEBAR_MIN_WIDTH) {
                        _splitViewAllowResize[1] = YES;
                    }
                    else {
                        _splitViewAllowResize[0] = YES;
                    }
                }
                else {
                    _splitViewAllowResize[0] = YES;
                }
            }
            else {
                _splitViewAllowResize[[[splitView subviews] indexOfObject:_conversationPanel]] = YES;
            }
        }
        else if ([self _hasFolderPanel]) {
            if ([_leftContainerView frame].size.width <= LEFT_MIN_WIDTH) {
                _splitViewAllowResize[0] = YES;
            }
            else {
                _splitViewAllowResize[1] = YES;
            }
        }
    }
    else {
        // size increasing
        if ([self _hasConversationPanel]) {
            _splitViewAllowResize[[[splitView subviews] indexOfObject:_conversationPanel]] = YES;
        }
        else if ([[splitView subviews] indexOfObject:_leftContainerView] != NSNotFound) {
            _splitViewAllowResize[[[splitView subviews] indexOfObject:_leftContainerView]] = YES;
        }
    }
    [_splitView adjustSubviews];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
{
    return _splitViewAllowResize[[[splitView subviews] indexOfObject:subview]];
}

#pragma mark -
#pragma mark conversation toolbar delegate

- (void) DJLConversationToolbarViewReply:(DJLConversationToolbarView *)view
{
    [_conversationViewController replyMessage:nil];
}

- (void) DJLConversationToolbarViewForward:(DJLConversationToolbarView *)view
{
    [_conversationListViewController forwardMessage:nil];
}

- (void) DJLConversationToolbarViewArchive:(DJLConversationToolbarView *)view
{
    [_conversationListViewController archiveMessage:nil];
}

- (void) DJLConversationToolbarViewTrash:(DJLConversationToolbarView *)view
{
    [_conversationListViewController deleteMessage:nil];
}

- (void) DJLConversationToolbarViewLabel:(DJLConversationToolbarView *)view
{
    [self _showLabelsPopOverAndArchive:NO];
}

- (void) DJLConversationToolbarViewSaveAttachments:(DJLConversationToolbarView *)view
{
    [_conversationViewController saveAllAttachments:nil];
}

- (void) DJLConversationToolbarViewEditDraft:(DJLConversationToolbarView *)view
{
    [_conversationViewController editDraft];
}

- (void) DJLConversationToolbarViewFocusWebView:(DJLConversationToolbarView *)view
{
    [[self window] makeFirstResponder:[_conversationViewController view]];
}

- (void) DJLConversationToolbarViewSearch:(DJLConversationToolbarView *)view
{
    [_conversationViewController searchWithString:[_conversationToolbarView searchString]];
}

- (void) DJLConversationToolbarViewCancelSearch:(DJLConversationToolbarView *)view
{
    [_conversationViewController cancelSearch];
}

- (void) DJLConversationToolbarViewSearchNext:(DJLConversationToolbarView *)view
{
    [_conversationViewController findNext:nil];
}

#define WIDTH 300
#define HEIGHT 500

- (void) _showLabelsPopOverAndArchive:(BOOL)archive
{
    if ([_labelsPopOver isShown]) {
        return;
    }

    if ([[_conversationListViewController selectedConversationsIDs] count] == 0) {
        return;
    }
    if ([_conversationListViewController uniqueAccountForSelection] == NULL) {
        return;
    }
    if ([_conversationListViewController uniqueAccountForSelection]->accountInfo()->providerIdentifier() == NULL) {
        return;
    }

    NSArray * conversationsInfos = [_conversationListViewController selectedConversationsInfos];

    DJLLabelsViewController * labelsViewController = [[DJLLabelsViewController alloc] init];
    [labelsViewController setArchiveEnabled:archive];
    if (![_conversationListViewController uniqueAccountForSelection]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        [labelsViewController setArchiveEnabled:YES];
    }
    [labelsViewController setDelegate:self];
    [[labelsViewController view] setFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
    [labelsViewController setConversations:conversationsInfos];
    [labelsViewController setAccount:[_conversationListViewController uniqueAccountForSelection]];
    [labelsViewController setStorageView:[_conversationListViewController storageViewForSingleSelection]];
    [labelsViewController setFolderPath:nil];
    if ([_conversationListViewController unifiedAccount] != NULL) {
        if ([_conversationListViewController unifiedAccount]->searchKeywords() == NULL) {
            [labelsViewController setFolderPath:[_conversationListViewController folderPath]];
        }
    }
    [labelsViewController reloadData];
    _labelsPopOver = [[NSPopover alloc] init];
    [_labelsPopOver setContentViewController:labelsViewController];
    [_labelsPopOver setBehavior:NSPopoverBehaviorTransient];
    [_labelsPopOver setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    [_labelsPopOver showRelativeToRect:[_conversationToolbarView labelButtonRect] ofView:_conversationToolbarView
                         preferredEdge:NSMinYEdge];
}

#pragma mark DJLLabelsViewController delegate

- (void) DJLLabelsViewControllerClose:(DJLLabelsViewController *)controller
{
    [_labelsPopOver close];
}

#pragma mark -
#pragma mark conversation window controller delegate

- (void) DJLConversationWindowControllerClose:(DJLConversationWindowController *)controller
{
    [controller setDelegate:nil];
    [_convWindowControllers removeObject:controller];
}

- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
                       replyMessageRowID:(int64_t)messageRowID
                                folderID:(int64_t)folderID
                               replyType:(DJLReplyType)replyType
{
    [self _replyMessageRowID:messageRowID folderID:folderID replyType:replyType account:[controller account]];
}

- (void) DJLConversationWindowControllerArchive:(DJLConversationWindowController *)controller
{
    [controller account]->archivePeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([controller convID])),
                                                     [controller storageView]->foldersScores());
}

- (void) DJLConversationWindowControllerDelete:(DJLConversationWindowController *)controller
{
    if ([controller account]->trashFolderPath() == NULL) {
        [self _showAlertTrashMissing:[controller account]];
        return;
    }
    if ([controller storageView]->folderID() == [controller storageView]->trashFolderID()) {
        [controller account]->purgeFromTrashPeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([controller convID])));
    }
    else {
        [controller account]->deletePeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([controller convID])),
                                                        [controller storageView]->foldersScores());
    }
}

- (void) _showAlertTrashMissing:(Account *)account
{
    NSAlert * alert = [[NSAlert alloc] init];
    NSString * title = [NSString stringWithFormat:@"Trash folder is required for %@", MCO_TO_OBJC(account->accountInfo()->email())];
    [alert setMessageText:title];
    [alert setInformativeText:@"DejaLu needs the Trash folder to delete emails. You can enable it in Gmail settings on the web > Labels > Check 'Show in IMAP' for Trash."];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void) _replyMessageRowID:(int64_t)messageRowID folderID:(int64_t)folderID replyType:(DJLReplyType)replyType account:(Account *)account
{
    DJLComposerWindowController * composer = [[DJLComposerWindowController alloc] init];
    [composer setDefaultEmailAliasForAccount:account];
    //[composer setAccount:account];

    if (replyType == DJLReplyTypeForward) {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"Forward" label:@"Open a forward composer" value:@(0)];
        [composer forwardMessageRowID:messageRowID folderID:folderID account:account];
    }
    else {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"Reply" label:@"Open a reply composer" value:@(0)];
        [composer replyMessageRowID:messageRowID folderID:folderID account:account];
    }

    [composer setDelegate:self];

    [self _cascadeComposer:composer];

    [composer showWindow:nil];
    [_composers addObject:composer];
}

- (void) _cascadeComposer:(DJLComposerWindowController *)controller
{
    // cascade.
    if ([_composers count] > 0) {
        DJLComposerWindowController * lastController = [_composers lastObject];
        NSRect lastWindowFrame = [[lastController window] frame];
        lastWindowFrame.origin.x += 30;
        lastWindowFrame.origin.y -= 30;
        [[controller window] setFrame:lastWindowFrame display:NO];
    }
}

- (BOOL) DJLConversationWindowControllerShouldSave:(DJLConversationWindowController *)controller
{
    return [_convWindowControllers count] == 1;
}

- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
                        editDraftMessage:(int64_t)messageRowID
                                folderID:(int64_t)folderID
{
    [self _editDraftMessage:messageRowID folderID:folderID account:[controller account]];
}

- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
                      composeWithAddress:(MCOAddress *)address
{
    [self _composeWithAddress:address account:[controller account]];
}

- (void) DJLConversationWindowController:(DJLConversationWindowController *)controller
               showSourceForMessageRowID:(int64_t)messageRowID
                                folderID:(int64_t)folderID
{
    [self _showSourceForMessageRowID:messageRowID folderID:folderID account:[controller account]];
}

#pragma mark -
#pragma mark conversation view controller delegate

- (void) DJLConversationViewController:(DJLConversationViewController *)controller separatorAlphaValue:(CGFloat)alphaValue
{
    [_conversationToolbarView setSeparatorAlphaValue:alphaValue];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                     replyMessageRowID:(int64_t)messageRowID
                              folderID:(int64_t)folderID
                             replyType:(DJLReplyType)replyType
{
    [self _replyMessageRowID:messageRowID folderID:folderID replyType:replyType account:[controller account]];
}

- (void) DJLConversationViewControllerArchive:(DJLConversationViewController *)controller
{
    [controller account]->archivePeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([controller convID])),
                                                     [controller storageView]->foldersScores());
}

- (void) DJLConversationViewControllerDelete:(DJLConversationViewController *)controller
{
    if ([controller account]->trashFolderPath() == NULL) {
        [self _showAlertTrashMissing:[controller account]];
        return;
    }
    if ([controller storageView]->folderID() == [controller storageView]->trashFolderID()) {
        [controller account]->purgeFromTrashPeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([controller convID])));
    }
    else {
        [controller account]->deletePeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([controller convID])),
                                                        [controller storageView]->foldersScores());
    }
}

- (void) DJLConversationView:(DJLConversationViewController *)controller
                draftEnabled:(BOOL)draftEnabled
{
    [_conversationToolbarView setDraft:draftEnabled];
}

- (void) DJLConversationView:(DJLConversationViewController *)controller
            editDraftMessage:(int64_t)messageRowID folderID:(int64_t)folderID
{
    [self _editDraftMessage:messageRowID folderID:folderID account:[controller account]];
}

- (void) DJLConversationViewSearch:(DJLConversationViewController *)controller
{
    [_conversationToolbarView focusSearch];
}

- (void) DJLConversationViewShowLabelsPanel:(DJLConversationViewController *)controller
                                    archive:(BOOL)archive
{
    [self _showLabelsPopOverAndArchive:archive];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                    composeWithAddress:(MCOAddress *)address
{
    [self _composeWithAddress:address account:[controller account]];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
             showSourceForMessageRowID:(int64_t)messageRowID
                              folderID:(int64_t)folderID
{
    [self _showSourceForMessageRowID:messageRowID folderID:folderID account:[controller account]];
}

- (void) DJLConversationViewControllerFocusConversationList:(DJLConversationViewController *)controller
{
    [_conversationListViewController makeFirstResponder];
}

- (void) DJLConversationViewValidateToolbar:(DJLConversationViewController *)controller
{
    _conversationToolbarEnabled = YES;
    [_conversationToolbarView validate];
}

- (void) DJLConversationViewDisableToolbar:(DJLConversationViewController *)controller
{
    _conversationToolbarEnabled = NO;
    [_conversationToolbarView validate];
}

#pragma mark -
#pragma mark conversations selection controller delegate

- (void) DJLConversationSelectionViewControllerArchive:(DJLConversationSelectionViewController *)controller
{
    [_conversationListViewController archiveMessage:nil];
}

- (void) DJLConversationSelectionViewControllerTrash:(DJLConversationSelectionViewController *)controller
{
    [_conversationListViewController deleteMessage:nil];
}

- (void) DJLConversationSelectionViewControllerToggleRead:(DJLConversationSelectionViewController *)controller
{
    [_conversationListViewController toggleRead:nil];
}

- (void) DJLConversationSelectionViewControllerToggleStar:(DJLConversationSelectionViewController *)controller
{
    [_conversationListViewController toggleStar:nil];
}

- (void) DJLConversationSelectionViewControllerFocusConversationList:(DJLConversationSelectionViewController *)controller
{
    [_conversationListViewController makeFirstResponder];
}

#pragma mark -
#pragma mark composer window controller delegate.

- (void) DJLComposerWindowControllerWillClose:(DJLComposerWindowController *)controller
{
    [self _closeComposer:controller];
}

- (void) _closeComposer:(DJLComposerWindowController *)controller
{
    [_composers removeObject:controller];
}

- (BOOL) DJLComposerWindowControllerShouldSave:(DJLComposerWindowController *)controller
{
    return [_composers count] == 1;
}

- (void) DJLComposerWindowControllerShow:(DJLComposerWindowController *)controller
{
    [self _cascadeComposer:controller];
    [controller showWindow:nil];
}

- (DJLComposerWindowController *) DJLComposerWindowController:(DJLComposerWindowController *)controller hasMessageID:(NSString *)messageID
{
    for(DJLComposerWindowController * currentController in _composers) {
        if (currentController == controller) {
            continue;
        }
        if (![[currentController window] isVisible]) {
            continue;
        }
        if ([[currentController messageID] isEqualToString:messageID]) {
            return currentController;
        }
    }

    return nil;
}

#pragma mark -
#pragma mark DJLFolderPaneViewControllerDelegate

- (void) DJLFolderPaneViewController:(DJLFolderPaneViewController *)controller didSelectPath:(NSString *)path unifiedAccount:(hermes::UnifiedAccount *)unifiedAccount
{
    [_conversationListViewController setUnifiedAccount:unifiedAccount];
    [_conversationListViewController setFolderPath:path];
    [_toolbarView setFolderPath:path];
    [_toolbarView validate];
}

- (void) DJLFolderPaneViewControllerCollapseDetails:(DJLFolderPaneViewController *)controller
{
    if ([self _hasConversationPanel]) {
        [self toggleDetails:nil];
    }
}

- (void) DJLFolderPaneViewControllerFocusConversationList:(DJLFolderPaneViewController *)controller
{
    [_conversationListViewController makeFirstResponder];
}

#pragma mark -
#pragma mark window delegate

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [self _updateFirstResponderState];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self _updateFirstResponderState];
}

- (void) _updateFirstResponderState
{
    [_conversationListViewController updateFirstResponderState];
}

- (void) _appStateDidChange
{
    [self _updateFirstResponderState];
}

#pragma mark -
#pragma mark menu management

- (BOOL) _isConversationViewFirstResponder
{
    if (![self _hasConversationPanel]) {
        return NO;
    }
    if ([[_conversationViewController view] superview] == nil) {
        return NO;
    }
    if (![_conversationViewController isFirstResponder]) {
        return NO;
    }

    return YES;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    SEL aSelector = [item action];
    if ([self _isConversationViewFirstResponder]) {
        if ([_conversationViewController respondsToSelector:aSelector]) {
            return [_conversationViewController validateMenuItem:item];
        }
    }
    if ([_conversationListViewController respondsToSelector:aSelector]) {
        return [_conversationListViewController validateMenuItem:item];
    }
    else if (aSelector == @selector(saveAllAttachments:)) {
        if ([[_conversationListViewController selectedConversationsIDs] count] == 1) {
            NSDictionary * info = [[_conversationListViewController selectedConversationsInfos] objectAtIndex:0];
            return [(NSNumber *) info[@"attachments-count"] intValue] > 0;
        }
        return NO;
    }
    else if (aSelector == @selector(printDocument:)) {
        return [[_conversationListViewController selectedConversationsIDs] count] == 1;
    }
    else if (aSelector == @selector(toggleDetails:)) {
        if ([self _hasConversationPanel]) {
            [item setTitle:@"Hide Details"];
        }
        else {
            [item setTitle:@"Show Details"];
        }
        return YES;
    }
    else if (aSelector == @selector(toggleSidebar:)) {
        if ([self _hasFolderPanel]) {
            [item setTitle:@"Hide Sidebar"];
        }
        else {
            [item setTitle:@"Show Sidebar"];
        }
        return YES;
    }
    else if (aSelector == @selector(selectPreviousAccount:)) {
        if (UnifiedAccountManager::sharedManager()->accounts()->count() == 0) {
            return NO;
        }
        return YES;
    }
    else if (aSelector == @selector(selectNextAccount:)) {
        if (UnifiedAccountManager::sharedManager()->accounts()->count() == 0) {
            return NO;
        }
        return YES;
    }
    return NO;
}

- (BOOL) respondsToSelector:(SEL)selector
{
    if ([super respondsToSelector:selector]) {
        return YES;
    }
    if ([self _isConversationViewFirstResponder]) {
        if ([_conversationViewController respondsToSelector:selector]) {
            return YES;
        }
    }
    if ([_conversationListViewController respondsToSelector:selector]) {
        return YES;
    }
    return NO;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    SEL aSelector = [invocation selector];
    if ([self _isConversationViewFirstResponder]) {
        if ([_conversationViewController respondsToSelector:aSelector]) {
            [invocation invokeWithTarget:_conversationViewController];
            return;
        }
    }
    if ([_conversationListViewController respondsToSelector:aSelector]) {
        [invocation invokeWithTarget:_conversationListViewController];
        return;
    }
    [super forwardInvocation:invocation];
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature * signature = [super methodSignatureForSelector:selector];
    if (signature != nil) {
        return signature;
    }
    if ([self _isConversationViewFirstResponder]) {
        signature = [_conversationViewController methodSignatureForSelector:selector];
        if (signature != nil) {
            return signature;
        }
    }
    signature = [_conversationListViewController methodSignatureForSelector:selector];
    if (signature != nil) {
        return signature;
    }
    return signature;
}

- (BOOL) DJLToolbarView:(DJLToolbarView *)toolbar validate:(SEL)selector
{
    if (toolbar == _conversationToolbarView) {
        if (!_conversationToolbarEnabled) {
            return NO;
        }
        NSMenuItem * item = [[NSMenuItem alloc] init];
        [item setAction:selector];
        return [self validateMenuItem:item];
    }
    else if (toolbar == _toolbarView) {
        if (selector == @selector(_compose)) { // method in DJLConversationListToolbarView
            return AccountManager::sharedManager()->accounts()->count() > 0;
        }
        else if (selector == @selector(_search)) { // method in DJLConversationListToolbarView
            return YES;
        }
        else if (selector == @selector(_cleanup)) { // method in DJLConversationListToolbarView
            if ([_conversationListViewController isSearchEnabled]) {
                return NO;
            }
            if ([_conversationListViewController unifiedAccount] == nil) {
                return NO;
            }
            NSString * inboxFolderPath = MCO_TO_OBJC([_conversationListViewController unifiedAccount]->inboxFolderPath());
            if ([inboxFolderPath isEqualToString:[_conversationListViewController folderPath]]) {
                return YES;
            } else {
                return NO;
            }
        }
        else {
            return NO;
        }
    }
    else {
        return NO;
    }
}

#pragma mark - DJLURLHandler delegate

- (BOOL) _checkHasAccount
{
    if (AccountManager::sharedManager()->accounts()->count() == 0) {
        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText:@"No account available"];
        [alert setInformativeText:@"Please add an account before composing emails."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return NO;
    }
    return YES;
}

- (void) DJLURLHandler:(DJLURLHandler *)handler composeMessageWithTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject body:(NSString *)body
{
    if (![self _checkHasAccount]) {
        return;
    }

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"URL" label:@"Click on mailto URL" value:@(0)];

    UnifiedAccount * unifiedAccount = [_conversationListViewController unifiedAccount];
    Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
    DJLComposerWindowController * controller = [[DJLComposerWindowController alloc] init];
    [controller setDefaultEmailAliasForAccount:account];
    [controller setTo:to cc:cc bcc:bcc subject:subject body:body];
    [controller setDelegate:self];
    [self _cascadeComposer:controller];
    [controller showWindow:nil];
    [_composers addObject:controller];
}

- (void) DJLURLHandler:(DJLURLHandler *)handler composeMessageWithTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject htmlBody:(NSString *)htmlBody
{
    if (![self _checkHasAccount]) {
        return;
    }

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"URL" label:@"Click on mailto URL with HTML body" value:@(0)];

    UnifiedAccount * unifiedAccount = [_conversationListViewController unifiedAccount];
    Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
    DJLComposerWindowController * controller = [[DJLComposerWindowController alloc] init];
    [controller setDefaultEmailAliasForAccount:account];
    [controller setTo:to cc:cc bcc:bcc subject:subject htmlBody:htmlBody];
    [controller setDelegate:self];
    [self _cascadeComposer:controller];
    [controller showWindow:nil];
    [_composers addObject:controller];
}

- (void) DJLURLHandler:(DJLURLHandler *)handler composeMessageWithTo:(NSString *)to cc:(NSString *)cc bcc:(NSString *)bcc subject:(NSString *)subject archive:(WebArchive *)archive
{
    if (![self _checkHasAccount]) {
        return;
    }

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Composer" action:@"URLWithWebArchive" label:@"Click on mailto URL with WebArchive" value:@(0)];

    UnifiedAccount * unifiedAccount = [_conversationListViewController unifiedAccount];
    Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
    DJLComposerWindowController * controller = [[DJLComposerWindowController alloc] init];
    [controller setDefaultEmailAliasForAccount:account];
    [controller setTo:to cc:cc bcc:bcc subject:subject archive:archive];
    [controller setDelegate:self];
    [self _cascadeComposer:controller];
    [controller showWindow:nil];
    [_composers addObject:controller];
}

- (void) DJLURLHandler:(DJLURLHandler *)handler openMessageWithMessageID:(NSString *)messageID
{
    [self _openMessageID:messageID];
}

- (void) _openMessageID:(NSString *)messageID
{
    String * mcMessageID = MCO_FROM_OBJC(String, messageID);
    _urlMessageIDCount = AccountManager::sharedManager()->accounts()->count();
    _urlMessageIDFound = -1;
    MC_SAFE_RELEASE(_urlMessageAccount);
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        account->fetchConversationIDForMessageID(mcMessageID);
    }
}

- (void) _reselectAccountIfNeeded
{
    UnifiedAccount * currentAccount = [_conversationListViewController unifiedAccount];
    if (currentAccount == NULL) {
        // No account selected -> select unified account.
        UnifiedAccount * account = UnifiedAccountManager::sharedManager()->unifiedAccount();
        if (account != NULL) {
            NSString * path = MCO_TO_OBJC(account->inboxFolderPath());
            [_conversationListViewController setUnifiedAccount:account];
            [_conversationListViewController setFolderPath:path];
            [_toolbarView setFolderPath:path];
            [_folderPaneViewController setUnifiedAccount:account];
            [_folderPaneViewController setFolderPath:path];
        }
        else {
            // deselect.
            NSString * path = nil;
            [_conversationListViewController setUnifiedAccount:NULL];
            [_conversationListViewController setFolderPath:path];
            [_toolbarView setFolderPath:path];
            [_folderPaneViewController setUnifiedAccount:NULL];
            [_folderPaneViewController setFolderPath:path];
        }
    }
    else if (currentAccount->accounts()->count() >= 2) {
        // Unified account selected -> reselect unified account.
        UnifiedAccount * account = UnifiedAccountManager::sharedManager()->unifiedAccount();
        if (account != NULL) {
            NSString * path = [_conversationListViewController folderPath];
            if (account->accounts()->count() == 1) {
                path = MCO_TO_OBJC(account->inboxFolderPath());
            }
            [_conversationListViewController setUnifiedAccount:account];
            [_conversationListViewController setFolderPath:path];
            [_toolbarView setFolderPath:path];
            [_folderPaneViewController setUnifiedAccount:account];
            [_folderPaneViewController setFolderPath:path];
        }
        else {
            // deselect.
            NSString * path = nil;
            [_conversationListViewController setUnifiedAccount:NULL];
            [_conversationListViewController setFolderPath:path];
            [_toolbarView setFolderPath:path];
            [_folderPaneViewController setUnifiedAccount:NULL];
            [_folderPaneViewController setFolderPath:path];
        }
    }
    else /* regular account -> reselect it if it still exists.  */ {
        Account * singleAccount = (Account *) currentAccount->accounts()->objectAtIndex(0);
        UnifiedAccount * account = NULL;
        account = UnifiedAccountManager::sharedManager()->accountForEmail(singleAccount->accountInfo()->email());
        if (account == NULL) {
            account = UnifiedAccountManager::sharedManager()->unifiedAccount();
        }
        if (account != NULL) {
            NSString * path = MCO_TO_OBJC(account->inboxFolderPath());
            [_conversationListViewController setUnifiedAccount:account];
            [_conversationListViewController setFolderPath:path];
            [_toolbarView setFolderPath:path];
            [_folderPaneViewController setUnifiedAccount:account];
            [_folderPaneViewController setFolderPath:path];
        }
        else {
            // deselect.
            NSString * path = nil;
            [_conversationListViewController setUnifiedAccount:NULL];
            [_conversationListViewController setFolderPath:path];
            [_toolbarView setFolderPath:path];
            [_folderPaneViewController setUnifiedAccount:NULL];
            [_folderPaneViewController setFolderPath:path];
        }
    }
    _currentAccountsNumber = AccountManager::sharedManager()->accounts()->count();
}

- (unsigned int) _residentMemory
{
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        return (unsigned int) (info.resident_size / (1024 * 1024));
    }
    else {
        return -1;
    }
}

- (void) _loopAnalytics
{
    // repeat every hour.
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"App" action:@"Ping" label:@"App is alive" value:@(0)];
    unsigned int residentMemory = [self _residentMemory];
    NSString * actionString = [NSString stringWithFormat:@"%u", (residentMemory + 49) / 50 * 50];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"AppMemory" action:actionString label:@"App memory usage" value:@(0)];
    if ([self _hasConversationPanel]) {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsMainWindowWithConversation" action:@"enabled" label:@"Main window with conversation view" value:@(0)];
    }
    else {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsMainWindowWithConversation" action:@"disabled" label:@"Main window without conversation view" value:@(0)];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ZenNotifications"]) {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsZenNotifications" action:@"enabled" label:@"Zen notifiations enabled" value:@(0)];
    }
    else {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsZenNotifications" action:@"disabled" label:@"Zen notifiations enabled" value:@(0)];
    }
    if ([[DJLURLHandler sharedManager] isRegisteredAsDefault]) {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsDefaultMailApp" action:@"enabled" label:@"Set as default mail app" value:@(0)];
    }
    else {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsDefaultMailApp" action:@"disabled" label:@"Not set as default mail app" value:@(0)];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SoundEnabled"]) {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsSound" action:@"enabled" label:@"Sound enabled" value:@(0)];
    }
    else {
        [MPGoogleAnalyticsTracker trackEventOfCategory:@"PrefsSound" action:@"disabled" label:@"Sound disabled" value:@(0)];
    }

    actionString = [NSString stringWithFormat:@"%u", AccountManager::sharedManager()->accounts()->count()];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Accounts" action:actionString label:@"Total number of accounts" value:@(0)];
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            Array * components = account->accountInfo()->email()->componentsSeparatedByString(MCSTR("@"));
            String * domain = NULL;
            if (components->count() >= 2) {
                domain = (String *) components->objectAtIndex(1);
            }
            if (domain != NULL) {
                [MPGoogleAnalyticsTracker trackEventOfCategory:@"AccountDomain" action:MCO_TO_OBJC(domain) label:@"Domain of the account" value:@(0)];
            }
        }
    }
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            int count = 0;
            if (account->folders() != NULL) {
                count = account->folders()->count();
            }
            count = (count + 9) / 10 * 10;
            actionString = [NSString stringWithFormat:@"%u", count];
            [MPGoogleAnalyticsTracker trackEventOfCategory:@"AccountsFolders" action:actionString label:@"Number of folders" value:@(0)];
        }
    }
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            int count = 0;
            if (account->accountInfo()->aliases() != NULL) {
                count = account->accountInfo()->aliases()->count();
            }
            actionString = [NSString stringWithFormat:@"%u", count];
            [MPGoogleAnalyticsTracker trackEventOfCategory:@"AccountsAliases" action:actionString label:@"Number of aliases" value:@(0)];
        }
    }
    actionString = [NSString stringWithFormat:@"%u", (([[DJLAddressBookManager sharedManager] count] + 99) / 100) * 100];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Contacts" action:actionString label:actionString value:@(0)];

    [self performSelector:@selector(_loopAnalytics) withObject:nil afterDelay:1 * 60 * 60];
}

#pragma mark - DJLCleanupWindowController delegate

- (void) DJLCleanupWindowControllerArchive:(DJLCleanupWindowController *)controller
{
    [_conversationListViewController archiveConversationsInfos:[controller selectedConversations]];
    [_cleanupWindowController close];
    _cleanupWindowController = nil;
}

- (void) DJLCleanupWindowControllerDelete:(DJLCleanupWindowController *)controller
{
    [_conversationListViewController trashConversationsInfos:[controller selectedConversations]];
    [_cleanupWindowController close];
    _cleanupWindowController = nil;
}

- (void) DJLCleanupWindowControllerCancel:(DJLCleanupWindowController *)controller
{
    _cleanupWindowController = nil;
}

@end
