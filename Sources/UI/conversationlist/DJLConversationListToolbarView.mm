// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationListToolbarView.h"

#import "DJLFoldersViewController.h"
#import "Hermes.h"
#import "DJLUIConstants.h"
#import "DJLGradientView.h"
#import "DJLColoredView.h"
#import "DJLGradientSeparatorLineView.h"
#import "NSImage+DJLColored.h"
#import "DJLPopoverButton.h"
#import "DJLToolbarButton.h"

using namespace hermes;
using namespace mailcore;

#define LICENSE_VIEW_HEIGHT 25

@interface DJLConversationListToolbarView () <DJLFoldersViewControllerDelegate>

@end

@implementation DJLConversationListToolbarView {
    __weak id <DJLConversationListToolbarViewDelegate> _delegate;
    NSButton * _mailboxButton;
    NSPopover * _foldersPopOver;
    DJLFoldersViewController * _foldersViewController;
    NSButton * _composeButton;
    NSButton * _searchButton;
    NSButton * _errorButton;
    NSImage * _errorImg;
    NSImage * _altErrorImg;
    NSImage * _offlineImg;
    NSImage * _altOfflineImg;
    DJLConversationListToolbarViewErrorKind _error;
    CGFloat _leftMargin;
}

@synthesize delegate = _delegate;
@synthesize error = _error;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    //_mailboxButton = [[DJLPopoverButton alloc] initWithFrame:NSMakeRect(76, 8, 150, 20)];
    _mailboxButton = [[DJLPopoverButton alloc] initWithFrame:NSMakeRect(76, 0, 150, 35)];
    [_mailboxButton setShowsBorderOnlyWhileMouseInside:YES];
    [_mailboxButton setBezelStyle:NSRecessedBezelStyle];
    [self _setCurrentFolderName:nil];
    NSImage * originImage = [NSImage imageNamed:@"DejaLu_ArrowDown_12"];
    //originImage = [originImage copy];
    //[originImage setSize:NSMakeSize(12, 12)];
    NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.75]];
    //NSImage * altImg = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_mailboxButton setImage:img];
    //[_mailboxButton setAlternateImage:altImg];
    [_mailboxButton setImagePosition:NSImageRight];
    //[_mailboxButton sizeToFit];
    [_mailboxButton setTarget:self];
    [_mailboxButton setAction:@selector(_showFoldersPopOver:)];
    //[_mailboxButton setImage:];
    [self addSubview:_mailboxButton];

    _errorButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 8, 20, 20)];
    [_errorButton setBordered:NO];

    _errorImg = [[NSImage alloc] initWithSize:NSMakeSize(10, 10)];
    [_errorImg lockFocus];
    NSColor * color = [NSColor colorWithCalibratedRed:1.0 green:0.2 blue:0.2 alpha:1.0];
    CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], NSMakeRect(0, 0, 10, 10));
    CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
    CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
    [_errorImg unlockFocus];
    _altErrorImg = [[NSImage alloc] initWithSize:NSMakeSize(10, 10)];
    [_altErrorImg lockFocus];
    color = [NSColor colorWithCalibratedRed:1.0 green:0.5 blue:0.5 alpha:1.0];
    CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], NSMakeRect(0, 0, 10, 10));
    CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
    CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
    [_altErrorImg unlockFocus];

    _offlineImg = [[NSImage alloc] initWithSize:NSMakeSize(10, 10)];
    [_offlineImg lockFocus];
    color = [NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1.0];
    CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], NSMakeRect(0, 0, 10, 10));
    CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
    CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
    [_offlineImg unlockFocus];
    _altOfflineImg = [[NSImage alloc] initWithSize:NSMakeSize(10, 10)];
    [_altOfflineImg lockFocus];
    color = [NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], NSMakeRect(0, 0, 10, 10));
    CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
    CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
    [_altOfflineImg unlockFocus];

    [_errorButton setImage:_offlineImg];
    [_errorButton setAlternateImage:_altOfflineImg];
    [[_errorButton cell] setHighlightsBy:NSContentsCellMask];
    [_errorButton setTarget:self];
    [_errorButton setAction:@selector(_showError)];
    [_errorButton setAutoresizingMask:0];
    [_errorButton setHidden:YES];
    [self addSubview:_errorButton];

    _composeButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 30, 10, 20, 20)];
    //[_composeButton setBordered:NO];
    originImage = [NSImage imageNamed:@"DejaLu_Composer_16"];
    //originImage = [originImage copy];
    //[originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    //altImg = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_composeButton setImage:img];
    //[_composeButton setAlternateImage:altImg];
    //[[_composeButton cell] setHighlightsBy:NSContentsCellMask];
    [_composeButton setTarget:self];
    [_composeButton setAction:@selector(_compose)];
    [_composeButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_composeButton];

    _searchButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 60, 8, 20, 20)];
    //[_searchButton setBordered:NO];
    [[_searchButton cell] setHighlightsBy:NSContentsCellMask];
    originImage = [NSImage imageNamed:@"DejaLu_Search_16"];
    //originImage = [originImage copy];
    //[originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    //altImg = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_searchButton setImage:img];
    //[_searchButton setAlternateImage:altImg];
    [_searchButton setTarget:self];
    [_searchButton setAction:@selector(_search)];
    [_searchButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_searchButton];

    [self setButtonValidation:_composeButton selector:@selector(composeMessage)];
    [self setButtonValidation:_searchButton selector:@selector(_search)];
    [self setViewsToFade:@[_searchButton, _composeButton]];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) _compose
{
    [_delegate DJLConversationListToolbarViewCompose:self];
}

