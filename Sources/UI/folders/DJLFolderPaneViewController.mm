// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneViewController.h"

#import "DJLScrollView.h"
#import "DJLTableView.h"
#import "DJLFolderPaneAccountCellView.h"
#import "DJLFolderPaneFolderCellView.h"
#import "DJLFolderPaneLabelsCellView.h"
#import "DJLFolderPaneRowView.h"
#import "DJLFolderPaneAccountInfo.h"
#import "DJLFolderPaneFolderInfo.h"
#import "DJLFolderPaneFoldersDisclosureInfo.h"

#include "Hermes.h"

#import "DJLSourceList.h"

using namespace mailcore;
using namespace hermes;

@interface DJLFolderPaneViewController () <PXSourceListDataSource, PXSourceListDelegate, DJLTableViewDelegate>

- (void) _unifiedAccountManagerChanged;
- (void) _accountFoldersUpdate;
- (void) _accountGotFolders;
- (void) _countChanged:(Array *)foldersIDs storageView:(MailStorageView *)view;

@end

class DJLFolderPaneViewControllerCallback : public UnifiedAccountManagerObserver,
public UnifiedAccountObserver,
public AccountObserver,
public MailStorageViewObserver,
public Object {
public:
    DJLFolderPaneViewControllerCallback(DJLFolderPaneViewController * controller)
    {
        mController = controller;
    }

    virtual void unifiedAccountManagerChanged(UnifiedAccountManager * manager)
    {
        [mController _unifiedAccountManagerChanged];
    }

    virtual void accountFoldersUpdated(UnifiedAccount * account, unsigned int accountIndex)
    {
        [mController _accountFoldersUpdate];
    }

    virtual void accountGotFolders(UnifiedAccount * account, unsigned int accountIndex)
    {
        [mController _accountGotFolders];
    }

    virtual void mailStorageFoldersCountsChanged(MailStorageView * view, mailcore::Array * foldersIDs)
    {
        [mController _countChanged:foldersIDs storageView:view];
    }

    __weak DJLFolderPaneViewController * mController;
};

@implementation DJLFolderPaneViewController {
    NSView * _view;
    DJLScrollView * _scrollView;
    //DJLTableView * _tableView;
    //NSOutlineView * _outlineView;
    PXSourceList * _sourceList;
    NSMutableArray * _accounts;
    NSMutableArray * _folders;
    DJLFolderPaneViewControllerCallback * _callback;
    hermes::UnifiedAccount * _unifiedAccount;
    Array * _registeredViews;
    Array * _registeredAccounts;
}

@synthesize folderPath = _folderPath;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    _callback = new DJLFolderPaneViewControllerCallback(self);
    UnifiedAccountManager::sharedManager()->addObserver(_callback);
    _registeredViews = new Array();
    _registeredAccounts = new Array();

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    MC_SAFE_RELEASE(_registeredAccounts);
    MC_SAFE_RELEASE(_registeredViews);
    MC_SAFE_RELEASE(_unifiedAccount);
    for(DJLFolderPaneAccountInfo * info in _accounts) {
        UnifiedAccount * unifiedAccount = [info unifiedAccount];
        unifiedAccount->removeObserver(_callback);
    }
    UnifiedAccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (NSView *) view
{
    if (_view != nil) {
        return _view;
    }
    _view = [[NSView alloc] initWithFrame:CGRectZero];
    [_view setWantsLayer:YES];
    [_view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self _setup];
    return _view;
}

