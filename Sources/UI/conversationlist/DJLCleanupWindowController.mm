// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLCleanupWindowController.h"

#import <MailCore/MailCore.h>

#import "FBKVOController.h"
#import "DJLDarkMode.h"
#import "DJLColoredView.h"
#import "DJLTableView.h"
#import "DJLScrollView.h"
#import "DJLConversationCellContentView.h"
#import "DJLConversationCellView.h"
#import "DJLGradientSeparatorLineView.h"
#import "DJLWindow.h"
#import "DJLArchivedOverlayView.h"
#import "DJLDeletedOverlayView.h"
#import "DJLHUDWindow.h"

using namespace mailcore;
using namespace hermes;

@interface DJLCleanupWindowController () <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, DJLConversationCellViewDelegate>

- (void) _storageView:(UnifiedMailStorageView *)view
  changedWithDeletion:(NSArray *)deleted
                moves:(NSArray *)moved
             addition:(NSArray *)added
         modification:(NSArray *)modified;
- (void) _notifyFetchSummaryDoneWithError:(hermes::ErrorCode)error;
- (void) _connected;

@end

class DJLCleanupWindowControllerCallback : public Object, public UnifiedMailStorageViewObserver, public UnifiedAccountObserver {
public:
    DJLCleanupWindowControllerCallback(DJLCleanupWindowController * controller) {
        mController = controller;
    }

    virtual ~DJLCleanupWindowControllerCallback() {}

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

    virtual void accountConnected(UnifiedAccount * account, unsigned int accountIndex)
    {
        [mController _connected];
    }

private:
    __weak DJLCleanupWindowController * mController;
};

@implementation DJLCleanupWindowController {
    FBKVOController * _kvoController;
    DJLTableView * _tableView;
    DJLScrollView * _scrollView;
    NSMutableArray * _conversations;
    NSButton * _archiveButton;
    NSButton * _deleteButton;
    NSButton * _cancelButton;
    NSTextField * _textField;
    DJLGradientSeparatorLineView * _separatorView;
    DJLGradientSeparatorLineView * _bottomSeparatorView;
    NSMutableIndexSet * _checkedMessages;
    NSMutableDictionary * _convIDMap;
    DJLCleanupWindowControllerCallback * _callback;
    UnifiedMailStorageView * _unifiedStorageView;
    UnifiedAccount * _unifiedAccount;
    BOOL _disableIdle;
    BOOL _cancelled;
}

- (id) init
{
    DJLWindow * window = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 600)
                                                      styleMask:NSTitledWindowMask | /* NSResizableWindowMask | */NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                        backing:NSBackingStoreBuffered defer:YES];
    NSRect frame;
    [window setTitlebarAppearsTransparent:YES];
    [window center];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setReleasedWhenClosed:NO];
    [window setTrafficLightAlternatePositionEnabled:NO];

    frame = [window frame];
    frame.origin = CGPointZero;
    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:frame];
    [contentView setAutoresizingMask:NSViewHeightSizable];
    [window setContentView:contentView];
    [window setTitle:@"Clean up notifications"];
    [contentView setWantsLayer:YES];

    self = [super initWithWindow:window];

    _callback = new DJLCleanupWindowControllerCallback(self);

    [window setDelegate:self];

    [self _setup];
    _cancelled = YES;

    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:[window contentView] keyPath:@"effectiveAppearance" options:0 block
                           :^(id observer, id object, NSDictionary *change) {
                               [weakSelf _applyDarkMode];
                           }];
    [self _applyDarkMode];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_unifiedStorageView != NULL) {
        _unifiedStorageView->removeObserver(_callback);
        _unifiedAccount->removeObserver(_callback);
    }
    MC_SAFE_RELEASE(_callback);
    MC_SAFE_RELEASE(_unifiedStorageView);
    if (_disableIdle) {
        _disableIdle = NO;
        if (_unifiedAccount != NULL) {
            _unifiedAccount->enableSync();
        }
    }
    MC_SAFE_RELEASE(_unifiedAccount);
}

- (void) setUnifiedAccount:(hermes::UnifiedAccount *)unifiedAccount
{
    MC_SAFE_RELEASE(_unifiedAccount);
    _unifiedAccount = unifiedAccount;
    MC_SAFE_RETAIN(_unifiedAccount);
}

- (hermes::UnifiedAccount *) unifiedAccount
{
    return _unifiedAccount;
}

- (void) setUnifiedStorageView:(UnifiedMailStorageView *)unifiedStorageView
{
    MC_SAFE_RELEASE(_unifiedStorageView);
    _unifiedStorageView = unifiedStorageView;
    MC_SAFE_RETAIN(_unifiedStorageView);
}

