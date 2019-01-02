// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationViewController.h"

#import <Quartz/Quartz.h>
#import <GoogleAnalyticsTracker/GoogleAnalyticsTracker.h>

#import "MCOCIDURLProtocol.h"
#import "DJLPathManager.h"
#import "NSString+DJL.h"
#import "DJLAddressBookManager.h"
#import "FBKVOController.h"
#import "DJLPrintMessageController.h"
#import "DJLWindow.h"

#include "DJLLog.h"
#include "Hermes.h"

#define LOG(...) DJLLogWithID("storage", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("storage", __VA_ARGS__)

using namespace mailcore;
using namespace hermes;

static NSDictionary * GetIconInfo(NSString * ext);;

@interface DJLQLPreviewItem : NSObject <QLPreviewItem>

- (id) initWithInfos:(NSDictionary *)infos webView:(WebView *)webView;

@property (retain) NSURL * previewItemURL;
@property (nonatomic, assign) IMAPAttachmentDownloader * downloader;

//- (NSURL *) previewItemURL;
- (NSString *) previewItemTitle;
- (NSRect) frame;

@end

@interface DJLConversationViewController () <QLPreviewPanelDelegate, QLPreviewPanelDataSource,
WebPolicyDelegate, WebFrameLoadDelegate, WebResourceLoadDelegate, WebUIDelegate>

- (void) _operationFinished:(Operation *)op;

- (void) _storageViewModifiedConversations:(NSArray *)modified
                      deletedConversations:(NSArray *)deleted;

- (void) _storageViewAddedMessageParts:(Array *)messageParts;

@end

class DJLConversationViewControllerCallback : public Object, public OperationCallback, public MailStorageViewObserver {
public:
    DJLConversationViewControllerCallback(DJLConversationViewController * controller)
    {
        mController = controller;
    }

    virtual void operationFinished(Operation * op)
    {
        [mController _operationFinished:op];
    }

    virtual void mailStorageViewModifiedDeletedConversations(MailStorageView * view,
                                                             mailcore::Array * modified,
                                                             mailcore::Array * deleted)
    {
        [mController _storageViewModifiedConversations:MCO_TO_OBJC(modified)
                                  deletedConversations:MCO_TO_OBJC(deleted)];
    }

    virtual void mailStorageViewAddedMessageParts(MailStorageView * view,
                                                  mailcore::Array * /* MailDBMeessagePartInfo */ messageParts)
    {
        [mController _storageViewAddedMessageParts:messageParts];
    }

    __weak DJLConversationViewController * mController;
};

@implementation DJLConversationViewController {
    int64_t _convID;
    MailDBConversationMessagesOperation * _messagesOp;
    MailStorageView * _storageView;
    hermes::Account * _account;
    DJLConversationViewControllerCallback * _callback;
    Array * _pendingOps;
    NSMutableDictionary * _parametersForOp;
    BOOL _setupDone;
    BOOL _loadConversationRequested;
    __weak id<DJLConversationViewControllerDelegate> _delegate;
    WebView * _webView;
    NSString * _temporaryFolder;
    Array * _attachmentDownloaders;
    Array * _attachmentToOpenDownloaders;
    NSInteger _quickLookItemToSelect;
    NSArray * _quickLookItems;
    NSMutableArray * _quickLookPreviewItems;
    Array * _attachmentToQuickLookDownloaders;
    NSMutableArray * _downloadsInProgressSelf;
    BOOL _draggingAttachment;
    MCOAddress * _currentAddress;
    dispatch_queue_t _queue;
    FBKVOController * _kvoController;
    DJLPrintMessageController * _printController;
}

@synthesize convID = _convID;
@synthesize delegate = _delegate;

#if 0
+ (void) initialize
{
    [MCOCIDURLProtocol registerProtocol];
}
#endif

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    _callback = new DJLConversationViewControllerCallback(self);
    
    _pendingOps = new Array();
    _parametersForOp = [[NSMutableDictionary alloc] init];
    //_messages = [[NSMutableDictionary alloc] init];
    //_saveAttachmentOps = new Array();
    _attachmentDownloaders = new Array();
    _attachmentToOpenDownloaders = new Array();
    _attachmentToQuickLookDownloaders = NULL;
    _downloadsInProgressSelf = [[NSMutableArray alloc] init];

    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:[NSUserDefaults standardUserDefaults] keyPath:@"ShowCellDebugInfo" options:0 block:^(id observer, id object, NSDictionary * change) {
        [weakSelf _updateDebugMode];
    }];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setStorageView:NULL];
    [self _cancelCurrentLoadConversation];
    MC_SAFE_RELEASE(_pendingOps);
    MC_SAFE_RELEASE(_callback);
    MC_SAFE_RELEASE(_attachmentDownloaders);
    MC_SAFE_RELEASE(_attachmentToOpenDownloaders);
    MC_SAFE_RELEASE(_attachmentToQuickLookDownloaders);
    MC_SAFE_RELEASE(_account);
}

- (void) setup
{
    NSString * filename = [[NSBundle mainBundle] pathForResource:@"conversation-view" ofType:@"html"];
    NSString * htmlString = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    [[_webView mainFrame] loadHTMLString:htmlString baseURL:[[NSBundle mainBundle] resourceURL]];
    
    NSScrollView * mainScrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    [mainScrollView setVerticalScrollElasticity:NSScrollElasticityAllowed];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrolled) name:NSViewBoundsDidChangeNotification object:[mainScrollView contentView]];
    [self _scrolled];

    [_webView setPolicyDelegate:self];
    [_webView setResourceLoadDelegate:self];
    [_webView setUIDelegate:self];
    [_webView setFrameLoadDelegate:self];
    [_webView setEditingDelegate:(id<WebEditingDelegate>)self];
    [[_webView windowScriptObject] setValue:self forKey:@"Controller"];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];
}

- (void) unsetup
{
    [_webView setPolicyDelegate:nil];
    [_webView setResourceLoadDelegate:nil];
    [_webView setUIDelegate:nil];
    [_webView setFrameLoadDelegate:nil];
    [_webView setEditingDelegate:nil];
    [[_webView windowScriptObject] setValue:nil forKey:@"Controller"];
    [_webView removeFromSuperview];
    _webView = nil;
}

- (NSView *) view
{
    if (_webView != nil) {
        return _webView;
    }
    _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0) frameName:nil groupName:nil];
    [_webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    return _webView;
}

- (void) setStorageView:(hermes::MailStorageView *)storageView
{
    if (_storageView != NULL) {
        _storageView->removeObserver(_callback);
        if (_storageView->folderID() != -1) {
            _account->closeViewForFolder(_storageView->folderID());
        }
    }
    MC_SAFE_REPLACE_RETAIN(MailStorageView, _storageView, storageView);
    if (_storageView != NULL) {
        if (_storageView->folderID() != -1) {
            _account->openViewForFolder(_storageView->folderID());
        }
        _storageView->addObserver(_callback);
        BOOL draftEnabled = _storageView->draftsFolderID() == _storageView->folderID();
        [[self delegate] DJLConversationView:self draftEnabled:draftEnabled];
    }
}

- (hermes::MailStorageView *) storageView
{
    return _storageView;
}

- (void) setAccount:(hermes::Account *)account
{
    if (_account != account) {
        [self setStorageView:NULL];
    }
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
}

- (hermes::Account *) account
{
    return _account;
}

- (void) _scrolled
{
    CGFloat alpha = 0.0;
    NSScrollView * mainScrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    if ([[mainScrollView contentView] bounds].origin.y > 50.) {
        alpha = 1.0;
    }
    else if ([[mainScrollView contentView] bounds].origin.y < 0) {
        alpha = 0.0;
    }
    else {
        alpha = [[mainScrollView contentView] bounds].origin.y / 50.;
    }
    [[self delegate] DJLConversationViewController:self separatorAlphaValue:alpha];
}