- (void) _setup
{
    NSRect frame = [[self view] bounds];
    _scrollView = [[DJLScrollView alloc] initWithFrame:frame];
    [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_scrollView setHasVerticalScroller:YES];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;

    _sourceList = [[DJLSourceList alloc] initWithFrame:frame];
//    [_sourceList setRowSizeStyle:NSTableViewRowSizeStyleCustom];
//    [_sourceList setRowHeight:40];
    [_sourceList setHeaderView:nil];
    [_sourceList setDataSource:self];
    [_sourceList setDelegate:self];
    [_sourceList setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLFolder"];
    frame = [[self view] bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_sourceList addTableColumn:column];
    [_sourceList setOutlineTableColumn:column];
    [_sourceList setIntercellSpacing:NSMakeSize(0, 0)];
    [_scrollView setDocumentView:_sourceList];
    [[self view] addSubview:_scrollView];
    [_scrollView setDrawsBackground:NO];
    [_sourceList setFocusRingType:NSFocusRingTypeNone];
    [_sourceList setBackgroundColor:[NSColor clearColor]];

    [self _reloadData];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
}

- (void) _scrollerStyleChanged
{
    [_scrollView setScrollerStyle:NSScrollerStyleOverlay];
}

enum {
    COUNT_TYPE_NONE,
    COUNT_TYPE_UNREAD,
    COUNT_TYPE_COUNT,
};

static int compareFoldersWithScore(void * a, void * b, void * context)
{
    NSDictionary * foldersOrderScore = (__bridge NSDictionary *) context;
    String * s_a = (String *) a;
    String * s_b = (String *) b;

    int score_a = 100;
    int score_b = 100;

    if (foldersOrderScore[MCO_TO_OBJC(s_a)] != nil) {
        score_a = [(NSNumber *) foldersOrderScore[MCO_TO_OBJC(s_a)] intValue];
    }
    if (foldersOrderScore[MCO_TO_OBJC(s_b)] != nil) {
        score_b = [(NSNumber *) foldersOrderScore[MCO_TO_OBJC(s_b)] intValue];
    }

    if (score_a != score_b) {
        return score_a - score_b;
    }

    return s_a->caseInsensitiveCompare(s_b);
}

- (DJLFolderPaneAccountInfo *) _infoForAccount:(UnifiedAccount *)unifiedAccount
{
    DJLFolderPaneAccountInfo * info = [[DJLFolderPaneAccountInfo alloc] init];
    [info addAccount:unifiedAccount favoriteAllSpecialFolders:NO singleAccount:(_registeredAccounts->count() == 1)];
    return info;
}

- (NSDictionary *) _saveExpandedNodes
{
    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];

    for(DJLFolderPaneAccountInfo * info in _accounts) {
        BOOL expanded = [_sourceList isItemExpanded:[info foldersDisclosureInfo]];
        UnifiedAccount * unifiedAccount = [[[info foldersDisclosureInfo] accountInfo] unifiedAccount];
        if (unifiedAccount->accounts()->count() == 1) {
            Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
            result[MCO_TO_OBJC(account->accountInfo()->email())] = @(expanded);
        }
        else {
            result[[NSNull null]] = @(expanded);
        }
    }

    return result;
}

- (void) _restoreExpandedNodes:(NSDictionary *)saved
{
    for(DJLFolderPaneAccountInfo * info in _accounts) {
        BOOL expanded = NO;
        UnifiedAccount * unifiedAccount = [[[info foldersDisclosureInfo] accountInfo] unifiedAccount];
        if (unifiedAccount->accounts()->count() == 1) {
            Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
            expanded = [(NSNumber *) saved[MCO_TO_OBJC(account->accountInfo()->email())] boolValue];
        }
        else {
            expanded = [(NSNumber *) saved[[NSNull null]] boolValue];
        }
        if (expanded) {
            [_sourceList expandItem:[info foldersDisclosureInfo]];
        }
    }
}

