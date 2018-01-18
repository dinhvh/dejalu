// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationListViewController.h"

#import <GoogleAnalyticsTracker/GoogleAnalyticsTracker.h>

#import "DJLTableView.h"
#import "DJLGradientView.h"
#import "DJLSyncProgressView.h"
#import "DJLConversationLoadMoreCellView.h"
#import "DJLConversationCellView.h"
#import "DJLConversationCellContentView.h"
#import "DJLConversationRowView.h"
#import "DJLSearchField.h"
#import "DJLLog.h"
#import "DJLColoredView.h"
#import "DJLUIConstants.h"
#import "DJLScrollView.h"
#import "DJLRefreshOverlayView.h"
#import "DJLAssert.h"
#import "DJLGradientSeparatorLineView.h"
#import "DJLNetworkErrorOverlayView.h"
#import "DJLConversationListPlaceholderView.h"
#import "DJLLabelsViewController.h"

#include "Hermes.h"

#define LOG_IDLE(...) DJLLogWithID("idle", __VA_ARGS__)
#define LOG_STORAGE(...) DJLLogWithID("storage", __VA_ARGS__)
#define LOG_STACK_STORAGE(...) DJLLogStackWithID("storage", __VA_ARGS__)

#define RESET_MESSAGES_TO_LOAD_TIMEOUT 300
#define REFRESH_DATE_DELAY 60.

using namespace hermes;
using namespace mailcore;

@implementation DJLUnifiedConversationID

@synthesize convID = _convID;
@synthesize accountIndex = _accountIndex;

- (BOOL) isEqual:(id)anObject
{
    DJLUnifiedConversationID * otherConvID = anObject;
    return _convID == otherConvID->_convID && _accountIndex == otherConvID->_accountIndex;
}

- (NSUInteger) hash
{
    unsigned int c = 5381;

    c = ((c << 5) + c) + _accountIndex;
    c = ((c << 5) + c) + (_convID >> 32);
    c = ((c << 5) + c) + (_convID & 0xffffffff);

    return c;
}

@end

@interface DJLConversationListViewController () <NSTableViewDataSource, NSTableViewDelegate,
DJLConversationCellViewDelegate, DJLSearchFieldDelegate, DJLLabelsViewControllerDelegate>

- (void) _storageView:(UnifiedMailStorageView *)view
  changedWithDeletion:(NSArray *)deleted
                moves:(NSArray *)moved
             addition:(NSArray *)added
         modification:(NSArray *)modified;

- (void) _notifyFetchSummaryDoneWithError:(hermes::ErrorCode)error;
- (void) _syncDoneWithFolderPath:(NSString *)folderPath accountIndex:(unsigned int)accountIndex error:(hermes::ErrorCode)error;
- (void) _connected;

@end

class DJLConversationListViewControllerCallback : public Object, public UnifiedMailStorageViewObserver, public AccountObserver, public UnifiedAccountObserver {
public:
    DJLConversationListViewControllerCallback(DJLConversationListViewController * controller) {
        mController = controller;
    }

    virtual ~DJLConversationListViewControllerCallback() {}

    virtual void mailStorageViewChanged(UnifiedMailStorageView * view,
                                        mailcore::Array * deleted,
                                        mailcore::Array * moved,
                                        mailcore::Array * added,
                                        mailcore::Array * modified)
    {
        [mController _storageView:view
              changedWithDeletion:MCO_TO_OBJC(deleted)
                            moves:MCO_TO_OBJC(moved)
                         addition:MCO_TO_OBJC(added)
                     modification:MCO_TO_OBJC(modified)];
    }

    virtual void accountFetchSummaryDone(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error, int64_t messageRowID)
    {
        [mController _notifyFetchSummaryDoneWithError:error];
    }

    virtual void accountSyncDone(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error, mailcore::String * folderPath)
    {
#warning should wait for all accounts
        [mController _syncDoneWithFolderPath:MCO_TO_OBJC(folderPath) accountIndex:accountIndex error:error];
    }

    virtual void accountConnected(Account * account)
    {
        [mController _connected];
    }

private:
    DJLConversationListViewController * mController;
};

@implementation DJLConversationListViewController {
    DJLTableView * _tableView;
    DJLScrollView * _scrollView;
    DJLSyncProgressView * _syncProgressView;
    UnifiedAccount * _unifiedAccount;
    UnifiedMailStorageView * _unifiedStorageView;
    UnifiedMailStorageView * _unifiedSearchStorageView;
    NSMutableSet * _folderToReset;
    BOOL _showingLoadMore;
    NSArray * _lastRowsIDsSelection;
    BOOL _showSearchField;
    DJLColoredView * _searchContainerView;
    DJLSearchField * _searchField;
    DJLGradientSeparatorLineView * _searchSeparatorView;
    DJLConversationListViewControllerCallback * _callback;
    bool _disableIdle;
    NSString * _folderPath;
    NSView * _view;
    BOOL _selectionReflected;
    DJLColoredView * _separatorLineView;
    BOOL _scrollStarted;
    CGFloat _vibrancy;
    DJLRefreshOverlayView * _refreshOverlayView;
    BOOL _refreshing;
    BOOL _progressShown;
    NSTimeInterval _progressShownTimestamp;
    CGFloat _separatorAlphaValue;
    NSString * _manualRefreshFolderPath;
    DJLNetworkErrorOverlayView * _networkErrorOverlayView;
    BOOL _showingNetworkFeedback;
    DJLConversationListPlaceholderView * _placeholderView;
    BOOL _hasPlaceholderUpdateScheduled;
    NSPopover * _labelsPopOver;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _folderToReset = [[NSMutableSet alloc] init];
    _callback = new DJLConversationListViewControllerCallback(self);
    _vibrancy = 1.0;
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_unifiedAccount != NULL) {
        _unifiedAccount->removeObserver(_callback);
    }
    MC_SAFE_RELEASE(_callback);
    MC_SAFE_RELEASE(_unifiedAccount);
}

- (void) setUnifiedAccount:(hermes::UnifiedAccount *)unifiedAccount
{
    if (unifiedAccount == _unifiedAccount) {
        return;
    }

    // restore syncing status
    if (_unifiedAccount != NULL) {
        if (_disableIdle) {
            _disableIdle = NO;
            _unifiedAccount->enableSync();
        }
    }
    _manualRefreshFolderPath = nil;

    [self _cancelSearch];
    [self _unsetupStorageView];
    if (_unifiedAccount != NULL) {
        _unifiedAccount->removeObserver(_callback);
    }
    MC_SAFE_RELEASE(_unifiedAccount);
    _unifiedAccount = unifiedAccount;
    MC_SAFE_RETAIN(_unifiedAccount);
    if (_unifiedAccount != NULL) {
        _unifiedAccount->addObserver(_callback);
    }
    _folderPath = nil;
}

- (hermes::UnifiedAccount *) unifiedAccount
{
    return _unifiedAccount;
}

- (NSScrollView *) scrollView {
    return _scrollView;
}

