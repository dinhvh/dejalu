// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrefsLabelsViewController.h"

#include "Hermes.h"

#import "DJLTableView.h"
#import "DJLColoredView.h"
#import "NSImage+DJLColored.h"
#import "DJLPrefsButtonCell.h"

using namespace mailcore;
using namespace hermes;

@protocol DJLFoldersManagerTableCellViewDelegate;

@interface DJLFoldersManagerTableCellView : NSTableCellView <NSTextFieldDelegate>

@property (nonatomic, assign) id <DJLFoldersManagerTableCellViewDelegate> delegate;
@property (nonatomic, copy) NSString * folderName;

- (void) edit;

@end

@protocol DJLFoldersManagerTableCellViewDelegate <NSObject>

- (void) DJLFoldersManagerTableCellView:(DJLFoldersManagerTableCellView *)view
                                 rename:(NSString *)initialFolderName
                                 toName:(NSString *)finalFolderName;
- (void) DJLFoldersManagerTableCellView:(DJLFoldersManagerTableCellView *)view
                           createFolder:(NSString *)folderName;

@end

@implementation DJLFoldersManagerTableCellView {
    NSString * _displayName;
}

@synthesize folderName = _folderName;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    NSRect bounds = [self bounds];
    NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 5, bounds.size.width - 20, 20)];
    [textField setDrawsBackground:NO];
    [textField setBezeled:NO];
    [textField setEditable:YES];
    [textField setDelegate:self];

    [self setTextField:textField];
    [self addSubview:textField];
    return self;
}

- (void) dealloc
{
    [[self textField] setDelegate:nil];
}

- (void) setFolderName:(NSString *)folderName
{
    _folderName = folderName;
    String * displayName = MCO_FROM_OBJC(String, folderName)->mUTF7DecodedString();
    _displayName = MCO_TO_OBJC(displayName);
    [[self textField] setStringValue:_displayName];
}

- (void) edit
{
    [[self window] makeFirstResponder:[self textField]];
}

- (BOOL) isEditing
{
    return [[self window] firstResponder] == [self textField];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    if ([_displayName length] == 0) {
        if ([[[self textField] stringValue] length] == 0) {
            // cancelled
            [[self delegate] DJLFoldersManagerTableCellView:self createFolder:nil];
        }
        else {
            String * mcFolderName = MCO_FROM_OBJC(String, [[self textField] stringValue])->mUTF7EncodedString();
            [[self delegate] DJLFoldersManagerTableCellView:self createFolder:MCO_TO_OBJC(mcFolderName)];
        }
    }
    else {
        if ([_displayName isEqualToString:[[self textField] stringValue]]) {
            return;
        }
        String * mcFolderName = MCO_FROM_OBJC(String, [[self textField] stringValue])->mUTF7EncodedString();
        [[self delegate] DJLFoldersManagerTableCellView:self rename:_folderName toName:MCO_TO_OBJC(mcFolderName)];
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    if (command == @selector(cancelOperation:)) {
        if ([_displayName length] == 0) {
            [[self textField] setStringValue:@""];
            [[self window] makeFirstResponder:nil];
            return YES;
        }
        else {
            return NO;
        }
    }
    return NO;
}

@end

@interface DJLPrefsLabelsViewController () <NSTableViewDataSource, NSTableViewDelegate, DJLFoldersManagerTableCellViewDelegate>

- (void) _foldersChanged:(hermes::ErrorCode)error;
- (void) _updateAccounts;

@end

class DJLPrefsLabelsViewControllerCallback : public mailcore::Object, public AccountObserver, public AccountManagerObserver {
public:
    DJLPrefsLabelsViewControllerCallback(DJLPrefsLabelsViewController * controller)
    {
        mController = controller;
    }

    virtual void accountFoldersChanged(Account * account, hermes::ErrorCode error)
    {
        [mController _foldersChanged:error];
    }

    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mController _updateAccounts];
    }

