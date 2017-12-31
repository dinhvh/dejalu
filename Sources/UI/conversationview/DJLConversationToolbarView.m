// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationToolbarView.h"

#import "DJLGradientSeparatorLineView.h"
#import "NSImage+DJLColored.h"
#import "DJLSearchField.h"
#import "DJLToolbarButton.h"

@implementation DJLConversationToolbarView {
    DJLToolbarButton * _attachmentsButton;
    DJLToolbarButton * _archiveButton;
    DJLToolbarButton * _replyButton;
    DJLToolbarButton * _labelButton;
    DJLToolbarButton * _trashButton;
    DJLToolbarButton * _forwardButton;
    NSButton * _editDraftButton;
    DJLSearchField * _searchField;
    __weak id <DJLConversationToolbarViewDelegate> _delegate;
}

@synthesize delegate = _delegate;
@synthesize draft = _draft;
@synthesize windowMode = _windowMode;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    _trashButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 180, 8, 20, 20)];
    NSImage * originImage = [NSImage imageNamed:@"DejaLu_Trash_16"];
    NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_trashButton setImage:img];
    [_trashButton setTarget:self];
    [_trashButton setAction:@selector(_trash)];
    [_trashButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_trashButton];
    [self setButtonValidation:_trashButton selector:@selector(deleteMessage:)];

    _archiveButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 150, 8, 20, 20)];
    originImage = [NSImage imageNamed:@"DejaLu_Archive_16"];
    //originImage = [originImage copy];
    //[originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_archiveButton setImage:img];
    [_archiveButton setTarget:self];
    [_archiveButton setAction:@selector(_archive)];
    [_archiveButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_archiveButton];
    [self setButtonValidation:_archiveButton selector:@selector(archiveMessage:)];

    _labelButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 120, 8, 20, 20)];
    originImage = [NSImage imageNamed:@"DejaLu_TagOff_16"];
//    originImage = [originImage copy];
//    [originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_labelButton setImage:img];
    [_labelButton setTarget:self];
    [_labelButton setAction:@selector(_label)];
    [_labelButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_labelButton];
    [self setButtonValidation:_labelButton selector:@selector(showLabelsPanel:)];

    _attachmentsButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 90, 8, 20, 20)];
    [[_attachmentsButton cell] setHighlightsBy:NSContentsCellMask];
    originImage = [NSImage imageNamed:@"DejaLu_Attachment_16"];
//    originImage = [originImage copy];
//    [originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_attachmentsButton setImage:img];
    [_attachmentsButton setTarget:self];
    [_attachmentsButton setAction:@selector(_saveAttachments)];
    [_attachmentsButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_attachmentsButton];
    [self setButtonValidation:_attachmentsButton selector:@selector(saveAllAttachments:)];

    _forwardButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 60, 8, 20, 20)];
    originImage = [NSImage imageNamed:@"DejaLu_Forward_16"];
//    originImage = [originImage copy];
//    [originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_forwardButton setImage:img];
    [_forwardButton setTarget:self];
    [_forwardButton setAction:@selector(_forward)];
    [_forwardButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_forwardButton];
    [self setButtonValidation:_forwardButton selector:@selector(forwardMessage:)];

    _replyButton = [[DJLToolbarButton alloc] initWithFrame:NSMakeRect(frame.size.width - 30, 8, 20, 20)];
    originImage = [NSImage imageNamed:@"DejaLu_Reply_16"];
//    originImage = [originImage copy];
//    [originImage setSize:NSMakeSize(20, 20)];
    img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]];
    [_replyButton setImage:img];
    [_replyButton setTarget:self];
    [_replyButton setAction:@selector(_reply)];
    [_replyButton setAutoresizingMask:NSViewMinXMargin];
    [self addSubview:_replyButton];
    [self setButtonValidation:_replyButton selector:@selector(replyMessage:)];

