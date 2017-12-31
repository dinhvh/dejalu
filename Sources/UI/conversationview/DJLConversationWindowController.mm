// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationWindowController.h"

#import <WebKit/WebKit.h>

#include "Hermes.h"
#import "DJLConversationViewController.h"
#import "DJLConversationToolbarView.h"
#import "DJLWindow.h"
#import "DJLColoredView.h"
#import "DJLLabelsViewController.h"

using namespace mailcore;
using namespace hermes;

@interface DJLConversationWindowController () <NSWindowDelegate, DJLConversationViewControllerDelegate,
DJLConversationToolbarViewDelegate, DJLWindowDelegate, DJLLabelsViewControllerDelegate, DJLToolbarViewValidationDelegate>

- (void) _deletedConversations:(NSArray *)deleted;

@end

class DJLConversationWindowControllerCallback : public mailcore::Object, public MailStorageViewObserver {

public:
    DJLConversationWindowControllerCallback(DJLConversationWindowController * controller)
    {
        mController = controller;
    }

    virtual ~DJLConversationWindowControllerCallback()
    {
    }

    virtual void mailStorageViewModifiedDeletedConversations(MailStorageView * view,
                                                             mailcore::Array * modified,
                                                             mailcore::Array * deleted) {
        [mController _deletedConversations:MCO_TO_OBJC(deleted)];
    }

private:
    __weak DJLConversationWindowController * mController;

};

@implementation DJLConversationWindowController {
    DJLConversationViewController * _viewController;
    WebView * _webView;
    __weak id <DJLConversationWindowControllerDelegate> _delegate;
    DJLConversationToolbarView * _conversationToolbarView;
    NSPopover * _labelsPopOver;
    DJLConversationWindowControllerCallback * _callback;
    BOOL _toolbarEnabled;
}

@synthesize delegate = _delegate;

- (id)init
{
    DJLWindow * window = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 500)
                                                      styleMask: NSTitledWindowMask | NSResizableWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                        backing:NSBackingStoreBuffered defer:YES];
    [window setReleasedWhenClosed:NO];
    [window setTitlebarAppearsTransparent:YES];
    [window setContentMinSize:NSMakeSize(400, 400)];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];

    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, 700, 500)];
    [window setContentView:contentView];
    [contentView setWantsLayer:YES];

    self = [self initWithWindow:window];

    [window setTitle:@"Conversation"];
    [window setTitleVisibility:NSWindowTitleHidden];
    [window setDelegate:self];

    _conversationToolbarView = [[DJLConversationToolbarView alloc] initWithFrame:NSMakeRect(0, 465, 700, 35)];
    [_conversationToolbarView setWindowMode:YES];
    [_conversationToolbarView setDelegate:self];
    [_conversationToolbarView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [_conversationToolbarView setValidationDelegate:self];
    [[window contentView] addSubview:_conversationToolbarView];

    _viewController = [[DJLConversationViewController alloc] init];
    [_viewController setDelegate:self];
    [[_viewController view] setFrame:NSMakeRect(0, 0, 700, 465)];
    [[_viewController view] setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [[window contentView] addSubview:[_viewController view]];

    NSString * frameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DJLConversationWindowFrame"];
    NSRect frame;
    [window center];
    if (frameString != nil) {
        frame = NSRectFromString(frameString);
        if ((frame.size.height != 0) && (frame.size.width != 0)) {
            [window setFrame:frame display:NO];
        }
    }

    _callback = new DJLConversationWindowControllerCallback(self);

    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_callback);
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self _savePosition];
}

- (void)windowDidMove:(NSNotification *)notification
{
    [self _savePosition];
}

- (void) _savePosition
{
    if ([self window] == nil) {
        return;
    }
    if (![[self delegate] DJLConversationWindowControllerShouldSave:self]) {
        return;
    }

    NSRect frame = [[self window] frame];
    NSString * frameString = NSStringFromRect(frame);
    [[NSUserDefaults standardUserDefaults] setObject:frameString forKey:@"DJLConversationWindowFrame"];
}

- (int64_t) convID
{
    return [_viewController convID];
}

- (void) setConvID:(int64_t)convID
{
    [_viewController setConvID:convID];
}

- (MailStorageView *) storageView
{
    return [_viewController storageView];
}

- (void) setStorageView:(MailStorageView *)storageView
{
    if ([_viewController storageView] != NULL) {
        [_viewController storageView]->removeObserver(_callback);
    }
    [_viewController setStorageView:storageView];
    if ([_viewController storageView] != NULL) {
        [_viewController storageView]->addObserver(_callback);
    }
}

- (Account *) account
{
    return [_viewController account];
}

- (void) setAccount:(Account *)account
{
    [_viewController setAccount:account];
}

- (void) setup
{
    [_viewController setup];
    //[_conversationToolbarView setup];
}

- (void) _unsetup
{
    if ([_viewController storageView] != NULL) {
        [_viewController storageView]->removeObserver(_callback);
    }
    [_viewController unsetup];
}