- (BOOL) hasAttachmentSelection
{
    NSNumber * nb = [[_webView windowScriptObject] callWebScriptMethod:@"objcHasAttachmentSelection" withArguments:nil];
    return [nb boolValue];
}

- (void) editDraft
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcEditDraftMessage" withArguments:nil];
}

- (void) findInText:(id)sender
{
    [[self delegate] DJLConversationViewSearch:self];
}

- (void) findNext:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcFocusNextSearchResult" withArguments:nil];
}

- (void) findPrevious:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcFocusPreviousSearchResult" withArguments:nil];
}

- (void) showLabelsPanel:(id)sender
{
    [[self delegate] DJLConversationViewShowLabelsPanel:self archive:NO];
}

- (void) showLabelsAndArchivePanel:(id)sender
{
    [[self delegate] DJLConversationViewShowLabelsPanel:self archive:YES];
}

- (void) searchWithString:(NSString *)searchString
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcHighlightSearchResult" withArguments:@[searchString]];
}

- (void) cancelSearch
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcClearSearchResult" withArguments:nil];
}

- (void) printDocument:(id)sender
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Conversation" action:@"Print" label:@"print a message" value:@(0)];
    NSString * jsonInfo = [[_webView windowScriptObject] callWebScriptMethod:@"objcHTMLForSelectedMessage" withArguments:nil];
    if (![jsonInfo isKindOfClass:[NSString class]]) {
        return;
    }
    NSDictionary * info = [NSJSONSerialization JSONObjectWithData:[jsonInfo dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];


    _printController = [[DJLPrintMessageController alloc] init];
    [_printController printMessageWithHTML:info[@"message"] header:info[@"header"]];
    //[_printController showWindow:nil];
    //NSLog(@"%@", html);
}

#pragma mark -
#pragma mark WebView delegate

- (void) webView:(WebView *)sender addMessageToConsole:(NSDictionary *)message withSource:(NSString *)source
{
	NSString * filename;
	NSObject * lineNumber;
	NSObject * messageString;
	NSURL * url;
	
	url = [NSURL URLWithString:[message objectForKey:@"sourceURL"]];
	filename = [[url path] lastPathComponent];
	lineNumber = [message objectForKey:@"lineNumber"];
	messageString = [message objectForKey:@"message"];
	
    //NSLog(@"(%s:%s) %s", [filename UTF8String], [[lineNumber description] UTF8String], [[messageString description] UTF8String]);
    LOG("(%s:%s) %s", [filename UTF8String], [[lineNumber description] UTF8String], [[messageString description] UTF8String]);
}

- (void) _openURL:(NSURL *)url modifierKeys:(NSInteger)modifierKeys
{
    [[NSWorkspace sharedWorkspace] openURL:url];
    if ((modifierKeys & NSCommandKeyMask) != 0) {
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
	NSInteger modifierKeys = [[actionInformation objectForKey:WebActionModifierFlagsKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            if ([[request URL] isFileURL] && [[[request URL] path] isEqualToString:[[NSBundle mainBundle] resourcePath]]) {
                [listener use];
                return;
            }
            
            [self _openURL:[request URL] modifierKeys:modifierKeys];
            [listener ignore];
            break;
            
        case WebNavigationTypeOther:
        default:
            [listener use];
            break;
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)newFrameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
	NSInteger modifierKeys = [[actionInformation objectForKey:WebActionModifierFlagsKey] intValue];
    
    switch(navType) {
        case WebNavigationTypeLinkClicked:
            if ([[request URL] isFileURL] && [[[request URL] path] isEqualToString:[[NSBundle mainBundle] resourcePath]]) {
                [listener use];
                return;
            }
            
            [self _openURL:[request URL] modifierKeys:modifierKeys];
            [listener ignore];
            break;
            
        case WebNavigationTypeOther:
        default:
            [listener use];
            break;
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    _setupDone = YES;
    [self _updateDebugMode];
    [self _loadConversationIfRequested];
    [self _scrollerStyleChanged];
}

- (void) _scrollerStyleChanged
{
    NSScrollView *mainScrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    [mainScrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (BOOL)webView:(WebView *)webView shouldChangeSelectedDOMRange:(DOMRange *)currentRange toDOMRange:(DOMRange *)proposedRange affinity:(NSSelectionAffinity)selectionAffinity stillSelecting:(BOOL)flag
{
    DOMNode * node;
    NSNumber * nb;

    node = [proposedRange commonAncestorContainer];
    if (node == nil)
        return YES;

    nb = [[_webView windowScriptObject] callWebScriptMethod:@"objcIsNodeTextContents" withArguments:[NSArray arrayWithObject:node]];
    return [nb boolValue];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(id)dataSource
{
    NSString * scheme = [[request URL] scheme];
    if ([scheme isEqualTo:@"https"] || [scheme isEqualTo:@"http"] || [scheme isEqualTo:@"file"] || [scheme isEqualTo:@"data"]) {
        return request;
    }
    return [NSURLRequest requestWithURL:[NSURL fileURLWithPath:@"/dev/null"]];
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)command
{
    if (command == @selector(selectAll:)) {
        [self _selectAll];
        return YES;
    }
    else {
        return NO;
    }
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    BOOL hasMessage = NO;
    [[_webView windowScriptObject] callWebScriptMethod:@"objcDeselectContextMenu" withArguments:nil];
    DOMNode * node = [element objectForKey:@"WebElementDOMNode"];
    while (node != nil) {
        if ([node isKindOfClass:[DOMHTMLElement class]]) {
            DOMHTMLElement * elt = (DOMHTMLElement *) node;
            NSString * className = [elt className];
            NSArray * classList = [className componentsSeparatedByString:@" "];
            if ([classList containsObject:@"message"]) {
                [elt setClassName:[className stringByAppendingString:@" context-menu-selected"]];
                hasMessage = YES;
                break;
            }
        }
        node = [node parentElement];
    }

    NSString * attachmentInfoJSON = [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectedAttachment" withArguments:nil];
    NSDictionary * attachmentInfo = [NSJSONSerialization JSONObjectWithData:[attachmentInfoJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];

    NSMutableArray * filteredMenu = [[NSMutableArray alloc] init];
    for(NSMenuItem * item in defaultMenuItems) {
        //NSLog(@"%@", NSStringFromSelector([item action]));
        switch ([item tag]) {
            case WebMenuItemTagCopyLinkToClipboard:
            case WebMenuItemTagCopyImageToClipboard:
            case WebMenuItemTagCopy:
            case WebMenuItemTagCut:
            case WebMenuItemTagPaste:
            case WebMenuItemTagSpellingGuess:
            case WebMenuItemTagNoGuessesFound:
            case WebMenuItemTagIgnoreSpelling:
            case WebMenuItemTagLearnSpelling:
            case WebMenuItemTagSearchInSpotlight:
            case WebMenuItemTagLookUpInDictionary:
            case 2024: // Inspect element
                [filteredMenu addObject:item];
                break;
            case WebMenuItemTagSearchWeb:
            {
                NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[item title]
                                                      action:@selector(_searchInGoogle:)
                                               keyEquivalent:[item keyEquivalent]];
                [menuItem setTarget:self];
                [filteredMenu addObject:menuItem];
                break;
            }

            default:
                if ([item isSeparatorItem]) {
                    if (![(NSMenuItem *) [filteredMenu lastObject] isSeparatorItem]) {
                        [filteredMenu addObject:item];
                    }
                }
                //NSLog(@"%i %@", (int) [item tag], [item title]);
                break;
        }
    }
    if (attachmentInfo != nil) {
        if (![(NSMenuItem *) [filteredMenu lastObject] isSeparatorItem]) {
            [filteredMenu addObject:[NSMenuItem separatorItem]];
        }
        {
            NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:@"Save Attachment"
                                                               action:@selector(_saveAttachment:)
                                                        keyEquivalent:@""];
            [menuItem setTarget:self];
            [filteredMenu addObject:menuItem];
        }
        {
            NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:@"Save Attachment As..."
                                                               action:@selector(_saveAttachmentAs:)
                                                        keyEquivalent:@""];
            [menuItem setTarget:self];
            [filteredMenu addObject:menuItem];
        }
    }
    if (hasMessage) {
        if (![(NSMenuItem *) [filteredMenu lastObject] isSeparatorItem]) {
            [filteredMenu addObject:[NSMenuItem separatorItem]];
        }
        {
            NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:@"Show Original Format"
                                                               action:@selector(_showOriginalFormat:)
                                                        keyEquivalent:@""];
            [menuItem setTarget:self];
            [filteredMenu addObject:menuItem];
        }
        {
            NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:@"Show Source of Message"
                                                               action:@selector(_showSource:)
                                                        keyEquivalent:@""];
            [menuItem setTarget:self];
            [filteredMenu addObject:menuItem];
        }
    }
    return filteredMenu;
}

- (void) _searchInGoogle:(id)sender
{
    NSString * value;

    value = [[_webView selectedDOMRange] toString];

    if ([value length] > 0) {
        NSString * urlString = [NSString stringWithFormat:@"http://www.google.com/search?q=%@&ie=UTF-8&oe=UTF-8", [value djlURLEncode]];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    }
}

- (void) _showOriginalFormat:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcShowOriginalFormat" withArguments:nil];
}

- (void) _showSource:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcShowSource" withArguments:nil];
}

- (void) _saveAttachment:(id)sender
{
    NSString * attachmentInfoJSON = [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectedAttachment" withArguments:nil];
    NSDictionary * attachmentInfo = [NSJSONSerialization JSONObjectWithData:[attachmentInfoJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    NSNumber * nbFolderID = attachmentInfo[@"folderid"];
    int64_t folderID = [nbFolderID longLongValue];
    NSNumber * nbRowID = attachmentInfo[@"rowid"];
    int64_t messageRowID = [nbRowID longLongValue];
    NSString * uniqueID = attachmentInfo[@"uniqueID"];
    NSString * filename = attachmentInfo[@"filename"];
    NSString * downloadFolder = [@"~/Downloads" stringByExpandingTildeInPath];
    String * folder = MCO_FROM_OBJC(String, downloadFolder);
    if (filename == nil) {
        filename = @"Untitled";
    }
    filename = [filename stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    NSString * path = MCO_TO_OBJC(hermes::uniquePath(folder, MCO_FROM_OBJC(String, filename)));
    [[NSData data] writeToFile:path atomically:NO];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:path]]];

    [self _saveAttachmentWithFolderID:folderID messageRowID:messageRowID uniqueID:uniqueID
                             filename:path];
}

- (void) _saveAttachmentAs:(id)sender
{
    NSString * attachmentInfoJSON = [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectedAttachment" withArguments:nil];
    NSDictionary * attachmentInfo = [NSJSONSerialization JSONObjectWithData:[attachmentInfoJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    NSString * filename = attachmentInfo[@"filename"];
    NSNumber * nbFolderID = attachmentInfo[@"folderid"];
    int64_t folderID = [nbFolderID longLongValue];
    NSNumber * nbRowID = attachmentInfo[@"rowid"];
    int64_t messageRowID = [nbRowID longLongValue];
    NSString * uniqueID = attachmentInfo[@"uniqueID"];

    NSSavePanel * panel = [NSSavePanel savePanel];
    NSString * downloadFolder = [@"~/Downloads" stringByExpandingTildeInPath];
    [panel setDirectoryURL:[NSURL fileURLWithPath:downloadFolder]];
    [panel setNameFieldStringValue:filename];
    __weak typeof(self) weakSelf = self;
    [(DJLWindow *) [[self view] window] _workaroundSheetLayoutTrafficLights];
    [panel beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton) {
            return;
        }

        NSString * destinationFilename = [[panel URL] path];
        [[NSData data] writeToFile:destinationFilename atomically:NO];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:destinationFilename]]];
        [weakSelf _saveAttachmentWithFolderID:folderID messageRowID:messageRowID uniqueID:uniqueID
                                     filename:destinationFilename];
    }];

}

- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
    return WebDragDestinationActionNone;
}

- (NSUInteger)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point
{
    _draggingAttachment = NO;
    NSDictionary * info = [_webView elementAtPoint:point];
    DOMNode * node = [info objectForKey:@"WebElementDOMNode"];
    while (node != nil) {
        if ([node isKindOfClass:[DOMHTMLElement class]]) {
            DOMHTMLElement * elt = (DOMHTMLElement *) node;
            NSString * className = [elt className];
            NSArray * classList = [className componentsSeparatedByString:@" "];
            if ([classList containsObject:@"embedded-image-container"] ||
                [classList containsObject:@"image-container"] ||
                [classList containsObject:@"attachment-container"]) {
                _draggingAttachment = YES;
                break;
            }
        }
        node = [node parentElement];
    }

    return WebDragSourceActionAny;
}

- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action fromPoint:(NSPoint)point withPasteboard:(NSPasteboard *)pasteboard
{
    if (_draggingAttachment) {
        NSString * attachmentInfoJSON = [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectedAttachment" withArguments:nil];
        NSDictionary * attachmentInfo = [NSJSONSerialization JSONObjectWithData:[attachmentInfoJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        NSString * filename = attachmentInfo[@"filename"];
        if (filename == nil) {
            filename = @"Untitled";
        }

        [pasteboard clearContents];
        [pasteboard declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];
        [pasteboard setPropertyList:[NSArray arrayWithObject:[filename pathExtension]] forType:NSFilesPromisePboardType];
    }
}

- (NSArray *)DJLWebHTMLView:(WebView *)webView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
    NSString * attachmentInfoJSON = [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectedAttachment" withArguments:nil];
    NSDictionary * attachmentInfo = [NSJSONSerialization JSONObjectWithData:[attachmentInfoJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    NSNumber * nbFolderID = attachmentInfo[@"folderid"];
    int64_t folderID = [nbFolderID longLongValue];
    NSNumber * nbRowID = attachmentInfo[@"rowid"];
    int64_t messageRowID = [nbRowID longLongValue];
    NSString * uniqueID = attachmentInfo[@"uniqueID"];
    NSString * filename = attachmentInfo[@"filename"];
    String * folder = MCO_FROM_OBJC(String, [dropDestination path]);
    if (filename == nil) {
        filename = @"Untitled";
    }
    filename = [filename stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    NSString * path = MCO_TO_OBJC(hermes::uniquePath(folder, MCO_FROM_OBJC(String, filename)));
    [[NSData data] writeToFile:path atomically:NO];

    [self _saveAttachmentWithFolderID:folderID messageRowID:messageRowID uniqueID:uniqueID
                             filename:path];
    return @[[path lastPathComponent]];
}

- (void) _operationFinished:(Operation *)op
{
    if (op->className()->isEqual(MCSTR("hermes::MailDBConversationMessagesOperation"))) {
        [self _jsLoadMessagesFinished:(MailDBConversationMessagesOperation *) op];
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBMessageInfoOperation"))) {
        [self _jsLoadMessageFinished:(MailDBMessageInfoOperation *) op];
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBRetrievePartOperation"))) {
        [self _jsLoadImageFinished:(MailDBRetrievePartOperation *) op];
    }
    else if (op->className()->isEqual(MCSTR("hermes::IMAPAttachmentDownloader"))) {
        [self _saveAttachmentFinished:(IMAPAttachmentDownloader *) op];
    }
}

- (void) _storageViewModifiedConversations:(NSArray *)modified
                      deletedConversations:(NSArray *)deleted
{
    if ([modified containsObject:[NSNumber numberWithLongLong:_convID]]) {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcUpdateConversation" withArguments:nil];
    }
}

- (void) _storageViewAddedMessageParts:(Array *)messageParts
{
    mc_foreacharray(MailDBMessagePartInfo, info, messageParts) {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcLoadImagesForMessageWithRowID" withArguments:@[[NSNumber numberWithLongLong:info->messageRowID()]]];
    }
}

- (void) loadConversation
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Conversation" action:@"Open" label:@"open a conversation" value:@(0)];

    BOOL draftEnabled = _storageView->draftsFolderID() == _storageView->folderID();
    [[self delegate] DJLConversationView:self draftEnabled:draftEnabled];

    [self _cancelCurrentLoadConversation];

    _temporaryFolder = nil;
    _loadConversationRequested = YES;
    [self _validateToolbar];
    [self _loadConversationIfRequested];
}

- (void) _cancelCurrentLoadConversation
{
    mc_foreacharray(IMAPAttachmentDownloader, downloader, _attachmentDownloaders) {
        downloader->cancel();
    }
    _attachmentDownloaders->removeAllObjects();
    _attachmentToOpenDownloaders->removeAllObjects();
    if (_attachmentToQuickLookDownloaders != NULL) {
        _attachmentToQuickLookDownloaders->removeAllObjects();
    }
    _loadConversationRequested = NO;
    mc_foreacharray(MailDBOperation, op, _pendingOps) {
        op->cancel();
    }
    _pendingOps->removeAllObjects();

    // XXX - clear content
}

- (NSString *) _recipientStrForInfo:(NSDictionary *)info
{
    if (info[@"listid"] != nil) {
        return info[@"listid"];
    }

    NSArray * senders = info[@"senders"];
    return [senders componentsJoinedByString:@", "];
}

- (void) _loadConversationIfRequested
{
    if (!_setupDone) {
        return;
    }
    
    if (!_loadConversationRequested) {
        return;
    }
    
    _loadConversationRequested = NO;
    HashMap * info = _storageView->conversationsInfoForConversationID(_convID);
    if (info == NULL) {
        return;
    }
    String * json = JSON::objectToJSONString(info);
    if ([[self delegate] respondsToSelector:@selector(DJLConversationViewController:setFrom:subject:)]) {
        [[self delegate] DJLConversationViewController:self
                                               setFrom:[self _recipientStrForInfo:MCO_TO_OBJC(info)]
                                               subject:MCO_TO_OBJC(info->objectForKey(MCSTR("subject")))];
    }
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSetConversationHeader" withArguments:@[MCO_TO_OBJC(json)]];
    [self _validateToolbar];
}

- (void) _updateDebugMode
{
    BOOL debugEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowCellDebugInfo"];
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSetDebugModeEnabled" withArguments:@[@(debugEnabled)]];
}

- (void) replyMessage:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcReplyCurrentMessage" withArguments:nil];
}

- (void) forwardMessage:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcForwardCurrentMessage" withArguments:nil];
}

- (void) saveAllAttachments:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSaveAllAttachments" withArguments:nil];
}

- (void) deleteMessage:(id)sender
{
    LOG_ERROR("delete one message");
    [[self delegate] DJLConversationViewControllerDelete:self];
}

- (void) archiveMessage:(id)sender
{
    LOG_ERROR("archive one message");
    [[self delegate] DJLConversationViewControllerArchive:self];
}

#pragma mark -
#pragma mark JS runtime

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel
{
    NSString * selectorName = NSStringFromSelector(sel);
    
    if ([selectorName isEqualToString:@"jsRunCommand:"])
        return NO;
    
    return YES;
}

- (void) jsRunCommand:(NSString *)jsonCommand
{
    static NSMutableSet * authorizedCommands = nil;
    if (authorizedCommands == nil) {
        authorizedCommands = [[NSMutableSet alloc] init];
        [authorizedCommands addObjectsFromArray:@[@"jsLoadMessages",
                                                  @"jsLoadMessage",
                                                  @"jsLoadImage",
                                                  @"jsMarkMessageAsRead",
                                                  @"jsReplyMessage",
                                                  @"jsForwardMessage",
                                                  @"jsQuickLookAttachment",
                                                  @"jsSaveAllAttachments",
                                                  @"jsOpenAttachment",
                                                  @"jsArchive",
                                                  @"jsDelete",
                                                  @"jsEditDraftMessage",
                                                  @"jsShowAddressMenu",
                                                  @"jsShowMessageSource",
                                                  @"jsFocusConversationList",
                                                  @"jsCloseWindow"]];
    }
    
    NSData * data = [jsonCommand dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary * commandInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSString * command = [commandInfo objectForKey:@"command"];

    if (![authorizedCommands containsObject:command]) {
        NSLog(@"call from JS not authorized - %@", command);
        return;
    }

    command = [command stringByAppendingString:@":"];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(command) withObject:commandInfo];
#pragma clang diagnostic pop
}

#pragma mark Obj-C calls from JS

- (void) jsLoadMessages:(NSDictionary *)parameters
{
    MailDBConversationMessagesOperation * op = _storageView->messagesForPeopleConversationOperation(_convID);
    op->setCallback(_callback);
    op->start();
    
    _pendingOps->addObject(op);
    [_parametersForOp setObject:parameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
}

- (void) _jsLoadMessagesFinished:(MailDBConversationMessagesOperation *)op
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    String * json = JSON::objectToJSONString(op->messages());
    //NSLog(@"%@", MCO_TO_OBJC(json));
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, MCO_TO_OBJC(json)]];
    _pendingOps->removeObject(op);
    [_parametersForOp removeObjectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
}

- (void) jsLoadMessage:(NSDictionary *)parameters
{
    NSNumber * nbMessageRowID = [parameters objectForKey:@"messagerowid"];
    int64_t rowid = [nbMessageRowID longLongValue];
    MailDBMessageInfoOperation * op = _account->messageInfoOperation(rowid);
    op->setCallback(_callback);
    op->start();
    
    _pendingOps->addObject(op);
    [_parametersForOp setObject:parameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
}

- (void) _jsLoadMessageFinished:(MailDBMessageInfoOperation *)op
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    
    HashMap * info = op->messageInfo();
    NSNumber * nbMessageRowID = [parameters objectForKey:@"messagerowid"];
    if (info == NULL) {
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
        _pendingOps->removeObject(op);
        [_parametersForOp removeObjectForKey:uuid];
        return;
    }

    //[_messages setObject:MCO_TO_OBJC(info) forKey:nbMessageRowID];
    if (info->objectForKey(MCSTR("content")) == NULL) {
        NSNumber * nbFolderID = [parameters objectForKey:@"folderid"];
        _account->fetchMessageSummary([nbFolderID longLongValue], [nbMessageRowID longLongValue], true);
    }
    
    String * json = JSON::objectToJSONString(op->messageInfo());
    //NSLog(@"%@", MCO_TO_OBJC(json));
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, MCO_TO_OBJC(json)]];
    _pendingOps->removeObject(op);
    [_parametersForOp removeObjectForKey:uuid];
}


