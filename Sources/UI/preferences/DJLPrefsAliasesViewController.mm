// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrefsAliasesViewController.h"

#import "NSImage+DJLColored.h"
#import "DJLColoredView.h"
#import "DJLTableView.h"
#import "NSString+DJL.h"
#import "DJLWindow.h"
#import "DJLPrefsButtonCell.h"
#import "FBKVOController.h"
#import "DJLDarkMode.h"

using namespace mailcore;
using namespace hermes;

@interface DJLPrefsAliasesViewController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

- (void) _updateAccounts;

@end

class DJLPrefsAliasesViewControllerCallback : public mailcore::Object, public AccountObserver, public AccountManagerObserver {
public:
    DJLPrefsAliasesViewControllerCallback(DJLPrefsAliasesViewController * controller)
    {
        mController = controller;
    }

    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mController _updateAccounts];
    }

private:
    __weak DJLPrefsAliasesViewController * mController;
};

enum {
    DIALOG_ADD,
    DIALOG_MODIFY,
};

@implementation DJLPrefsAliasesViewController {
    DJLPrefsAliasesViewControllerCallback * _callback;
    NSPopUpButton * _popupButton;
    NSButton * _addButton;
    NSButton * _removeButton;
    NSButton * _editButton;
    Account * _account;
    DJLColoredView * _borderView;
    NSScrollView * _scrollView;
    DJLTableView * _tableView;
    Array * _addresses;
    DJLWindow * _aliasDialog;
    NSTextField * _nameLabel;
    NSTextField * _emailLabel;
    NSTextField * _nameField;
    NSTextField * _emailField;
    NSButton * _okButton;
    NSButton * _cancelButton;
    NSTextField * _errorMessageLabel;
    int _type;
    Address * _selectedAddress;
    NSButton * _defaultCheckbox;
    NSButton * _makeDefaultButton;
    NSTextField * _placeholder;
    FBKVOController * _kvoController;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _account = NULL;
    _callback = new DJLPrefsAliasesViewControllerCallback(self);
    AccountManager::sharedManager()->addObserver(_callback);
    _addresses = new Array();
    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_selectedAddress);
    MC_SAFE_RELEASE(_addresses);
    MC_SAFE_RELEASE(_account);
    AccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (NSImage *) icon
{
    return [NSImage imageNamed:@"DejaLu_Aliases_Light_32"];
}

- (NSString *) title
{
    return @"Aliases";
}

- (CGFloat) height
{
    return 300;
}

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
    [self setView:view];

    NSView * contentView = [self view];

    NSRect frame = [contentView bounds];

    _popupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, frame.size.height - 40, 300, 30)];
    [_popupButton setTarget:self];
    [_popupButton setAction:@selector(_accountSelected)];
    [_popupButton setAutoresizingMask:NSViewMinYMargin];
    [contentView addSubview:_popupButton];

    _addButton = [[NSButton alloc] initWithFrame:NSMakeRect(frame.size.width - 40, frame.size.height - 40, 20, 30)];
    [_addButton setCell:[[DJLPrefsButtonCell alloc] init]];
    [_addButton setBezelStyle:NSRoundRectBezelStyle];
    [_addButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    //[_addButton setBordered:NO];
    NSImage * originImage = [NSImage imageNamed:@"DejaLu_Plus_12"];
//    originImage = [originImage copy];
//    [originImage setSize:NSMakeSize(12, 12)];
    NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
    //NSImage * altImg = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_addButton setImage:img];
    //[_addButton setAlternateImage:altImg];
    //[[_addButton cell] setHighlightsBy:NSContentsCellMask];
    [_addButton setTarget:self];
    [_addButton setAction:@selector(_add)];
    [contentView addSubview:_addButton];

    _removeButton = [[NSButton alloc] initWithFrame:NSMakeRect(frame.size.width - 65, frame.size.height - 40, 20, 30)];
    [_removeButton setCell:[[DJLPrefsButtonCell alloc] init]];
    [_removeButton setBezelStyle:NSRoundRectBezelStyle];
    [_removeButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    //[_removeButton setBordered:NO];
    originImage = [NSImage imageNamed:@"DejaLu_Minus_12"];
//    originImage = [originImage copy];
//    [originImage setSize:NSMakeSize(12, 12)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
    //altImg = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_removeButton setImage:img];
    //[_removeButton setAlternateImage:altImg];
    //[[_removeButton cell] setHighlightsBy:NSContentsCellMask];
    [_removeButton setTarget:self];
    [_removeButton setAction:@selector(_remove)];
    [contentView addSubview:_removeButton];

    _editButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, frame.size.height - 40, 100, 30)];
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

    frame = [contentView bounds];
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
    [_tableView setRowHeight:30];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setHeaderView:nil];
    [_tableView setTarget:self];
    [_tableView setDoubleAction:@selector(_tableViewDoubleClick)];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLFolder"];
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
    [_placeholder setAlignment:NSCenterTextAlignment];
    [_placeholder setFont:[NSFont systemFontOfSize:30]];
    [_placeholder setStringValue:@"You need to add an account before adding a label to it"];
    [_placeholder sizeToFit];
    [_placeholder setHidden:YES];
    [contentView addSubview:_placeholder];

    [self _updateView];

    _kvoController = [FBKVOController controllerWithObserver:self];
    [_kvoController observe:self keyPath:@"effectiveAppearance" options:0 block
                           :^(id observer, id object, NSDictionary *change) {
                               [self _applyDarkMode];
                           }];
    [self _applyDarkMode];
}

