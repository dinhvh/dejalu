// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFoldersViewController.h"

#import "DJLTableView.h"
#import "DJLColoredView.h"
#import "NSImage+DJLColored.h"
#import "DJLFolderPaneAccountInfo.h"
#import "DJLFolderPaneFolderInfo.h"
#import "DJLFolderPaneFoldersDisclosureInfo.h"

#include "Hermes.h"

using namespace mailcore;
using namespace hermes;

typedef enum DJLFoldersTableCellViewMode {
    DJLFoldersTableCellViewModeLabel,
    DJLFoldersTableCellViewModeBack,
    DJLFoldersTableCellViewModeAccount,
} DJLFoldersTableCellViewMode;

@interface DJLFoldersTableCellView : NSTableCellView

@property (nonatomic, assign) int count;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy) NSString * folderName;
@property (nonatomic, assign) int margin;
@property (nonatomic, assign) DJLFoldersTableCellViewMode mode;
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, assign) NSInteger rightButtonTag;

@end

@implementation DJLFoldersTableCellView {
    NSButton * _rightButton;
    NSImageView * _backImage;
    NSTextField * _countLabel;
}

static NSMutableDictionary * s_images = nil;

+ (void) initialize
{
    s_images = [[NSMutableDictionary alloc] init];
    [self setupImage:@"DejaLu_Settings_16"];
    [self setupImage:@"DejaLu_ArrowLeft_12"];
    [self setupImage:@"DejaLu_ArrowRightButton_16"];
}

+ (void) setupImage:(NSString *)imageName
{
    NSImage * originImage = [NSImage imageNamed:imageName];
    NSImage * image = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
    NSImage * pressedImage = [originImage djl_imageWithColor:[NSColor blackColor]];
    NSImage * selectedImage = [originImage djl_imageWithColor:[NSColor whiteColor]];
    NSImage * selectedPressedImage = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.6]];
    s_images[imageName] = @{@"normal": image, @"pressed": pressedImage,
                            @"selected": selectedImage, @"pressed-selected": selectedPressedImage};
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    NSRect bounds = [self bounds];
    _enabled = YES;
    _rightButton = [[NSButton alloc] initWithFrame:NSMakeRect(bounds.size.width - 25, 7, 20, 20)];
    [[_rightButton cell] setHighlightsBy:NSContentsCellMask];
    [_rightButton setBordered:NO];
    NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 0, bounds.size.width - 10, 25)];
    [textField setDrawsBackground:NO];
    [textField setBezeled:NO];
    [textField setEditable:NO];
    _countLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 9, 0, 25)];
    [_countLabel setDrawsBackground:NO];
    [_countLabel setBezeled:NO];
    [_countLabel setEditable:NO];
    [self setTextField:textField];
    _backImage = [[NSImageView alloc] initWithFrame:NSMakeRect(5, 5, 20, 20)];
    [self addSubview:_backImage];
    [self addSubview:textField];
    [self addSubview:_rightButton];
    [self addSubview:_countLabel];
    return self;
}

- (void) setMode:(DJLFoldersTableCellViewMode)mode
{
    _mode = mode;
    [self _update];
}

- (void) setFolderName:(NSString *)folderName
{
    _folderName = folderName;
    [self _update];
}

- (void) setMargin:(int)margin
{
    _margin = margin;
    [self _update];
}

- (void) setCount:(int)count
{
    _count = count;
    [self _update];
}

- (void) setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    [self _update];
}