#define SEARCH_WIDTH 250
    _searchField = [[DJLSearchField alloc] initWithFrame:NSMakeRect((int) ((frame.size.width - SEARCH_WIDTH) / 2), 7, SEARCH_WIDTH, 22)];
    [_searchField setFont:[NSFont systemFontOfSize:13]];
    [_searchField setFocusRingType:NSFocusRingTypeNone];
    // cast to id to avoid typing to NSSearchFieldDelegate (which is available in 10.11 only).
    [_searchField setDelegate:(id) self];
    [_searchField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin];
    [self addSubview:_searchField];
    [_searchField setAlphaValue:0.0];
    [_searchField setHidden:YES];
    [_searchField setTarget:self];
    [_searchField setAction:@selector(_findNext)];

    _editDraftButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 5, 20, 20)];
    [_editDraftButton setFont:[NSFont boldSystemFontOfSize:14]];
    [_editDraftButton setShowsBorderOnlyWhileMouseInside:YES];
    [_editDraftButton setBezelStyle:NSRecessedBezelStyle];
    [_editDraftButton setTitle:@"Edit Draft"];
    [_editDraftButton sizeToFit];
    frame = [_editDraftButton frame];
    frame.size.height += 6;
    [_editDraftButton setFrame:frame];
    [_editDraftButton setTarget:self];
    [_editDraftButton setAction:@selector(_editDraft)];
    [self addSubview:_editDraftButton];

    [self setViewsToFade:@[_attachmentsButton, _labelButton, _replyButton, _archiveButton, _forwardButton, _trashButton]];

    return self;
}

- (void) setDraft:(BOOL)draft
{
    _draft = draft;
    [_editDraftButton setHidden:!draft];
    [_editDraftButton updateTrackingAreas];
}

- (void) setWindowMode:(BOOL)windowMode
{
    _windowMode = windowMode;
    NSRect frame = [_editDraftButton frame];
    if (_windowMode) {
        frame.origin.x = 80;
    }
    else {
        frame.origin.x = 10;
    }
    [_editDraftButton setFrame:frame];
}

- (void) _saveAttachments
{
    [[self delegate] DJLConversationToolbarViewSaveAttachments:self];
}

- (void) _archive
{
    [[self delegate] DJLConversationToolbarViewArchive:self];
}

- (void) _trash
{
    [[self delegate] DJLConversationToolbarViewTrash:self];
}

- (void) _reply
{
    [[self delegate] DJLConversationToolbarViewReply:self];
}

- (void) _label
{
    [[self delegate] DJLConversationToolbarViewLabel:self];
}

- (void) _forward
{
    [[self delegate] DJLConversationToolbarViewForward:self];
}

- (void) _editDraft
{
    [[self delegate] DJLConversationToolbarViewEditDraft:self];
}

- (void) focusSearch
{
    [_searchField setHidden:NO];
    [_searchField setAlphaValue:1.0];
    [[self window] makeFirstResponder:_searchField];
}

- (void) djl_searchFieldOperationCancelled:(DJLSearchField *)searchField
{
    [self _hideSearchFieldAfterDelay];
    [[self delegate] DJLConversationToolbarViewFocusWebView:self];
}

- (void) _hideSearchFieldAfterDelay
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_tryHideSearch) object:nil];
    [self performSelector:@selector(_tryHideSearch) withObject:nil afterDelay:2.0];
}

- (void) _tryHideSearch
{
    if ([[self window] firstResponder] == [[self window] fieldEditor:NO forObject:_searchField]) {
        return;
    }
    if ([[_searchField stringValue] length] != 0) {
        return;
    }
    [[self delegate] DJLConversationToolbarViewCancelSearch:self];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [_searchField setHidden:YES];
    }];
    [[_searchField animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

- (void) djl_searchFieldResignFirstResponder:(DJLSearchField *)searchField
{
    [self _hideSearchFieldAfterDelay];
    [[self delegate] DJLConversationToolbarViewFocusWebView:self];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    [self _hideSearchFieldAfterDelay];
    [[self delegate] DJLConversationToolbarViewFocusWebView:self];
}

/*
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if (control == _searchField) {
        [self _hideSearchFieldAfterDelay];
        return YES;
    }
    else {
        return YES;
    }
}
 */

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
    [[self delegate] DJLConversationToolbarViewSearch:self];
}

- (void) _findNext
{
    [[self delegate] DJLConversationToolbarViewSearchNext:self];
}

- (NSString *) searchString
{
    return [_searchField stringValue];
}

- (BOOL) isSearchFieldVisible
{
    return ![_searchField isHidden];
}

- (NSRect) labelButtonRect
{
    return [_labelButton frame];
}

#pragma mark validation

- (void) saveAllAttachments:(id)sender {}
- (void) showLabelsPanel:(id)sender {}
- (void) archiveMessage:(id)sender {}
- (void) replyMessage:(id)sender {}
- (void) forwardMessage:(id)sender {}
- (void) deleteMessage:(id)sender {}

@end