- (void) _applyDarkMode
{
    if ([DJLDarkMode isDarkModeForView:[self view]]) {
        [_borderView setBackgroundColor:[NSColor colorWithWhite:0.3 alpha:1.0]];
        [(DJLColoredView *)[_aliasDialog contentView] setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
    } else {
        [_borderView setBackgroundColor:[NSColor colorWithWhite:0.95 alpha:1.0]];
        [(DJLColoredView *)[_aliasDialog contentView] setBackgroundColor:[NSColor whiteColor]];
    }
}

- (void) _updateView
{
    [_popupButton removeAllItems];
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        [_popupButton addItemWithTitle:MCO_TO_OBJC(account->accountInfo()->email())];
    }
    [self _accountSelected];
}

- (void) viewDidShow
{
    [self _updateView];
}

- (void) viewDidHide
{
}

- (void) _accountSelected
{
    int selectedIndex = (int) [_popupButton indexOfSelectedItem];
    if (selectedIndex >= AccountManager::sharedManager()->accounts()->count()) {
        if (AccountManager::sharedManager()->accounts()->count() == 0) {
            selectedIndex = -1;
        }
        else {
            selectedIndex = 0;
        }
    }
    if (selectedIndex == -1) {
        [self setAccount:NULL];
    }
    else {
        Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex(selectedIndex);
        [self setAccount:account];
    }
    [self reloadData];
}

- (void) setAccount:(hermes::Account *)account
{
    int idx = AccountManager::sharedManager()->accounts()->indexOfObject(account);
    if (idx != -1) {
        if ([_popupButton indexOfSelectedItem] != idx) {
            [_popupButton selectItemAtIndex:idx];
            [self _accountSelected];
        }
    }

    if (_account != NULL) {
        _account->removeObserver(_callback);
    }
    MC_SAFE_RELEASE(_account);
    _account = account;
    MC_SAFE_RETAIN(_account);
}

- (hermes::Account *) account
{
    return _account;
}

static int compareAddresses(void * a, void * b, void * context)
{
    Address * addrA = (Address *) a;
    Address * addrB = (Address *) b;
    return addrA->mailbox()->caseInsensitiveCompare(addrB->mailbox());
}

- (void) reloadData
{
    _addresses->removeAllObjects();
    if (_account != NULL) {
        _addresses->addObject(Address::addressWithDisplayName(_account->accountInfo()->displayName(), _account->accountInfo()->email()));
        _addresses->addObjectsFromArray(_account->accountInfo()->aliases());
        _addresses->sortArray(compareAddresses, NULL);
    }
    [_tableView reloadData];

    if (AccountManager::sharedManager()->accounts()->count() == 0) {
        NSRect frame = [_scrollView frame];
        frame.size.height -= 25;
        [_placeholder setFrame:frame];
        [_placeholder setHidden:NO];
    }
    else {
        [_placeholder setHidden:YES];
    }

    [self _updateButtonStates];
}