- (UnifiedMailStorageView *) unifiedStorageView
{
    return _unifiedStorageView;
}

- (void) _applyDarkMode
{
    NSColor * backgroundColor;
    if ([DJLDarkMode isDarkModeForView:[[self window] contentView]]) {
        backgroundColor = [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
    } else {
        backgroundColor = [NSColor whiteColor];
    }
    [(DJLColoredView *)[[self window] contentView] setBackgroundColor:backgroundColor];
    [_textField setBackgroundColor:backgroundColor];
}

- (void) _setup
{
    NSView * contentView = [[self window] contentView];
    NSRect contentFrame = [contentView bounds];
    NSRect frame;

    // Buttons.
    _archiveButton = [NSButton buttonWithTitle:@"Archive" target:self action:@selector(_archive:)];
    [contentView addSubview:_archiveButton];
    _deleteButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(_delete:)];
    [contentView addSubview:_deleteButton];
    _cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(_cancel:)];
    [contentView addSubview:_cancelButton];

    // Bottom separator.
    frame = contentFrame;
    frame.origin.y = 0;
    frame.size.height = 1;
    _bottomSeparatorView = [[DJLGradientSeparatorLineView alloc] initWithFrame:frame];
    [_bottomSeparatorView setAlphaValue:1.0];
    [contentView addSubview:_bottomSeparatorView];

    // list of emails.
    frame.origin.x = 20;
    frame.origin.y = NSMaxY([_bottomSeparatorView frame]) + 10;
    frame.size.width = contentFrame.size.width - 40;
    frame.size.height = 400;
    _scrollView = [[DJLScrollView alloc] initWithFrame:frame];
    //[_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_scrollView setHasVerticalScroller:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
    _tableView = [[DJLTableView alloc] initWithFrame:[_scrollView bounds]];
    [_tableView setAllowsMultipleSelection:YES];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_tableView setHeaderView:nil];
    [_tableView setRowHeight:80];
    [_tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [_tableView setIntercellSpacing:NSMakeSize(0, 0)];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLConversation"];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_tableView addTableColumn:column];
    [_scrollView setDocumentView:_tableView];
    [contentView addSubview:_scrollView];
    [_scrollView setDrawsBackground:NO];
    [_tableView setBackgroundColor:[NSColor clearColor]];

    // Text.
    _textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_textField setAlignment:NSTextAlignmentCenter];
    [_textField sizeToFit];
    [_textField setEditable:NO];
    [_textField setBordered:NO];
    frame = [_textField frame];
    frame.origin.x = 20;
    frame.size.width = contentFrame.size.width - 40;
    frame.origin.y = 0;
    [_textField setFrame:frame];
    [contentView addSubview:_textField];

    // Top separator.
    frame = contentFrame;
    frame.origin.y = 0;
    frame.size.height = 1;
    _separatorView = [[DJLGradientSeparatorLineView alloc] initWithFrame:frame];
    [_separatorView setAutoresizingMask:NSViewWidthSizable];
    [_separatorView setAlphaValue:0.0];
    [contentView addSubview:_separatorView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrolled) name:NSViewBoundsDidChangeNotification object:[_scrollView contentView]];
    [self _scrolled];
}

- (void) _layout
{
    NSRect frame;
    NSView * contentView = [[self window] contentView];
    NSRect contentFrame = [contentView bounds];

    [_textField sizeToFit];

    frame = [_archiveButton frame];
    frame.origin.x = contentFrame.size.width - frame.size.width - 10;
    frame.origin.y = 5;
    [_archiveButton setFrame:frame];

    frame = [_archiveButton frame];
    frame.origin.x = [_archiveButton frame].origin.x - frame.size.width;
    frame.origin.y = 5;
    [_deleteButton setFrame:frame];

    frame = [_cancelButton frame];
    frame.origin.x = [_deleteButton frame].origin.x - frame.size.width;
    frame.origin.y = 5;
    [_cancelButton setFrame:frame];

    frame = contentFrame;
    frame.origin.y = NSMaxY([_archiveButton frame]) + 10;
    frame.size.height = 1;
    [_bottomSeparatorView setFrame:frame];

    frame.origin.x = 20;
    frame.origin.y = NSMaxY([_bottomSeparatorView frame]);
    frame.size.width = contentFrame.size.width - 40;
    frame.size.height = 400;
    [_scrollView setFrame:frame];

    frame = contentFrame;
    frame.origin.y = NSMaxY([_scrollView frame]);
    frame.size.height = 1;
    [_separatorView setFrame:frame];

    frame = [_textField frame];
    frame.origin.x = 20;
    frame.origin.y = NSMaxY([_separatorView frame]) + 10;
    frame.size.width = contentFrame.size.width - 40;
    [_textField setFrame:frame];

    CGFloat maxY = NSMaxY([_textField frame]) + 35;
    [[self window] setFrame:NSMakeRect(0, 0, contentFrame.size.width, maxY) display:NO];
    [[self window] center];
}