- (void) jsLoadImage:(NSDictionary *)parameters
{
    NSDictionary * msg = [parameters objectForKey:@"msg"];
    NSDictionary * info = [parameters objectForKey:@"messageinfo"];
    NSString * urlString = [parameters objectForKey:@"url"];
    NSURL * url = [NSURL URLWithString:urlString];
    NSMutableDictionary * opParameters = [parameters mutableCopy];

    AbstractPart * part = NULL;
    AbstractMessage * imapMsg = (IMAPMessage *) Object::objectWithSerializable(MCO_FROM_OBJC(HashMap, [info objectForKey:@"msg"]));
    if ((imapMsg == NULL) || ([url resourceSpecifier] == nil)) {
        LOG_ERROR("jsLoadImage, msg was NULL, %s %s", [[parameters description] UTF8String], [urlString UTF8String]);
    }
    if ([[url scheme] isEqualToString:@"x-dejalu-icon"]) {
        NSString * ext = [url resourceSpecifier];
        NSDictionary * iconInfo = GetIconInfo(ext);

        NSMutableDictionary * result = [NSMutableDictionary dictionary];
        NSData * imageData = iconInfo[@"data"];
        NSData * base64Data = [imageData base64EncodedDataWithOptions:0];
        NSString * base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        result[@"base64"] = base64String;
        result[@"height"] = iconInfo[@"height"];
        result[@"width"] = iconInfo[@"width"];
        result[@"uniqueID"] = parameters[@"uniqueID"];
        result[@"filename"] = parameters[@"filename"];

        NSString * uuid = [parameters objectForKey:@"uuid"];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
        return;
    }
    else if ([MCOCIDURLProtocol isCID:url]) {
        if ([url resourceSpecifier] != nil) {
            part = imapMsg->partForContentID([[url resourceSpecifier] mco_mcString]);
        }
    }
    else if ([MCOCIDURLProtocol isXMailcoreImage:url]) {
        if ([url resourceSpecifier] != nil) {
            part = imapMsg->partForUniqueID([[url resourceSpecifier] mco_mcString]);
        }
    }
    if (part != NULL) {
        [opParameters setObject:MCO_TO_OBJC(part->mimeType()) forKey:@"mimeType"];
    }
    if (part == NULL) {
        NSMutableDictionary * result = [NSMutableDictionary dictionary];

        result[@"uniqueID"] = parameters[@"uniqueID"];
        result[@"filename"] = parameters[@"filename"];

        NSString * uuid = [parameters objectForKey:@"uuid"];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
        return;
    }

    if (part->className()->isEqual(MCSTR("mailcore::IMAPPart"))) {
        IMAPPart * imapPart = (IMAPPart *) part;
        String * partID = imapPart->partID();
        if (partID == NULL) {
            NSString * uuid = [parameters objectForKey:@"uuid"];
            [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
            [_parametersForOp removeObjectForKey:uuid];
            return;
        }
        NSNumber * nbRowID = msg[@"rowid"];
        int64_t rowid = [nbRowID longLongValue];
        MailDBRetrievePartOperation * op = _account->dataForPartOperation(rowid, partID);
        op->setUniqueID(imapPart->uniqueID());
        op->setFilename(imapPart->filename());
        op->setCallback(_callback);
        op->start();
        _pendingOps->addObject(op);
        [_parametersForOp setObject:opParameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    }
    else if (part->className()->isEqual(MCSTR("mailcore::Attachment"))) {
        Attachment * localPart = (Attachment *) part;
        String * uniqueID = localPart->uniqueID();
        if (uniqueID == NULL) {
            NSString * uuid = [parameters objectForKey:@"uuid"];
            [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
            [_parametersForOp removeObjectForKey:uuid];
            return;
        }
        NSNumber * nbRowID = msg[@"rowid"];
        int64_t rowid = [nbRowID longLongValue];
        MailDBRetrievePartOperation * op;
        if ([msg[@"type"] isEqualToString:@"imap"]) {
            op = _account->dataForPartOperation(rowid, localPart->partID());
        }
        else {
            op = _account->dataForLocalPartOperation(rowid, uniqueID);
        }
        op->setFilename(localPart->filename());
        op->setCallback(_callback);
        op->start();
        _pendingOps->addObject(op);
        [_parametersForOp setObject:opParameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    }
}

#define ICONSIZE 64

static NSDictionary * GetIconInfo(NSString * ext)
{
    NSImage * icon = [[NSWorkspace sharedWorkspace] iconForFileType:ext];

    NSImage * scratch;
    scratch = [[NSImage alloc] initWithSize:NSMakeSize(ICONSIZE, ICONSIZE)];

    [scratch lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [icon drawInRect:NSMakeRect(0, 0, ICONSIZE, ICONSIZE) fromRect:NSMakeRect(0, 0, [icon size].width, [icon size].height) operation:NSCompositeSourceOver fraction:1.0];
    NSBitmapImageRep * output = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,ICONSIZE, ICONSIZE)];

    NSData * bitmapData;
    NSMutableDictionary * info = [[NSMutableDictionary alloc] init];
    //[info setObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    bitmapData = [output representationUsingType:NSPNGFileType
                                      properties:info];
    [scratch unlockFocus];

    NSDictionary * imageInfo = @{@"data": bitmapData, @"height": [NSNumber numberWithFloat:ICONSIZE], @"width": [NSNumber numberWithFloat:ICONSIZE], @"mimeType": @"image/png"};
    return imageInfo;
}

static NSDictionary * GetGIFImageInfo(NSData * data, size_t width, size_t height)
{
    NSDictionary * imageInfo = @{@"data": data, @"height": [NSNumber numberWithFloat:height], @"width": [NSNumber numberWithFloat:width], @"mimeType": @"image/gif"};
    return imageInfo;
}

static NSDictionary * GetImageInfo(NSData * data, BOOL allowResize)
{
    CGImageSourceRef imageSource;
    CGImageRef thumbnail;
    CGRect resizedRect;
    NSMutableDictionary * info;

    imageSource = CGImageSourceCreateWithData((CFDataRef) data, NULL);
    if (imageSource == NULL) {
        return nil;
    }

    NSString * type = CFBridgingRelease(CGImageSourceGetType(imageSource));
    if ([type isEqualToString:@"com.compuserve.gif"] && CGImageSourceGetCount(imageSource) >= 2) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);
        CGImageRelease(image);
        return GetGIFImageInfo(data, width, height);
    }

    info = [[NSMutableDictionary alloc] init];
    [info setObject:(id) kCFBooleanTrue forKey:(__bridge id) kCGImageSourceCreateThumbnailWithTransform];
    [info setObject:(id) kCFBooleanTrue forKey:(__bridge id) kCGImageSourceCreateThumbnailFromImageAlways];
    thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef) info);
    if (thumbnail == NULL) {
        CFRelease(imageSource);
        return NULL;
    }

    resizedRect = CGRectMake(0, 0, CGImageGetWidth(thumbnail), CGImageGetHeight(thumbnail));
    if ((resizedRect.size.width == 0.) || (resizedRect.size.height == 0.)) {
        if (thumbnail != NULL) {
            CFRelease(thumbnail);
        }
        CFRelease(imageSource);
        return nil;
    }

    if (allowResize) {
        if ((resizedRect.size.width > 170) && (resizedRect.size.height > 170)) {
            CGFloat ratio = resizedRect.size.width / resizedRect.size.height;
            if (ratio > 1.0) {
                resizedRect.size.height = 170;
                resizedRect.size.width = ceilf(resizedRect.size.height * ratio);
            }
            else {
                resizedRect.size.width = 170;
                resizedRect.size.height =  ceilf(resizedRect.size.width / ratio);
            }
        }
    }
    else {
        if ((resizedRect.size.width > 580) || (resizedRect.size.height > 400)) {
            CGFloat ratio = resizedRect.size.width / resizedRect.size.height;
            if (ratio > 1) {
                if (resizedRect.size.width > 580) {
                    resizedRect.size.width = 580;
                    resizedRect.size.height =  ceilf(resizedRect.size.width / ratio);
                }
            }
            else {
                if (resizedRect.size.height > 400) {
                    resizedRect.size.height = 400;
                    resizedRect.size.width = ceilf(resizedRect.size.height * ratio);
                }
            }
        }
    }

    NSImage * scratch;
    scratch = [[NSImage alloc] initWithSize:NSMakeSize(resizedRect.size.width, resizedRect.size.height)];

    [scratch lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    CGContextDrawImage([[NSGraphicsContext currentContext] CGContext], CGRectMake(0, 0, resizedRect.size.width, resizedRect.size.height), thumbnail);
    NSBitmapImageRep * output = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,resizedRect.size.width, resizedRect.size.height)];

    NSData * bitmapData;
    info = [[NSMutableDictionary alloc] init];
    //[info setObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    bitmapData = [output representationUsingType:NSPNGFileType
                                      properties:info];
    [scratch unlockFocus];

    CFRelease(thumbnail);
    CFRelease(imageSource);

    NSDictionary * imageInfo = @{@"data": bitmapData, @"height": [NSNumber numberWithFloat:resizedRect.size.height], @"width": [NSNumber numberWithFloat:resizedRect.size.width], @"mimeType": @"image/png"};
    return imageInfo;
}

