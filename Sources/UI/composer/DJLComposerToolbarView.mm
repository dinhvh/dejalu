// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLComposerToolbarView.h"

#import "DJLGradientSeparatorLineView.h"
#import "NSImage+DJLColored.h"
#import "NSString+DJL.h"
#import "DJLSearchField.h"
#import "DJLPopoverButton.h"
#import "DJLAccountsSelectionViewController.h"
#import "DJLToolbarButton.h"
#import "DJLButtonCell.h"
#import "DJLGiphyViewController.h"

using namespace mailcore;
using namespace hermes;

@interface DJLComposerToolbarView () <DJLAccountsSelectionViewControllerDelegate, DJLGiphyViewControllerDelegate>

@end

@implementation DJLComposerToolbarView {
    NSButton * _sendButton;
    NSButton * _attachmentButton;
    DJLSearchField * _searchField;
    DJLPopoverButton * _accountSelectionButton;
    NSString * _emailAlias;
    DJLAccountsSelectionViewController * _accountSelectionViewController;
    NSPopover * _accountsPopover;
    NSButton * _ccButton;
    DJLPopoverButton * _giphyButton;
    DJLGiphyViewController * _giphyViewController;
    NSPopover * _giphyPopover;
}

@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    _sendButton = [[DJLPopoverButton alloc] initWithFrame:NSMakeRect(0, 7, 150, 20)];
    [_sendButton setTitle:@"Send"];
    [_sendButton setFont:[NSFont boldSystemFontOfSize:14]];
    [_sendButton setShowsBorderOnlyWhileMouseInside:YES];
    [_sendButton setBezelStyle:NSRecessedBezelStyle];
    [_sendButton setTarget:self];
    [_sendButton setAction:@selector(_sendMessage)];
    [_sendButton sizeToFit];
    frame = [_sendButton frame];
    frame.origin.x = [self bounds].size.width - frame.size.width - 10;
    [_sendButton setFrame:frame];
    [_sendButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_sendButton];

    _attachmentButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(80, 8, 20, 20)];
    NSImage * originImage = [NSImage imageNamed:@"DejaLu_Attachment_16"];
    NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_attachmentButton setImage:img];
    [_attachmentButton setTarget:self];
    [_attachmentButton setAction:@selector(_addAttachment)];
    [self addSubview:_attachmentButton];

    _giphyButton = [[DJLPopoverButton alloc] initWithFrame:NSMakeRect(100, 7, 40, 20)];
    [_giphyButton setTitle:@"GIF"];
    [_giphyButton setShowsBorderOnlyWhileMouseInside:YES];
    [_giphyButton setBezelStyle:NSRecessedBezelStyle];
    [_giphyButton setTarget:self];
    [_giphyButton setAction:@selector(_showGiphyPopover:)];
    [self addSubview:_giphyButton];

    _ccButton = [[NSButton alloc] initWithFrame:NSMakeRect(140, 8, 20, 20)];
    [_ccButton setCell:[[DJLButtonCell alloc] init]];
    [_ccButton setBordered:NO];
    [(NSButtonCell *) [_ccButton cell] setHighlightsBy:NSNoCellMask];
    [_ccButton setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Cc" attributes:@{NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.0 alpha:0.75]}]];
    [_ccButton setAttributedAlternateTitle:[[NSAttributedString alloc] initWithString:@"Cc" attributes:@{NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]}]];
    [_ccButton setFont:[NSFont systemFontOfSize:10]];
    [_ccButton setTarget:self];
    [_ccButton setAction:@selector(_showCc)];
    [_ccButton sizeToFit];
    frame = [_ccButton frame];
    frame.size.height = 20;
    [_ccButton setFrame:frame];
    [self addSubview:_ccButton];

    _accountSelectionButton = [[DJLPopoverButton alloc] initWithFrame:NSMakeRect(160, 7, 20, 20)];
    [_accountSelectionButton setShowsBorderOnlyWhileMouseInside:YES];
    [_accountSelectionButton setBezelStyle:NSRecessedBezelStyle];
    originImage = [NSImage imageNamed:@"DejaLu_ArrowDown_12"];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.75]];
    [_accountSelectionButton setImage:img];
    [_accountSelectionButton setImagePosition:NSImageRight];
    [_accountSelectionButton setTarget:self];
    [_accountSelectionButton setAction:@selector(_showAccountsPopOver:)];

    [self addSubview:_accountSelectionButton];