- (void) _scrollerStyleChanged
{
    [_scrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [[self conversations] count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 75;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSRect frame = NSMakeRect(0, 0, [_tableView frame].size.width, 70);
    DJLConversationCellContentView * view = [[DJLConversationCellContentView alloc] initWithFrame:frame];
    [view setCheckMode:YES];
    [view setChecked:[_checkedMessages containsIndex:row]];
    [view setVibrancy:0.0];
    NSDictionary * objcInfo = [self conversations][row];
    [view setConversation:objcInfo];
    [view setDelegate:self];
    return view;
}

- (void) setConversations:(NSArray *)conversations
{
    NSMutableArray * notifications = [[NSMutableArray alloc] init];
    _convIDMap = [[NSMutableDictionary alloc] init];
    for(NSDictionary * conversation in conversations) {
        NSNumber * nbStarred = [conversation objectForKey:@"starred"];
        if ([nbStarred boolValue]) {
            continue;
        }
        NSNumber * nbNotification = conversation[@"notification"];
        if (![nbNotification boolValue]) {
            continue;
        }
        NSNumber * nbConvID = [conversation objectForKey:@"id"];
        NSNumber * nbAccountIndex = [conversation objectForKey:@"account"];
        NSString * identifier = [NSString stringWithFormat:@"%@-%@", nbAccountIndex, nbConvID];
        _convIDMap[identifier] = [NSNumber numberWithInt:(int) [notifications count]];

        [notifications addObject:conversation];
    }
    _checkedMessages = [[NSMutableIndexSet alloc] init];
    [_checkedMessages addIndexesInRange:NSMakeRange(0, [notifications count])];
    _conversations = notifications;
    if ([[self conversations] count] == 1) {
        [_textField setStringValue:[NSString stringWithFormat:@"1 email notification found in the last 30 days.\nPlease unselect the emails you'd like to keep\nthen use Archive or Delete."]];
    } else {
        [_textField setStringValue:[NSString stringWithFormat:@"%i email notifications found in the last 30 days.\nPlease unselect the emails you'd like to keep\nthen use Archive or Delete.", (int)[[self conversations] count]]];
    }

    [self _applyButtonStatus];
    if (_unifiedAccount != NULL) {
        _unifiedAccount->addObserver(_callback);
    }
    if (_unifiedStorageView != NULL) {
        _unifiedStorageView->addObserver(_callback);
    }
}

- (NSArray *) conversations
{
    return _conversations;
}

- (NSArray *) selectedConversations
{
    NSMutableArray * result = [[NSMutableArray alloc] init];
    [_checkedMessages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [result addObject:_conversations[idx]];
    }];
    return result;
}

- (void) showWindow:(id)sender
{
    [self _layout];
    [super showWindow:sender];
    [_tableView reloadData];
    [NSApp runModalForWindow:[self window]];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModal];
    if (_cancelled) {
        [[self delegate] DJLCleanupWindowControllerCancel:self];
    }
}

- (void) DJLConversationCellViewStarClicked:(DJLConversationCellView *)view
{
    // do nothing.
}

- (void) DJLConversationCellViewUnreadClicked:(DJLConversationCellView *)view
{
    // do nothing.
}

- (void) DJLConversationCellViewCheckedClicked:(DJLConversationCellView *)view
{
    NSDictionary * conversation = [view conversation];
    NSNumber * nbConvID = [conversation objectForKey:@"id"];
    NSNumber * nbAccountIndex = [conversation objectForKey:@"account"];
    NSString * identifier = [NSString stringWithFormat:@"%@-%@", nbAccountIndex, nbConvID];
    NSNumber * nbIndex = _convIDMap[identifier];
    int idx = [nbIndex intValue];
    if ([_checkedMessages containsIndex:idx]) {
        [_checkedMessages removeIndex:idx];
        [view setChecked:NO];
    } else {
        [_checkedMessages addIndex:idx];
        [view setChecked:YES];
    }

    [self _applyButtonStatus];
}

- (void) _applyButtonStatus
{
    BOOL enabled = [_checkedMessages count] > 0;
    [_deleteButton setEnabled:enabled];
    [_archiveButton setEnabled:enabled];
}