- (void) _update
{
    if (_folderName == nil) {
        [[self textField] setStringValue:@""];
    }
    else {
        [[self textField] setTextColor:_enabled ? [NSColor blackColor] : [NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
        [[self textField] setStringValue:_folderName];
    }

    if (_mode == DJLFoldersTableCellViewModeLabel || _mode == DJLFoldersTableCellViewModeAccount) {
        if (_count == 0) {
            [_countLabel setHidden:YES];
        }
        else {
            [_countLabel setStringValue:[NSString stringWithFormat:@"%i", _count]];
            [_countLabel setHidden:NO];
            [_countLabel sizeToFit];
        }
    }
    else {
        [_countLabel setHidden:YES];
    }

    NSString * name;
    NSRect bounds = [self bounds];
    switch (_mode) {
        case DJLFoldersTableCellViewModeLabel:
            [_rightButton setHidden:YES];
            [_backImage setHidden:YES];
            if ([_countLabel isHidden]) {
                [[self textField] setFrame:NSMakeRect(5 + _margin * 10, 0, bounds.size.width - 10 - _margin * 10, 25)];
            }
            else {
                NSRect frame = [_countLabel frame];
                frame.origin.x = bounds.size.width - 5 - [_countLabel frame].size.width;
                [_countLabel setFrame:frame];
                [[self textField] setFrame:NSMakeRect(5 + _margin * 10, 0, [_countLabel frame].origin.x - 10 - _margin * 10, 25)];
            }
            break;
        case DJLFoldersTableCellViewModeAccount:
            [_rightButton setHidden:NO];
            [_rightButton setFrame:NSMakeRect(bounds.size.width - 25, 6, 20, 20)];
            name = @"DejaLu_ArrowRightButton_16";
            if ([self backgroundStyle] == NSBackgroundStyleDark) {
                [_rightButton setImage:s_images[name][@"selected"]];
                [_rightButton setAlternateImage:s_images[name][@"pressed-selected"]];
            }
            else {
                [_rightButton setImage:s_images[name][@"normal"]];
                [_rightButton setAlternateImage:s_images[name][@"pressed"]];
            }
            [_backImage setHidden:YES];
            if ([_countLabel isHidden]) {
                [[self textField] setFrame:NSMakeRect(5, 0, bounds.size.width - 30, 25)];
            }
            else {
                NSRect frame = [_countLabel frame];
                frame.origin.x = bounds.size.width - [_countLabel frame].size.width - 25;
                [_countLabel setFrame:frame];
                [[self textField] setFrame:NSMakeRect(5, 0, [_countLabel frame].origin.x - 10, 25)];
            }
            break;
        case DJLFoldersTableCellViewModeBack:
            name = @"DejaLu_ArrowLeft_12";
            if ([self backgroundStyle] == NSBackgroundStyleDark) {
                [_backImage setImage:s_images[name][@"selected"]];
            }
            else {
                [_backImage setImage:s_images[name][@"normal"]];
            }
            [_countLabel setHidden:YES];
            [_backImage setHidden:NO];
            [_rightButton setHidden:NO];
            [_rightButton setFrame:NSMakeRect(bounds.size.width - 25, 6, 20, 20)];
            name = @"DejaLu_Settings_16";
            if ([self backgroundStyle] == NSBackgroundStyleDark) {
                [_rightButton setImage:s_images[name][@"selected"]];
                [_rightButton setAlternateImage:s_images[name][@"pressed-selected"]];
            }
            else {
                [_rightButton setImage:s_images[name][@"normal"]];
                [_rightButton setAlternateImage:s_images[name][@"pressed"]];
            }
            [[self textField] setFrame:NSMakeRect(30, 0, bounds.size.width - 55, 25)];
            break;
    }
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    [super setBackgroundStyle:style];
    [self _update];
}

- (void) setTarget:(id)target
{
    [_rightButton setTarget:target];
}

- (id) target
{
    return [_rightButton target];
}

- (void) setAction:(SEL)action
{
    [_rightButton setAction:action];
}

- (SEL) action
{
    return [_rightButton action];
}

- (void) setRightButtonTag:(NSInteger)tag
{
    [_rightButton setTag:tag];
}

- (NSInteger) rightButtonTag
{
    return [_rightButton tag];
}

@end

enum {
    CELL_TYPE_BACK,
    CELL_TYPE_SEPARATOR,
    CELL_TYPE_FOLDER,
};

@interface DJLFoldersCellInfo : NSObject {
}

@property (nonatomic, assign) int cellType;
@property (nonatomic, assign) int level;
@property (nonatomic, retain) DJLFolderPaneFolderInfo * info;

@end

@implementation DJLFoldersCellInfo

@end

@interface DJLFoldersViewController () <NSTableViewDataSource, NSTableViewDelegate>

@end

@implementation DJLFoldersViewController {
    NSScrollView * _foldersScrollView;
    DJLTableView * _foldersTableView;
    NSScrollView * _mainScrollView;
    DJLTableView * _mainTableView;
    Array * _mainFolders;
    IndexSet * _separatorIndexes;
    BOOL _reflectingSelectedPath;
    BOOL _filterAttachment;
    UnifiedAccount * _selectedAccount;
    NSString * _selectedPath;
    DJLFolderPaneAccountInfo * _accountInfo;
    NSMutableArray * _foldersCellsInfos;
}

@synthesize filterAttachment = _filterAttachment;

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    MC_SAFE_RELEASE(_mainFolders);
    MC_SAFE_RELEASE(_selectedAccount);
    MC_SAFE_RELEASE(_separatorIndexes);
}

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [self setView:view];

    NSRect frame = [[self view] bounds];
    _foldersScrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_foldersScrollView setWantsLayer:YES];
    //[_foldersScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_foldersScrollView setHasVerticalScroller:YES];
    [_foldersScrollView setDrawsBackground:NO];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    _foldersTableView = [[DJLTableView alloc] initWithFrame:frame];
    [_foldersTableView setDataSource:self];
    [_foldersTableView setDelegate:self];
    [_foldersTableView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_foldersTableView setHeaderView:nil];
    [_foldersTableView setRowHeight:80];
    [_foldersTableView setBackgroundColor:[NSColor clearColor]];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLFolder"];
    frame = [[self view] bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_foldersTableView addTableColumn:column];
    [_foldersScrollView setDocumentView:_foldersTableView];
    [[self view] addSubview:_foldersScrollView];

    frame = [[self view] bounds];
    _mainScrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_mainScrollView setWantsLayer:YES];
    //[_mainScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_mainScrollView setHasVerticalScroller:YES];
    [_mainScrollView setDrawsBackground:NO];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    _mainTableView = [[DJLTableView alloc] initWithFrame:frame];
    [_mainTableView setDataSource:self];
    [_mainTableView setDelegate:self];
    [_mainTableView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_mainTableView setHeaderView:nil];
    [_mainTableView setRowHeight:80];
    [_mainTableView setBackgroundColor:[NSColor clearColor]];
    column = [[NSTableColumn alloc] initWithIdentifier:@"DJLFolder"];
    frame = [[self view] bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_mainTableView addTableColumn:column];
    [_mainScrollView setDocumentView:_mainTableView];
    [[self view] addSubview:_mainScrollView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
}