- (void) _jsLoadImageFinished:(MailDBRetrievePartOperation *)op
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) op]];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    NSNumber * allowResize = [parameters objectForKey:@"allowResize"];

    NSDictionary * msg = [parameters objectForKey:@"msg"];
    NSNumber * nbRowID = msg[@"rowid"];
    Data * data = op->content();
#warning not sure why data == NULL && op->partID() == NULL but it happens
    if ((data == NULL) && (op->partID() != NULL)) {
        NSNumber * nbFolderID = msg[@"folderid"];
        _account->fetchMessagePart([nbFolderID longLongValue], [nbRowID longLongValue], op->partID(), true);
    }

    if (_queue == NULL) {
        _queue = dispatch_queue_create("DJLConversationViewController", DISPATCH_QUEUE_SERIAL);
    }
    op->retain();
    dispatch_async(_queue, ^{
        NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
        if (data != NULL) {
            NSDictionary * imageInfo = GetImageInfo([NSData mco_dataWithMCData:data], [allowResize boolValue]);
            if (imageInfo != nil) {
                NSData * imageData = imageInfo[@"data"];
                NSData * base64Data = [imageData base64EncodedDataWithOptions:0];
                NSString * base64String = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
                result[@"base64"] = base64String;
                result[@"height"] = imageInfo[@"height"];
                result[@"width"] = imageInfo[@"width"];
            }
        }
        result[@"uniqueID"] = MCO_TO_OBJC(op->uniqueID());
        result[@"filename"] = MCO_TO_OBJC(op->filename());
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, json]];
            _pendingOps->removeObject(op);
            [_parametersForOp removeObjectForKey:uuid];
            op->release();
        });
    });
}