- (void) loadConversation
{
    [self account]->markAsReadPeopleConversations(Array::arrayWithObject(Value::valueWithLongLongValue([self convID])));
    [_viewController loadConversation];
}

- (void) replyMessage:(id)sender
{
    [self _replyMessage];
}

- (void) _replyMessage
{
    [_viewController replyMessage:nil];
    [self close];
}

- (void) forwardMessage:(id)sender
{
    [self _forwardMessage];
}

- (void) _forwardMessage
{
    [_viewController forwardMessage:nil];
    [self close];
}

- (void) findInText:(id)sender
{
    [_viewController findInText:sender];
}

- (void) findNext:(id)sender
{
    [_viewController findNext:sender];
}

- (void) findPrevious:(id)sender
{
    [_viewController findPrevious:sender];
}

- (IBAction) showLabelsPanel:(id)sender
{
    [self _showLabelsPopOverAndArchive:NO];
}

- (IBAction) showLabelsAndArchivePanel:(id)sender
{
    [self _showLabelsPopOverAndArchive:NO];
}

- (void) deleteMessage:(id)sender
{
    [_viewController deleteMessage:sender];
}

- (void) archiveMessage:(id)sender
{
    [_viewController archiveMessage:sender];
}

- (void) saveAllAttachments:(id)sender
{
    [_viewController saveAllAttachments:sender];
}

- (IBAction) printDocument:(id)sender;
{
    [_viewController printDocument:sender];
}

#pragma mark -
#pragma mark window delegate

- (BOOL) DJLWindowSpaceKeyPressed:(DJLWindow *)window
{
    // search field is focused.
    if ([[window firstResponder] class] == [NSTextView class]) {
        return NO;
    }
    if ([_viewController hasAttachmentSelection]) {
        return NO;
    }
    [self close];
    return YES;
}

- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window
{
    if ([_labelsPopOver isShown]) {
        return NO;
    }
    if ([_conversationToolbarView isSearchFieldVisible]) {
        return NO;
    }
    [self close];
    return YES;
}

- (void) windowWillClose:(NSNotification *)notification
{
    [self _unsetup];
    [[self delegate] DJLConversationWindowControllerClose:self];
}

#pragma mark -
#pragma mark conversation view delegate

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                   separatorAlphaValue:(CGFloat)alphaValue
{
    [_conversationToolbarView setSeparatorAlphaValue:alphaValue];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                     replyMessageRowID:(int64_t)messageRowID
                              folderID:(int64_t)folderID
                             replyType:(DJLReplyType)replyType
{
    [[self delegate] DJLConversationWindowController:self
                                   replyMessageRowID:messageRowID
                                            folderID:folderID
                                           replyType:replyType];
}

- (void) DJLConversationViewControllerArchive:(DJLConversationViewController *)controller;
{
    [[self delegate] DJLConversationWindowControllerArchive:self];
    [self close];
}

- (void) DJLConversationViewControllerDelete:(DJLConversationViewController *)controller
{
    [self _delete];
}

- (void) _delete
{
    if ([self account]->trashFolderPath() == NULL) {
        [self _showAlertTrashMissing:[self account]];
        return;
    }
    [[self delegate] DJLConversationWindowControllerDelete:self];
    [self close];
}

- (void) _showAlertTrashMissing:(Account *)account
{
    NSAlert * alert = [[NSAlert alloc] init];
    NSString * title = [NSString stringWithFormat:@"Trash folder is required for %@", MCO_TO_OBJC(account->accountInfo()->email())];
    [alert setMessageText:title];
    [alert setInformativeText:@"DejaLu needs the Trash folder to delete emails. You can enable it in Gmail settings on the web > Labels > Check 'Show in IMAP' for Trash."];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        // do nothing
    }];
}

- (void) DJLConversationView:(DJLConversationViewController *)controller
                draftEnabled:(BOOL)draftEnabled
{
    [_conversationToolbarView setDraft:draftEnabled];
}

- (void) DJLConversationView:(DJLConversationViewController *)controller
            editDraftMessage:(int64_t)messageRowID folderID:(int64_t)folderID
{
    [[self delegate] DJLConversationWindowController:self editDraftMessage:messageRowID folderID:folderID];
}

