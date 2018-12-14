// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrefsAccountsViewController.h"

#import "DJLColoredView.h"
#import "DJLTableView.h"
#import "NSImage+DJLColored.h"
#import "DJLWindow.h"
#import "DJLAppDelegate.h"
#import "DJLPrefsButtonCell.h"
#import "FBKVOController.h"
#import "DJLDarkMode.h"

using namespace hermes;
using namespace mailcore;

@interface DJLPrefsAccountsViewController () <NSTableViewDataSource, NSTableViewDelegate, DJLWindowDelegate>

- (void) _accountClosed:(hermes::Account *)account;
- (void) _updateAccounts;

@end

class DJLPrefsAccountsViewControllerCallback : public Object, public AccountObserver, public AccountManagerObserver {

public:
    DJLPrefsAccountsViewControllerCallback(DJLPrefsAccountsViewController * controller)
    {
        mController = controller;
    }

    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mController _updateAccounts];
    }
    
    virtual void accountClosed(Account * account)
    {
        [mController _accountClosed:account];
    }

    __weak DJLPrefsAccountsViewController * mController;
};

@implementation DJLPrefsAccountsViewController {
    DJLColoredView * _borderView;
    NSScrollView * _scrollView;
    DJLTableView * _tableView;
    dispatch_queue_t _queue;
    NSButton * _addButton;
    NSButton * _removeButton;
    NSButton * _editButton;
    DJLPrefsAccountsViewControllerCallback * _callback;
    NSWindow * _deleteWindow;
    DJLWindow * _editDialog;
    NSTextField * _nameLabel;
    NSTextField * _nameField;
    NSTextField * _emailLabel;
    NSTextField * _emailField;
    NSButton * _okButton;
    NSButton * _cancelButton;
    Account * _account;
    NSTextField * _placeholder;
    FBKVOController * _kvoController;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _callback = new DJLPrefsAccountsViewControllerCallback(self);
    AccountManager::sharedManager()->addObserver(_callback);
    return self;
}

- (void) dealloc
{
    AccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (NSImage *) icon
{
    return [NSImage imageNamed:@"DejaLu_Accounts_Light_32"];
}

- (NSString *) title
{
    return @"Accounts";
}

- (CGFloat) height
{
    return 300;
}

#define DJLAccountType @"DJLAccountType"

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSZeroRect];
    [self setView:view];

    NSView * contentView = [self view];
    NSRect frame = [contentView bounds];

    NSTextField * label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, frame.size.height - 40, frame.size.width - 50, 20)];
    [label setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [label setEditable:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setTextColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];
    [label setStringValue:@"Accounts can be reordered"];
    [contentView addSubview:label];

    _addButton = [[NSButton alloc] initWithFrame:NSMakeRect(frame.size.width - 40, frame.size.height - 40, 20, 30)];
    [_addButton setCell:[[DJLPrefsButtonCell alloc] init]];
    [_addButton setBezelStyle:NSRoundRectBezelStyle];
    [_addButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    NSImage * originImage = [NSImage imageNamed:@"DejaLu_Plus_12"];
    [_addButton setImage:originImage];
    [_addButton setTarget:self];
    [_addButton setAction:@selector(_add)];
    [contentView addSubview:_addButton];

    _removeButton = [[NSButton alloc] initWithFrame:NSMakeRect(frame.size.width - 65, frame.size.height - 40, 20, 30)];
    [_removeButton setCell:[[DJLPrefsButtonCell alloc] init]];
    [_removeButton setBezelStyle:NSRoundRectBezelStyle];
    [_removeButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    originImage = [NSImage imageNamed:@"DejaLu_Minus_12"];
    [_removeButton setImage:originImage];
    [_removeButton setTarget:self];
    [_removeButton setAction:@selector(_remove)];
    [contentView addSubview:_removeButton];

    _editButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, frame.size.height - 40, 100, 30)];
    [_editButton setCell:[[DJLPrefsButtonCell alloc] init]];
    [_editButton setBezelStyle:NSRoundRectBezelStyle];
    [_editButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [_editButton setTitle:@"Edit"];
    [_editButton setTarget:self];
    [_editButton setAction:@selector(_edit)];
    [_editButton sizeToFit];
    NSRect buttonFrame = [_editButton frame];
    buttonFrame.size.height = 30;
    buttonFrame.size.width += 20;
    buttonFrame.origin.x = frame.size.width - 65 - buttonFrame.size.width - 5;
    [_editButton setFrame:buttonFrame];
    [contentView addSubview:_editButton];

    frame = NSInsetRect(frame, 19, 19);
    frame.size.height -= 25;
    _borderView = [[DJLColoredView alloc] initWithFrame:frame];
    [_borderView setBackgroundColor:[NSColor colorWithWhite:0.95 alpha:1.0]];
    [_borderView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [contentView addSubview:_borderView];

    frame = [contentView bounds];
    frame = NSInsetRect(frame, 20, 20);
    frame.size.height -= 25;
    _scrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_scrollView setHasVerticalScroller:YES];
    _tableView = [[DJLTableView alloc] initWithFrame:[_scrollView bounds]];
    [_tableView registerForDraggedTypes:@[DJLAccountType]];
    [_tableView setRowHeight:30];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setHeaderView:nil];
    [_tableView setTarget:self];
    [_tableView setDoubleAction:@selector(_edit)];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLAccount"];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_tableView addTableColumn:column];
    [_scrollView setDocumentView:_tableView];
    [contentView addSubview:_scrollView];

    frame = [contentView bounds];
    frame = NSInsetRect(frame, 20, 20);
    frame.size.height -= 25;
    _placeholder = [[NSTextField alloc] initWithFrame:frame];
    [_placeholder setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_placeholder setEditable:NO];
    [_placeholder setBezeled:NO];
    [_placeholder setDrawsBackground:NO];
    [_placeholder setTextColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];
    [_placeholder setStringValue:@"Click on + to create an account"];
    [_placeholder setAlignment:NSCenterTextAlignment];
    [_placeholder setFont:[NSFont systemFontOfSize:30]];
    [_placeholder sizeToFit];
    [_placeholder setHidden:YES];
    [contentView addSubview:_placeholder];

    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:[self view] keyPath:@"effectiveAppearance" options:0 block
                           :^(id observer, id object, NSDictionary *change) {
                               [weakSelf _applyDarkMode];
                           }];
    [self _applyDarkMode];

    [self _updateAccounts];
}