- (void) _updateAccounts
{
    [self _updateView];
}

#define DIALOG_WIDTH 350
#define DIALOG_HEIGHT 160

- (void) _setupDialog
{
    _aliasDialog = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT) styleMask:NSTitledWindowMask | NSTexturedBackgroundWindowMask backing:NSBackingStoreBuffered defer:YES];
    [_aliasDialog setDelegate:self];
    [_aliasDialog setTrafficLightAlternatePositionEnabled:NO];
    [_aliasDialog setTitlebarAppearsTransparent:YES];
    NSView * contentView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT)];
    [_aliasDialog setContentView:contentView];
    _nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 117, DIALOG_WIDTH - 40, 22)];
    [_nameLabel setAutoresizingMask:NSViewMinYMargin];
    [_nameLabel setAlignment:NSTextAlignmentRight];
    [_nameLabel setEditable:NO];
    [_nameLabel setBezeled:NO];
    [_nameLabel setStringValue:@"Name"];
    [_nameLabel setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [_nameLabel sizeToFit];
    [contentView addSubview:_nameLabel];
    _emailLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 87, DIALOG_WIDTH - 40, 22)];
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
    _nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 10, 115, DIALOG_WIDTH - x - 20 - 10, 24)];
    [_nameField setAutoresizingMask:NSViewMinYMargin];
    [_nameField setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [contentView addSubview:_nameField];
    x = NSMaxX([_nameLabel frame]);
    _emailField = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 10, 85, DIALOG_WIDTH - x - 20 - 10, 24)];
    [_emailField setAutoresizingMask:NSViewMinYMargin];
    [_emailField setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [contentView addSubview:_emailField];

    _defaultCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(x + 10, 55, DIALOG_WIDTH - x - 20 - 10, 24)];
    [_defaultCheckbox setButtonType:NSSwitchButton];
    [_defaultCheckbox setAutoresizingMask:NSViewMinYMargin];
    NSString * title = [NSString stringWithFormat:@"Default alias for %@", MCO_TO_OBJC(_account->accountInfo()->email())];
    [_defaultCheckbox setTitle:title];
    [contentView addSubview:_defaultCheckbox];

    _makeDefaultButton = [[NSButton alloc] initWithFrame:NSMakeRect(x + 10, 55, DIALOG_WIDTH - x - 20 - 10, 25)];
    [_makeDefaultButton setBezelStyle:NSRoundRectBezelStyle];
    [_makeDefaultButton setAutoresizingMask:NSViewMinYMargin];
    [_makeDefaultButton setTitle:@"Make Default"];
    [_makeDefaultButton setTarget:self];
    [_makeDefaultButton setAction:@selector(_makeDefault)];
    [contentView addSubview:_makeDefaultButton];

    _errorMessageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, DIALOG_WIDTH - 40, 0)];
    [_errorMessageLabel setHidden:YES];
    [_errorMessageLabel setEditable:NO];
    [_errorMessageLabel setBordered:NO];
    [_errorMessageLabel setTextColor:[NSColor colorWithCalibratedRed:0.75 green:0.25 blue:0.25 alpha:1.0]];
    [contentView addSubview:_errorMessageLabel];

    _okButton = [[NSButton alloc] initWithFrame:NSMakeRect(DIALOG_WIDTH - 20 - 100, 20, 100, 25)];
    [_okButton setBezelStyle:NSRoundRectBezelStyle];
    [_okButton setTitle:@"OK"];
    [_okButton setTarget:self];
    [_okButton setKeyEquivalent:@"\r"];
    [contentView addSubview:_okButton];
    _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(DIALOG_WIDTH - 20 - 200 - 10, 20, 100, 25)];
    [_cancelButton setBezelStyle:NSRoundRectBezelStyle];
    [_cancelButton setTitle:@"Cancel"];
    [_cancelButton setTarget:self];
    [_cancelButton setAction:@selector(_cancelAddAlias)];
    [contentView addSubview:_cancelButton];

    [self _applyDarkMode];
}