private:
    __weak DJLPrefsLabelsViewController * mController;
};

@implementation DJLPrefsLabelsViewController {
    Account * _account;
    DJLColoredView * _borderView;
    DJLTableView * _tableView;
    NSScrollView * _scrollView;
    Array * _paths;
    DJLPrefsLabelsViewControllerCallback * _callback;
    NSPopUpButton * _popupButton;
    NSButton * _addButton;
    NSButton * _removeButton;
    NSButton * _editButton;
    NSTextField * _placeholder;
    BOOL _shouldReload;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _account = NULL;
    _callback = new DJLPrefsLabelsViewControllerCallback(self);
    AccountManager::sharedManager()->addObserver(_callback);
    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_account);
    AccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (NSImage *) icon
{
    return [NSImage imageNamed:@"DejaLu_TagOff_Light_32"];
}

- (NSString *) title
{
    return @"Labels";
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
    [_placeholder sizeToFit];
    [_placeholder setHidden:YES];
    [contentView addSubview:_placeholder];

    [self _updateView];
}

- (void) _updateView
{
    [_popupButton removeAllItems];
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        [_popupButton addItemWithTitle:MCO_TO_OBJC(account->accountInfo()->email())];
    }
    [self _accountSelected];
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
    if (_account != NULL) {
        _account->addObserver(_callback);
    }
}

- (hermes::Account *) account
{
    return _account;
}

static int compareFolders(void * a, void * b, void * context)
{
    DJLPrefsLabelsViewController * self = (__bridge DJLPrefsLabelsViewController *) context;
    (void) self;
    String * folderA = ((String *) a)->lowercaseString();
    String * folderB = ((String *) b)->lowercaseString();
    return folderA->compare(folderB);
}

- (void) reloadData
{
    MC_SAFE_RELEASE(_paths);

    _paths = new Array();
    if (_account != NULL) {
        Set * foldersSet = Set::setWithArray(_account->folders());
        foldersSet->removeObject(_account->inboxFolderPath());
        foldersSet->removeObject(_account->archiveFolderPath());
        foldersSet->removeObject(_account->allMailFolderPath());
        foldersSet->removeObject(_account->draftsFolderPath());
        foldersSet->removeObject(_account->importantFolderPath());
        foldersSet->removeObject(_account->sentFolderPath());
        foldersSet->removeObject(_account->spamFolderPath());
        foldersSet->removeObject(_account->starredFolderPath());
        foldersSet->removeObject(_account->trashFolderPath());

        Array * sortedFolders = foldersSet->allObjects()->sortedArray(compareFolders, (__bridge void *) self);
        _paths->addObjectsFromArray(sortedFolders);
    }
    [self _reloadDataWithoutUpdatingPaths];
    _shouldReload = NO;
}

- (void) _reloadDataWithoutUpdatingPaths
{
    [_tableView reloadData];

    if (AccountManager::sharedManager()->accounts()->count() == 0) {
        NSRect frame = [_scrollView frame];
        frame.size.height -= 25;
        [_placeholder setFrame:frame];
        [_placeholder setHidden:NO];
        [_placeholder setStringValue:@"You need to add an account before adding a label to it"];
    }
    else if (_paths->count() == 0) {
        NSRect frame = [_scrollView frame];
        frame.size.height -= 25;
        [_placeholder setFrame:frame];
        [_placeholder setHidden:NO];
        [_placeholder setStringValue:@"Click on + to create a label"];
    }
    else {
        [_placeholder setHidden:YES];
    }

    [self _updateButtonStates];
}