#define SEARCH_WIDTH 150
    _searchField = [[DJLSearchField alloc] initWithFrame:NSMakeRect((int) (([self bounds].size.width - SEARCH_WIDTH) / 2), 7, SEARCH_WIDTH, 22)];
    [_searchField setFont:[NSFont systemFontOfSize:13]];
    [_searchField setFocusRingType:NSFocusRingTypeNone];
    // cast to id to avoid typing to NSSearchFieldDelegate (which is available in 10.11 only).
    [_searchField setDelegate:(id) self];
    [_searchField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin];
    [self addSubview:_searchField];
    [_searchField setAlphaValue:0.0];
    [_searchField setHidden:YES];

    [self setViewsToFade:@[_ccButton, _attachmentButton, _accountSelectionButton, _giphyButton]];

    return self;
}

- (void) dealloc
{
}

- (void) _updateAccountNameSize
{
    [_accountSelectionButton sizeToFit];
    if (NSMaxX([_accountSelectionButton frame]) > NSMinX([_sendButton frame])) {
        NSRect frame = [_accountSelectionButton frame];
        frame.size.width = NSMinX([_sendButton frame]) - NSMinX([_accountSelectionButton frame]);
        [_accountSelectionButton setFrame:frame];
    }
}

- (NSArray *) _accountsAllEmails
{
    NSMutableArray * result = [[NSMutableArray alloc] init];
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        [result addObject:MCO_TO_OBJC(account->accountInfo()->email())];
        mc_foreacharray(Address, address, account->accountInfo()->aliases()) {
            [result addObject:MCO_TO_OBJC(address->mailbox())];
        }
    }
    return result;
}

- (void) setEmailAlias:(NSString *)emailAlias
{
    _emailAlias = [emailAlias copy];
    [_accountSelectionButton setTitle:[_emailAlias djlShortEmailDisplayNameWithAllEmails:[self _accountsAllEmails]]];
    [self _updateAccountNameSize];
}

- (NSString *) emailAlias
{
    return _emailAlias;
}

- (BOOL) isSendButtonEnabled
{
    return [_sendButton isEnabled];
}

- (void) setSendButtonEnabled:(BOOL)enabled
{
    [_sendButton setEnabled:enabled];
}

- (void) _showCc
{
    [[self delegate] DJLComposerToolbarViewToggleCc:self];
}

- (void) _sendMessage
{
    [[self delegate] DJLComposerToolbarViewSendMessage:self];
}

- (void) _addAttachment
{
    [[self delegate] DJLComposerToolbarViewAddAttachment:self];
}

- (void) focusSearch
{
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [_accountSelectionButton setHidden:YES];
    }];
    [[_accountSelectionButton animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];

    [_searchField setHidden:NO];
    [_searchField setAlphaValue:1.0];
    [[self window] makeFirstResponder:_searchField];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
    [super resizeSubviewsWithOldSize:oldBoundsSize];
    [self _updateAccountNameSize];
}

- (void) djl_searchFieldOperationCancelled:(DJLSearchField *)searchField
{
    [self _tryHideSearch];
}

- (void) _tryHideSearch
{
    [[self delegate] DJLComposerToolbarViewCancelSearch:self];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [_searchField setHidden:YES];
    }];
    [[_searchField animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];

    [_accountSelectionButton setHidden:NO];
    [_accountSelectionButton setAlphaValue:[self currentViewToFadeAlphaValue]];
}

- (void) djl_searchFieldResignFirstResponder:(DJLSearchField *)searchField
{
    [self _tryHideSearch];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    [self _tryHideSearch];
}

