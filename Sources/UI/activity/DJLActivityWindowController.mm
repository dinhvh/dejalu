// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLActivityWindowController.h"

#include "Hermes.h"

#import "DJLActivityFolderCellView.h"
#import "DJLActivityAccountCellView.h"
#import "DJLActivityCellView.h"

using namespace mailcore;
using namespace hermes;

@interface DJLActivityWindowController () <NSOutlineViewDataSource, NSOutlineViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSSplitViewDelegate>

- (void) _activityManagerUpdated;

@end

class DJLActivityWindowControllerCallback : public ActivityManagerObserver, public AccountManagerObserver {
public:
    DJLActivityWindowControllerCallback(DJLActivityWindowController * controller)
    {
        mController = controller;
    }
    
    virtual void activityManagerUpdated(ActivityManager * manager)
    {
        [mController _activityManagerUpdated];
    }
    
    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mController update];
    }

private:
    DJLActivityWindowController * mController;
};

@implementation DJLActivityWindowController {
    NSOutlineView * _sourceListOutlineView;
    NSScrollView * _sourceListScrollView;
    NSSplitView * _splitView;
    NSTextView * _contentTextView;
    NSScrollView * _contentScrollView;
    NSMutableSet * _values;
    NSMutableDictionary * _folders;
    NSTableView * _activityListTableView;
    NSScrollView * _activityListScrollView;
    DJLActivityWindowControllerCallback * _callback;
}

- (id)init
{
    NSWindow * window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 400) styleMask:NSTitledWindowMask | NSResizableWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask
                                                      backing:NSBackingStoreBuffered defer:YES];
    
    self = [super initWithWindow:window];
    
    [window setDelegate:self];
    
    NSView * contentView = [window contentView];
    
    NSRect frame;
    frame = [contentView bounds];
    _splitView = [[NSSplitView alloc] initWithFrame:frame];
    [_splitView setVertical:YES];
    [_splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [_splitView setDelegate:self];
    [contentView addSubview:_splitView];
    
    frame = [contentView bounds];
    frame.size.width = frame.size.height / 2;
    _sourceListScrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_sourceListScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_sourceListScrollView setHasVerticalScroller:YES];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    _sourceListOutlineView = [[NSOutlineView alloc] initWithFrame:frame];
    [_sourceListOutlineView setDataSource:self];
    [_sourceListOutlineView setDelegate:self];
    [_sourceListOutlineView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_sourceListOutlineView setHeaderView:nil];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLFolder"];
    frame = [contentView bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_sourceListOutlineView addTableColumn:column];
    [_sourceListOutlineView setOutlineTableColumn:column];
    [_sourceListScrollView setDocumentView:_sourceListOutlineView];
    [_splitView addSubview:_sourceListScrollView];
    
    frame = [contentView bounds];
    _contentScrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_contentScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_contentScrollView setHasVerticalScroller:YES];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    frame = [contentView bounds];
    _contentTextView = [[NSTextView alloc] initWithFrame:frame];
    [_contentScrollView setDocumentView:_contentTextView];
    [_splitView addSubview:_contentScrollView];
    
    frame = [contentView bounds];
    frame.size.width = frame.size.height / 2;
    _activityListScrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_activityListScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_activityListScrollView setHasVerticalScroller:YES];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    _activityListTableView = [[NSTableView alloc] initWithFrame:frame];
    [_activityListTableView setDataSource:self];
    [_activityListTableView setDelegate:self];
    [_activityListTableView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_activityListTableView setHeaderView:nil];
    column = [[NSTableColumn alloc] initWithIdentifier:@"DJLActivity"];
    frame = [contentView bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_activityListTableView addTableColumn:column];
    [_activityListScrollView setDocumentView:_activityListTableView];
    [_splitView addSubview:_activityListScrollView];
    
    _callback = new DJLActivityWindowControllerCallback(self);
    ActivityManager::sharedManager()->addObserver(_callback);
    AccountManager::sharedManager()->addObserver(_callback);
    
    return self;
}

- (void) dealloc
{
    AccountManager::sharedManager()->removeObserver(_callback);
    ActivityManager::sharedManager()->removeObserver(_callback);
}