- (void) _search
{
    [_delegate DJLConversationListToolbarViewSearch:self];
}

#define WIDTH 300
#define HEIGHT 500

- (void) _showFoldersPopOver:(id)sender
{
    if ([_foldersPopOver isShown]) {
        return;
    }

    _foldersViewController = [[DJLFoldersViewController alloc] init];
    [_foldersViewController setDelegate:self];
    [[_foldersViewController view] setFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
    //Account * account = [_delegate DJLConversationListToolbarViewAccount:self];
    //[foldersViewController setAccount:account];
    [_foldersViewController reloadData];
    //[foldersViewController setSelectedPath:[_delegate DJLConversationListToolbarViewSelectedPath:self]];
    _foldersPopOver = [[NSPopover alloc] init];
    [_foldersPopOver setContentViewController:_foldersViewController];
    [_foldersPopOver setBehavior:NSPopoverBehaviorTransient];
    [_foldersPopOver setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    [_foldersViewController prepareSize];
    [_foldersPopOver showRelativeToRect:[_mailboxButton bounds] ofView:_mailboxButton preferredEdge:NSMaxYEdge];
    [_foldersViewController makeFirstResponder];
}

- (void) DJLFoldersViewController:(DJLFoldersViewController *)controller hasHeight:(CGFloat)height
{
    //NSLog(@"height: %g", height);
    if (height > 500) {
        [_foldersPopOver setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    }
    else {
        [_foldersPopOver setContentSize:NSMakeSize(WIDTH, height)];
    }
}

- (void) DJLFoldersViewControllerPathSelected:(DJLFoldersViewController *)controller
{
    [[self delegate] DJLConversationListToolbarView:self
                                    selectedAccount:[_foldersViewController selectedAccount]
                                       selectedPath:[_foldersViewController selectedPath]];
    [_foldersPopOver close];
}

- (void) DJLFoldersViewController:(DJLFoldersViewController *)controller openManager:(hermes::Account *)account
{
    [[self delegate] DJLConversationListToolbarView:self openFoldersManager:account];
}

- (void) _showError
{
    [[self delegate] DJLConversationListToolbarViewShowError:self];
}

- (void) setFolderPath:(NSString *)path
{
    NSString * displayName = NULL;
    if (path != NULL) {
        String * mcPath = MCO_FROM_OBJC(String, path);
        if (mcPath != NULL) {
            displayName = MCO_TO_OBJC(mcPath->mUTF7DecodedString());
        }
    }
    UnifiedAccount * account = [_delegate DJLConversationListToolbarViewAccount:self];
    if (account == NULL) {
        displayName = nil;
    }
    else {
        String * selectedPath = MCO_FROM_OBJC(String, path);
        if ((account->inboxFolderPath() != NULL) && account->inboxFolderPath()->isEqual(selectedPath)) {
            if (account->accounts()->count() >= 2) {
                displayName = @"All Inboxes";
            }
            else {
                displayName = @"Inbox";
            }
        }
        else if ((account->importantFolderPath() != NULL) && account->importantFolderPath()->isEqual(selectedPath)) {
            displayName = @"Important";
        }
        else if ((account->starredFolderPath() != NULL) && account->starredFolderPath()->isEqual(selectedPath)) {
            displayName = @"Starred";
        }
        else if ((account->sentFolderPath() != NULL) && account->sentFolderPath()->isEqual(selectedPath)) {
            displayName = @"Sent";
        }
        else if ((account->draftsFolderPath() != NULL) && account->draftsFolderPath()->isEqual(selectedPath)) {
            displayName = @"Drafts";
        }
        else if ((account->allMailFolderPath() != NULL) && account->allMailFolderPath()->isEqual(selectedPath)) {
            displayName = @"All Mail";
        }
        else if ((account->archiveFolderPath() != NULL) && account->archiveFolderPath()->isEqual(selectedPath)) {
            displayName = @"Archive";
        }
        else if ((account->trashFolderPath() != NULL) && account->trashFolderPath()->isEqual(selectedPath)) {
            displayName = @"Trash";
        }
        else if ((account->spamFolderPath() != NULL) && account->spamFolderPath()->isEqual(selectedPath)) {
            displayName = @"Spam";
        }
    }
    [self _setCurrentFolderName:displayName];
    [self _updateFolderSize];
}

- (void) _setCurrentFolderName:(NSString *)name
{
    [_mailboxButton setTitle:name];
    UnifiedAccount * account = [[self delegate] DJLConversationListToolbarViewAccount:self];
    if (AccountManager::sharedManager()->accounts()->count() == 1) {
        [_mailboxButton setAlternateTitle:@""];
    }
    else if ((account == NULL) || (account->accounts()->count() >= 2)) {
        [_mailboxButton setAlternateTitle:@""];
    }
    else {
        [_mailboxButton setAlternateTitle:MCO_TO_OBJC(account->shortDisplayName())];
    }
    [self _updateFolderSize];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
    [super resizeSubviewsWithOldSize:oldBoundsSize];
    [self _updateFolderSize];
}

- (NSRect) toolbarRect
{
    NSRect rect = [self bounds];
    rect.origin.x += 70;
    rect.size.width -= 70;
    return rect;
}

- (void) setError:(DJLConversationListToolbarViewErrorKind)error
{
    _error = error;
    switch (_error) {
        case DJLConversationListToolbarViewErrorKindNone:
            [_errorButton setHidden:YES];
            break;
        case DJLConversationListToolbarViewErrorKindOffline:
            [_errorButton setHidden:NO];
            [_errorButton setImage:_offlineImg];
            [_errorButton setAlternateImage:_altOfflineImg];
            break;
        case DJLConversationListToolbarViewErrorKindError:
            [_errorButton setHidden:NO];
            [_errorButton setImage:_errorImg];
            [_errorButton setAlternateImage:_altErrorImg];
            break;
    }
    [self _updateFolderSize];
}

- (void) setLeftMargin:(CGFloat)margin
{
    _leftMargin = margin;
    [self _updateFolderSize];
}

- (CGFloat) leftMargin
{
    return _leftMargin;
}

- (void) _updateFolderSize
{
    [_mailboxButton sizeToFit];
    NSRect frame = [_mailboxButton frame];
    if ([_mailboxButton frame].size.width > [self bounds].size.width - 70 - _leftMargin - 20) {
        frame.size.width = [self bounds].size.width - 70 - _leftMargin - 20;
    }
    frame.origin.x = _leftMargin;
    frame.origin.y = ([self bounds].size.height - [_mailboxButton frame].size.height) / 2;
    frame = NSIntegralRect(frame);
    [_mailboxButton setFrame:frame];

    frame = [_errorButton frame];
    frame.origin.x = NSMaxX([_mailboxButton frame]);
    [_errorButton setFrame:frame];
}

@end