- (void) _scrollerStyleChanged
{
    [_scrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (void) _setup {
    NSRect frame = [[self view] bounds];
    _scrollView = [[DJLScrollView alloc] initWithFrame:frame];
    [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_scrollView setHasVerticalScroller:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    _tableView = [[DJLTableView alloc] initWithFrame:frame];
    [_tableView setAllowsMultipleSelection:YES];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_tableView setHeaderView:nil];
    [_tableView setRowHeight:80];
    [_tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [_tableView setIntercellSpacing:NSMakeSize(0, 0)];
    [_tableView setTarget:self];
    [_tableView setDoubleAction:@selector(_doubleClick)];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLConversation"];
    frame = [[self view] bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_tableView addTableColumn:column];
    [_scrollView setDocumentView:_tableView];
    [[self view] addSubview:_scrollView];
    [_scrollView setDrawsBackground:NO];
    [_tableView setBackgroundColor:[NSColor clearColor]];
    frame = [[self view] bounds];
    _placeholderView = [[DJLConversationListPlaceholderView alloc] initWithFrame:frame];
    [_placeholderView setAlphaValue:0.0];
    [[self view] addSubview:_placeholderView];

    frame = [[self view] bounds];
    frame.size.height = 50;
    _syncProgressView = [[DJLSyncProgressView alloc] initWithFrame:frame];
    [_syncProgressView setAutoresizingMask:NSViewWidthSizable];
    [[self view] addSubview:_syncProgressView];
    [_syncProgressView setHidden:YES];

    _refreshOverlayView = [[DJLRefreshOverlayView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [_refreshOverlayView sizeToFit];
    [_refreshOverlayView setAlphaValue:0.0];
    [[self view] addSubview:_refreshOverlayView];

    _networkErrorOverlayView = [[DJLNetworkErrorOverlayView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    [_networkErrorOverlayView setAlphaValue:0.0];
    [[self view] addSubview:_networkErrorOverlayView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrolled) name:NSViewBoundsDidChangeNotification object:[_scrollView contentView]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollDidEndDragging) name:DJLScrollViewDidEndDraggingScrollNotification object:_scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_resized) name:NSViewFrameDidChangeNotification object:[self view]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_markFolderAsRead) name:NSWindowDidBecomeKeyNotification object:[[self view] window]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_markFolderAsRead) name:NSApplicationDidBecomeActiveNotification object:NSApp];

    [self _scrolled];
    [self _updateFirstResponderState];
    [self _periodicRedrawCells];
}

- (void) _resized
{
    NSRect frame = [[self view] frame];
    [_placeholderView setFrame:frame];

    frame = [_refreshOverlayView frame];
    frame.origin.y = [[self view] bounds].size.height - [_refreshOverlayView frame].size.height - 20;
    frame.origin.x = (int) (([[self view] bounds].size.width - [_refreshOverlayView frame].size.width) / 2);
    [_refreshOverlayView setFrame:frame];

    frame = [_networkErrorOverlayView frame];
    frame.origin.y = [[self view] bounds].size.height - [_networkErrorOverlayView frame].size.height - 20;
    frame.origin.x = (int) (([[self view] bounds].size.width - [_networkErrorOverlayView frame].size.width) / 2);
    [_networkErrorOverlayView setFrame:frame];

    [self _reflectSelection];
}

- (void) _scrollDidEndDragging
{
    // Don't allow pull to refresh when searching.
    if (_unifiedSearchStorageView != NULL) {
        return;
    }

    if ([[_scrollView contentView] bounds].origin.y < -20) {
        [self refresh];
    }
}

- (void) _markFolderAsRead
{
    if (!([[[self view] window] isKeyWindow] && [NSApp isActive])) {
        return;
    }
    if (_unifiedAccount == NULL) {
        return;
    }
    if (_folderPath == nil) {
        return;
    }
    _unifiedAccount->markFolderAsSeen(_unifiedAccount->folderIDForPath(MCO_FROM_OBJC(String, _folderPath)));
}

- (NSView *) view
{
    if (_view != nil) {
        return _view;
    }
    _view = [[NSView alloc] initWithFrame:CGRectZero];
    [_view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self _setup];
    return _view;
}

- (void) _scrolled
{
    NSRect frame = [_placeholderView frame];
    frame.origin.y = [[_scrollView contentView] bounds].origin.y;
    [_placeholderView setFrame:frame];

    if ([_scrollView isDragging]) {
        _showingNetworkFeedback = NO;
    }

    CGFloat alpha = 0.0;
    if ([[_scrollView contentView] bounds].origin.y < 0) {
        alpha = (- [[_scrollView contentView] bounds].origin.y) / 20.;
        if (alpha > 1.0) {
            alpha = 1.0;
        }
    }
    if (_refreshing) {
        alpha = 1.0;
    }
    if (_showingNetworkFeedback) {
        alpha = 0.0;
    }
    if (alpha > 0.0) {
        [self _hideNetworkErrorOverlay];
    }
    // Don't allow pull to refresh when searching.
    if (_unifiedSearchStorageView != NULL) {
        alpha = 0.0;
    }
    [_refreshOverlayView setAlphaValue:alpha];

    alpha = 0.0;
    if ([[_scrollView contentView] bounds].origin.y > 50.) {
        alpha = 1.0;
    }
    else if ([[_scrollView contentView] bounds].origin.y < 0) {
        alpha = 0.0;
    }
    else {
        alpha = [[_scrollView contentView] bounds].origin.y / 50.;
    }
    _separatorAlphaValue = alpha;
    if (_showSearchField) {
        [_searchSeparatorView setAlphaValue:alpha];
        [[self delegate] DJLConversationListViewController:self separatorAlphaValue:0.0];
    }
    else {
        [_searchSeparatorView setAlphaValue:0.0];
        [[self delegate] DJLConversationListViewController:self separatorAlphaValue:alpha];
    }

    [self _reflectSelection];
    [self _loadVisibleCellsAfterScrolling];

    if ((_unifiedAccount != NULL) && (_unifiedSearchStorageView == NULL)) {
        int64_t folderID =  _unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]);
        if (_unifiedAccount->messagesToLoadCanBeResetForFolder(folderID)) {
            if ([[_scrollView contentView] bounds].origin.y < 20 * 50) {
                if (![_folderToReset containsObject:[NSNumber numberWithLongLong:folderID]]) {
                    //NSLog(@"should reset");
                    [_folderToReset addObject:[NSNumber numberWithLongLong:folderID]];
                    [self performSelector:@selector(_resetMessagesToLoad) withObject:nil afterDelay:RESET_MESSAGES_TO_LOAD_TIMEOUT];
                }
            }
            else if ([[_scrollView contentView] bounds].origin.y > [[_scrollView contentView] bounds].size.height / 2 - [_scrollView frame].size.height) {
                if ([_folderToReset containsObject:[NSNumber numberWithLongLong:folderID]]) {
                    //NSLog(@"don't reset");
                    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_resetMessagesToLoad) object:nil];
                    [_folderToReset removeObject:[NSNumber numberWithLongLong:folderID]];
                }
            }
        }
    }
}

- (void) _loadVisibleCellsAfterScrolling
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_loadVisibleCells) object:nil];
    [self performSelector:@selector(_loadVisibleCells) withObject:nil afterDelay:0.1];
}

- (void) _resetMessagesToLoad
{
    //NSLog(@"reset messages to load");
    if (_unifiedSearchStorageView != NULL) {
        return;
    }
    int64_t folderID =  _unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]);
    _unifiedAccount->resetMessagesToLoadForFolder(folderID);
    [_folderToReset removeObject:[NSNumber numberWithLongLong:folderID]];
}

- (UnifiedMailStorageView *) _currentUnifiedStorageView
{
    if (_unifiedSearchStorageView != NULL) {
        return _unifiedSearchStorageView;
    }
    else {
        return _unifiedStorageView;
    }
}

- (UnifiedMailStorageView *) currentUnifiedStorageView
{
    return [self _currentUnifiedStorageView];
}

- (CGFloat) vibrancy
{
    return _vibrancy;
}

- (void) setVibrancy:(CGFloat)vibrancy
{
    _vibrancy = vibrancy;
    [_tableView setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1 - vibrancy]];
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    for(NSUInteger i = range.location ; i < range.location + range.length ; i ++) {
        DJLConversationCellContentView * cell = [_tableView viewAtColumn:0 row:i makeIfNecessary:NO];
        [cell setVibrancy:_vibrancy];
    }
    [_searchContainerView setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1 - vibrancy]];
}

- (void) updateFirstResponderState
{
    [self _updateFirstResponderState];
}

- (void) _notifyFetchSummaryDoneWithError:(hermes::ErrorCode)error
{
    if (error == hermes::ErrorFetch) {
        [self _loadVisibleCells];
    }
    else {
        if (_disableIdle) {
            LOG_IDLE("error getting summary: enable idle");
            _disableIdle = NO;
            _unifiedAccount->enableSync();
        }
    }
}

- (void) refresh
{
    int64_t folderID = _unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]);
    _manualRefreshFolderPath = [self folderPath];
    [[self delegate] DJLConversationListViewControllerConfirmRefresh:self];
    _unifiedAccount->refreshFolder(folderID);
    _unifiedAccount->refreshFolder(_unifiedAccount->folderIDForPath(_unifiedAccount->allMailFolderPath()));
    _unifiedAccount->refreshFolder(_unifiedAccount->folderIDForPath(_unifiedAccount->archiveFolderPath()));
    if (Reachability::sharedManager()->isReachable()) {
        mc_foreacharray(Account, account, _unifiedAccount->accounts()) {
            if (!account->isSending()) {
                account->setDeliveryEnabled(false);
                account->setDeliveryEnabled(true);
            }
        }
    }
}

- (void) refreshAndScrollToTop
{
    NSTimeInterval startDate = [NSDate timeIntervalSinceReferenceDate];
    CGFloat initialPosition = [[_scrollView contentView] bounds].origin.y;
    if (initialPosition > 0) {
        while (1) {
            NSTimeInterval timeInterval = [NSDate timeIntervalSinceReferenceDate] - startDate;
            CGFloat alpha = timeInterval / 0.25;
            if (alpha < 0.) {
                alpha = 0.;
            }
            if (alpha > 1.) {
                alpha = 1.;
                break;
            }
            [[_scrollView contentView] scrollToPoint: NSMakePoint(0, initialPosition * (1.0 - alpha))];
            [_scrollView reflectScrolledClipView:[_scrollView contentView]];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1. / 120.]];
        }

        [[_scrollView contentView] scrollToPoint: NSMakePoint(0, 0)];
        [_scrollView reflectScrolledClipView:[_scrollView contentView]];
    }

    [self refresh];
}

- (NSDictionary *) _infoForConversationID:(int64_t)conversationID accountIndex:(unsigned int)accountIndex
{
    HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoForConversationID(accountIndex, conversationID);
    return MCO_TO_OBJC(info);
}

