// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLLabelsViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "DJLTableView.h"
#import "DJLColoredView.h"
#import "NSImage+DJLColored.h"
#import "DJLDarkMode.h"

using namespace mailcore;
using namespace hermes;

@interface DJLLabelsTableCellView : NSTableCellView

@property (nonatomic, assign, getter=state) NSCellStateValue state;
@property (nonatomic, copy) NSString * folderName;

@end

@implementation DJLLabelsTableCellView

@synthesize state = _state;
@synthesize folderName = _folderName;

static NSMutableDictionary * s_images = nil;

+ (void) initialize
{
    s_images = [[NSMutableDictionary alloc] init];
    [self setupImage:@"DejaLu_CheckmarkOn_12"];
    [self setupImage:@"DejaLu_Minus_12"];
}

+ (void) setupImage:(NSString *)imageName
{
    NSImage * originImage = [NSImage imageNamed:imageName];

    NSImage * image = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
    NSImage * selectedImage = [originImage djl_imageWithColor:[NSColor whiteColor]];
    NSImage * darkImage = [originImage djl_imageWithColor:[NSColor whiteColor]];
    NSImage * darkSelectedImage = [originImage djl_imageWithColor:[NSColor whiteColor]];

    s_images[imageName] = @{
                            @"normal": image,
                            @"selected": selectedImage,
                            @"dark-normal": darkImage,
                            @"dark-selected": darkSelectedImage,
                            };
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    NSRect bounds = [self bounds];
    NSImageView * imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(5, 9, 15, 15)];
    NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(25, 0, bounds.size.width - 30, 25)];
    [textField setDrawsBackground:NO];
    [textField setBezeled:NO];
    [textField setEditable:NO];
    [self setImageView:imageView];
    [self setTextField:textField];
    [self addSubview:imageView];
    [self addSubview:textField];
    return self;
}

- (void) setState:(NSCellStateValue)state
{
    _state = state;
    [self _applyImage];
}

- (void) setFolderName:(NSString *)folderName
{
    _folderName = folderName;
    [[self textField] setStringValue:folderName];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    [super setBackgroundStyle:style];
    [self _applyImage];
}

- (void) _applyImage
{
    if (_state == NSOnState) {
        NSString * name = @"DejaLu_CheckmarkOn_12";
        if ([self backgroundStyle] == NSBackgroundStyleDark) {
            if ([DJLDarkMode isDarkModeForView:self]) {
                [[self imageView] setImage:s_images[name][@"dark-selected"]];
            } else {
                [[self imageView] setImage:s_images[name][@"selected"]];
            }
        }
        else {
            if ([DJLDarkMode isDarkModeForView:self]) {
                [[self imageView] setImage:s_images[name][@"dark-normal"]];
            } else {
                [[self imageView] setImage:s_images[name][@"normal"]];
            }
        }
    }
    else if (_state == NSMixedState) {
        NSString * name = @"DejaLu_Minus_12";
        if ([self backgroundStyle] == NSBackgroundStyleDark) {
            if ([DJLDarkMode isDarkModeForView:self]) {
                [[self imageView] setImage:s_images[name][@"dark-selected"]];
            } else {
                [[self imageView] setImage:s_images[name][@"selected"]];
            }
        }
        else {
            if ([DJLDarkMode isDarkModeForView:self]) {
                [[self imageView] setImage:s_images[name][@"dark-normal"]];
            } else {
                [[self imageView] setImage:s_images[name][@"normal"]];
            }
        }
    }
    else {
        [[self imageView] setImage:nil];
    }
}

@end


@interface DJLLabelsViewController () <NSTableViewDataSource, NSTableViewDelegate>

@end

@implementation DJLLabelsViewController {
    NSScrollView * _scrollView;
    DJLTableView * _tableView;
    Account * _account;
    MailStorageView * _storageView;
    Array * _folders;
    Array * _paths;
    IndexSet * _separatorIndexes;
    BOOL _reflectingSelectedPath;
    NSArray * _conversations;
    NSSet * _labelsSet;
    NSSet * _labelsMixedSet;
    NSString * _folderPath;
}

@synthesize conversations = _conversations;
@synthesize folderPath = _folderPath;

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    MC_SAFE_RELEASE(_account);
    MC_SAFE_RELEASE(_folders);
    MC_SAFE_RELEASE(_paths);
    MC_SAFE_RELEASE(_separatorIndexes);
}

- (BOOL) _isTrash
{
    return [[self folderPath] isEqualToString:MCO_TO_OBJC(_account->trashFolderPath())];
}

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [self setView:view];
    NSRect frame = [[self view] bounds];
    _scrollView = [[NSScrollView alloc] initWithFrame:frame];
    [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_scrollView setHasVerticalScroller:YES];
    frame.origin = CGPointZero;
    frame.size = CGSizeZero;
    _tableView = [[DJLTableView alloc] initWithFrame:frame];
    //[_tableView setAllowsMultipleSelection:YES];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
    [_tableView setHeaderView:nil];
    [_tableView setRowHeight:80];
    //[_tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