- (void) jsMarkMessageAsRead:(NSDictionary *)parameters
{
    NSDictionary * msg = [parameters objectForKey:@"msg"];

    NSNumber * nbRowID = msg[@"rowid"];
    //NSLog(@"%@", msg);
    int64_t rowid = [nbRowID longLongValue];
    //fprintf(stderr, "mark as read %lli\n", rowid);

    Array * rowids = Array::arrayWithObject(Value::valueWithLongLongValue(rowid));
    _account->markAsReadMessages(rowids);

    NSString * uuid = [parameters objectForKey:@"uuid"];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid]];
    [_parametersForOp removeObjectForKey:uuid];
}

- (void) jsReplyMessage:(NSDictionary *)parameters
{
    //NSDictionary * info = [parameters objectForKey:@"messageinfo"];
    NSDictionary * msg = [parameters objectForKey:@"msg"];
    NSNumber * nbRowID = msg[@"rowid"];
    NSNumber * nbFolderID = msg[@"folderid"];

    // also mark as read
    Array * rowids = Array::arrayWithObject(Value::valueWithLongLongValue([nbRowID longLongValue]));
    _account->markAsReadMessages(rowids);

    [[self delegate] DJLConversationViewController:self replyMessageRowID:[nbRowID longLongValue] folderID:[nbFolderID longLongValue] replyType:DJLReplyTypeReplyAll];
}

- (void) jsForwardMessage:(NSDictionary *)parameters
{
    NSDictionary * msg = [parameters objectForKey:@"msg"];
    NSNumber * nbRowID = msg[@"rowid"];
    NSNumber * nbFolderID = msg[@"folderid"];

    // also mark as read
    Array * rowids = Array::arrayWithObject(Value::valueWithLongLongValue([nbRowID longLongValue]));
    _account->markAsReadMessages(rowids);

    [[self delegate] DJLConversationViewController:self replyMessageRowID:[nbRowID longLongValue] folderID:[nbFolderID longLongValue] replyType:DJLReplyTypeForward];
}

- (void) jsQuickLookAttachment:(NSDictionary *)parameters
{
    _quickLookItems = [parameters objectForKey:@"attachments"];
    _quickLookItemToSelect = [[parameters objectForKey:@"selected-index"] intValue];

    NSResponder * aNextResponder = [[[self view] window] nextResponder];
    if (aNextResponder != self) {
        [[[self view] window] setNextResponder:self];
        [self setNextResponder:aNextResponder];
    }
    [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
}

- (void) jsSaveAllAttachments:(NSDictionary *)parameters
{
    NSArray * attachments = parameters[@"attachments"];
    NSString * folderName = parameters[@"subject"];
    if ([folderName length] == 0) {
        folderName = @"No subject";
    }
    folderName = [folderName stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    folderName = [folderName stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    NSString * downloadFolder = [@"~/Downloads" stringByExpandingTildeInPath];
    downloadFolder = MCO_TO_OBJC(hermes::uniquePath(MCO_FROM_OBJC(String, downloadFolder), MCO_FROM_OBJC(String, folderName)));
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadFolder withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:downloadFolder]]];
    for(NSDictionary * attachmentInfo in attachments) {
        NSNumber * nbFolderID = attachmentInfo[@"folderid"];
        int64_t folderID = [nbFolderID longLongValue];
        NSNumber * nbRowID = attachmentInfo[@"rowid"];
        int64_t messageRowID = [nbRowID longLongValue];
        NSString * uniqueID = attachmentInfo[@"uniqueID"];
        [self _saveAttachmentWithFolderID:folderID messageRowID:messageRowID uniqueID:uniqueID
                           downloadFolder:downloadFolder];
    }
}

- (void) jsCloseWindow:(NSDictionary *)parameters
{
    if ([[self delegate] respondsToSelector:@selector(DJLConversationViewControllerClose:)]) {
        [[self delegate] DJLConversationViewControllerClose:self];
    }
}

- (NSString *) _temporaryFolder
{
    if (_temporaryFolder != nil) {
        return _temporaryFolder;
    }

    _temporaryFolder = [[DJLPathManager sharedManager] temporaryFolder];
    return _temporaryFolder;
}