- (void) _add
{
    _type = DIALOG_ADD;
    [self _setupDialog];
    [_nameField setStringValue:MCO_TO_OBJC(_account->accountInfo()->displayName())];
    [_defaultCheckbox setHidden:NO];
    [_makeDefaultButton setHidden:YES];
    [_okButton setAction:@selector(_confirmAddAlias)];
    [[[self view] window] beginSheet:_aliasDialog completionHandler:^(NSModalResponse response) {
    }];
}

- (void) _makeDefault
{
    if (_selectedAddress->mailbox()->isEqual(_account->accountInfo()->email())) {
        _account->accountInfo()->setDefaultAlias(NULL);
    }
    else {
        _account->accountInfo()->setDefaultAlias(_selectedAddress->mailbox());
    }
    _account->save();
    [_makeDefaultButton setTitle:@"This is the default alias"];
    [_makeDefaultButton setEnabled:NO];
}

- (void) _edit
{
    NSInteger row = [_tableView selectedRow];
    if (row == -1) {
        return;
    }

    Address * address = (Address *) _addresses->objectAtIndex((int) row);
    MC_SAFE_REPLACE_RETAIN(Address, _selectedAddress, address);

    _type = DIALOG_MODIFY;
    [self _setupDialog];
    [_nameField setStringValue:MCO_TO_OBJC(address->displayName())];
    [_emailField setStringValue:MCO_TO_OBJC(address->mailbox())];
    [_emailField setEditable:NO];
    [_emailField setTextColor:[NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
    [_emailField setSelectable:YES];

    [_defaultCheckbox setHidden:YES];
    [_makeDefaultButton setHidden:NO];
    BOOL isDefault = NO;
    if (_account->accountInfo()->defaultAlias() == NULL) {
        if (address->mailbox()->isEqual(_account->accountInfo()->email())) {
            isDefault = YES;
        }
    }
    else {
        if (address->mailbox()->isEqual(_account->accountInfo()->defaultAlias())) {
            isDefault = YES;
        }
    }
    if (isDefault) {
        [_makeDefaultButton setTitle:@"This is the default alias"];
        [_makeDefaultButton setEnabled:NO];
    }

    [_okButton setAction:@selector(_confirmEditAlias)];
    [[[self view] window] beginSheet:_aliasDialog completionHandler:^(NSModalResponse response) {
    }];
}

- (void) _confirmEditAlias
{
    NSString * displayName = [_nameField stringValue];
    if (_selectedAddress->mailbox()->isEqual(_account->accountInfo()->email())) {
        _account->accountInfo()->setDisplayName(MCO_FROM_OBJC(String, displayName));
        _account->save();
    }
    else {
        _addresses->removeObject(_selectedAddress);
        _addresses->sortArray(compareAddresses, NULL);
        MCOAddress * address = [MCOAddress addressWithDisplayName:[_nameField stringValue] mailbox:[_emailField stringValue]];
        _addresses->addObject(MCO_FROM_OBJC(Address, address));
        [self _save];
    }
    [self reloadData];
    MC_SAFE_RELEASE(_selectedAddress);
    [_aliasDialog orderOut:nil];
    [[[self view] window] endSheet:_aliasDialog];
}

- (void) _confirmAddAlias
{
    String * displayName =  MCO_FROM_OBJC(String, [_nameField stringValue]);
    String * email =  MCO_FROM_OBJC(String, [_emailField stringValue]);
    bool exist = false;
    mc_foreacharray(Address, address, _addresses) {
        if (email->isEqual(_account->accountInfo()->email())) {
            exist = true;
        }
        mc_foreacharray(Address, address, _account->accountInfo()->aliases()) {
            if (email->isEqual(address->mailbox())) {
                exist = true;
            }
        }
    }
    if (![(NSString *) MCO_TO_OBJC(email) djlIsValidEmail]) {
        [self _showError:@"The email address you entered is not valid. Please check that you typed it properly."];
        return;
    }
    if (email->length() == 0) {
        [self _showError:@"Please type an email address for the new alias."];
        return;
    }
    if (exist) {
        [self _showError:@"The email address you entered already exists."];
        return;
    }

    if ([_defaultCheckbox state] == NSOnState) {
        _account->accountInfo()->setDefaultAlias(email);
    }

    _addresses->addObject(Address::addressWithDisplayName(displayName, email));
    _addresses->sortArray(compareAddresses, NULL);
    [self _save];
    [_tableView reloadData];
    [_aliasDialog orderOut:nil];
    [[[self view] window] endSheet:_aliasDialog];
}

- (void) _remove
{
    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Do you really want to remove this alias?"];
    [alert setInformativeText:@"The alias will be removed from DejaLu."];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];

    __weak DJLPrefsAliasesViewController * weakSelf = self;
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
    [[_tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        Address * address = (Address *) _addresses->objectAtIndex((unsigned int) row);
        if (!address->mailbox()->isEqual(_account->accountInfo()->email())) {
            _addresses->removeObjectAtIndex((unsigned int) row);
            [_tableView reloadData];
            [self _save];
        }
    }];
}

- (void) _showError:(NSString *)errorString
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_dialogDidResize) name:NSWindowDidResizeNotification object:_aliasDialog];

    if (errorString == nil) {
        // hide error
        [_errorMessageLabel setHidden:YES];

        NSRect frame = [_aliasDialog frame];
        CGFloat delta = DIALOG_HEIGHT - frame.size.height;
        frame.origin.y -= delta;
        frame.size.height += delta;
        [_aliasDialog setFrame:frame display:YES animate:YES];
    }
    else {
        // show error
        [_errorMessageLabel setStringValue:errorString];
        [_errorMessageLabel setHidden:NO];
        NSSize size = [_errorMessageLabel sizeThatFits:NSMakeSize(260, MAXFLOAT)];

        NSRect frame = [_aliasDialog frame];
        CGFloat delta = (DIALOG_HEIGHT + size.height) - frame.size.height;
        frame.origin.y -= delta;
        frame.size.height += delta;
        [_aliasDialog setFrame:frame display:YES animate:YES];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:_aliasDialog];
}