- (void) _applyDarkMode
{
    if ([DJLDarkMode isDarkModeForView:[self view]]) {
        [_borderView setBackgroundColor:[NSColor colorWithWhite:0.3 alpha:1.0]];
        [(DJLColoredView *)[_editDialog contentView] setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
    } else {
        [_borderView setBackgroundColor:[NSColor colorWithWhite:0.95 alpha:1.0]];
        [(DJLColoredView *)[_editDialog contentView] setBackgroundColor:[NSColor whiteColor]];
    }
}

#pragma mark -
#pragma mark Edit dialog

#define DIALOG_WIDTH 350
#define DIALOG_HEIGHT 130

- (void) _setupDialog
{
    _editDialog = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT) styleMask:NSTitledWindowMask | NSTexturedBackgroundWindowMask backing:NSBackingStoreBuffered defer:YES];
    [_editDialog setDelegate:self];
    [_editDialog setTrafficLightAlternatePositionEnabled:NO];
    [_editDialog setTitlebarAppearsTransparent:YES];
    NSView * contentView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT)];
    [_editDialog setContentView:contentView];
    _nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 87, DIALOG_WIDTH - 40, 22)];
    [_nameLabel setAutoresizingMask:NSViewMinYMargin];
    [_nameLabel setAlignment:NSTextAlignmentRight];
    [_nameLabel setEditable:NO];
    [_nameLabel setBezeled:NO];
    [_nameLabel setStringValue:@"Name"];
    [_nameLabel setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [_nameLabel sizeToFit];
    [contentView addSubview:_nameLabel];
    _emailLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 57, DIALOG_WIDTH - 40, 22)];
    [_emailLabel setAutoresizingMask:NSViewMinYMargin];
    [_emailLabel setAlignment:NSTextAlignmentRight];
    [_emailLabel setEditable:NO];
    [_emailLabel setBezeled:NO];
    [_emailLabel setStringValue:@"Email"];
    [_emailLabel setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [_emailLabel sizeToFit];
    [contentView addSubview:_emailLabel];
    CGFloat width = [_nameLabel frame].size.width;
    if ([_emailLabel frame].size.width > width) {
        width = [_emailLabel frame].size.width;
    }
    NSRect frame = [_nameLabel frame];
    frame.size.width = width;
    [_nameLabel setFrame:frame];
    frame = [_emailLabel frame];
    frame.size.width = width;
    [_emailLabel setFrame:frame];

    CGFloat x;
    x = NSMaxX([_nameLabel frame]);
    _nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 10, 85, DIALOG_WIDTH - x - 20 - 10, 24)];
    [_nameField setAutoresizingMask:NSViewMinYMargin];
    [_nameField setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [contentView addSubview:_nameField];
    x = NSMaxX([_nameLabel frame]);
    _emailField = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 10, 55, DIALOG_WIDTH - x - 20 - 10, 24)];
    [_emailField setAutoresizingMask:NSViewMinYMargin];
    [_emailField setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [contentView addSubview:_emailField];

    _okButton = [[NSButton alloc] initWithFrame:NSMakeRect(DIALOG_WIDTH - 20 - 100, 20, 100, 25)];
    [_okButton setBezelStyle:NSRoundRectBezelStyle];
    [_okButton setTitle:@"OK"];
    [_okButton setTarget:self];
    [_okButton setAction:@selector(_confirmEdit)];
    [_okButton setKeyEquivalent:@"\r"];
    [contentView addSubview:_okButton];
    _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(DIALOG_WIDTH - 20 - 200 - 10, 20, 100, 25)];
    [_cancelButton setBezelStyle:NSRoundRectBezelStyle];
    [_cancelButton setTitle:@"Cancel"];
    [_cancelButton setTarget:self];
    [_cancelButton setAction:@selector(_cancelEdit)];
    [contentView addSubview:_cancelButton];

    [self _applyDarkMode];
}