- (IMAPAttachmentDownloader *) _saveAttachmentWithFolderID:(int64_t)folderID messageRowID:(int64_t)rowID uniqueID:(NSString *)uniqueID
                                            downloadFolder:(NSString *)downloadFolder
{
    [_downloadsInProgressSelf addObject:self];

    //IMAPAttachmentDownloader * downloader = new IMAPAttachmentDownloader();
    IMAPAttachmentDownloader * downloader = _account->attachmentDownloader();
    //downloader->setAccount(_account);
    downloader->setFolderID(folderID);
    downloader->setMessageRowID(rowID);
    //NSLog(@"download uniqueID %@", uniqueID);
    downloader->setUniqueID(MCO_FROM_OBJC(String, uniqueID));
    downloader->setDownloadFolder(MCO_FROM_OBJC(String, downloadFolder));
    downloader->setCallback(_callback);
    _attachmentDownloaders->addObject(downloader);
    downloader->start();

    return downloader;
}

- (IMAPAttachmentDownloader *) _saveAttachmentWithFolderID:(int64_t)folderID messageRowID:(int64_t)rowID uniqueID:(NSString *)uniqueID
                                                   filename:(NSString *)filename
{
    [_downloadsInProgressSelf addObject:self];

    //IMAPAttachmentDownloader * downloader = new IMAPAttachmentDownloader();
    IMAPAttachmentDownloader * downloader = _account->attachmentDownloader();
    //downloader->setAccount(_account);
    downloader->setFolderID(folderID);
    downloader->setMessageRowID(rowID);
    //NSLog(@"download uniqueID %@", uniqueID);
    downloader->setUniqueID(MCO_FROM_OBJC(String, uniqueID));
    //downloader->setDownloadFolder(MCO_FROM_OBJC(String, downloadFolder));
    downloader->setFilename(MCO_FROM_OBJC(String, filename));
    downloader->setCallback(_callback);
    _attachmentDownloaders->addObject(downloader);
    downloader->start();

    return downloader;
}

- (void) _showDownloadAttachmentError
{
    if ([[[self view] window] attachedSheet] != nil) {
        return;
    }

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Could not download an attachment"];
    [alert addButtonWithTitle:@"OK"];

    [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
    }];
}

- (void) _saveAttachmentFinished:(IMAPAttachmentDownloader *)downloader
{
#if 0
    NSLog(@"download uniqueID %s %i %s",
          MCUTF8(downloader->uniqueID()),
          downloader->error(),
          MCUTF8(downloader->filename()));
#endif

    if (downloader->error() != hermes::ErrorNone) {
        [self _showDownloadAttachmentError];
        _attachmentToOpenDownloaders->removeObject(downloader);
        if (_attachmentToQuickLookDownloaders != NULL) {
            _attachmentToQuickLookDownloaders->removeObject(downloader);
        }
        _attachmentDownloaders->removeObject(downloader);
        [_downloadsInProgressSelf removeObject:self];
        return;
    }

    if (_attachmentToOpenDownloaders->containsObject(downloader)) {
        [[NSWorkspace sharedWorkspace] openFile:MCO_TO_OBJC(downloader->filename())];
        _attachmentToOpenDownloaders->removeObject(downloader);
    }
    if (_attachmentToQuickLookDownloaders != NULL) {
        if (_attachmentToQuickLookDownloaders->containsObject(downloader)) {
            [self _updateQuicklookWithDownloader:downloader];
            // _attachmentToQuickLookDownloaders might be set to NULL during -_updateQuicklookWithDownloader:
            if (_attachmentToQuickLookDownloaders != NULL) {
                _attachmentToQuickLookDownloaders->removeObject(downloader);
            }
        }
    }
    _attachmentDownloaders->removeObject(downloader);
    [_downloadsInProgressSelf removeObject:self];
}

- (void) jsOpenAttachment:(NSDictionary *)parameters
{
    NSNumber * nbFolderID = parameters[@"folderid"];
    int64_t folderID = [nbFolderID longLongValue];
    NSNumber * nbRowID = parameters[@"rowid"];
    int64_t messageRowID = [nbRowID longLongValue];
    NSString * uniqueID = parameters[@"uniqueID"];
    NSString * downloadFolder = [[DJLPathManager sharedManager] temporaryFolder];

    IMAPAttachmentDownloader * downloader = [self _saveAttachmentWithFolderID:folderID messageRowID:messageRowID uniqueID:uniqueID
                                                               downloadFolder:downloadFolder];
    _attachmentToOpenDownloaders->addObject(downloader);
}

- (void) jsArchive:(NSDictionary *)parameters
{
    [self archiveMessage:nil];
}

- (void) jsDelete:(NSDictionary *)parameters
{
    [self deleteMessage:nil];
}

- (void) jsEditDraftMessage:(NSDictionary *)parameters
{
    NSNumber * nbFolderID = parameters[@"folderid"];
    int64_t folderID = [nbFolderID longLongValue];
    NSNumber * nbRowID = parameters[@"rowid"];
    int64_t messageRowID = [nbRowID longLongValue];
    [[self delegate] DJLConversationView:self editDraftMessage:messageRowID folderID:folderID];
}