- (void) controlTextDidChange:(NSNotification *) notification
{
    [self _performSearch];
}

- (void) _performSearch
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallySearch) object:nil];
    [self performSelector:@selector(_reallySearch) withObject:nil afterDelay:0.5];
}

- (void) _reallySearch
{
    [[self delegate] DJLComposerToolbarViewSearch:self];
}

- (NSString *) searchString
{
    return [_searchField stringValue];
}

- (BOOL) isSearchFieldVisible
{
    return ![_searchField isHidden];
}

#define WIDTH 300
#define HEIGHT 500

- (void) _showAccountsPopOver:(id)sender
{
    if ([_accountsPopover isShown]) {
        return;
    }

    _accountSelectionViewController = [[DJLAccountsSelectionViewController alloc] init];
    [_accountSelectionViewController setDelegate:self];
    [[_accountSelectionViewController view] setFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
    [_accountSelectionViewController reloadData];
    _accountsPopover = [[NSPopover alloc] init];
    [_accountsPopover setContentViewController:_accountSelectionViewController];
    [_accountsPopover setBehavior:NSPopoverBehaviorTransient];
    [_accountsPopover setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    [_accountSelectionViewController prepareSize];
    [_accountsPopover showRelativeToRect:[_accountSelectionButton bounds] ofView:_accountSelectionButton preferredEdge:NSMaxYEdge];
    [_accountSelectionViewController makeFirstResponder];
}

- (void) DJLAccountsSelectionViewController:(DJLAccountsSelectionViewController *)controller hasHeight:(CGFloat)height
{
    //NSLog(@"height: %g", height);
    if (height > 500) {
        [_accountsPopover setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    }
    else {
        [_accountsPopover setContentSize:NSMakeSize(WIDTH, height)];
    }
}

- (void) DJLAccountsSelectionViewController:(DJLAccountsSelectionViewController *)controller accountSelected:(hermes::Account *)account emailAlias:(NSString *)emailAlias
{
    [[self delegate] DJLComposerToolbarView:self accountSelected:account emailAlias:emailAlias];
    [_accountsPopover close];
}

#define GIPHY_WIDTH 500
#define GIPHY_HEIGHT 500

- (void) _showGiphyPopover:(id)sender
{
    if ([_accountsPopover isShown]) {
        return;
    }

    _giphyViewController = [[DJLGiphyViewController alloc] init];
    [_giphyViewController setDelegate:self];
    [[_giphyViewController view] setFrame:NSMakeRect(0, 0, GIPHY_WIDTH, GIPHY_HEIGHT)];
    _giphyPopover = [[NSPopover alloc] init];
    [_giphyPopover setContentViewController:_giphyViewController];
    [_giphyPopover setBehavior:NSPopoverBehaviorTransient];
    [_giphyPopover setContentSize:NSMakeSize(GIPHY_WIDTH, GIPHY_HEIGHT)];
    [_giphyViewController prepareSize];
    [_giphyPopover showRelativeToRect:[_giphyButton bounds] ofView:_giphyButton preferredEdge:NSMaxYEdge];
    [_giphyViewController makeFirstResponder];
}

- (void) DJLGiphyViewController:(DJLGiphyViewController *)controller itemSelected:(NSDictionary *)item
{
    [[self delegate] DJLComposerToolbarView:self giphySelected:item];
    [_giphyPopover close];
}

- (void) DJLGiphyViewController:(DJLGiphyViewController *)controller hasHeight:(CGFloat)height
{
    if (height > 500) {
        [_giphyPopover setContentSize:NSMakeSize(GIPHY_WIDTH, GIPHY_HEIGHT)];
    }
    else {
        [_giphyPopover setContentSize:NSMakeSize(GIPHY_WIDTH, height)];
    }
}

- (void) DJLGiphyViewControllerClosed:(DJLGiphyViewController *)controller
{
    [_giphyPopover close];
}

@end