- (NSArray *) selectedConversationsInfos
{
    NSMutableArray * result = [NSMutableArray array];
    [[self selectedConversationsIDs] enumerateObjectsUsingBlock:^(DJLUnifiedConversationID * convID, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary * info = [self _infoForConversationID:[convID convID] accountIndex:[convID accountIndex]];
        [result addObject:info];
    }];
    return result;
}

- (BOOL) _archiveMessage
{
    if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->inboxFolderPath())]) {
        [self archiveSelection];
        return YES;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->importantFolderPath())]) {
        [self archiveSelection];
        return YES;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->draftsFolderPath())]) {
        [self _deleteDraftsSelection];
        return YES;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->trashFolderPath())]) {
        // remove forever
        [self trashSelection];
        return YES;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->spamFolderPath())]) {
        // remove forever
        [self trashSelection];
        return YES;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->starredFolderPath())]) {
        // remove star
        [self _unstarSelection];
        return YES;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->allMailFolderPath())] ||
             [_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->archiveFolderPath())] ||
             [_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->sentFolderPath())]) {
        // do nothing
        return NO;
    }
    else {
        Account * account = NULL;
        if (_unifiedAccount->accounts()->count() == 1) {
            account = (Account *) _unifiedAccount->accounts()->objectAtIndex(0);
        }

        if ((account != NULL) &&
            (account->accountInfo()->providerIdentifier() != NULL) &&
            (account->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail")))) {
            [self _removeSelectionFromFolder];
            return YES;
        }
        // Do nothing for other providers.
        return NO;
    }
}

- (void) _removeSelectionFromFolder
{
    String * mcPath = MCO_FROM_OBJC(String, _folderPath);
    MCAssert(!mcPath->isEqual(_unifiedAccount->inboxFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->importantFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->draftsFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->trashFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->spamFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->starredFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->allMailFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->archiveFolderPath()));
    MCAssert(!mcPath->isEqual(_unifiedAccount->sentFolderPath()));

    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
    }];
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            account->removeConversationFromFolder(conversationsIDs, mcPath);
            account->removeLabelFromConversations(conversationsIDs, mcPath, false);
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (void) _unstarSelection
{
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
    }];
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            account->unstarPeopleConversations(conversationsIDs);
            account->removeConversationFromFolder(conversationsIDs, account->starredFolderPath());
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (void) _deleteMessage
{
    if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->draftsFolderPath())]) {
        [self _deleteDraftsSelection];
        return;
    }
    else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->trashFolderPath())]) {
        // remove forever
        [self trashSelection];
        return;
    }
    else {
        // move to trash
        [self trashSelection];
        return;
    }
}

- (void) makeFirstResponder
{
    [[_tableView window] makeFirstResponder:_tableView];
}

- (IBAction) toggleRead:(id)sender
{
    [self toggleReadSelection];
}

- (IBAction) toggleStar:(id)sender
{
    [self toggleStarSelection];
}

- (IBAction) deleteMessage:(id)sender
{
    [self _deleteMessage];
}

- (IBAction) archiveMessage:(id)sender
{
    [self _archiveMessage];
}

- (void) replyMessage:(id)sender
{
    [self _replyMessage];
}

- (void) forwardMessage:(id)sender
{
    [self _forwardMessage];
}

- (IBAction) showLabelsPanel:(id)sender
{
    [self _showLabelsPopOverAndArchive:NO];
}

- (IBAction) showLabelsAndArchivePanel:(id)sender
{
    [self _showLabelsPopOverAndArchive:YES];
}

- (IBAction) markAsSpam:(id)sender
{
    [self _markAsSpamSelection];
}

#pragma mark -
#pragma mark tableview delegate

- (void) _periodicRedrawCells
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_periodicRedrawCells) object:nil];

    [self _redrawCells];

    [self performSelector:@selector(_periodicRedrawCells) withObject:nil afterDelay:REFRESH_DATE_DELAY];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger count = 0;

    if ([self _currentUnifiedStorageView] == NULL) {
        count = 0;
    }
    else {
        count = [self _currentUnifiedStorageView]->conversationsCount();
        if (_showingLoadMore) {
            count ++;
        }
    }

    return count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    unsigned int conversationsCount = [self _currentUnifiedStorageView]->conversationsCount();
    if (row >= conversationsCount) {
        // load more cells
        return 30;
    }

    HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
    Array * messages = (Array *) info->objectForKey(MCSTR("messages"));
    int64_t count = messages->count();
    CGFloat height = 20;
    switch (count) {
        case 1:
            height = 75;
            break;
        case 2:
            height = 65;
            break;
        default:
            height = 80;
            break;
    }
    return height;
}

- (void) _reflectSelectionForCellView:(DJLConversationCellContentView *)cellView index:(NSInteger)idx selectedRows:(NSIndexSet *)selectedRows
{
    [cellView setSelected:[selectedRows containsIndex:idx]];
    [cellView setNextCellSelected:[selectedRows containsIndex:idx + 1]];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    //NSLog(@"should select %li", (long)rowIndex);
    return YES;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([self _currentUnifiedStorageView] == nil) {
        return nil;
    }
    unsigned int conversationsCount = [self _currentUnifiedStorageView]->conversationsCount();
    if (row >= conversationsCount) {
        // load more cells
        NSRect frame = NSMakeRect(0, 0, [_tableView frame].size.width, 70);
        DJLConversationLoadMoreCellView * view = [[DJLConversationLoadMoreCellView alloc] initWithFrame:frame];
        return view;
    }

    HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
    MCAssert(info != NULL);
    NSRect frame = NSMakeRect(0, 0, [_tableView frame].size.width, 70);
    DJLConversationCellContentView * view = [[DJLConversationCellContentView alloc] initWithFrame:frame];
    if (_unifiedSearchStorageView == NULL) {
        [view setFolderPath:[self folderPath]];
    }
    [view setVibrancy:_vibrancy];
    [view setDelegate:self];
    NSDictionary * objcInfo = MCO_TO_OBJC(info);
    [view setConversation:objcInfo];
    [self _reflectSelectionForCellView:view index:row selectedRows:[_tableView selectedRowIndexes]];
    return view;
}

- (void) _redrawCells
{
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    for(NSUInteger i = range.location ; i < range.location + range.length ; i ++) {
        DJLConversationCellContentView * cell = [_tableView viewAtColumn:0 row:i makeIfNecessary:NO];
        if (![cell isKindOfClass:[DJLConversationCellContentView class]]) {
            continue;
        }
        [cell update];
    }
}

- (void) _reflectSelection
{
    _lastRowsIDsSelection = [self _rowsIDsSelection];
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    if (range.length > 0) {
        NSIndexSet * selection = [_tableView selectedRowIndexes];
        for(NSUInteger i = range.location ; i < range.location + range.length ; i ++) {
            DJLConversationCellContentView * cell = [_tableView viewAtColumn:0 row:i makeIfNecessary:NO];
            if (![cell isKindOfClass:[DJLConversationCellContentView class]]) {
                continue;
            }
            [cell setVibrancy:_vibrancy];
            [self _reflectSelectionForCellView:cell index:i  selectedRows:selection];
        }
    }
    _selectionReflected = YES;
}

- (void)tableViewSelectionIsChanging:(NSNotification *)notification
{
    [self _reflectSelection];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    _lastRowsIDsSelection = [self _rowsIDsSelection];
    [[self delegate] DJLConversationListViewControllerSelectionChanged:self];

    [self _reflectSelection];
    _selectionReflected = NO;
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
    NSMutableIndexSet * result = [proposedSelectionIndexes mutableCopy];
    if ([self _currentUnifiedStorageView] == NULL) {
        return [NSIndexSet indexSet];
    }
    unsigned int conversationsCount = [self _currentUnifiedStorageView]->conversationsCount();
    [result removeIndex:conversationsCount];
    return result;
}

- (BOOL)djl_tableView:(NSTableView *)tableView keyPress:(NSEvent *)event
{
    if ([[event characters] isEqualToString:@" "]) {
        [self _viewConversationWindow];
        return YES;
    }
    else if ([event keyCode] == 36) {
        [self _openConversationWindow];
        return YES;
    }
#if 0
    else if ([event keyCode] == 51 &&
             ([event modifierFlags] & (NSControlKeyMask | NSAlternateKeyMask)) == 0) {
        // backspace.
        if (([event modifierFlags] & NSCommandKeyMask) != 0) {
            [self deleteMessage];
            return YES;
        }
        else {
            return [self _archiveMessage];
        }
    }
#endif
    else if ([event keyCode] == 53) {
        // ESC
        if (_showSearchField) {
            [self _hideSearch];
            return YES;
        }
    }
    else if ([event keyCode] == 123) {
        // left
        [[self delegate] DJLConversationListViewControllerCollapseDetails:self];
        return YES;
    }
    else if ([event keyCode] == 124) {
        // right
        [[self delegate] DJLConversationListViewControllerExpandDetails:self];
        return YES;
    }
    return NO;
}