- (void) jsShowAddressMenu:(NSDictionary *)parameters
{
    NSDictionary * addressDict = parameters[@"address"];
    NSDictionary * rectDict = parameters[@"rect"];

    NSPoint position;
    NSPoint webPosition;

    position.x = [(NSNumber *) rectDict[@"x"] intValue];
    position.y = [(NSNumber *) rectDict[@"y"] intValue] + [(NSNumber *) rectDict[@"height"] intValue] + 5;
    position.y = [_webView bounds].size.height - position.y;
    webPosition = [_webView convertPoint:position toView:nil];

    NSEvent* fake = [NSEvent mouseEventWithType:NSLeftMouseDown
                                       location:webPosition
                                  modifierFlags:0
                                      timestamp:0
                                   windowNumber:[[_webView window] windowNumber]
                                        context:[NSGraphicsContext currentContext]
                                    eventNumber:0
                                     clickCount:1
                                       pressure:0];

    _currentAddress = [MCOAddress addressWithDisplayName:addressDict[@"display-name"] mailbox:addressDict[@"mailbox"]];
    NSMenu * menu = [[NSMenu alloc] init];
    NSMenuItem * item;
    item = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(_copyAddress:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    NSString * email = addressDict[@"mailbox"];
    if ([[DJLAddressBookManager sharedManager] hasPersonWithEmail:email]) {
        item = [[NSMenuItem alloc] initWithTitle:@"Open in Address Book" action:@selector(_openInAddressBook:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
    }
    else {
        item = [[NSMenuItem alloc] initWithTitle:@"Add to Address Book" action:@selector(_addToAddressBook:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
    }
    item = [[NSMenuItem alloc] initWithTitle:@"New Message" action:@selector(_composeWithAddress:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    if ([menu respondsToSelector:@selector(setAllowsContextMenuPlugIns:)]) {
        [menu setAllowsContextMenuPlugIns:NO];
    }
    [NSMenu popUpContextMenu:menu withEvent:fake forView:_webView];
}

- (void) _copyAddress:(id)sender
{
    NSPasteboard * pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    [pboard setString:[_currentAddress nonEncodedRFC822String] forType:NSStringPboardType];
}

- (void) _openInAddressBook:(id)sender
{
    NSString * uniqueId = [[DJLAddressBookManager sharedManager] uniqueIdForEmail:[_currentAddress mailbox]];
    NSString *urlString = [NSString stringWithFormat:@"addressbook://%@", uniqueId];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (void) _addToAddressBook:(id)sender
{
    [[DJLAddressBookManager sharedManager] addAddress:_currentAddress withCompletion:^(NSString * uniqueId) {
        NSString * urlString = [NSString stringWithFormat:@"addressbook://%@?edit", uniqueId];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    }];
}

- (void) _composeWithAddress:(id)sender
{
    [[self delegate] DJLConversationViewController:self
                                composeWithAddress:_currentAddress];
}

- (void) jsShowMessageSource:(NSDictionary *)parameters
{
    NSNumber * nbRowID = parameters[@"rowid"];
    NSNumber * nbFolderID = parameters[@"folderid"];

    [[self delegate] DJLConversationViewController:self showSourceForMessageRowID:[nbRowID longLongValue] folderID:[nbFolderID longLongValue]];
}

- (void) jsFocusConversationList:(NSDictionary *)parameters
{
    if ([[self delegate] respondsToSelector:@selector(DJLConversationViewControllerFocusConversationList:)]) {
        [[self delegate] DJLConversationViewControllerFocusConversationList:self];
    }
}

#pragma mark -
#pragma mark quicklook

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel
{
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    [panel setDataSource:self];
    [panel setDelegate:self];

    [panel setCurrentPreviewItemIndex:_quickLookItemToSelect];
    [panel reloadData];

    NSString * downloadFolder = [[DJLPathManager sharedManager] temporaryFolder];

    // prepare preview items
    MC_SAFE_RELEASE(_attachmentToQuickLookDownloaders);
    _quickLookPreviewItems = [[NSMutableArray alloc] init];
    _attachmentToQuickLookDownloaders = new Array();
    for(NSDictionary * info in _quickLookItems) {
        DJLQLPreviewItem * item = [[DJLQLPreviewItem alloc] initWithInfos:info webView:_webView];
        [_quickLookPreviewItems addObject:item];

        IMAPAttachmentDownloader * downloader = [self _saveAttachmentWithFolderID:[[info objectForKey:@"folderid"] longLongValue]
                                                                     messageRowID:[[info objectForKey:@"rowid"] longLongValue]
                                                                         uniqueID:[info objectForKey:@"uniqueID"]
                                                                   downloadFolder:downloadFolder];
        _attachmentToQuickLookDownloaders->addObject(downloader);

        [item setDownloader:downloader];
    }
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
    MC_SAFE_RELEASE(_attachmentToQuickLookDownloaders);
    _quickLookPreviewItems = nil;
}

- (void) _updateQuicklookWithDownloader:(IMAPAttachmentDownloader *)downloader
{
    NSString * filename = MCO_TO_OBJC(downloader->filename());
    if (filename == nil) {
        return;
    }
    NSURL * url = [NSURL fileURLWithPath:filename];
    DJLQLPreviewItem * foundItem = nil;
    for(NSUInteger i = 0 ; i < [_quickLookPreviewItems count] ; i ++) {
        DJLQLPreviewItem * item = [_quickLookPreviewItems objectAtIndex:i];
        if ([item downloader] == downloader) {
            foundItem = item;
        }
    }
    [foundItem setPreviewItemURL:url];
    if (foundItem == [[QLPreviewPanel sharedPreviewPanel] currentPreviewItem]) {
        // -refreshCurrentPreviewItem might run the runloop.
        [[QLPreviewPanel sharedPreviewPanel] refreshCurrentPreviewItem];
    }
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return [_quickLookPreviewItems count];
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    return [_quickLookPreviewItems objectAtIndex:index];
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id<QLPreviewItem>)item
{
    DJLQLPreviewItem * concreteItem = item;
    return [concreteItem frame];
}

- (BOOL) _isWebView:(NSView *)view
{
    NSView * currentView;

    currentView = view;
    while (currentView != nil) {
        if (currentView == _webView)
            return YES;
        currentView = [currentView superview];
    }

    return NO;
}

- (BOOL) isFirstResponder
{
    if (![[[_webView window] firstResponder] isKindOfClass:[NSView class]])
        return NO;

    return [self _isWebView:(NSView *) [[_webView window] firstResponder]];
}

- (void) _selectAll
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectAll" withArguments:nil];
}

#pragma mark -
#pragma mark menu management

- (BOOL) _isInbox
{
    HashMap * info = _storageView->conversationsInfoForConversationID(_convID);
    if (info == NULL) {
      return NO;
    }
    Array * labels = (Array *) info->objectForKey(MCSTR("labels"));
    if (labels == NULL) {
        return NO;
    }
    return labels->containsObject(MCSTR("\\Inbox"));
}

- (BOOL) _hasAttachment
{
    HashMap * info = _storageView->conversationsInfoForConversationID(_convID);
    if (info == NULL) {
        return NO;
    }
    Value * value = (Value *) info->objectForKey(MCSTR("attachments-count"));
    return value->intValue() > 0;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    if ([item action] == @selector(archiveMessage:)) {
        return [self _isInbox];
    }
    else if ([item action] == @selector(deleteMessage:)) {
        return YES;
    }
    else if ([item action] == @selector(replyMessage:)) {
        return YES;
    }
    else if ([item action] == @selector(forwardMessage:)) {
        return YES;
    }
    else if ([item action] == @selector(findInText:)) {
        return YES;
    }
    else if ([item action] == @selector(findNext:)) {
        return YES;
    }
    else if ([item action] == @selector(findPrevious:)) {
        return YES;
    }
    else if ([item action] == @selector(saveAllAttachments:)) {
        return [self _hasAttachment];
    }
    else if ([item action] == @selector(showLabelsPanel:)) {
        return YES;
    }
    else if ([item action] == @selector(showLabelsAndArchivePanel:)) {
        return [self _isInbox];
    }
    else if ([item action] == @selector(printDocument:)) {
        return YES;
    }

    // contextual menu
    else if ([item action] == @selector(_searchInGoogle:)) {
        return YES;
    }
    else if ([item action] == @selector(_showOriginalFormat:)) {
        return YES;
    }
    else if ([item action] == @selector(_showSource:)) {
        return YES;
    }
    else if ([item action] == @selector(_saveAttachment:)) {
        return YES;
    }
    else if ([item action] == @selector(_saveAttachmentAs:)) {
        return YES;
    }

    // address menu
    else if ([item action] == @selector(_copyAddress:)) {
        return YES;
    }
    else if ([item action] == @selector(_openInAddressBook:)) {
        return YES;
    }
    else if ([item action] == @selector(_addToAddressBook:)) {
        return YES;
    }
    else if ([item action] == @selector(_composeWithAddress:)) {
        return YES;
    }
    else {
        return NO;
    }
}

- (void) _validateToolbar
{
    if (_loadConversationRequested) {
        [[self delegate] DJLConversationViewDisableToolbar:self];
    }
    else {
        [[self delegate] DJLConversationViewValidateToolbar:self];
    }
}

@end

@implementation DJLQLPreviewItem {
    NSDictionary * _infos;
    NSRect _frame;
    IMAPAttachmentDownloader * _downloader;
}

@synthesize previewItemURL = _previewItemURL;
@synthesize downloader = _IMAPAttachmentDownloader;

- (id) initWithInfos:(NSDictionary *)infos webView:(WebView *)webView
{
    self = [super init];
    _infos = infos;

    NSDictionary * rectDict = [_infos objectForKey:@"rect"];
    NSRect rect;
    rect.origin.x = [rectDict[@"x"] intValue];
    rect.origin.y = [webView bounds].size.height - [rectDict[@"y"] intValue] - [rectDict[@"height"] intValue];
    rect.size.width = [rectDict[@"width"] intValue];
    rect.size.height = [rectDict[@"height"] intValue];
    NSRect webRect;
    webRect = [webView convertRect:rect toView:nil];
    webRect = [[webView window] convertRectToScreen:webRect];
    _frame = webRect;

    return self;
}

- (NSString *) previewItemTitle
{
    if ([_infos objectForKey:@"filename"] != nil) {
        return [NSString stringWithFormat:@"%@ - %@", [_infos objectForKey:@"sender"], [_infos objectForKey:@"filename"]];
    }
    else {
        return [_infos objectForKey:@"sender"];
    }
}

- (NSRect) frame
{
    return _frame;
}

@end