- (void) _foldersChanged:(hermes::ErrorCode)error
{
    if ([_tableView selectedRow] != -1) {
        DJLFoldersManagerTableCellView * cell = [_tableView viewAtColumn:0 row:[_tableView selectedRow] makeIfNecessary:YES];
        if ([cell isEditing]) {
            _shouldReload = YES;
            return;
        }
    }

    String * lastSelectedPath = NULL;

    if ([_tableView selectedRow] != -1) {
        String * path = (String *) _paths->objectAtIndex((unsigned int) [_tableView selectedRow]);
        lastSelectedPath = (String *) path->retain()->autorelease();
    }

    [self reloadData];

    if (lastSelectedPath != NULL) {
        NSUInteger idx =  _paths->indexOfObject(lastSelectedPath);
        if (idx != NSNotFound) {
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
            [_tableView scrollRowToVisible:idx];
        }
    }
}

#pragma mark -
#pragma mark tableview delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (_paths == NULL) {
        return 0;
    }
    return _paths->count();
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    DJLFoldersManagerTableCellView * view = [[DJLFoldersManagerTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 460, 30)];
    [view setDelegate:self];
    String * folderPath = (String *) _paths->objectAtIndex((int) row);
    [view setFolderName:MCO_TO_OBJC(folderPath)];
    return view;
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
        [_removeButton setEnabled:YES];
    }
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

- (void) DJLFoldersManagerTableCellView:(DJLFoldersManagerTableCellView *)view
                                 rename:(NSString *)initialFolderName
                                 toName:(NSString *)finalFolderName
{
    String * mcInitialFolderName = MCO_FROM_OBJC(String, initialFolderName);
    String * finalPath = MCO_FROM_OBJC(String, finalFolderName);
    _paths->replaceObject((unsigned int) [_tableView selectedRow], finalPath);
    _account->renameFolder(mcInitialFolderName, finalPath);
    [self _reloadDataWithoutUpdatingPaths];
    if (_shouldReload) {
        [self reloadData];
    }
}

- (void) _add
{
    _paths->addObject(MCSTR(""));
    [_tableView reloadData];
    [_placeholder setHidden:YES];
    [_tableView scrollRowToVisible:_paths->count() - 1];
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_paths->count() - 1] byExtendingSelection:NO];
    DJLFoldersManagerTableCellView * cell = [_tableView viewAtColumn:0 row:_paths->count() - 1 makeIfNecessary:YES];
    [cell edit];
}

- (void) _remove
{
    NSUInteger row = [[_tableView selectedRowIndexes] firstIndex];
    if (row != NSNotFound) {
        return;
    }

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Do you really want to remove this label?"];
    [alert setInformativeText:@"The label will be removed from the account."];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];

    __weak DJLPrefsLabelsViewController * weakSelf = self;
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
    NSUInteger row = [[_tableView selectedRowIndexes] firstIndex];
    if (row != NSNotFound) {
        return;
    }
    NSString * path = MCO_TO_OBJC(_paths->objectAtIndex((unsigned int) row));
    _account->deleteFolder(MCO_FROM_OBJC(String, path));
    _paths->removeObjectAtIndex((unsigned int) row);
    [self _reloadDataWithoutUpdatingPaths];
    if (_shouldReload) {
        [self reloadData];
    }
}

- (void) _edit
{
    NSInteger row = [_tableView selectedRow];
    if (row == -1) {
        return;
    }

    DJLFoldersManagerTableCellView * cell = [_tableView viewAtColumn:0 row:row makeIfNecessary:YES];
    [cell edit];
}

- (void) DJLFoldersManagerTableCellView:(DJLFoldersManagerTableCellView *)view
                           createFolder:(NSString *)folderName
{
    if (folderName == nil) {
        _paths->removeLastObject();
        [self _reloadDataWithoutUpdatingPaths];
        return;
    }
    _paths->removeLastObject();
    String * path = MCO_FROM_OBJC(String, folderName);
    _paths->addObject(path);
    _account->createFolder(path);
    [self _reloadDataWithoutUpdatingPaths];
    if (_shouldReload) {
        [self reloadData];
    }
}

- (void) _updateAccounts
{
    [self _updateView];
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