- (void) _scrolled
{
    CGFloat alpha = 0.0;
    if ([[_scrollView contentView] bounds].origin.y > 50.) {
        alpha = 1.0;
    }
    else if ([[_scrollView contentView] bounds].origin.y < 0) {
        alpha = 0.0;
    }
    else {
        alpha = [[_scrollView contentView] bounds].origin.y / 50.;
    }
    [_separatorView setAlphaValue:alpha];
}

- (void) _archive:(id)sender
{
    DJLArchivedOverlayView * view = [[DJLArchivedOverlayView alloc] initWithFrame:NSMakeRect(0,0, 150, 150)];
    [view setCount:(int) [_checkedMessages count]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * 500), dispatch_get_main_queue(), ^{
        [DJLHUDWindow windowWithView:view];
    });
    _cancelled = NO;
    [[self delegate] DJLCleanupWindowControllerArchive:self];
}

- (void) _delete:(id)sender
{
    DJLDeletedOverlayView * view = [[DJLDeletedOverlayView alloc] initWithFrame:NSMakeRect(0,0, 150, 150)];
    [view setCount:(int) [_checkedMessages count]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * 500), dispatch_get_main_queue(), ^{
        [DJLHUDWindow windowWithView:view];
    });
    _cancelled = NO;
    [[self delegate] DJLCleanupWindowControllerDelete:self];
}

- (void) _cancel:(id)sender
{
    [self close];
}

- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window
{
    [self _cancel:nil];
    return YES;
}

- (void) _storageView:(UnifiedMailStorageView *)view
  changedWithDeletion:(NSArray *)deleted
                moves:(NSArray *)moved
             addition:(NSArray *)added
         modification:(NSArray *)modified
{
    if (_unifiedStorageView != view) {
        return;
    }

    NSMutableDictionary * modifiedConversations = [[NSMutableDictionary alloc] init];
    for(NSNumber * nbIndex in modified) {
        unsigned int idx = [nbIndex intValue];
        HashMap * info = _unifiedStorageView->conversationsInfoAtIndex(idx);
        NSDictionary * convInfo = MCO_TO_OBJC(info);
        NSNumber * nbConvID = convInfo[@"id"];
        NSNumber * nbAccount = convInfo[@"account"];
        NSString * identifier = [NSString stringWithFormat:@"%@-%@", nbAccount, nbConvID];
        [modifiedConversations setObject:convInfo forKey:identifier];
    }
    for(unsigned int i = 0 ; i < [_conversations count] ; i ++) {
        NSDictionary * conversation = _conversations[i];
        NSNumber * nbConvID = [conversation objectForKey:@"id"];
        NSNumber * nbAccount = [conversation objectForKey:@"account"];
        NSString * identifier = [NSString stringWithFormat:@"%@-%@", nbAccount, nbConvID];
        NSDictionary * convInfo = modifiedConversations[identifier];
        if (convInfo != nil) {
            [_conversations replaceObjectAtIndex:i withObject:convInfo];
            DJLConversationCellContentView * row = [_tableView viewAtColumn:0 row:i makeIfNecessary:NO];
            if (row != nil) {
                [row setConversation:convInfo];
                [row update];
            }
        }
    }

    [self _loadVisibleCells];
}

- (void) _loadVisibleCells
{
    BOOL needsLoadVisibleCells = [self _needsLoadVisibleCells];
    //fprintf(stderr, "needs load cell: %i %i\n", needsLoadVisibleCells, _disableIdle);
    if (needsLoadVisibleCells) {
        if (!_disableIdle) {
            _disableIdle = YES;
            _unifiedAccount->disableSync();
        }
    }
    else {
        if (_disableIdle) {
            _disableIdle = NO;
            _unifiedAccount->enableSync();
        }
    }

    [self _loadVisibleCellsAfterDelay];
}

- (BOOL) _needsLoadVisibleCells
{
    NSRange range = [_tableView rowsInRect:[_tableView visibleRect]];
    if (range.length == 0)
        return NO;

    for(unsigned int i = (unsigned int) range.location ; i < range.location + range.length ; i ++) {
        unsigned int row = i;
        NSDictionary * info = _conversations[row];
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
        NSDictionary * info = _conversations[row];
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

- (void) _notifyFetchSummaryDoneWithError:(hermes::ErrorCode)error
{
    if (error == hermes::ErrorFetch) {
        [self _loadVisibleCells];
    }
    else {
        if (_disableIdle) {
            _disableIdle = NO;
            _unifiedAccount->enableSync();
        }
    }
}

- (void) _connected
{
    [self _loadVisibleCells];
}

@end