#define COLOR (235./255.)
    //[_tableView setBackgroundColor:[NSColor colorWithCalibratedRed:COLOR green:COLOR blue:COLOR alpha:1.0]];
    [_tableView setBackgroundColor:[NSColor clearColor]];
    [_scrollView setDrawsBackground:NO];
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"DJLFolder"];
    frame = [[self view] bounds];
    [column setWidth:frame.size.width - 3];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [_tableView addTableColumn:column];
    [_scrollView setDocumentView:_tableView];
    [[self view] addSubview:_scrollView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
}

- (void) _scrollerStyleChanged
{
    [_scrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (void) setConversations:(NSArray *)conversations
{
    _conversations = conversations;
    NSMutableSet * labelsSet = nil;
    NSMutableSet * labelsMixedSet = [[NSMutableSet alloc] init];

    for(NSDictionary * conversation in conversations) {
        NSArray * labels = [conversation objectForKey:@"labels"];
        [labelsMixedSet addObjectsFromArray:labels];
        if (labelsSet == nil) {
            labelsSet = [[NSMutableSet alloc] initWithArray:labels];
        }
        [labelsSet intersectSet:[NSSet setWithArray:labels]];
    }
    _labelsSet = labelsSet;
    _labelsMixedSet = labelsMixedSet;
}

- (void) setAccount:(hermes::Account *)account
{
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
}

- (hermes::Account *) account
{
    return _account;
}

- (void) setStorageView:(hermes::MailStorageView *)storageView
{
    MC_SAFE_REPLACE_RETAIN(MailStorageView, _storageView, storageView);
}

- (hermes::MailStorageView *)storageView
{
    return _storageView;
}

static int compareFolders(void * a, void * b, void * context)
{
    DJLLabelsViewController * self = (__bridge DJLLabelsViewController *) context;
    (void) self;
    String * folderA = ((String *) a)->lowercaseString();
    String * folderB = ((String *) b)->lowercaseString();
    return folderA->compare(folderB);
}

- (void) reloadData
{
    MC_SAFE_RELEASE(_paths);
    MC_SAFE_RELEASE(_folders);
    MC_SAFE_RELEASE(_separatorIndexes);

    if (_account != NULL) {
        Set * foldersSet = Set::setWithArray(_account->folders());
        foldersSet->removeObject(_account->inboxFolderPath());
        foldersSet->removeObject(_account->allMailFolderPath());
        foldersSet->removeObject(_account->archiveFolderPath());
        foldersSet->removeObject(_account->draftsFolderPath());
        foldersSet->removeObject(_account->importantFolderPath());
        foldersSet->removeObject(_account->sentFolderPath());
        foldersSet->removeObject(_account->spamFolderPath());
        foldersSet->removeObject(_account->starredFolderPath());
        foldersSet->removeObject(_account->trashFolderPath());
        BOOL hasImportant = (_account->importantFolderPath() != NULL);

        Array * sortedFolders = foldersSet->allObjects()->sortedArray(compareFolders, (__bridge void *) self);
        _separatorIndexes = new IndexSet();
        _paths = new Array();
        _folders = new Array();
        if (![self archiveEnabled]) {
            if (![_labelsMixedSet containsObject:@"\\Inbox"]) {
                _folders->addObject(MCSTR("Add to Inbox"));
                _paths->addObject(MCSTR("\\Inbox"));
            }
            if (hasImportant) {
                _folders->addObject(MCSTR("Important"));
                _paths->addObject(MCSTR("\\Important"));
            }
            if ((_folders->count() > 0) && (sortedFolders->count() > 0)) {
                _separatorIndexes->addIndex(_folders->count());
                _folders->addObject(MCSTR("--"));
                _paths->addObject(MCSTR("--"));
            }
        }
        else {
            if (!_account->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
                if (![[self folderPath] isEqualToString:MCO_TO_OBJC(_account->inboxFolderPath())]) {
                    _folders->addObject(MCSTR("Move to Inbox"));
                    _paths->addObject(_account->inboxFolderPath());
                }
                if ((_folders->count() > 0) && (sortedFolders->count() > 0)) {
                    _separatorIndexes->addIndex(_folders->count());
                    _folders->addObject(MCSTR("--"));
                    _paths->addObject(MCSTR("--"));
                }
            }
        }
        mc_foreacharray(String, path, sortedFolders) {
            _folders->addObject(path->mUTF7DecodedString());
            _paths->addObject(path);
        }
    }
    [_tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (_folders == NULL) {
        return 0;
    }
    return _folders->count();
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if (_separatorIndexes->containsIndex((uint64_t) row)) {
        return 1;
    }
    else {
        return 30;
    }
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    if (_separatorIndexes->containsIndex((uint64_t) rowIndex)) {
        return NO;
    }
    else {
        return YES;
    }
}

#define WIDTH 300

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (_separatorIndexes->containsIndex((uint64_t) row)) {
        NSRect frame = NSMakeRect(0, 0, WIDTH, 5);
        NSTableCellView * cell = [[NSTableCellView alloc] initWithFrame:frame];
        DJLColoredView * view = [[DJLColoredView alloc] initWithFrame:NSMakeRect(5, 0, WIDTH - 10, 1)];
        [view setBackgroundColor:[NSColor colorWithWhite:0.85 alpha:1.0]];
        [cell addSubview:view];
        return cell;
    }
    else {
        NSString * folderName = MCO_TO_OBJC(_folders->objectAtIndex((int) row));
        NSString * path = MCO_TO_OBJC(_paths->objectAtIndex((int) row));

        NSRect frame = NSMakeRect(0, 0, WIDTH, 30);
        DJLLabelsTableCellView * cell = [[DJLLabelsTableCellView alloc] initWithFrame:frame];
        if ([_labelsSet containsObject:path]) {
            [cell setState:NSOnState];
        }
        else if ([_labelsMixedSet containsObject:path]) {
            [cell setState:NSMixedState];
        }
        else {
            [cell setState:NSOffState];
        }
        [cell setFolderName:folderName];
        return cell;
    }
}

- (void) _confirmSelection
{
    NSInteger row = [_tableView selectedRow];
    if (row == -1) {
        return;
    }

    DJLLabelsTableCellView * cell = [_tableView viewAtColumn:0 row:row makeIfNecessary:NO];
    NSString * path = MCO_TO_OBJC(_paths->objectAtIndex((unsigned int) row));
    if (_account->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        if ([self _isTrash] && [path isEqualTo:@"\\Inbox"]) {
            [self _moveToInbox];
            [[self delegate] DJLLabelsViewControllerClose:self];
            return;
        }
    }
    else {
        if ([path isEqualTo:MCO_TO_OBJC(_account->inboxFolderPath())]) {
            [self _moveToInbox];
            [[self delegate] DJLLabelsViewControllerClose:self];
            return;
        }
    }

    if ([_labelsSet containsObject:path]) {
        [cell setState:NSOffState];
        [self _removeLabel:path];
        [[self delegate] DJLLabelsViewControllerClose:self];
    }
    else if ([_labelsMixedSet containsObject:path]) {
        [cell setState:NSOnState];
        [self _addLabel:path];
        [[self delegate] DJLLabelsViewControllerClose:self];
    }
    else {
        [cell setState:NSOnState];
        [self _addLabel:path];
        [[self delegate] DJLLabelsViewControllerClose:self];
    }
}

- (BOOL) djl_tableView:(NSTableView *)tableView keyPress:(NSEvent *)event
{
    if ([event keyCode] == 36) {
        [self _confirmSelection];
        return YES;
    }
    return NO;
}

- (void) djl_tableView:(NSTableView *)tableView didClickedRow:(NSInteger)row
{
    [self _confirmSelection];
}

- (void) _addLabel:(NSString *)path
{
    Array * convIDs = Array::array();
    for(NSDictionary * conversation in _conversations) {
        NSNumber * nbRowID = conversation[@"id"];
        convIDs->addObject(Value::valueWithLongLongValue([nbRowID longLongValue]));
    }
    if ([self account]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        if ([self archiveEnabled]) {
            [self account]->movePeopleConversations(convIDs, MCO_FROM_OBJC(String, path), _storageView->foldersScores());
        }
        else {
            [self account]->addLabelToConversations(convIDs, MCO_FROM_OBJC(String, path), [self _isTrash]);
        }
    }
    else {
        if ([self archiveEnabled]) {
            [self account]->movePeopleConversations(convIDs, MCO_FROM_OBJC(String, path), _storageView->foldersScores());
        }
        else {
            [self account]->copyPeopleConversations(convIDs, MCO_FROM_OBJC(String, path), _storageView->foldersScores());
        }
    }
}

- (void) _removeLabel:(NSString *)path
{
    if (![self account]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        return;
    }
    Array * convIDs = Array::array();
    for(NSDictionary * conversation in _conversations) {
        NSNumber * nbRowID = conversation[@"id"];
        convIDs->addObject(Value::valueWithLongLongValue([nbRowID longLongValue]));
    }
    [self account]->removeLabelFromConversations(convIDs, MCO_FROM_OBJC(String, path), [self _isTrash]);
}

- (void) _moveToInbox
{
    Array * convIDs = Array::array();
    for(NSDictionary * conversation in _conversations) {
        NSNumber * nbRowID = conversation[@"id"];
        convIDs->addObject(Value::valueWithLongLongValue([nbRowID longLongValue]));
    }
    [self account]->movePeopleConversations(convIDs, [self account]->inboxFolderPath(), _storageView->foldersScores());
}

@end