- (void) showWindow:(id)sender
{
    [super showWindow:sender];
    [_sourceListOutlineView expandItem:nil expandChildren:YES];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    NSString * child = nil;
    if (item == nil) {
        Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex((int) index);
        child = [NSString stringWithFormat:@"account:%@", MCO_TO_OBJC(account->accountInfo()->email())];
    }
    else {
        NSString * nodeIdentifier = item;
        NSString * email = [nodeIdentifier substringFromIndex:8];
        //Account * account = (Account *) AccountManager::sharedManager()->accountForEmail(MCO_FROM_OBJC(mailcore::String, email));
        //NSArray * folders = [_folders objectForKey:MCO_TO_OBJC(account->accountInfo()->email())];
        NSArray * folders = [_folders objectForKey:email];
        child = [NSString stringWithFormat:@"folder:%@/%@", email, [folders objectAtIndex:index]];
    }
    if (child != nil) {
        [_values addObject:child];
    }
    return [_values member:child];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    NSString * identifier = item;
    if ([identifier hasPrefix:@"account:"]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        return AccountManager::sharedManager()->accounts()->count();
    }
    else {
        NSString * nodeIdentifier = item;
        NSString * email = [nodeIdentifier substringFromIndex:8];
        NSArray * folders = [_folders objectForKey:email];
        return [folders count];
    }
}


- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSString * identifier = item;
    if ([identifier hasPrefix:@"account:"]) {
        NSString * email = [identifier substringFromIndex:8];
        DJLActivityAccountCellView * cellView = [[DJLActivityAccountCellView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        [cellView setEmail:email];
        return cellView;
    }
    else if ([identifier hasPrefix:@"folder:"]) {
        NSString * accountFolderPath = [identifier substringFromIndex:7];
        NSUInteger location = [accountFolderPath rangeOfString:@"/"].location;
        NSString * email = [accountFolderPath substringToIndex:location];
        NSString * folderPath = [accountFolderPath substringFromIndex:location + 1];
        Account * account = (Account *) AccountManager::sharedManager()->accountForEmail(MCO_FROM_OBJC(mailcore::String, email));
        DJLActivityFolderCellView * cellView = [[DJLActivityFolderCellView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        [cellView setFolderPath:folderPath];
        [cellView setUrgentTask:MCO_TO_OBJC(account->urgentTaskDescriptionForFolder([folderPath mco_mcString]))];
        [cellView setSyncState:MCO_TO_OBJC(account->syncStateDescriptionForFolder([folderPath mco_mcString]))];
        [cellView setSyncing:account->isSyncingFolder([folderPath mco_mcString])];
        return cellView;
    }
    else {
        return nil;
    }
}

- (CGFloat) outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    NSString * identifier = item;
    if ([identifier hasPrefix:@"account:"]) {
        return 30;
    }
    else if ([identifier hasPrefix:@"folder:"]) {
        return 60;
    }
    else {
        return 0;
    }
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
    return [NSIndexSet indexSet];
}

- (void) update
{
    @autoreleasepool {
        _folders = [NSMutableDictionary dictionary];
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            NSMutableArray * folders = [NSMutableArray array];
            Array * accountFolders = account->folders();
            for(unsigned int i = 0 ; i < accountFolders->count() ; i ++) {
                mailcore::String * folderPath = (mailcore::String *) accountFolders->objectAtIndex(i);
                if (account->isSyncingFolder(folderPath)) {
                    [folders addObject:MCO_TO_OBJC(folderPath)];
                }
            }
            [_folders setObject:folders forKey:MCO_TO_OBJC(account->accountInfo()->email())];
        }
        _values = [NSMutableSet set];
        [_sourceListOutlineView reloadData];
        [_sourceListOutlineView expandItem:nil expandChildren:YES];
    }
}

- (void) _activityManagerUpdated
{
    [_activityListTableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return ActivityManager::sharedManager()->activities()->count();
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    DJLActivityCellView * view = [[DJLActivityCellView alloc] init];
    ActivityItem * item = (ActivityItem *) ActivityManager::sharedManager()->activities()->objectAtIndex((unsigned int) row);
    [view setActivityItem:item];
    return view;
}

- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 40;
}

#if 0
- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
{
    if (subview == _contentScrollView) {
        return YES;
    } else {
        return NO;
    }
}
#endif

@end
