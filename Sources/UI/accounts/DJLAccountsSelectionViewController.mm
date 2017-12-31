// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAccountsSelectionViewController.h"

#import "DJLTableView.h"
#import "NSString+DJL.h"

using namespace hermes;
using namespace mailcore;

@interface DJLAccountTableCellView : NSTableCellView

@property (nonatomic, copy) NSString * email;

@end

@implementation DJLAccountTableCellView {
}

@synthesize email = _email;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    NSRect bounds = [self bounds];
    NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 0, bounds.size.width - 10, 25)];
    [textField setDrawsBackground:NO];
    [textField setBezeled:NO];
    [textField setEditable:NO];

    [self setTextField:textField];
    [self addSubview:textField];
    return self;
}

- (void) setEmail:(NSString *)folderName
{
    _email = folderName;
    [self _update];
}

- (void) _update
{
    if (_email == nil) {
        [[self textField] setStringValue:@""];
    }
    else {
        [[self textField] setStringValue:_email];
    }
}

@end

@interface DJLAccountsSelectionViewController () <NSTableViewDataSource, NSTableViewDelegate>

@end

@implementation DJLAccountsSelectionViewController {
    NSScrollView * _mainScrollView;
    DJLTableView * _mainTableView;
    Array * _accounts;
    NSMutableArray * _aliases;
    NSMutableArray * _shortDisplayNames;
}

@synthesize delegate = _delegate;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    _aliases = [[NSMutableArray alloc] init];
    _shortDisplayNames = [[NSMutableArray alloc] init];
    _accounts = new Array();

    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_accounts);
}

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [self setView:view];

    NSRect frame = [[self view] bounds];
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
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLAccount"];
    frame = [[self view] bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_mainTableView addTableColumn:column];
    [_mainScrollView setDocumentView:_mainTableView];
    [[self view] addSubview:_mainScrollView];
}

- (void)viewDidLayout
{
    NSRect frame = [[self view] bounds];
    [_mainScrollView setFrame:frame];
}

- (void) reloadData
{
    [_shortDisplayNames removeAllObjects];
    [_aliases removeAllObjects];
    _accounts->removeAllObjects();
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {

        NSMutableArray * emails = [[NSMutableArray alloc] init];
        [emails addObject:MCO_TO_OBJC(account->accountInfo()->email())];
        mc_foreacharray(Address, address, account->accountInfo()->aliases()) {
            [emails addObject:MCO_TO_OBJC(address->mailbox())];
        }
        [emails sortedArrayUsingSelector:@selector(compare:)];

        for(NSString * email in emails) {
            [_aliases addObject:email];
            _accounts->addObject(account);
        }
        
    }

    [self _computeShortDisplayNames];

    [_mainTableView reloadData];
}

- (void) _computeShortDisplayNames
{
    for(NSString * email in _aliases) {
        [_shortDisplayNames addObject:[email djlShortEmailDisplayNameWithAllEmails:_aliases]];
    }
}

- (void) makeFirstResponder
{
    [[_mainTableView window] makeFirstResponder:_mainTableView];
}

- (void) prepareSize
{
    [[self delegate] DJLAccountsSelectionViewController:self hasHeight:[[_mainScrollView documentView] frame].size.height];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _accounts->count();
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 30;
}

#define WIDTH 300

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSRect frame = NSMakeRect(0, 0, WIDTH, 30);
    DJLAccountTableCellView * cell = [[DJLAccountTableCellView alloc] initWithFrame:frame];
    //Account * account = (Account *) _accounts->objectAtIndex((int) row);
    [cell setEmail:_shortDisplayNames[row]];
    return cell;
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
    NSInteger row = [_mainTableView selectedRow];
    if (row == -1) {
        return;
    }
    Account * account = (Account *) _accounts->objectAtIndex((int) row);
    [[self delegate] DJLAccountsSelectionViewController:self accountSelected:account emailAlias:[_aliases objectAtIndex:row]];
}

@end