#pragma mark -
#pragma mark tableview delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return AccountManager::sharedManager()->accounts()->count();
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView * view = [_tableView viewAtColumn:0 row:row makeIfNecessary:NO];
    if ([_tableView selectedRow] == row) {
        [[view textField] setTextColor:[NSColor whiteColor]];
    } else {
        [[view textField] setTextColor:[NSColor blackColor]];
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView * view = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 460, 30)];
    NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 5, 440, 20)];
    [textField setEditable:NO];
    [textField setBordered:NO];
    [textField setBackgroundColor:[NSColor clearColor]];
    [view addSubview:textField];
    [view setTextField:textField];
    Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex((int) row);
    [[view textField] setStringValue:MCO_TO_OBJC(account->accountInfo()->email())];
    return view;
}

- (BOOL)djl_tableView:(NSTableView *)tableView keyPress:(NSEvent *)event
{
    if ([event keyCode] == 51) {
        // backspace.
        [self _remove];
        return YES;
    }
    return NO;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pasteboard = [info draggingPasteboard];
    NSData *rowData = [pasteboard dataForType:DJLAccountType];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

    NSUInteger originRow;
    originRow = [rowIndexes firstIndex];

    Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex((int) originRow);
    AccountManager::sharedManager()->moveAccountToIndex(account, (int) row);
    AccountManager::sharedManager()->save();

    [_tableView reloadData];

    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if( operation == NSTableViewDropOn ) {
        [aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
    }

    NSPasteboard *pasteboard = [info draggingPasteboard];
    NSData *rowData = [pasteboard dataForType:DJLAccountType];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

    if ([rowIndexes firstIndex] == row)
        return NSDragOperationNone;
    if ([rowIndexes firstIndex] + 1 == row)
        return NSDragOperationNone;
    
    return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:@[DJLAccountType] owner:self];
    [pboard setData:data forType:DJLAccountType];
    return YES;
}

- (void) _accountClosed:(hermes::Account *)account
{
    String * path = AccountManager::sharedManager()->path()->stringByAppendingPathComponent(account->accountInfo()->email());
    if (_queue == NULL) {
        _queue = dispatch_queue_create("DJLPrefsAccountsViewController", DISPATCH_QUEUE_SERIAL);
    }
    MC_SAFE_RETAIN(path);

    MC_SAFE_RETAIN(account);
    AccountManager::sharedManager()->removeAccount(account);
    [self _updateAccounts];

    __weak DJLPrefsAccountsViewController * weakSelf = self;
    dispatch_async(_queue, ^{
        DJLPrefsAccountsViewController * strongSelf = weakSelf;
        hermes::removeFile(path);
        path->release();
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf _updateAfterDelete:account];
        });
    });
}