- (void) _reloadData
{
    CGFloat scrollPosition = [_scrollView documentVisibleRect].origin.y;
    NSString * savedFolderPath = [self folderPath];

    NSDictionary * saved = [self _saveExpandedNodes];

    for(DJLFolderPaneAccountInfo * info in _accounts) {
        UnifiedAccount * unifiedAccount = [info unifiedAccount];
        unifiedAccount->removeObserver(_callback);
    }
    _accounts = [[NSMutableArray alloc] init];
    _folders = [[NSMutableArray alloc] init];

    if (UnifiedAccountManager::sharedManager()->accounts()->count() >= 2) {
        UnifiedAccount * unifiedAccount = UnifiedAccountManager::sharedManager()->unifiedAccount();
        if (unifiedAccount != NULL) {
            unifiedAccount->addObserver(_callback);
            DJLFolderPaneAccountInfo * info = [self _infoForAccount:unifiedAccount];
            [_accounts addObject:info];
        }
    }

    mc_foreacharray(UnifiedAccount, unifiedAccount, UnifiedAccountManager::sharedManager()->accounts()) {
        if (unifiedAccount->inboxFolderPath() == NULL) {
            // continue;
        }
        unifiedAccount->addObserver(_callback);
        DJLFolderPaneAccountInfo * info = [self _infoForAccount:unifiedAccount];
        [_accounts addObject:info];
    }

    [_sourceList reloadData];

    [self _restoreExpandedNodes:saved];
    // Workaround to prevent the scrollbars from flashing.
    BOOL isFirstResponder = ([[_scrollView window] firstResponder] == _sourceList);

    [self setFolderPath:savedFolderPath];

    [_scrollView setHidden:YES];
    [[_scrollView contentView] scrollToPoint: NSMakePoint(0, scrollPosition)];
    [_scrollView reflectScrolledClipView:[_scrollView contentView]];
    [_scrollView setHidden:NO];
    if (isFirstResponder) {
        [[_scrollView window] makeFirstResponder:_sourceList];
    }
}

- (NSUInteger)sourceList:(PXSourceList*)sourceList numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        return [_accounts count];
    }
    else if ([item isKindOfClass:[DJLFolderPaneAccountInfo class]]) {
        DJLFolderPaneAccountInfo * info = item;
#if 0
        if ([[info folders] count] > 0) {
            return [[info baseFolders] count] + 1;
        }
        else {
            return [[info baseFolders] count];
        }
#else
        if ([[[info foldersRootInfo] children] count] > 0) {
            return [[[info favoritesRootInfo] children] count] + 1;
        }
        else {
            return [[[info favoritesRootInfo] children] count];
        }
#endif
    }
    else if ([item isKindOfClass:[DJLFolderPaneFoldersDisclosureInfo class]]) {
        DJLFolderPaneFoldersDisclosureInfo * info = item;
        DJLFolderPaneAccountInfo * accountInfo = [info accountInfo];
        //return [[accountInfo folders] count];
        return [[[accountInfo foldersRootInfo] children] count];
    }
    else if ([item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        DJLFolderPaneFolderInfo * info = item;
        return [[info children] count];
    }
    else {
        MCAssert(0);
        return 0;
    }
}

