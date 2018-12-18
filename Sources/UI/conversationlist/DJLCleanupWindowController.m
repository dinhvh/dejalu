// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLCleanupWindowController.h"

#import "FBKVOController.h"
#import "DJLDarkMode.h"
#import "DJLColoredView.h"
#import "DJLTableView.h"
#import "DJLScrollView.h"
#import "DJLConversationCellContentView.h"
#import "DJLConversationCellView.h"
#import "DJLGradientSeparatorLineView.h"
#import "DJLWindow.h"

@interface DJLCleanupWindowController () <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, DJLConversationCellViewDelegate>

@end

@implementation DJLCleanupWindowController {
    FBKVOController * _kvoController;
    DJLTableView * _tableView;
    DJLScrollView * _scrollView;
    NSArray * _conversations;
    NSButton * _archiveButton;
    NSButton * _deleteButton;
    NSButton * _cancelButton;
    NSTextField * _textField;
    DJLGradientSeparatorLineView * _separatorView;
    DJLGradientSeparatorLineView * _bottomSeparatorView;
    NSMutableIndexSet * _checkedMessages;
    NSMutableDictionary * _convIDMap;
}

- (id) init
{
    NSWindow * window = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 600)
                                                     styleMask:NSTitledWindowMask | /* NSResizableWindowMask | */NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                       backing:NSBackingStoreBuffered defer:YES];
    NSRect frame;
    [window setTitlebarAppearsTransparent:YES];
    [window center];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setReleasedWhenClosed:NO];

    frame = [window frame];
    frame.origin = CGPointZero;
    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:frame];
    [contentView setAutoresizingMask:NSViewHeightSizable];
    [window setContentView:contentView];
    [window setTitle:@"Clean up notifications"];
    [contentView setWantsLayer:YES];

    self = [super initWithWindow:window];

    [window setDelegate:self];

    [self _setup];

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
    NSRect frame = [contentView bounds];
    frame.origin.x = 20;
    frame.origin.y = 50;
    frame.size.width -= 40;
    frame.size.height -= 120;
    _scrollView = [[DJLScrollView alloc] initWithFrame:frame];
    [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
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

    // Buttons.
    _archiveButton = [NSButton buttonWithTitle:@"Archive" target:self action:@selector(_archive:)];
    NSRect contentFrame = [contentView bounds];
    frame = [_archiveButton frame];
    frame.origin.x = contentFrame.size.width - frame.size.width - 10;
    frame.origin.y = 10;
    [_archiveButton setFrame:frame];
    [contentView addSubview:_archiveButton];
    _deleteButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(_delete:)];
    frame = [_archiveButton frame];
    frame.origin.x = [_archiveButton frame].origin.x - frame.size.width;
    frame.origin.y = 10;
    [_deleteButton setFrame:frame];
    [contentView addSubview:_deleteButton];
    _cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(_cancel:)];
    frame = [_cancelButton frame];
    frame.origin.x = [_deleteButton frame].origin.x - frame.size.width;
    frame.origin.y = 10;
    [_cancelButton setFrame:frame];
    [contentView addSubview:_cancelButton];

    // Text.
    _textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_textField setAlignment:NSTextAlignmentCenter];
    [_textField setStringValue:@"Please unselect the emails you'd like to keep\nthen use Archive or Delete."];
    [_textField sizeToFit];
    [_textField setEditable:NO];
    [_textField setBordered:NO];
    frame = [_textField frame];
    frame.origin.x = 20;
    frame.size.width = contentFrame.size.width - 40;
    frame.origin.y = contentFrame.size.height - (30 + frame.size.height);
    [_textField setFrame:frame];
    [contentView addSubview:_textField];

    // Top separator.
    frame = contentFrame;
    frame.origin.y = [_textField frame].origin.y - 3;
    frame.size.height = 1;
    _separatorView = [[DJLGradientSeparatorLineView alloc] initWithFrame:frame];
    [_separatorView setAutoresizingMask:NSViewWidthSizable];
    [_separatorView setAlphaValue:0.0];
    [contentView addSubview:_separatorView];

    // Bottom separator.
    frame = contentFrame;
    frame.origin.y = 50;
    frame.size.height = 1;
    //_bottomSeparatorView = [[DJLColoredView alloc] initWithFrame:frame];
    _bottomSeparatorView = [[DJLGradientSeparatorLineView alloc] initWithFrame:frame];
    [_bottomSeparatorView setAlphaValue:1.0];
    [contentView addSubview:_bottomSeparatorView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrolled) name:NSViewBoundsDidChangeNotification object:[_scrollView contentView]];
    [self _scrolled];
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
    [super showWindow:sender];
    [_tableView reloadData];
    [NSApp runModalForWindow:[self window]];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModal];
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
    [[self delegate] DJLCleanupWindowControllerArchive:self];
}

- (void) _delete:(id)sender
{
    [[self delegate] DJLCleanupWindowControllerDelete:self];
}

- (void) _cancel:(id)sender
{
    [[self delegate] DJLCleanupWindowControllerCancel:self];
}

- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window
{
    [self _cancel:nil];
    return YES;
}

@end