- (void) _updateAfterDelete:(hermes::Account *)account
{
    [_deleteWindow orderOut:nil];
    [[[self view] window] endSheet:_deleteWindow];

    account->removeObserver(_callback);
    MC_SAFE_RELEASE(account);
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    [self _updateButtonStates];
}

- (void) _updateButtonStates
{
    if ([[_tableView selectedRowIndexes] count] == 0) {
        [_editButton setEnabled:NO];
        [_removeButton setEnabled:NO];
    }
    else {
        [_editButton setEnabled:YES];
        [_removeButton setEnabled:YES];
    }
}

#pragma mark -
#pragma mark actions

- (void) _add
{
    [DJLAppDelegate addAccount];
}

- (void) _remove
{
    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Do you really want to remove this account?"];
    [alert setInformativeText:@"The account will be removed from DejaLu."];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];

    __weak DJLPrefsAccountsViewController * weakSelf = self;
    [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        [weakSelf _handleRemoveDialog:returnCode];
    }];
}

- (void) _handleRemoveDialog:(NSModalResponse)returnCode
{
    switch (returnCode) {
        case NSAlertFirstButtonReturn:
            [self _confirmRemove];
            [[[[self view] window] attachedSheet] close];
            break;
        case NSAlertSecondButtonReturn:
            [[[[self view] window] attachedSheet] close];
            break;
    }
}

- (void) _confirmRemove
{
    NSUInteger firstIndex = [[_tableView selectedRowIndexes] firstIndex];
    if (firstIndex == NSNotFound) {
        return;
    }
    Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex((int) firstIndex);
    account->addObserver(_callback);
    account->close();

    _deleteWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 100) styleMask:NSTitledWindowMask | NSTexturedBackgroundWindowMask backing:NSBackingStoreBuffered defer:YES];
    NSView * contentView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
    [_deleteWindow setContentView:contentView];
    NSTextField * label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 30, 260, 40)];
    [label setAlignment:NSTextAlignmentCenter];
    [label setEditable:NO];
    [label setBezeled:NO];
    [label setStringValue:@"Deleting account..."];
    [label setFont:[NSFont fontWithName:@"Helvetica Neue" size:15]];
    [label sizeToFit];
    NSRect frame = [label frame];
    frame.origin.x = (int) (([contentView frame].size.width - frame.size.width) / 2);
    frame.origin.y = (int) (([contentView frame].size.height - frame.size.height) / 2);
    [label setFrame:frame];
    [contentView addSubview:label];

    [[[self view] window] beginSheet:_deleteWindow completionHandler:^(NSModalResponse response) {
    }];
}

- (void) _updateAccounts
{
    if (AccountManager::sharedManager()->accounts()->count() == 0) {
        NSRect frame = [_scrollView frame];
        frame.size.height -= 25;
        [_placeholder setFrame:frame];
        [_placeholder setHidden:NO];
    }
    else {
        [_placeholder setHidden:YES];
    }

    [_tableView reloadData];
    [self _updateButtonStates];
}

- (void) _edit
{
    [self _setupDialog];
    [_emailField setEditable:NO];
    [_emailField setTextColor:[NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
    [_emailField setSelectable:YES];
    NSUInteger firstIndex = [[_tableView selectedRowIndexes] firstIndex];
    if (firstIndex == NSNotFound) {
        return;
    }
    Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex((int) firstIndex);
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
    [_nameField setStringValue:MCO_TO_OBJC(account->accountInfo()->displayName())];
    [_emailField setStringValue:MCO_TO_OBJC(account->accountInfo()->email())];
    [[[self view] window] beginSheet:_editDialog completionHandler:^(NSModalResponse response) {
    }];
}

- (void) _confirmEdit
{
    if ([[_nameField stringValue] length] == 0) {
        _account->accountInfo()->setDisplayName(NULL);
    }
    else {
        _account->accountInfo()->setDisplayName(MCO_FROM_OBJC(String, [_nameField stringValue]));
    }
    _account->save();
    [_editDialog orderOut:nil];
    [[[self view] window] endSheet:_editDialog];
    MC_SAFE_RELEASE(_account);
}

- (void) _cancelEdit
{
    [_editDialog orderOut:nil];
    [[[self view] window] endSheet:_editDialog];
    MC_SAFE_RELEASE(_account);
}

#pragma mark -
#pragma mark DJLWindow delegate

- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window
{
    [self _cancelEdit];
    return YES;
}

@end