- (void) djl_tableViewBecomeFirstResponder:(NSTableView *)tableView
{
    [self _updateFirstResponderState];
}

- (void) djl_tableViewResignFirstResponder:(NSTableView *)tableView
{
    [self _updateFirstResponderState];
}

- (NSMenu *) djl_tableView:(NSTableView *)tableView menuForEvent:(NSEvent *)event row:(NSInteger)row
{
    // Select right-clicked row if it isn't already in the selection.
    if (![[_tableView selectedRowIndexes] containsIndex:row]) {
        if (row != -1) {
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }

    NSMenu * menu = [[NSMenu alloc] init];
    NSMenuItem * item;
    item = [[NSMenuItem alloc] initWithTitle:@"Reply" action:@selector(replyMessage:) keyEquivalent:@"r"];
    [item setKeyEquivalentModifierMask:NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Forward" action:@selector(forwardMessage:) keyEquivalent:@"f"];
    [item setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Delete" action:@selector(deleteMessage:) keyEquivalent:[NSString stringWithFormat:@"%c", 0x08]];
    [item setKeyEquivalentModifierMask:NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Archive" action:@selector(archiveMessage:) keyEquivalent:[NSString stringWithFormat:@"%c", 0x08]];
    [item setKeyEquivalentModifierMask:0];
    [item setTarget:self];
    [menu addItem:item];
    item = [NSMenuItem separatorItem];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Mark as Read" action:@selector(toggleRead:) keyEquivalent:@"u"];
    [item setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Mark as Starred" action:@selector(toggleStar:) keyEquivalent:@"l"];
    [item setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Mark as Spam" action:@selector(markAsSpam:) keyEquivalent:@"j"];
    [item setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Apply Labels" action:@selector(showLabelsPanel:) keyEquivalent:@"l"];
    [item setKeyEquivalentModifierMask:NSCommandKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    item = [[NSMenuItem alloc] initWithTitle:@"Apply Labels And Archive" action:@selector(showLabelsAndArchivePanel:) keyEquivalent:@"l"];
    [item setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
    [item setTarget:self];
    [menu addItem:item];
    return menu;
}

- (void) _updateFirstResponderState
{
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    for(NSUInteger i = range.location ; i < range.location + range.length ; i ++) {
        DJLConversationCellContentView * cell = [_tableView viewAtColumn:0 row:i makeIfNecessary:NO];
        if ([cell isKindOfClass:[DJLConversationCellContentView class]]) {
            [cell update];
        }
    }
}

- (void) _openConversationWindow
{
    if ([[self selectedConversationsIDs] count] != 1) {
        return;
    }
    if ((_unifiedSearchStorageView == NULL) && [_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->draftsFolderPath())]) {
        DJLUnifiedConversationID * convID = [[self selectedConversationsIDs] objectAtIndex:0];
        int64_t conversationRowID = [convID convID];
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex([convID accountIndex]);
        int64_t folderID = account->folderIDForPath(account->draftsFolderPath());
        [[self delegate] DJLConversationListViewController:self
                                                   account:account
                                     editDraftConversation:conversationRowID
                                                  folderID:folderID];
    }
    else {
        [[self delegate] DJLConversationListViewControllerOpenConversationWindow:self];
    }
}

- (void) _viewConversationWindow
{
    [[self delegate] DJLConversationListViewControllerOpenConversationWindow:self];
}

- (void) _doubleClick
{
    if ([[self selectedConversationsIDs] count] == 1) {
        [self _openConversationWindow];
    }
}

#pragma cell delegate

- (void) DJLConversationCellViewStarClicked:(DJLConversationCellView *)view
{
    NSNumber * nbConvID = [[view conversation] objectForKey:@"id"];
    int64_t convID = [nbConvID longLongValue];
    NSNumber * nbAccountIndex = [[view conversation] objectForKey:@"account"];
    unsigned int accountIndex = [nbAccountIndex unsignedIntValue];
    Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);

    NSNumber * nbStarred = [[view conversation] objectForKey:@"starred"];
    Array * convIDs = Array::array();
    convIDs->addObject(Value::valueWithLongLongValue(convID));
    if ([nbStarred boolValue]) {
        account->unstarPeopleConversations(convIDs);
    }
    else {
        account->starPeopleConversations(convIDs);
    }
}

- (void) DJLConversationCellViewUnreadClicked:(DJLConversationCellView *)view
{
    NSNumber * nbConvID = [[view conversation] objectForKey:@"id"];
    int64_t convID = [nbConvID longLongValue];
    NSNumber * nbAccountIndex = [[view conversation] objectForKey:@"account"];
    unsigned int accountIndex = [nbAccountIndex unsignedIntValue];
    Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);

    NSNumber * nbUnread = [[view conversation] objectForKey:@"unread"];
    Array * convIDs = Array::array();
    convIDs->addObject(Value::valueWithLongLongValue(convID));
    if ([nbUnread boolValue]) {
        account->markAsReadPeopleConversations(convIDs);
    }
    else {
        account->markAsUnreadPeopleConversations(convIDs);
    }
}

#pragma mark -
#pragma mark search field delegate

- (void) djl_searchFieldOperationCancelled:(DJLSearchField *)searchField
{
    [self _hideSearch];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    if ([aNotification object] == _searchField) {
        if ([[_searchField stringValue] length] == 0) {
            [self performSelector:@selector(_hideSearch) withObject:nil afterDelay:0.0];
        }
    }
}

- (void) toggleSearch
{
    if (_showSearchField) {
        [self _hideSearch];
    }
    else {
        [self _showSearch];
    }
}

- (void) search:(id)sender
{
    [self _showSearch];
}

- (void) _hideSearch
{
    if (!_showSearchField) {
        return;
    }

    _showSearchField = NO;
    NSRect frame = [[self view] bounds];

    [_searchSeparatorView setAlphaValue:0.0];
    [[self delegate] DJLConversationListViewController:self separatorAlphaValue:0.0];

    [NSAnimationContext beginGrouping];
    __weak DJLConversationListViewController * weakSelf = self;
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [_searchSeparatorView setAlphaValue:0.0];
        [[weakSelf delegate] DJLConversationListViewController:weakSelf separatorAlphaValue:_separatorAlphaValue];
        [_searchContainerView setHidden:YES];
    }];
    [[_scrollView animator] setFrame:frame];
    [_searchField setStringValue:@""];
    [NSAnimationContext endGrouping];
    [self _cancelSearch];
    [self _reloadSearchData];
    [[_tableView window] makeFirstResponder:_tableView];
}

#define SEARCH_HEIGHT 22

- (void) _showSearch
{
    if (_showSearchField) {
        [[[self view] window] makeFirstResponder:_searchField];
        return;
    }

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Search" action:@"Show" label:@"Show search" value:@(0)];
    _showSearchField = YES;
    NSRect frame = [[self view] bounds];
    if (_searchField == nil) {
        frame.origin.y = frame.size.height - SEARCH_HEIGHT - 5;
        frame.size.height = SEARCH_HEIGHT + 5;
        frame.origin.x = 0;
        _searchContainerView = [[DJLColoredView alloc] initWithFrame:frame];
        [_searchContainerView setNeedsDisplay:YES];
        [_searchContainerView setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
        [_searchContainerView setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1 - _vibrancy]];
        frame = [_searchContainerView bounds];
        frame.origin.y = 5;
        frame.size.height = SEARCH_HEIGHT;
        frame.origin.x = 8;
        frame.size.width -= 16;
        _searchField = [[DJLSearchField alloc] initWithFrame:frame];
        [_searchField setFont:[NSFont systemFontOfSize:13]];
        [_searchField setFocusRingType:NSFocusRingTypeNone];
        // cast to id to avoid typing to NSSearchFieldDelegate (which is available in 10.11 only).
        [_searchField setDelegate:(id) self];
        [_searchField setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];

        NSRect separatorFrame = [_searchContainerView bounds];
        separatorFrame.size.height = 1;
        _searchSeparatorView = [[DJLGradientSeparatorLineView alloc] initWithFrame:separatorFrame];
        [_searchSeparatorView setAutoresizingMask:NSViewWidthSizable];
        [_searchSeparatorView setAlphaValue:0.0];
        [_searchContainerView addSubview:_searchSeparatorView];

        [_searchContainerView addSubview:_searchField];
        [[self view] addSubview:_searchContainerView positioned:NSWindowBelow relativeTo:_scrollView];
    }
    [_searchContainerView setHidden:NO];

    frame = [[self view] bounds];
    frame.size.height -= SEARCH_HEIGHT + 5;
    frame.origin.y = 0;
    [NSAnimationContext beginGrouping];
    [[_scrollView animator] setFrame:frame];
    [NSAnimationContext endGrouping];
    [[[self view] window] makeFirstResponder:_searchField];
    [_searchSeparatorView setAlphaValue:_separatorAlphaValue];
    [[self delegate] DJLConversationListViewController:self separatorAlphaValue:0.0];
}

- (void) _cancelSearchAfterDelay
{
    [self _cancelSearch];
    _showingLoadMore = _unifiedAccount->canLoadMoreForFolder(_unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]));
    [_tableView reloadData];
    [self _clearPlaceholder];
    [self _setRowsIDsSelection:_lastRowsIDsSelection fallback:NSNotFound];
}

- (void) controlTextDidChange: (NSNotification *) notification
{
    [self _performSearch];
}

- (void) _performSearch
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallySearch) object:nil];
    [self performSelector:@selector(_reallySearch) withObject:nil afterDelay:0.5];
}

