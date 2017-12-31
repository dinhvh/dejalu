// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationSelectionViewController.h"

#import <WebKit/WebKit.h>

#import "DJLLabelsViewController.h"

using namespace mailcore;
using namespace hermes;

@interface DJLConversationSelectionViewController () <DJLLabelsViewControllerDelegate, WebPolicyDelegate, WebFrameLoadDelegate, WebResourceLoadDelegate, WebUIDelegate>

@end

@implementation DJLConversationSelectionViewController {
    WebView * _webView;
    BOOL _setupDone;
    int _pendingCount;
    NSArray * _conversations;
    NSPopover * _labelsPopOver;
    UnifiedAccount * _unifiedAccount;
    UnifiedMailStorageView * _unifiedStorageView;
}

@synthesize conversations = _conversations;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    _pendingCount = -1;

    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_unifiedStorageView);
    MC_SAFE_RELEASE(_unifiedAccount);
}

- (void) setUnifiedAccount:(hermes::UnifiedAccount *)unifiedAccount
{
    MC_SAFE_REPLACE_RETAIN(UnifiedAccount, _unifiedAccount, unifiedAccount);
}

- (hermes::UnifiedAccount *) unifiedAccount
{
    return _unifiedAccount;
}

- (void) setUnifiedStorageView:(hermes::UnifiedMailStorageView *)unifiedStorageView
{
    MC_SAFE_REPLACE_RETAIN(UnifiedMailStorageView, _unifiedStorageView, unifiedStorageView);
}

- (hermes::UnifiedMailStorageView *) unifiedStorageView
{
    return _unifiedStorageView;
}

- (NSView *) view
{
    if (_webView != nil) {
        return _webView;
    }
    _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0) frameName:nil groupName:nil];
    [_webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_webView setPolicyDelegate:self];
    [_webView setResourceLoadDelegate:self];
    [_webView setUIDelegate:self];
    [_webView setFrameLoadDelegate:self];
    [[_webView windowScriptObject] setValue:self forKey:@"Controller"];
    return _webView;
}

- (void) setup
{
    NSString * filename = [[NSBundle mainBundle] pathForResource:@"conversation-selection-view" ofType:@"html"];
    NSString * htmlString = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    [[_webView mainFrame] loadHTMLString:htmlString baseURL:[[NSBundle mainBundle] resourceURL]];
}

- (void) unsetup
{
    [_webView setPolicyDelegate:nil];
    [_webView setResourceLoadDelegate:nil];
    [_webView setUIDelegate:nil];
    [_webView setFrameLoadDelegate:nil];
    [[_webView windowScriptObject] setValue:nil forKey:@"Controller"];
}

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
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    NSMutableArray * filteredMenu = [[NSMutableArray alloc] init];
    for(NSMenuItem * item in defaultMenuItems) {
        switch ([item tag]) {
            case 2024: // Inspect element
                [filteredMenu addObject:item];
                break;
        }
    }
    return filteredMenu;
}

- (void)setSelectionCount:(int)count
{
    if (!_setupDone) {
        _pendingCount = count;
        return;
    }
    [[_webView windowScriptObject] callWebScriptMethod:@"setSelectionConversationCount" withArguments:@[[NSNumber numberWithInt:count]]];
}

#define WIDTH 300
#define HEIGHT 500

- (void) _showLabelsPopOver
{
    if ([_labelsPopOver isShown]) {
        return;
    }

    int accountIndex = -1;
    BOOL uniqueAccount = YES;
    for(NSDictionary * info in _conversations) {
        NSNumber * nbAccountIndex = info[@"account"];
        int currentAccountIndex = [nbAccountIndex unsignedIntValue];
        if (accountIndex == -1) {
            accountIndex = currentAccountIndex;
        }
        else if (currentAccountIndex != accountIndex) {
            uniqueAccount = NO;
            break;
        }
    }

    if (!uniqueAccount) {
        return;
    }
    if (_unifiedAccount == NULL) {
        return;
    }
    if (_unifiedStorageView == NULL) {
        return;
    }

    Account * account = (Account *) _unifiedAccount->accounts()->objectAtIndex(accountIndex);
    MailStorageView * storageView = (MailStorageView *) _unifiedStorageView->storageViews()->objectAtIndex(accountIndex);

    DJLLabelsViewController * labelsViewController = [[DJLLabelsViewController alloc] init];
    if (!account->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail"))) {
        [labelsViewController setArchiveEnabled:YES];
    }
    [labelsViewController setDelegate:self];
    [[labelsViewController view] setFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
    [labelsViewController setConversations:_conversations];
    [labelsViewController setAccount:account];
    [labelsViewController setStorageView:storageView];
    [labelsViewController setFolderPath:[self folderPath]];
    [labelsViewController reloadData];
    _labelsPopOver = [[NSPopover alloc] init];
    [_labelsPopOver setContentViewController:labelsViewController];
    [_labelsPopOver setBehavior:NSPopoverBehaviorTransient];
    [_labelsPopOver setContentSize:NSMakeSize(WIDTH, HEIGHT)];
    NSString * positionString = [[_webView windowScriptObject] callWebScriptMethod:@"labelsButtonPosition" withArguments:nil];
    NSDictionary * rectDict = [NSJSONSerialization JSONObjectWithData:[positionString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    NSRect rect;
    rect.origin.x = [rectDict[@"x"] intValue];
    rect.origin.y = [_webView bounds].size.height - [rectDict[@"y"] intValue] - [rectDict[@"height"] intValue];
    rect.size.width = [rectDict[@"width"] intValue];
    rect.size.height = [rectDict[@"height"] intValue];
    [_labelsPopOver showRelativeToRect:rect ofView:_webView preferredEdge:NSMinYEdge];
}

#pragma mark DJLLabelsViewController delegate

- (void) DJLLabelsViewControllerClose:(DJLLabelsViewController *)controller
{
    [_labelsPopOver close];
}

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
        [authorizedCommands addObjectsFromArray:@[@"jsRunAction", @"jsFocusConversationList", @"jsApplyPendingCount"]];
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

- (void) jsRunAction:(NSDictionary *)parameters
{
    NSString * name = [parameters objectForKey:@"name"];
    if ([name isEqualToString:@"archive"]) {
        [[self delegate] DJLConversationSelectionViewControllerArchive:self];
    }
    else if ([name isEqualToString:@"trash"]) {
        [[self delegate] DJLConversationSelectionViewControllerTrash:self];
    }
    else if ([name isEqualToString:@"toggle-read"]) {
        [[self delegate] DJLConversationSelectionViewControllerToggleRead:self];
    }
    else if ([name isEqualToString:@"toggle-star"]) {
        [[self delegate] DJLConversationSelectionViewControllerToggleStar:self];
    }
    else if ([name isEqualToString:@"label"]) {
        [self _showLabelsPopOver];
    }
}

- (void) jsFocusConversationList:(NSDictionary *)parameters
{
    if ([[self delegate] respondsToSelector:@selector(DJLConversationSelectionViewControllerFocusConversationList:)]) {
        [[self delegate] DJLConversationSelectionViewControllerFocusConversationList:self];
    }
}

- (void) jsApplyPendingCount:(NSDictionary *)parameters
{
    _setupDone = YES;
    if (_pendingCount != -1) {
        [self setSelectionCount:_pendingCount];
    }
}

@end