- (void) _scrollerStyleChanged
{
    [_foldersScrollView setScrollerStyle:NSScrollerStyleOverlay];
    [_mainScrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (void)viewDidLayout
{
    NSRect frame = [[self view] bounds];

    if (_selectedAccount == NULL) {
        [_mainScrollView setFrame:frame];
        frame.origin.x += frame.size.width;
        [_foldersScrollView setFrame:frame];
    }
    else {
        [_foldersScrollView setFrame:frame];
        frame.origin.x -= frame.size.width;
        [_mainScrollView setFrame:frame];
    }
}

- (void) reloadData
{
    [self _updateAccounts];
    [self _updateFolders];
}

- (void) prepareSize
{
    [[self delegate] DJLFoldersViewController:self hasHeight:[[_mainScrollView documentView] frame].size.height];
}

- (void) _updateAccounts
{
    MC_SAFE_RELEASE(_mainFolders);
    _mainFolders = new Array();
    _mainFolders->addObject(MCSTR("All Inboxes"));
    _mainFolders->addObject(MCSTR("Starred"));
    _mainFolders->addObject(MCSTR("Sent"));
    _mainFolders->addObject(MCSTR("Drafts"));
    _mainFolders->addObject(MCSTR("All Mail"));
    [_mainTableView reloadData];
}

- (void) _flattenFoldersInfos
{
    _foldersCellsInfos = [[NSMutableArray alloc] init];

    DJLFoldersCellInfo * backInfo = [[DJLFoldersCellInfo alloc] init];
    [backInfo setCellType:CELL_TYPE_BACK];
    [_foldersCellsInfos addObject:backInfo];

    DJLFoldersCellInfo * separatorInfo = [[DJLFoldersCellInfo alloc] init];
    [separatorInfo setCellType:CELL_TYPE_SEPARATOR];
    [_foldersCellsInfos addObject:separatorInfo];

    [self _addRecursiveFoldersInfos:[_accountInfo favoritesRootInfo] level:0];

    [_foldersCellsInfos addObject:separatorInfo];

    [self _addRecursiveFoldersInfos:[_accountInfo foldersRootInfo] level:0];
}

- (void) _addRecursiveFoldersInfos:(DJLFolderPaneFolderInfo *)info level:(int)level
{
    if ([info parent] != nil) {
        DJLFoldersCellInfo * cellInfo = [[DJLFoldersCellInfo alloc] init];
        [cellInfo setCellType:CELL_TYPE_FOLDER];
        [cellInfo setLevel:level];
        [cellInfo setInfo:info];
        [_foldersCellsInfos addObject:cellInfo];
    }
    for(DJLFolderPaneFolderInfo * child in [info children]) {
        [self _addRecursiveFoldersInfos:child level:level + 1];
    }
}

- (void) _updateFolders
{
    if (_selectedAccount == NULL) {
        _accountInfo = nil;
        [_foldersTableView reloadData];
        return;
    }

    _accountInfo = [[DJLFolderPaneAccountInfo alloc] init];
    [_accountInfo addAccount:_selectedAccount favoriteAllSpecialFolders:YES singleAccount:YES];

    [self _flattenFoldersInfos];
    [_foldersTableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == _mainTableView) {
        if (_mainFolders == NULL) {
            return 0;
        }
        return _mainFolders->count() + 1 + UnifiedAccountManager::sharedManager()->accounts()->count();
    }
    else if (tableView == _foldersTableView) {
        /*
        if (_folders == NULL) {
            return 0;
        }
        return 1 + _folders->count();
         */
        return [_foldersCellsInfos count];
    }
    else {
        return 0;
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if (tableView == _mainTableView) {
        if (row < _mainFolders->count()) {
            // main folders
            return 30;
        }
        else if (row == _mainFolders->count()) {
            // line
            return 1;
        }
        else {
            // accounts
            return 30;
        }
    }
    else if (tableView == _foldersTableView) {
        DJLFoldersCellInfo * info = _foldersCellsInfos[row];
        switch ([info cellType]) {
            case CELL_TYPE_BACK:
                return 30;
            case CELL_TYPE_SEPARATOR:
                return 1;
            case CELL_TYPE_FOLDER:
                return 30;
            default:
                MCAssert(0);
                return 0;
        }
    }
    else {
        return 0;
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
    if (tableView == _mainTableView) {
        if (rowIndex == _mainFolders->count()) {
            return NO;
        }
        else if (rowIndex >= (_mainFolders->count() + 1)) {
            return YES;
        }
        else {
            NSString * path = [self _mainFolderNameForIndex:rowIndex];
            return (path != nil);
        }
    }
    else if (tableView == _foldersTableView) {
        DJLFoldersCellInfo * info = _foldersCellsInfos[rowIndex];
        switch ([info cellType]) {
            case CELL_TYPE_BACK:
                return YES;
            case CELL_TYPE_SEPARATOR:
                return NO;
            case CELL_TYPE_FOLDER:
                return ([[info info] folderPath] != nil);
            default:
                MCAssert(0);
                return 0;
        }
    }
    else {
        return NO;
    }
}

#define WIDTH 300

- (NSString *) _mainFolderNameForIndex:(NSInteger)row
{
    String * path = NULL;
    UnifiedAccount * account = UnifiedAccountManager::sharedManager()->unifiedAccount();
    if (account == NULL) {
        return nil;
    }
    switch (row) {
        case 0:
            path = account->inboxFolderPath();
            break;
        case 1:
            path = account->starredFolderPath();
            break;
        case 2:
            path = account->sentFolderPath();
            break;
        case 3:
            path = account->draftsFolderPath();
            break;
        case 4:
            path = account->allMailFolderPath();
            break;
    }
    return MCO_TO_OBJC(path);
}

- (int64_t) _mainFolderIDForIndex:(NSInteger)row
{
    NSString * path = [self _mainFolderNameForIndex:row];
    UnifiedAccount * account = UnifiedAccountManager::sharedManager()->unifiedAccount();
    if (account == NULL) {
        return -1;
    }
    return account->folderIDForPath([path mco_mcString]);
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (tableView == _mainTableView) {
        if (row < _mainFolders->count()) {
            // main folders
            NSRect frame = NSMakeRect(0, 0, WIDTH, 30);
            DJLFoldersTableCellView * cell = [[DJLFoldersTableCellView alloc] initWithFrame:frame];
            UnifiedAccount * account = UnifiedAccountManager::sharedManager()->unifiedAccount();
            int count = 0;
            int64_t folderID = [self _mainFolderIDForIndex:row];
            if (account != NULL) {
                switch (row) {
                    case 0:
                        // inbox: unread
                        count = account->unreadCountForFolderID(folderID);
                        break;
                    case 1:
                        // starred: count
                        count = account->countForFolderID(folderID);
                        break;
                    case 2:
                        // sent: 0
                        break;
                    case 3:
                        // drafts: count
                        count = account->countForFolderID(folderID);
                        break;
                    case 4:
                        // allmail: 0
                        break;
                }
            }
            [cell setCount:count];
            [cell setFolderName:MCO_TO_OBJC(_mainFolders->objectAtIndex((unsigned int) row))];
            NSString * path = [self _mainFolderNameForIndex:row];
            [cell setEnabled:(path != nil)];
            [cell setMode:DJLFoldersTableCellViewModeLabel];
            return cell;
        }
        else if (row == _mainFolders->count()) {
            // line
            NSRect frame = NSMakeRect(0, 0, WIDTH, 5);
            NSTableCellView * cell = [[NSTableCellView alloc] initWithFrame:frame];
            DJLColoredView * view = [[DJLColoredView alloc] initWithFrame:NSMakeRect(5, 0, WIDTH - 10, 1)];
            [view setBackgroundColor:[NSColor colorWithWhite:0.85 alpha:1.0]];
            [cell addSubview:view];
            return cell;
        }
        else {
            // accounts
            NSRect frame = NSMakeRect(0, 0, WIDTH, 30);
            DJLFoldersTableCellView * cell = [[DJLFoldersTableCellView alloc] initWithFrame:frame];
            int accountIndex = (unsigned int) row - (_mainFolders->count() + 1);
            UnifiedAccount * account = (UnifiedAccount *) UnifiedAccountManager::sharedManager()->accounts()->objectAtIndex(accountIndex);
            Account * singleAccount = (Account *) account->accounts()->objectAtIndex(0);
            [cell setCount:singleAccount->unreadCountForFolderID(singleAccount->folderIDForPath(singleAccount->inboxFolderPath()))];
            [cell setRightButtonTag:accountIndex];
            [cell setTarget:self];
            [cell setAction:@selector(_showLabels:)];
            [cell setFolderName:MCO_TO_OBJC(singleAccount->accountInfo()->email())];
            [cell setMode:DJLFoldersTableCellViewModeAccount];
            return cell;
        }
    }
    else if (tableView == _foldersTableView) {
        DJLFoldersCellInfo * info = _foldersCellsInfos[row];
        switch ([info cellType]) {
            case CELL_TYPE_BACK:
            {
                NSRect frame = NSMakeRect(0, 0, WIDTH, 30);
                DJLFoldersTableCellView * cell = [[DJLFoldersTableCellView alloc] initWithFrame:frame];
                Account * singleAccount = (Account *) _selectedAccount->accounts()->objectAtIndex(0);
                NSString * backTitle = MCO_TO_OBJC(singleAccount->accountInfo()->email());
                [cell setFolderName:backTitle];
                [cell setTarget:self];
                [cell setAction:@selector(_settings)];
                [cell setMode:DJLFoldersTableCellViewModeBack];
                return cell;
            }
            case CELL_TYPE_SEPARATOR:
            {
                NSRect frame = NSMakeRect(0, 0, WIDTH, 5);
                NSTableCellView * cell = [[NSTableCellView alloc] initWithFrame:frame];
                DJLColoredView * view = [[DJLColoredView alloc] initWithFrame:NSMakeRect(5, 0, WIDTH - 10, 1)];
                [view setBackgroundColor:[NSColor colorWithWhite:0.85 alpha:1.0]];
                [cell addSubview:view];
                return cell;
            }
            case CELL_TYPE_FOLDER:
            {
                NSRect frame = NSMakeRect(0, 0, WIDTH, 30);
                DJLFoldersTableCellView * cell = [[DJLFoldersTableCellView alloc] initWithFrame:frame];
                [cell setCount:[[info info] count]];
                [cell setEnabled:[[info info] folderPath] != nil];
                [cell setFolderName:[[info info] displayName]];
                [cell setMode:DJLFoldersTableCellViewModeLabel];
                [cell setMargin:[info level] - 1];
                return cell;
            }
            default:
                MCAssert(0);
                return nil;
        }
    }
    else {
        return nil;
    }
}



- (BOOL) djl_tableView:(NSTableView *)tableView keyPress:(NSEvent *)event
{
    if ([event keyCode] == 36) {
        [self _confirmSelection:tableView useKeyboard:YES];
        return YES;
    }
    return NO;
}

- (void) djl_tableView:(NSTableView *)tableView didClickedRow:(NSInteger)row
{
    [self _confirmSelection:tableView useKeyboard:NO];
}

- (void) _confirmSelection:(NSTableView *)tableView useKeyboard:(BOOL)useKeyboard
{
    if (tableView == _mainTableView) {
        NSUInteger selectedIndex = [[tableView selectedRowIndexes] firstIndex];
        UnifiedAccount * account = NULL;
        if (selectedIndex != NSNotFound) {
            if (selectedIndex >= (_mainFolders->count() + 1)) {
                account = (UnifiedAccount *) UnifiedAccountManager::sharedManager()->accounts()->objectAtIndex((int) selectedIndex - (_mainFolders->count() + 1));
                MC_SAFE_REPLACE_RETAIN(UnifiedAccount, _selectedAccount, account);
                _selectedPath = @"INBOX";
                [[self delegate] DJLFoldersViewControllerPathSelected:self];
            }
            else {
                account = (UnifiedAccount *) UnifiedAccountManager::sharedManager()->unifiedAccount();
                NSString * path = [self _mainFolderNameForIndex:selectedIndex];
                MC_SAFE_REPLACE_RETAIN(UnifiedAccount, _selectedAccount, account);
                _selectedPath = path;
                [[self delegate] DJLFoldersViewControllerPathSelected:self];
            }
        }
    }
    else if (tableView == _foldersTableView) {
        if (_reflectingSelectedPath) {
            return;
        }
        NSUInteger selectedIndex = [[tableView selectedRowIndexes] firstIndex];
        if (selectedIndex == NSNotFound) {
            // Do nothing.
        }
        else {
            DJLFoldersCellInfo * info = _foldersCellsInfos[selectedIndex];
            switch ([info cellType]) {
                case CELL_TYPE_BACK:
                {
                    MC_SAFE_RELEASE(_selectedAccount);
                    [NSAnimationContext beginGrouping];
                    [[NSAnimationContext currentContext] setCompletionHandler:^{
                        [self makeFirstResponder];
                    }];
                    [[NSAnimationContext currentContext] setDuration:0.25];
                    NSRect frame = [_mainScrollView frame];
                    frame.origin.x += frame.size.width;
                    [[_mainScrollView animator] setFrame:frame];
                    frame = [_foldersScrollView frame];
                    frame.origin.x += frame.size.width;
                    [[_foldersScrollView animator] setFrame:frame];
                    [NSAnimationContext endGrouping];
                    break;
                }
                case CELL_TYPE_SEPARATOR:
                    break;
                case CELL_TYPE_FOLDER:
                    _selectedPath = [[info info] folderPath];
                    [[self delegate] DJLFoldersViewControllerPathSelected:self];
                    break;
                default:
                    MCAssert(0);
                    break;
            }
        }
    }
}

#if 0
- (void) setSelectedPath:(NSString *)selectedPath
{
    String * path = MCO_FROM_OBJC(String, selectedPath);
    int selectedIndex = -1;
    mc_foreacharrayIndex(idx, String, currentPath, _paths) {
        if (currentPath->isEqual(path)) {
            selectedIndex = idx;
        }
    }
    _reflectingSelectedPath = YES;
    if (selectedIndex == -1) {
        [_foldersTableView deselectAll:nil];
    }
    else {
        [_foldersTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
    }
    _reflectingSelectedPath = NO;
    [_foldersTableView scrollRowToVisible:selectedIndex];
}
#endif

- (NSString *) selectedPath
{
    return _selectedPath;
}

- (hermes::UnifiedAccount *) selectedAccount
{
    return _selectedAccount;
}

- (void) setSelectedAccount:(hermes::UnifiedAccount *)selectedAccount
{
    MC_SAFE_REPLACE_RETAIN(hermes::UnifiedAccount, _selectedAccount, selectedAccount);
}

- (void) _settings
{
    Account * singleAccount = (Account *) _selectedAccount->accounts()->objectAtIndex(0);
    [[self delegate] DJLFoldersViewController:self openManager:singleAccount];
}

- (void) _showLabels:(id)sender
{
    NSButton * button = sender;

    int selectedIndex = (int) [button tag];
    UnifiedAccount * account = NULL;
    account = (UnifiedAccount *) UnifiedAccountManager::sharedManager()->accounts()->objectAtIndex(selectedIndex);

    MC_SAFE_REPLACE_RETAIN(UnifiedAccount, _selectedAccount, account);
    [self _updateFolders];

    [_mainTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [self makeFirstResponder];
        [_foldersScrollView flashScrollers];
    }];
    [[NSAnimationContext currentContext] setDuration:0.25];
    NSRect frame = [_mainScrollView frame];
    frame.origin.x -= frame.size.width;
    [[_mainScrollView animator] setFrame:frame];
    frame = [_foldersScrollView frame];
    frame.origin.x -= frame.size.width;
    [[_foldersScrollView animator] setFrame:frame];
    [NSAnimationContext endGrouping];
}

- (void) makeFirstResponder
{
    //[self prepareSize];
    if (_selectedAccount == NULL) {
        [[_mainTableView window] makeFirstResponder:_mainTableView];
    }
    else {
        [[_foldersTableView window] makeFirstResponder:_foldersTableView];
    }
}

@end