- (void) _dialogDidResize
{
    NSSize size = [_aliasDialog frame].size;
    NSRect frame = [_errorMessageLabel frame];
    frame.size.height = size.height - DIALOG_HEIGHT;
    [_errorMessageLabel setFrame:frame];
}

- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window
{
    [self _cancelAddAlias];
    return YES;
}

- (void) _cancelAddAlias
{
    [_aliasDialog orderOut:nil];
    [[[self view] window] endSheet:_aliasDialog];
}

#pragma mark -
#pragma mark tableview delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _addresses->count();
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
    Address * address = (Address *)_addresses->objectAtIndex((int) row);
    [[view textField] setStringValue:MCO_TO_OBJC(address->nonEncodedRFC822String())];
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

- (void) _tableViewDoubleClick
{
    [self _edit];
}

- (void) _save
{
    BOOL hasDefaultAlias = NO;
    Array * aliases = Array::array();
    mc_foreacharray(Address, address, _addresses) {
        if (!address->mailbox()->isEqual(_account->accountInfo()->email())) {
            aliases->addObject(address);
            if (address->mailbox()->isEqual(_account->accountInfo()->defaultAlias())) {
                hasDefaultAlias = YES;
            }
        }
    }
    if (!hasDefaultAlias) {
        _account->accountInfo()->setDefaultAlias(NULL);
    }
    _account->accountInfo()->setAliases(aliases);
    _account->save();
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    [self _updateButtonStates];
}

- (void) _updateButtonStates
{
    if (AccountManager::sharedManager()->accounts()->count() > 0) {
        [_addButton setEnabled:YES];
    }
    else {
        [_addButton setEnabled:NO];
    }
    if ([[_tableView selectedRowIndexes] count] == 0) {
        [_editButton setEnabled:NO];
        [_removeButton setEnabled:NO];
    }
    else {
        [_editButton setEnabled:YES];
        NSInteger row = [_tableView selectedRow];
        Address * address = (Address *) _addresses->objectAtIndex((unsigned int) row);
        if (!address->mailbox()->isEqual(_account->accountInfo()->email())) {
            [_removeButton setEnabled:YES];
        }
        else {
            [_removeButton setEnabled:NO];
        }
    }
}

#pragma mark menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(_accountSelected)) {
        return YES;
    }
    return NO;
}

@end