- (id)sourceList:(PXSourceList*)aSourceList child:(NSUInteger)index ofItem:(id)item
{
    if (item == nil) {
        return _accounts[index];
    }
    else if ([item isKindOfClass:[DJLFolderPaneAccountInfo class]]) {
        DJLFolderPaneAccountInfo * info = item;
#if 0
        if (index < [[info baseFolders] count]) {
            return [info baseFolders][index];
        }
        else {
            return [info foldersDisclosureInfo];
        }
#endif
        if (index < [[[info favoritesRootInfo] children] count]) {
            return [[info favoritesRootInfo] children][index];
        }
        else {
            return [info foldersDisclosureInfo];
        }
    }
    else if ([item isKindOfClass:[DJLFolderPaneFoldersDisclosureInfo class]]) {
        DJLFolderPaneFoldersDisclosureInfo * info = item;
        DJLFolderPaneAccountInfo * accountInfo = [info accountInfo];
        //return [accountInfo folders][index];
        return [[accountInfo foldersRootInfo] children][index];
    }
    else if ([item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        DJLFolderPaneFolderInfo * info = item;
        return [info children][index];
    }
    else {
        MCAssert(0);
        return nil;
    }
}


- (BOOL)sourceList:(PXSourceList*)aSourceList isItemExpandable:(id)item
{
    if (item == nil) {
        return YES;
    }
    else if ([item isKindOfClass:[DJLFolderPaneAccountInfo class]]) {
        return YES;
    }
    else if ([item isKindOfClass:[DJLFolderPaneFoldersDisclosureInfo class]]) {
        return YES;
    }
    else if ([item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        DJLFolderPaneFolderInfo * info = item;
        return [[info children] count] > 0;
    }
    else {
        return NO;
    }
}

- (BOOL)sourceList:(PXSourceList*)aSourceList shouldSelectItem:(id)item
{
    if ([item isKindOfClass:[DJLFolderPaneAccountInfo class]]) {
        return NO;
    }
    else if ([item isKindOfClass:[DJLFolderPaneFoldersDisclosureInfo class]]) {
        return YES;
    }
    else if ([item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSTableRowView *) sourceList:(PXSourceList *)aSourceList rowViewForItem:(id)item
{
    return [[DJLFolderPaneRowView alloc] initWithFrame:NSZeroRect];
}

- (NSView *)sourceList:(PXSourceList *)aSourceList viewForItem:(id)item
{
    if ([item isKindOfClass:[DJLFolderPaneAccountInfo class]]) {
        DJLFolderPaneAccountInfo * info = item;
        UnifiedAccount * unifiedAccount = [info unifiedAccount];
        DJLFolderPaneAccountCellView *view = [[DJLFolderPaneAccountCellView alloc] initWithFrame:NSZeroRect];
        if (unifiedAccount->accounts()->count() >= 2) {
            [view setDisplayName:@"All Accounts"];
        }
        else {
            [view setDisplayName:MCO_TO_OBJC(unifiedAccount->shortDisplayName())];
        }
        return view;
    }
    else if ([item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        DJLFolderPaneFolderInfo * info = item;
        DJLFolderPaneFolderCellView *view = [[DJLFolderPaneFolderCellView alloc] initWithFrame:NSZeroRect];
        [view setDisplayName:[info displayName]];
        [view setCount:[info count]];
        [view setSelectable:[info folderPath] != nil];
        return view;
    }
    else if ([item isKindOfClass:[DJLFolderPaneFoldersDisclosureInfo class]]) {
        DJLFolderPaneLabelsCellView *view = [[DJLFolderPaneLabelsCellView alloc] initWithFrame:NSZeroRect];
        [view setDisplayName:@"Other"];
        return view;
    }
    else {
        MCAssert(0);
        return nil;
    }
}

- (BOOL)sourceList:(PXSourceList*)aSourceList isGroupAlwaysExpanded:(id)group
{
    if ([group isKindOfClass:[DJLFolderPaneAccountInfo class]]) {
        return YES;
    }

    return NO;
}

- (CGFloat)sourceList:(PXSourceList *)aSourceList heightOfRowByItem:(id)item
{
    return 26;
}

- (void)sourceListSelectionDidChange:(NSNotification *)notification
{
    NSInteger row = [_sourceList selectedRow];
    if (row == -1) {
        return;
    }
    id item = [_sourceList itemAtRow:row];
    if (![item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        return;
    }
    DJLFolderPaneFolderInfo * info = item;
    if ([info folderPath] == nil) {
        return;
    }
    UnifiedAccount * unifiedAccount = [[info accountInfo] unifiedAccount];
    [self setUnifiedAccount:unifiedAccount];
    [[self delegate] DJLFolderPaneViewController:self didSelectPath:[info folderPath] unifiedAccount:unifiedAccount];
}

- (BOOL) djl_tableView:(NSTableView *)tableView keyPress:(NSEvent *)event
{
    if ([event keyCode] == 123) {
        // left
        [[self delegate] DJLFolderPaneViewControllerCollapseDetails:self];
        return YES;
    }
    else if ([event keyCode] == 124) {
        // right
        [[self delegate] DJLFolderPaneViewControllerFocusConversationList:self];
        return YES;
    }
    return NO;
}

- (BOOL) djl_tableView:(NSTableView *)tableView handleClickedRow:(NSInteger)row
{
    if ([_sourceList selectedRow] == row) {
        [[self delegate] DJLFolderPaneViewControllerScrollToTop:self];
        return YES;
    }
    return NO;
}

- (NSMenu *)sourceList:(PXSourceList*)aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item
{
    if (![item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        return nil;
    }
    NSInteger row = [_sourceList rowForItem:item];
    if (row == -1) {
        return nil;
    }
    [_sourceList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

    DJLFolderPaneFolderInfo * folderInfo = item;
    UnifiedAccount * unifiedAccount = [[folderInfo accountInfo] unifiedAccount];
    String * path = MCO_FROM_OBJC(String, [folderInfo folderPath]);
    BOOL disabled = NO;
    if (path->isEqual(unifiedAccount->inboxFolderPath())) {
        disabled = YES;
    }

    Set * foldersSet = NULL;
    if (unifiedAccount->accounts()->count() == 1) {
        Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
        foldersSet = Set::setWithArray(account->accountInfo()->favoriteFolders());
    }
    else {
        NSArray * favoriteFolders = [[NSUserDefaults standardUserDefaults] arrayForKey:@"DJLFavoriteFoldersForUnifiedInbox"];
        foldersSet = Set::setWithArray(MCO_FROM_OBJC(Array, favoriteFolders));
    }

    NSMenu * menu = [[NSMenu alloc] init];
    NSMenuItem * menuItem;
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Favorite" action:@selector(toggleFavorite:) keyEquivalent:@""];
    [menuItem setState:foldersSet->containsObject(path) ? NSOnState : NSOffState];
    if (disabled) {
        [menuItem setEnabled:NO];
        [menuItem setAction:NULL];
    }
    [menuItem setTarget:self];
    [menu addItem:menuItem];
    return menu;
}

- (void) toggleFavorite:(id)sender
{
    NSInteger row = [_sourceList selectedRow];
    if (row == -1) {
        return;
    }
    id item = [_sourceList itemAtRow:row];
    if (![item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        return;
    }

    DJLFolderPaneFolderInfo * folderInfo = item;
    UnifiedAccount * unifiedAccount = [[folderInfo accountInfo] unifiedAccount];
    if (unifiedAccount->accounts()->count() == 1) {
        Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
        Set * foldersSet = Set::setWithArray(account->accountInfo()->favoriteFolders());
        String * mcPath = MCO_FROM_OBJC(String, [folderInfo folderPath]);
        if (foldersSet->containsObject(mcPath)) {
            foldersSet->removeObject(mcPath);
        }
        else {
            foldersSet->addObject(mcPath);
        }

        // filter non-existing folders.
        Set * existingFolders = Set::setWithArray(account->folders());
        Array * result = Array::array();
        {
            mc_foreacharray(String, path, foldersSet->allObjects()) {
                if (existingFolders->containsObject(path)) {
                    result->addObject(path);
                }
            }
        }

        account->accountInfo()->setFavoriteFolders(result);
        account->save();
    }
    else {
        NSArray * favoriteFolders = [[NSUserDefaults standardUserDefaults] arrayForKey:@"DJLFavoriteFoldersForUnifiedInbox"];
        NSMutableArray * modifiedFavoriteFolders = [favoriteFolders mutableCopy];
        if ([favoriteFolders containsObject:[folderInfo folderPath]]) {
            [modifiedFavoriteFolders removeObject:[folderInfo folderPath]];
        }
        else {
            [modifiedFavoriteFolders addObject:[folderInfo folderPath]];
        }

        NSMutableSet * resultSet = [NSMutableSet setWithArray:modifiedFavoriteFolders];
        NSSet * existingFolders = [NSSet setWithArray:MCO_TO_OBJC(unifiedAccount->folders())];
        [resultSet intersectSet:existingFolders];
        [[NSUserDefaults standardUserDefaults] setObject:[resultSet allObjects] forKey:@"DJLFavoriteFoldersForUnifiedInbox"];
    }

    [self _reloadData];
}

- (hermes::UnifiedAccount *) unifiedAccount
{
    return _unifiedAccount;
}

- (void) setUnifiedAccount:(hermes::UnifiedAccount *)unifiedAccount
{
    MC_SAFE_REPLACE_RETAIN(UnifiedAccount, _unifiedAccount, unifiedAccount);
}

- (NSString *) folderPath
{
    NSInteger row = [_sourceList selectedRow];
    if (row == -1) {
        return nil;
    }
    id item = [_sourceList itemAtRow:row];
    if (![item isKindOfClass:[DJLFolderPaneFolderInfo class]]) {
        return nil;
    }
    DJLFolderPaneFolderInfo * info = item;
    return [info folderPath];
}

//- (DJLFolderPaneFolderInfo *) _folderInfoForPath:(NSString *)folderPath
//{
//    for(DJLFolderPaneAccountInfo * info in _accounts) {
//    }
//}

- (void) setFolderPath:(NSString *)folderPath
{
    _folderPath = folderPath;
    if (folderPath == nil) {
        [_sourceList deselectAll:nil];
        return;
    }
    for(DJLFolderPaneAccountInfo * info in _accounts) {
        UnifiedAccount * unifiedAccount = [info unifiedAccount];
        if (unifiedAccount != _unifiedAccount) {
            continue;
        }
        DJLFolderPaneFolderInfo * folderInfo = [[info favoritesRootInfo] findFolderInfoForPath:folderPath];
        if (folderInfo != nil) {
            [_sourceList expandItem:[info foldersDisclosureInfo]];
        }
        else {
            folderInfo = [[info foldersRootInfo] findFolderInfoForPath:folderPath];
        }
        if (folderInfo == nil) {
            continue;
        }
        DJLFolderPaneFolderInfo * currentParent = folderInfo;
        while (currentParent != nil) {
            [_sourceList expandItem:currentParent];
            currentParent = [currentParent parent];
        }
        NSInteger row = [_sourceList rowForItem:folderInfo];
        [_sourceList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [_sourceList scrollRowToVisible:row];
        return;

#if 0
        for(DJLFolderPaneFolderInfo * folderInfo in [info folders]) {
            if ([[folderInfo folderPath] isEqualToString:folderPath]) {
                [_sourceList expandItem:info];
                [_sourceList expandItem:[info foldersDisclosureInfo]];
                NSInteger row = [_sourceList rowForItem:folderInfo];
                [_sourceList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                [_sourceList scrollRowToVisible:row];
                //NSLog(@"select folder: %i", (int) row);
                return;
            }
        }
        for(DJLFolderPaneFolderInfo * folderInfo in [info baseFolders]) {
            if ([[folderInfo folderPath] isEqualToString:folderPath]) {
                [_sourceList expandItem:info];
                NSInteger row = [_sourceList rowForItem:folderInfo];
                [_sourceList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                [_sourceList scrollRowToVisible:row];
                //NSLog(@"select folder2: %i", (int) row);
                return;
            }
        }
#endif
    }
    [_sourceList deselectAll:nil];
}

- (void) _accountsChanged
{
    {
        for(unsigned int i = 0 ; i  < _registeredAccounts->count() ; i ++) {
            MailStorageView * view = (MailStorageView *) _registeredViews->objectAtIndex(i);
            Account * account = (Account *) _registeredAccounts->objectAtIndex(i);
            account->removeObserver(_callback);
            view->removeObserver(_callback);
            account->closeViewForCounters(view);
        }
    }
    _registeredViews->removeAllObjects();
    _registeredAccounts->removeAllObjects();
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            MailStorageView * view = account->viewForCounters();
            view->addObserver(_callback);
            account->addObserver(_callback);
            _registeredViews->addObject(view);
            _registeredAccounts->addObject(account);
        }
    }
}

- (void) _unifiedAccountManagerChanged
{
    BOOL transitionFromOneToTwoAccounts = NO;

    if (AccountManager::sharedManager()->accounts()->count() >= 2) {
        if ((_registeredAccounts != NULL) && (_registeredAccounts->count() == 1)) {
            Account * account = (Account *) _registeredAccounts->objectAtIndex(0);
            Set * favoriteFoldersSet = Set::setWithArray(account->accountInfo()->favoriteFolders());
            favoriteFoldersSet->removeObject(account->draftsFolderPath());
            favoriteFoldersSet->removeObject(account->allMailFolderPath());
            favoriteFoldersSet->removeObject(account->archiveFolderPath());
            account->accountInfo()->setFavoriteFolders(favoriteFoldersSet->allObjects());
            account->save();
            transitionFromOneToTwoAccounts = YES;
        }
    }
    [self _accountsChanged];
    [self _reloadData];

    if (_unifiedAccount != NULL) {
        if (_unifiedAccount->accounts()->count() >= 2) {
            UnifiedAccount * unifiedAccount = UnifiedAccountManager::sharedManager()->unifiedAccount();
            [self setUnifiedAccount:unifiedAccount];
        }
        else {
            Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(0);
            UnifiedAccount * unifiedAccount = UnifiedAccountManager::sharedManager()->accountForEmail(account->accountInfo()->email());
            [self setUnifiedAccount:unifiedAccount];
       }
    }

    if (transitionFromOneToTwoAccounts) {
        UnifiedAccount * unifiedAccount = UnifiedAccountManager::sharedManager()->unifiedAccount();
        [self setUnifiedAccount:unifiedAccount];
        [self setFolderPath:MCO_TO_OBJC(unifiedAccount->inboxFolderPath())];
    }
}

- (void) _accountFoldersUpdate
{
    [self _reloadData];
}

- (void) _accountGotFolders
{
    [self _reloadData];
}

- (void) _updateCountRecursively:(DJLFolderPaneFolderInfo *)info unifiedAccount:(UnifiedAccount *)unifiedAccount
{
    if (([info folderPath] != nil) && ([info countType] != COUNT_TYPE_NONE)) {
        int count;
        String * mcPath = MCO_FROM_OBJC(String, [info folderPath]);
        int64_t folderID = unifiedAccount->folderIDForPath(mcPath);
        switch ([info countType]) {
            case COUNT_TYPE_UNREAD:
                count = unifiedAccount->unreadCountForFolderID(folderID);
                break;
            case COUNT_TYPE_COUNT:
                count = unifiedAccount->countForFolderID(folderID);
                break;
            default:
                count = 0;
                break;
        }

        NSInteger row = [_sourceList rowForItem:info];
        if (row != -1) {
            DJLFolderPaneFolderCellView * view = [_sourceList viewAtColumn:0 row:row makeIfNecessary:NO];
            [view setCount:count];
        }
    }

    for(DJLFolderPaneFolderInfo * childInfo in [info children]) {
        [self _updateCountRecursively:childInfo unifiedAccount:unifiedAccount];
    }
}

- (void) _countChanged:(Array *)foldersIDs storageView:(MailStorageView *)view
{
    Account * matchingAccount = NULL;
    for(unsigned int i = 0 ; i  < _registeredAccounts->count() ; i ++) {
        MailStorageView * currentView = (MailStorageView *) _registeredViews->objectAtIndex(i);
        if (currentView == view) {
            matchingAccount = (Account *) _registeredAccounts->objectAtIndex(i);
        }
    }
    for(DJLFolderPaneAccountInfo * info in _accounts) {
        UnifiedAccount * unifiedAccount = [info unifiedAccount];
        [self _updateCountRecursively:[info favoritesRootInfo] unifiedAccount:unifiedAccount];
        [self _updateCountRecursively:[info foldersRootInfo] unifiedAccount:unifiedAccount];
    }
}

@end