- (void) _cancelSearch
{
    if (_unifiedAccount == NULL) {
        return;
    }

    _unifiedAccount->setSearchKeywords(NULL);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallySearch) object:nil];
    if (_unifiedSearchStorageView != NULL) {
        _unifiedAccount->closeViewForSearch(_unifiedSearchStorageView);
        MC_SAFE_RELEASE(_unifiedSearchStorageView);
    }
}

- (void) _reallySearch
{
    [self _cancelSearch];
    if ([[_searchField stringValue] length] == 0) {
        [self _reloadSearchData];
        return;
    }
    if (_unifiedAccount == NULL) {
        [self _reloadSearchData];
        return;
    }

    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Search" action:@"Start" label:@"Start search" value:@(0)];
    NSArray * keywords = [[_searchField stringValue] componentsSeparatedByString:@" "];
    Array * mcKeywords = MCO_FROM_OBJC(Array, keywords);
    _unifiedAccount->setSearchKeywords(mcKeywords);
    _unifiedSearchStorageView = _unifiedAccount->openViewForSearchKeywords(mcKeywords);
    _unifiedSearchStorageView->addObserver(_callback);
    MC_SAFE_RETAIN(_unifiedSearchStorageView);

    [self _reloadSearchData];

    [[self delegate] DJLConversationListViewControllerSelectionChanged:self];
}

- (void) _reloadSearchData
{
    if (_unifiedAccount == NULL) {
        [_tableView reloadData];
        [self _clearPlaceholder];
        return;
    }

    NSUInteger firstIndex = [[_tableView selectedRowIndexes] firstIndex];
    NSArray * selection = _lastRowsIDsSelection;
    if (_unifiedSearchStorageView != NULL) {
        _showingLoadMore = NO;
    }
    else {
        int64_t folderID =  _unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]);
        _showingLoadMore = _unifiedAccount->canLoadMoreForFolder(folderID);
    }
    [_tableView reloadData];
    [self _clearPlaceholder];
    [self _setRowsIDsSelection:selection fallback:firstIndex];
}

#pragma mark -
#pragma mark misc

- (void) accountStateUpdated
{
    BOOL showLoadMore = NO;
    if ([self folderPath] == nil) {
        return;
    }

    if (_unifiedAccount != NULL) {
        showLoadMore = _unifiedAccount->canLoadMoreForFolder(_unifiedAccount->folderIDForPath([[self folderPath] mco_mcString])) && !_unifiedStorageView->isLoading();
    }
    if (_unifiedSearchStorageView != NULL) {
        showLoadMore = NO;
    }
    if (showLoadMore != _showingLoadMore) {
        _showingLoadMore = showLoadMore;
        NSInteger count = [self numberOfRowsInTableView:_tableView];
        if (_showingLoadMore) {
            [_tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:count - 1] withAnimation:NSTableViewAnimationSlideLeft];
        }
        else {
            [_tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:count] withAnimation:NSTableViewAnimationSlideLeft];
        }
    }

    BOOL show = NO;
    if (_unifiedAccount != NULL) {
        show = _unifiedAccount->shouldShowProgressForFolder(_unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]));
    }
    if (!show) {
        // XXX - hide toolbar progress indicator
        //[_toolbarView setShowActivity:NO];
    }

    BOOL sending = NO;
    mc_foreacharray(Account, account, _unifiedAccount->accounts()) {
        if ((account != NULL) && account->isSending()) {
            //[_syncProgressView setHidden:NO];
            if (account->currentMessageProgressMax() == 0) {
                [_syncProgressView setProgressValue:account->currentMessageIndex()];
            }
            else {
                [_syncProgressView setProgressValue: account->currentMessageIndex() + (double) account->currentMessageProgress() / (double) account->currentMessageProgressMax()];
            }
            [_syncProgressView setProgressMax:account->totalMessagesCount()];
            NSString * progressString;
            if (account->totalMessagesCount() == 1) {
                if ((account->currentMessageSubject() != NULL) && (account->currentMessageSubject()->length() > 0)) {
                    progressString = [NSString stringWithFormat:@"Sending %@",
                                      MCO_TO_OBJC(account->currentMessageSubject())];
                }
                else {
                    progressString = @"Sending";
                }
            }
            else {
                progressString = [NSString stringWithFormat:@"Sending %u/%u",
                                  account->currentMessageIndex(), account->totalMessagesCount()];
            }
            [_syncProgressView setText:progressString];
            [self _showProgress];
            sending = YES;
            break;
        }
    }

/*
    if ((_account != NULL) && _account->isSending()) {
        //[_syncProgressView setHidden:NO];
        if (_account->currentMessageProgressMax() == 0) {
            [_syncProgressView setProgressValue:_account->currentMessageIndex()];
        }
        else {
            [_syncProgressView setProgressValue: _account->currentMessageIndex() + (double) _account->currentMessageProgress() / (double) _account->currentMessageProgressMax()];
        }
        [_syncProgressView setProgressMax:_account->totalMessagesCount()];
        NSString * progressString;
        if (_account->totalMessagesCount() == 1) {
            if ((_account->currentMessageSubject() != NULL) && (_account->currentMessageSubject()->length() > 0)) {
                progressString = [NSString stringWithFormat:@"Sending %@",
                                  MCO_TO_OBJC(_account->currentMessageSubject())];
            }
            else {
                progressString = @"Sending";
            }
        }
        else {
            progressString = [NSString stringWithFormat:@"Sending %u/%u",
                              _account->currentMessageIndex(), _account->totalMessagesCount()];
        }
        [_syncProgressView setText:progressString];
        [self _showProgress];
    }
    else {
 */
    if (!sending) {
        if (_showingLoadMore) {
            //unsigned int count = [self _currentUnifiedStorageView]->conversationsCount();
            NSInteger count = [self numberOfRowsInTableView:_tableView] - 1;
            DJLConversationLoadMoreCellView * loadMoreView = [_tableView viewAtColumn:0 row:count makeIfNecessary:NO];
            [loadMoreView setSyncing:NO];
        }

        int progressValue = 0;
        int progressMax = 0;
        if (_unifiedAccount != NULL) {
            progressValue = _unifiedAccount->headersProgressValueForFolder(_unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]));
            progressMax = _unifiedAccount->headersProgressMaxForFolder(_unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]));
        }
        if (show && (progressMax != 0)) {
            [_syncProgressView setProgressValue:progressValue];
            [_syncProgressView setProgressMax:progressMax];
            [_syncProgressView setText:@"Getting emails"];
            [self _showProgress];
        }
        else {
            [self _hideProgress];
        }
    }
    [self _updatePlaceholder];

    // XXX - update activity debug controller.
    //[_debugActivityWindowController update];
}

- (void) _showProgress
{
    if (_progressShown) {
        return;
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideProgressAfterDelay) object:nil];
    _progressShown = YES;
    _progressShownTimestamp = [NSDate timeIntervalSinceReferenceDate];
    [_syncProgressView setHidden:NO];
}

- (void) _hideProgress
{
    _progressShown = NO;
    if ([NSDate timeIntervalSinceReferenceDate] - _progressShownTimestamp > 1.5) {
        [self _hideProgressAfterDelay];
        return;
    }

    [self performSelector:@selector(_hideProgressAfterDelay) withObject:nil afterDelay:1.5];
}

- (void) _hideProgressAfterDelay
{
    [_syncProgressView setHidden:YES];
}

- (void) _showNetworkErrorOverlay
{
    _showingNetworkFeedback = YES;
    [self setRefreshing:NO];
    [_networkErrorOverlayView setAlphaValue:1.0];
    [self performSelector:@selector(_hideNetworkErrorOverlay) withObject:nil afterDelay:1.5];
}

- (void) _hideNetworkErrorOverlay
{
    _showingNetworkFeedback = NO;
    [[_networkErrorOverlayView animator] setAlphaValue:0.0];
}

- (void) _syncDoneWithFolderPath:(NSString *)folderPath accountIndex:(unsigned int)accountIndex error:(hermes::ErrorCode)error
{
    //_shouldNotShowProgressForNextSync = NO;
    if ([_manualRefreshFolderPath isEqualToString:folderPath]) {
        if (error != hermes::ErrorNone) {
            [self _showNetworkErrorOverlay];
            Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);
            [[self delegate] DJLConversationListViewControllerNotifyRefreshError:self account:account];
        }
        //NSLog(@"done for %@ - %i", folderPath, error);
        _manualRefreshFolderPath = nil;
    }
}