- (void) DJLConversationViewSearch:(DJLConversationViewController *)controller
{
    [_conversationToolbarView focusSearch];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
                    composeWithAddress:(MCOAddress *)address
{
    [[self delegate] DJLConversationWindowController:self composeWithAddress:address];
}

- (void) DJLConversationViewShowLabelsPanel:(DJLConversationViewController *)controller
                                    archive:(BOOL)archive
{
    [self _showLabelsPopOverAndArchive:archive];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller
             showSourceForMessageRowID:(int64_t)messageRowID
                              folderID:(int64_t)folderID
{
    [[self delegate] DJLConversationWindowController:self
                           showSourceForMessageRowID:messageRowID
                                            folderID:folderID];
}

- (void) DJLConversationViewControllerClose:(DJLConversationViewController *)controller
{
    [self close];
}

- (void) DJLConversationViewValidateToolbar:(DJLConversationViewController *)controller
{
    _toolbarEnabled = YES;
    [_conversationToolbarView validate];
}

- (void) DJLConversationViewDisableToolbar:(DJLConversationViewController *)controller
{
    _toolbarEnabled = NO;
    [_conversationToolbarView validate];
}

- (void) DJLConversationViewController:(DJLConversationViewController *)controller setFrom:(NSString *)from subject:(NSString *)subject
{
    NSString * title = @"Conversation";
    if (from != nil) {
        if ([subject length] > 0) {
            title = [NSString stringWithFormat:@"%@ - %@", from, subject];
        }
        else {
            title = [NSString stringWithFormat:@"%@", from];
        }
    }
    [[self window] setTitle:title];
}

#pragma mark -
#pragma mark conversation toolbar delegate

- (void) DJLConversationToolbarViewReply:(DJLConversationToolbarView *)view
{
    [self _replyMessage];
}

- (void) DJLConversationToolbarViewForward:(DJLConversationToolbarView *)view
{
    [self _forwardMessage];
}

- (void) DJLConversationToolbarViewArchive:(DJLConversationToolbarView *)view
{
    [[self delegate] DJLConversationWindowControllerArchive:self];
    [self close];
}

- (void) DJLConversationToolbarViewTrash:(DJLConversationToolbarView *)view
{
    [self _delete];
}

- (void) DJLConversationToolbarViewLabel:(DJLConversationToolbarView *)view
{
    [self _showLabelsPopOverAndArchive:NO];
}

- (void) DJLConversationToolbarViewSaveAttachments:(DJLConversationToolbarView *)view
{
    [_viewController saveAllAttachments:nil];
}

- (void) DJLConversationToolbarViewEditDraft:(DJLConversationToolbarView *)view
{
    [_viewController editDraft];
    [self close];
}

- (void) DJLConversationToolbarViewFocusWebView:(DJLConversationToolbarView *)view
{
    [[self window] makeFirstResponder:[_viewController view]];
}

- (void) DJLConversationToolbarViewSearch:(DJLConversationToolbarView *)view
{
    [_viewController searchWithString:[_conversationToolbarView searchString]];
}

- (void) DJLConversationToolbarViewCancelSearch:(DJLConversationToolbarView *)view
{
    [_viewController cancelSearch];
    [[self window] makeFirstResponder:[_viewController view]];
}

- (void) DJLConversationToolbarViewSearchNext:(DJLConversationToolbarView *)view
{
    [_viewController findNext:nil];
}

#define WIDTH 300
#define HEIGHT 500

- (void) _showLabelsPopOverAndArchive:(BOOL)archive
{
    if ([_labelsPopOver isShown]) {
        return;
    }

    int64_t convID = [_viewController convID];
    NSDictionary * info = MCO_TO_OBJC([_viewController storageView]->conversationsInfoForConversationID(convID));

    DJLLabelsViewController * labelsViewController = [[DJLLabelsViewController alloc] init];
    [labelsViewController setArchiveEnabled:archive];
    if (![self account]->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        [labelsViewController setArchiveEnabled:YES];
    }
    [labelsViewController setDelegate:self];
    [[labelsViewController view] setFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
    [labelsViewController setConversations:@[info]];
    [labelsViewController setAccount:[self account]];
    [labelsViewController setStorageView:[self storageView]];
    [labelsViewController setFolderPath:MCO_TO_OBJC([self account]->pathForFolderID([self storageView]->folderID()))];
#if 0
    int64_t trashFolderID = [self account]->folderIDForPath([self account]->trashFolderPath());
    if (trashFolderID != -1) {
        [labelsViewController setTrash:[self storageView]->folderID() == trashFolderID];
    }
#endif
    [labelsViewController reloadData];
    _labelsPopOver = [[NSPopover alloc] init];
    [_labelsPopOver setContentViewController:labelsViewController];
    [_labelsPopOver setBehavior:NSPopoverBehaviorTransient];
    [_labelsPopOver setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    [_labelsPopOver showRelativeToRect:[_conversationToolbarView labelButtonRect] ofView:_conversationToolbarView
                         preferredEdge:NSMinYEdge];
}

#pragma mark DJLLabelsViewController delegate

- (void) DJLLabelsViewControllerClose:(DJLLabelsViewController *)controller
{
    [_labelsPopOver close];
}

#pragma mark MailStorage observer

- (void) _deletedConversations:(NSArray *)deleted
{
    if ([deleted containsObject:[NSNumber numberWithLongLong:[self convID]]]) {
        [self close];
    }
}

#pragma mark menuvalidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return [_viewController validateMenuItem:menuItem];
}

- (BOOL) DJLToolbarView:(DJLToolbarView *)toolbar validate:(SEL)selector
{
    if (!_toolbarEnabled) {
        return NO;
    }
    NSMenuItem * item = [[NSMenuItem alloc] init];
    [item setAction:selector];
    return [self validateMenuItem:item];
}

@end