- (void) _connected
{
    [self _loadVisibleCells];
}

- (void) _setupStorageView
{
    if (_unifiedStorageView != NULL) {
        return;
    }

    if ([self folderPath] == nil) {
        return;
    }

    if (_unifiedAccount == NULL) {
        return;
    }

    int64_t folderID = _unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]);
    if (folderID == -1) {
        return;
    }

    _unifiedAccount->openViewForFolder(folderID);
    _unifiedStorageView = _unifiedAccount->viewForFolder(folderID);
    MC_SAFE_RETAIN(_unifiedStorageView);
    _unifiedStorageView->addObserver(_callback);
    _unifiedAccount->refreshFolder(folderID);
}

- (void) _unsetupStorageView
{
    if ([self folderPath] == nil) {
        return;
    }
    if (_unifiedAccount == NULL) {
        return;
    }
    _unifiedAccount->closeView(_unifiedStorageView);
    if (_unifiedStorageView != NULL) {
        _unifiedStorageView->removeObserver(_callback);
    }
    MC_SAFE_RELEASE(_unifiedStorageView);
}

- (NSArray *) _rowsIDsSelection
{
    NSMutableArray * result = [[NSMutableArray alloc] init];
    NSIndexSet * selection = [_tableView selectedRowIndexes];
    if ([self _currentUnifiedStorageView] == NULL) {
        return [NSArray array];
    }
    unsigned int conversationsCount = [self _currentUnifiedStorageView]->conversationsCount();
    [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * stop) {
        if (idx >= conversationsCount) {
            return;
        }

        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) idx);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        DJLUnifiedConversationID * convIDContainer = [[DJLUnifiedConversationID alloc] init];
        [convIDContainer setConvID:convID];
        [convIDContainer setAccountIndex:accountIndex];
        [result addObject:convIDContainer];
    }];
    return result;
}

- (void) _setRowsIDsSelection:(NSArray *)unifiedConversationsIDs fallback:(NSUInteger)firstIndex
{
    if ([self _currentUnifiedStorageView] == NULL) {
        return;
    }

    NSSet * unifiedConversationsIDsSet = [NSSet setWithArray:unifiedConversationsIDs];

    NSMutableIndexSet * selection = [NSMutableIndexSet indexSet];
    for(unsigned int i = 0 ; i < [self _currentUnifiedStorageView]->conversationsCount() ; i ++) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex(i);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        DJLUnifiedConversationID * convIDContainer = [[DJLUnifiedConversationID alloc] init];
        [convIDContainer setConvID:convID];
        [convIDContainer setAccountIndex:accountIndex];
        if ([unifiedConversationsIDsSet containsObject:convIDContainer]) {
            [selection addIndex:i];
        }
    }
    if (([selection count] == 0) && (firstIndex != NSNotFound)) {
        if ((firstIndex >= [self _currentUnifiedStorageView]->conversationsCount()) && ([self _currentUnifiedStorageView]->conversationsCount() > 0)) {
            firstIndex = [self _currentUnifiedStorageView]->conversationsCount() - 1;
        }
        [selection addIndex:firstIndex];
    }
    if (![[_tableView selectedRowIndexes] isEqualTo:selection]) {
        //NSLog(@"reselect rows: %@ %@", selection, [_tableView selectedRowIndexes]);
        [_tableView selectRowIndexes:selection byExtendingSelection:NO];
    }
}

- (void) _storageView:(UnifiedMailStorageView *)view
  changedWithDeletion:(NSArray *)deleted
                moves:(NSArray *)moved
             addition:(NSArray *)added
         modification:(NSArray *)modified
{
    if ([self _currentUnifiedStorageView] != view) {
        return;
    }

    NSUInteger firstIndex = [[_tableView selectedRowIndexes] firstIndex];
    //MCOIndexSet * selection = [self _rowsIDsSelection];
    NSArray * selection = _lastRowsIDsSelection;

#if 0
    if (([deleted count] + [moved count] + [added count] > 3) || DISABLE_TABLEVIEW_ANIMATION) {
        LOG_STACK_STORAGE("storage update without animation %i %i %i %i", (int) [deleted count], (int) [moved count], (int) [added count], (int) [modified count]);
        //NSIndexSet * selection = [_tableView selectedRowIndexes];
        [_tableView reloadData];
        _showingLoadMore = _sync->canLoadMoreForFolder(_sync->storage()->folderIDForPath([_currentFolderPath mco_mcString]));
        //[_tableView selectRowIndexes:selection byExtendingSelection:NO];
        [self _setRowsIDsSelection:selection fallback:firstIndex];

        [self _loadVisibleCells];

        return;
    }
#endif

    //LOG_STACK_STORAGE("storage update with animation %i %i %i %i", (int) [deleted count], (int) [moved count], (int) [added count], (int) [modified count]);
    NSMutableIndexSet * indexSet = [NSMutableIndexSet indexSet];

    for(NSNumber * nbIndex in modified) {
        unsigned int idx = [nbIndex intValue];
        DJLConversationCellContentView * row = [_tableView viewAtColumn:0 row:idx makeIfNecessary:NO];
        if (row != NULL) {
            NSNumber * nbConvID = [[row conversation] objectForKey:@"id"];
            NSNumber * nbAccount = [[row conversation] objectForKey:@"account"];
            NSDictionary * conv = MCO_TO_OBJC([self _currentUnifiedStorageView]->conversationsInfoForConversationID([nbAccount unsignedIntValue], [nbConvID longLongValue]));
            [row setConversation:conv];
            //[row setNeedsDisplay:YES];
            [row update];
        }
    }

    [_tableView beginUpdates];
    [indexSet removeAllIndexes];
    for(NSNumber * nbConvID in deleted) {
        [indexSet addIndex:[nbConvID longLongValue]];
    }
    if ([indexSet count] > 0) {
        [_tableView removeRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationSlideLeft];
    }
    for(NSArray * swapInfo in moved) {
        NSNumber * firstIndex = [swapInfo objectAtIndex:0];
        NSNumber * secondIndex = [swapInfo objectAtIndex:1];
        [_tableView moveRowAtIndex:[firstIndex longLongValue] toIndex:[secondIndex longLongValue]];
    }
    [indexSet removeAllIndexes];
    for(NSNumber * nbConvID in added) {
        [indexSet addIndex:[nbConvID longLongValue]];
    }
    if ([indexSet count] > 0) {
        [_tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationSlideLeft];
    }

    [indexSet removeAllIndexes];
    for(NSNumber * nbConvID in modified) {
        [indexSet addIndex:[nbConvID longLongValue]];
    }
    [_tableView noteHeightOfRowsWithIndexesChanged:indexSet];
    [_tableView endUpdates];

    [self _setRowsIDsSelection:selection fallback:firstIndex];

    [self _loadVisibleCells];

    [self _updatePlaceholder];

    [self _markFolderAsRead];
}

- (BOOL) _needsLoadVisibleCells
{
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    if (range.length == 0)
        return NO;

    for(unsigned int i = (unsigned int) range.location ; i < range.location + range.length ; i ++) {
        unsigned int row = i;
        if (row >= [self _currentUnifiedStorageView]->conversationsCount()) {
            continue;
        }

        NSDictionary * info = MCO_TO_OBJC([self _currentUnifiedStorageView]->conversationsInfoAtIndex(row));
        if (![[info objectForKey:@"unread"] boolValue]) {
            continue;
        }
        unsigned int accountIndex = [(NSNumber *) [info objectForKey:@"account"] unsignedIntValue];
        NSArray * messages = [info objectForKey:@"messages"];
        for(NSDictionary * message in messages) {
            if ([message objectForKey:@"snippet"] == nil) {
                int64_t messageRowID = [(NSNumber *) [message objectForKey:@"id"] longLongValue];
                Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);
                if (account->canFetchMessageSummary(messageRowID)) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void) _loadVisibleCells
{
    bool waitingLoadMore = false;
    int64_t folderID = -1;
    if ((_unifiedSearchStorageView == NULL) && [self folderPath] != nil) {
        folderID = _unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]);
    }
    if (folderID != -1) {
        _unifiedAccount->setWaitingLoadMoreForFolder(folderID, waitingLoadMore);
    }

    BOOL needsLoadVisibleCells = [self _needsLoadVisibleCells];
    //fprintf(stderr, "needs load cell: %i %i\n", needsLoadVisibleCells, _disableIdle);
    if (needsLoadVisibleCells) {
        if (!_disableIdle) {
            LOG_IDLE("disable idle");
            _disableIdle = YES;
            _unifiedAccount->disableSync();
        }
    }
    else {
        if (_disableIdle) {
            LOG_IDLE("enable idle");
            _disableIdle = NO;
            _unifiedAccount->enableSync();
        }
    }

    //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_loadVisibleCellsAfterDelay) object:nil];
    //[self performSelector:@selector(_loadVisibleCellsAfterDelay) withObject:nil afterDelay:0.3];
    [self _loadVisibleCellsAfterDelay];
}

- (void) _loadVisibleCellsAfterDelay
{
    //NSLog(@"try to fetch");
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    if (range.length == 0)
        return;

    NSMutableIndexSet * accountQueried = [[NSMutableIndexSet alloc] init];
    BOOL fetched = NO;
    for(unsigned int i = (unsigned int) range.location ; i < range.location + range.length ; i ++) {
        unsigned int row = i;
        if (row >= [self _currentUnifiedStorageView]->conversationsCount()) {
            continue;
        }

        NSDictionary * info = MCO_TO_OBJC([self _currentUnifiedStorageView]->conversationsInfoAtIndex(row));
        unsigned int accountIndex = [(NSNumber *) [info objectForKey:@"account"] unsignedIntValue];
        if ([accountQueried containsIndex:accountIndex]) {
            continue;
        }
        NSArray * messages = [info objectForKey:@"messages"];
        for(NSDictionary * message in messages) {
            if ([message objectForKey:@"snippet"] == nil) {
                int64_t messageRowID = [(NSNumber *) [message objectForKey:@"id"] longLongValue];
                int64_t folderID = [(NSNumber *) [message objectForKey:@"folder"] longLongValue];
                Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);
                if (account->canFetchMessageSummary(messageRowID)) {
                    [accountQueried addIndex:accountIndex];
                    account->fetchMessageSummary(folderID, messageRowID, false);
                    fetched = YES;
                    break;
                }
            }
        }
    }
}

- (void) setFolderPath:(NSString *)folderPath
{
    if ([_folderPath isEqualToString:folderPath]) {
        return;
    }

    [self _hideSearch];

    [self _unsetupStorageView];
    _folderPath = folderPath;
    [self _setupStorageView];

    //NSLog(@"%s", MCUTF8(_account->accountInfo()->email()));
    _showingLoadMore = NO;
    [_tableView reloadData];
    [_tableView scrollRowToVisible:0];

    _lastRowsIDsSelection = nil;
    [_tableView deselectAll:nil];
    [self _clearPlaceholder];
    [[self delegate] DJLConversationListViewControllerSelectionChanged:self];
}

- (NSString *) folderPath
{
    return _folderPath;
}

#if 0
- (hermes::MailStorageView *) storageView
{
    return [self _currentStorageView];
}
#endif

- (hermes::MailStorageView *) storageViewForSingleSelection
{
    UnifiedMailStorageView * unifiedStorage = [self _currentUnifiedStorageView];
    DJLUnifiedConversationID * convID = [[self selectedConversationsIDs] objectAtIndex:0];
    return (MailStorageView *) unifiedStorage->storageViews()->objectAtIndex([convID accountIndex]);
}

- (hermes::Account *) accountForSingleSelection
{
    DJLUnifiedConversationID * convID = [[self selectedConversationsIDs] objectAtIndex:0];
    Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex([convID accountIndex]);
    return account;
}

- (hermes::Account *) uniqueAccountForSelection
{
    int accountIndex = -1;
    for(DJLUnifiedConversationID * convID in [self selectedConversationsIDs]) {
        if (accountIndex == -1) {
            accountIndex = [convID accountIndex];
        }
        else if ([convID accountIndex] != accountIndex) {
            return NULL;
        }
    }
    if (accountIndex == -1) {
        return NULL;
    }
    if (_unifiedAccount == NULL) {
        return NULL;
    }
    return (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);
}

- (NSArray *) selectedConversationsIDs
{
    return [self _rowsIDsSelection];
}

- (void) archiveSelection
{
    LOG_ERROR("archive selection");
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
    }];
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        LOG_ERROR("archive selection %i conv", conversationsIDs->count());
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        MailStorageView * storageView = (MailStorageView *) [self _currentUnifiedStorageView]->storageViews()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            account->archivePeopleConversations(conversationsIDs, storageView->foldersScores());
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (void) trashSelection
{
    LOG_ERROR("delete selection");
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    __block bool isAllTrash = true;
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        bool isTrash = (info->objectForKey(MCSTR("trash")) != NULL);
        isAllTrash = isAllTrash && isTrash;
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
    }];
    BOOL missingTrash = NO;
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            if (account->trashFolderPath() == NULL) {
                missingTrash = YES;
                [self _showAlertTrashMissing:account];
                break;
            }
        }
    }
    if (missingTrash) {
        MC_SAFE_RELEASE(conversationsByAccount);
        return;
    }
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        LOG_ERROR("delete selection %i conv", conversationsIDs->count());
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            if (isAllTrash) {
                account->purgeFromTrashPeopleConversations(conversationsIDs);
            }
            else {
                MailStorageView * storageView = (MailStorageView *) [self _currentUnifiedStorageView]->storageViews()->objectAtIndex(i);
                account->deletePeopleConversations(conversationsIDs, storageView->foldersScores());
            }
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
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

- (BOOL) _isRead
{
    if (_unifiedAccount == NULL) {
        return YES;
    }

    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    __block BOOL hasUnread = NO;
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
        if (((Value *) info->objectForKey(MCSTR("unread")))->boolValue()) {
            hasUnread = YES;
        }
    }];
    return !hasUnread;
}

- (void) toggleReadSelection
{
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    __block BOOL hasUnread = NO;
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
        if (((Value *) info->objectForKey(MCSTR("unread")))->boolValue()) {
            hasUnread = YES;
        }
    }];
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            if (hasUnread) {
                account->markAsReadPeopleConversations(conversationsIDs);
            }
            else {
                account->markAsUnreadPeopleConversations(conversationsIDs);
            }
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (BOOL) _isStarred
{
    if (_unifiedAccount == NULL) {
        return YES;
    }

    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    __block BOOL hasUnstarred = NO;
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
        if (!((Value *) info->objectForKey(MCSTR("starred")))->boolValue()) {
            hasUnstarred = YES;
        }
    }];
    return !hasUnstarred;
}

- (void) toggleStarSelection
{
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    __block BOOL hasUnstarred = NO;
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
        if (!((Value *) info->objectForKey(MCSTR("starred")))->boolValue()) {
            hasUnstarred = YES;
        }
    }];
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            if (hasUnstarred) {
                account->starPeopleConversations(conversationsIDs);
            }
            else {
                account->unstarPeopleConversations(conversationsIDs);
            }
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (void) _markAsSpamSelection
{
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
    }];
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        MailStorageView * storageView = (MailStorageView *) [self _currentUnifiedStorageView]->storageViews()->objectAtIndex(i);
        if ((conversationsIDs->count() > 0) && (account->spamFolderPath() != NULL)) {
            //account->movePeopleConversations(conversationsIDs, account->spamFolderPath());
            account->movePeopleConversations(conversationsIDs, account->spamFolderPath(), storageView->foldersScores());
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (void) setRefreshing:(BOOL)refreshing
{
    _refreshing = refreshing;
    if (_refreshing) {
        [[_refreshOverlayView animator] setAlphaValue:1.0];
        [_refreshOverlayView startAnimation];
    }
    else {
        [[_refreshOverlayView animator] setAlphaValue:0.0];
        [_refreshOverlayView stopAnimation];
    }
}

- (BOOL) isRefreshing
{
    return _refreshing;
}

- (void) _replyMessage
{
    [self _replyMessageWithType:DJLReplyTypeReplyAll];
}

- (void) _forwardMessage
{
    [self _replyMessageWithType:DJLReplyTypeForward];
}

- (void) _replyMessageWithType:(DJLReplyType)replyType
{
    if ([[self selectedConversationsIDs] count] == 1) {
        DJLUnifiedConversationID * convID = [[self selectedConversationsIDs] objectAtIndex:0];
        mailcore::HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoForConversationID([convID accountIndex], [convID convID]);
        DJLAssert(info != NULL);
        Array * messages = (Array *) info->objectForKey(MCSTR("messages"));
        DJLAssert(messages != NULL);
        DJLAssert(messages->count() > 0);
        HashMap * messageInfo = (HashMap *) messages->objectAtIndex(0);
        Value * vRowID = (Value *) messageInfo->objectForKey(MCSTR("id"));
        Value * vFolderID = (Value *) messageInfo->objectForKey(MCSTR("folder"));

        // mark as read.
        Array * rowids = Array::arrayWithObject(vRowID);
        Account * account = [self accountForSingleSelection];
        account->markAsReadMessages(rowids);

        [[self delegate] DJLConversationListViewController:self
                                                   account:account
                                         replyMessageRowID:vRowID->longLongValue()
                                                  folderID:vFolderID->longLongValue()
                                                 replyType:replyType];
    }
}

- (void) _deleteDraftsSelection
{
    Array * conversationsByAccount = new Array();
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        conversationsByAccount->addObject(Array::array());
    }
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        HashMap * info = [self _currentUnifiedStorageView]->conversationsInfoAtIndex((unsigned int) row);
        int64_t convID = ((Value *) info->objectForKey(MCSTR("id")))->longLongValue();
        unsigned int accountIndex = ((Value *) info->objectForKey(MCSTR("account")))->unsignedIntValue();
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(accountIndex);
        conversationsIDs->addObject(Value::valueWithLongLongValue(convID));
    }];
    BOOL missingTrash = NO;
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            if (account->trashFolderPath() == NULL) {
                missingTrash = YES;
                [self _showAlertTrashMissing:account];
                break;
            }
        }
    }
    if (missingTrash) {
        MC_SAFE_RELEASE(conversationsByAccount);
        return;
    }
    for(unsigned int i = 0 ; i < _unifiedAccount->accounts()->count() ; i ++) {
        Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(i);
        Array * conversationsIDs = (Array *) conversationsByAccount->objectAtIndex(i);
        if (conversationsIDs->count() > 0) {
            account->purgePeopleConversations(conversationsIDs);
        }
    }
    MC_SAFE_RELEASE(conversationsByAccount);
}

- (void) _updatePlaceholder
{
    if (([self _currentUnifiedStorageView] != NULL) && ([self _currentUnifiedStorageView]->conversationsCount() != 0)) {
        _hasPlaceholderUpdateScheduled = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_delayedUpdatePlaceholder) object:nil];
        [[_placeholderView animator] setAlphaValue:0.0];
    }
    else {
        if (_hasPlaceholderUpdateScheduled) {
            return;
        }

        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_delayedUpdatePlaceholder) object:nil];
        _hasPlaceholderUpdateScheduled = YES;
        [self performSelector:@selector(_delayedUpdatePlaceholder) withObject:nil afterDelay:1.0];
    }
}

- (void) _clearPlaceholder
{
    [_placeholderView setKind:DJLConversationListPlaceholderKindNone];
    [self _updatePlaceholder];
}

- (void) _delayedUpdatePlaceholder
{
    _hasPlaceholderUpdateScheduled = NO;
    BOOL show = NO;
    BOOL isSearching = NO;
    DJLConversationListPlaceholderKind kind = DJLConversationListPlaceholderKindNone;
    if (_unifiedAccount != NULL) {
        show = _unifiedAccount->shouldShowProgressForFolder(_unifiedAccount->folderIDForPath([[self folderPath] mco_mcString]));
        isSearching = _unifiedAccount->isSearching();
    }
    BOOL searchMode = NO;
    if (_unifiedSearchStorageView != NULL) {
        searchMode = YES;
    }
    if ([self _currentUnifiedStorageView] == NULL) {
        kind = DJLConversationListPlaceholderKindNoAccounts;
    }
    else if (isSearching) {
        kind = DJLConversationListPlaceholderKindSearching;
    }
    else if ([self _currentUnifiedStorageView]->isLoading()) {
        kind = DJLConversationListPlaceholderKindNone;
    }
    else if (!Reachability::sharedManager()->isReachable()) {
        kind = DJLConversationListPlaceholderKindNotLoaded;
    }
    else if (show) {
        kind = DJLConversationListPlaceholderKindLoading;
    }
    else if (searchMode) {
        kind = DJLConversationListPlaceholderKindEmpty;
    }
    else {
        kind = DJLConversationListPlaceholderKindInboxZero;
    }
    [_placeholderView setKind:kind];

    if (([self _currentUnifiedStorageView] == NULL) || ([self _currentUnifiedStorageView]->conversationsCount() == 0)) {
        [[_placeholderView animator] setAlphaValue:1.0];
    }
    else {
        [[_placeholderView animator] setAlphaValue:0.0];
    }
}

#pragma mark labels popover

- (BOOL) _sameAccountForConversations:(NSArray *)conversations
{
    int accountIndex = -1;
    for(NSDictionary * info in conversations) {
        NSNumber * nbCurrentAccountIndex = [info objectForKey:@"account"];
        if (nbCurrentAccountIndex != nil) {
            int currentAccountIndex = [(NSNumber *) [info objectForKey:@"account"] unsignedIntValue];
            if (accountIndex == -1) {
                accountIndex = currentAccountIndex;
            }
            else if (accountIndex != currentAccountIndex) {
                return NO;
            }
        }
    }
    return YES;
}

#define WIDTH 300
#define HEIGHT 500

- (void) _showLabelsPopOverAndArchive:(BOOL)archive
{
    if ([_labelsPopOver isShown]) {
        return;
    }
    if ([[_tableView selectedRowIndexes] count] == 0) {
        return;
    }
    NSArray * infos = [self selectedConversationsInfos];
    if (![self _sameAccountForConversations:infos]) {
        return;
    }

    DJLLabelsViewController * labelsViewController = [[DJLLabelsViewController alloc] init];
    [labelsViewController setArchiveEnabled:archive];
    if (![self uniqueAccountForSelection]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        [labelsViewController setArchiveEnabled:YES];
    }
    [labelsViewController setDelegate:self];
    [[labelsViewController view] setFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
    [labelsViewController setConversations:infos];
    [labelsViewController setAccount:[self uniqueAccountForSelection]];
    [labelsViewController setStorageView:[self storageViewForSingleSelection]];
    [labelsViewController setFolderPath:[self folderPath]];
#if 0
    if ((_unifiedSearchStorageView == NULL) && [[self folderPath] isEqualToString:MCO_TO_OBJC(_unifiedAccount->trashFolderPath())]) {
        [labelsViewController setTrash:YES];
    }
#endif
    [labelsViewController reloadData];
    _labelsPopOver = [[NSPopover alloc] init];
    [_labelsPopOver setContentViewController:labelsViewController];
    [_labelsPopOver setBehavior:NSPopoverBehaviorTransient];
    [_labelsPopOver setContentSize:NSMakeSize(WIDTH, HEIGHT)];

    NSRect rect;
    NSUInteger idx = [[_tableView selectedRowIndexes] firstIndex];
    rect = [_tableView rectOfRow:idx];
    rect = [[self view] convertRect:rect fromView:_tableView];
    NSRect intersection = NSIntersectionRect(rect, [_scrollView frame]);
    if (intersection.size.width == 0) {
        rect = [_scrollView frame];
    }

    [_labelsPopOver showRelativeToRect:rect ofView:[self view]
                         preferredEdge:NSMaxXEdge];
}

#pragma mark DJLLabelsViewController delegate

- (void) DJLLabelsViewControllerClose:(DJLLabelsViewController *)controller
{
    [_labelsPopOver close];
}

#pragma mark -
#pragma mark menu management

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    if ([item action] == @selector(toggleRead:)) {
        if ([self _isRead]) {
            [item setTitle:@"Mark as Unread"];
        }
        else {
            [item setTitle:@"Mark as Read"];
        }
        return [[_tableView selectedRowIndexes] count] > 0;
    }
    else if ([item action] == @selector(toggleStar:)) {
        if ([self _isStarred]) {
            [item setTitle:@"Removed star"];
        }
        else {
            [item setTitle:@"Mark as Starred"];
        }
        return [[_tableView selectedRowIndexes] count] > 0;
    }
    else if ([item action] == @selector(archiveMessage:)) {
        if ([[_tableView selectedRowIndexes] count] == 0) {
            return NO;
        }
        if (_unifiedSearchStorageView != NULL) {
            return NO;
        }
        else if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->allMailFolderPath())] ||
                 [_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->archiveFolderPath())] ||
                 [_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->sentFolderPath())]) {
            return NO;
        }
        else {
            return YES;
        }
    }
    else if ([item action] == @selector(deleteMessage:)) {
        if ([[_tableView selectedRowIndexes] count] == 0) {
            return NO;
        }
        return YES;
    }
    else if ([item action] == @selector(search:)) {
        return YES;
    }
    else if ([item action] == @selector(replyMessage:)) {
        return ([[_tableView selectedRowIndexes] count] == 1);
    }
    else if ([item action] == @selector(forwardMessage:)) {
        return ([[_tableView selectedRowIndexes] count] == 1);
    }
    else if ([item action] == @selector(showLabelsPanel:)) {
        return [self uniqueAccountForSelection] != NULL;
    }
    else if ([item action] == @selector(showLabelsAndArchivePanel:)) {
        if (_unifiedAccount == NULL) {
            return NO;
        }
        if (![[self folderPath] isEqualToString:MCO_TO_OBJC(_unifiedAccount->inboxFolderPath())] &&
            ![[self folderPath] isEqualToString:MCO_TO_OBJC(_unifiedAccount->importantFolderPath())]) {
            return NO;
        }
        return [self uniqueAccountForSelection] != NULL;
    }
    else if ([item action] == @selector(markAsSpam:)) {
        if (_unifiedAccount == NULL) {
            return NO;
        }
        if ([_folderPath isEqualToString:MCO_TO_OBJC(_unifiedAccount->spamFolderPath())]) {
            return NO;
        }
        return YES;
    }
    else {
        return NO;
    }
}

@end
