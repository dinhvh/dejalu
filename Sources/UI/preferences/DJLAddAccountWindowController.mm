// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAddAccountWindowController.h"

#include <sys/time.h>
#include <time.h>

#import <WebKit/WebKit.h>

#include "Hermes.h"

#import "DJLColoredView.h"
#import "NSDictionary+DJL.h"
#import "BSHTTPCookieStorage.h"
#import "DJLOAuth2Request.h"
#import "DJLProfileRequest.h"
#import "DJLPathManager.h"
#import "NSData+DJL.h"
#import "DJLColoredProgressIndicator.h"
#import "DJLLog.h"
#import "DJLPathManager.h"

#define SMALL_HEIGHT 350

#define DJLAddAccountWindowControllerErrorDomain @"DJLAddAccountWindowControllerErrorDomain"

enum {
    DJLAddAccountWindowControllerErrorNonMatchingAccount,
    DJLAddAccountWindowControllerErrorAccountAlreadyExisting,
    DJLAddAccountWindowControllerErrorAccountNeedsLicense,
    DJLAddAccountWindowControllerErrorAliasAlreadyExists,
    DJLAddAccountWindowControllerErrorCancelled,
};

using namespace mailcore;
using namespace hermes;

@interface DJLAddAccountWindowController () <NSWindowDelegate, WebFrameLoadDelegate, WebResourceLoadDelegate, WebUIDelegate, WebPolicyDelegate>

- (void) _operationFinished:(Operation *)operation;
- (void) _logWithSender:(void *)sender connectionType:(MCOConnectionLogType)logType data:(NSData *)data;

@end

class DJLAddAccountWindowControllerCallback : public mailcore::Object, public mailcore::OperationCallback, public mailcore::ConnectionLogger {
public:
    DJLAddAccountWindowControllerCallback(DJLAddAccountWindowController * controller)
    {
        mController = controller;
    }

    virtual ~DJLAddAccountWindowControllerCallback()
    {
    }

    virtual void operationFinished(Operation * op) {
        [mController _operationFinished:op];
    }

    virtual void log(void * sender, ConnectionLogType logType, Data * buffer)
    {
        [mController _logWithSender:sender connectionType:(MCOConnectionLogType)logType data:MCO_TO_OBJC(buffer)];
    }

    __weak DJLAddAccountWindowController * mController;
};

@implementation DJLAddAccountWindowController {
    WebView * _webView;
    WebView * _googleWebView;
    BSHTTPCookieStorage * _cookieStorage;
    BOOL _done;
    __weak id<DJLAddAccountWindowControllerDelegate> _delegate;
    BOOL _closed;
    DJLAddAccountWindowControllerCallback * _callback;
    NSString * _hintEmail;
    FILE * _logFile;
    NSMutableDictionary * _parametersForOp;
    NSDictionary * _gmailAuthenticationParameters;
    NSDictionary * _requestTokenParameters;
    Array * _gmailValidatorOps;
}

@synthesize hintEmail = _hintEmail;
@synthesize delegate = _delegate;

- (id) init
{
    NSWindow * window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, SMALL_HEIGHT)
                                                    styleMask:NSTitledWindowMask /* | NSResizableWindowMask */ | NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                      backing:NSBackingStoreBuffered defer:YES];
    NSRect frame;
    [window setTitlebarAppearsTransparent:YES];
    [window center];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setReleasedWhenClosed:NO];

    frame = [window frame];
    frame.origin = CGPointZero;
    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:frame];
    [contentView setAutoresizingMask:NSViewHeightSizable];
    [window setContentView:contentView];
    [contentView setWantsLayer:YES];

    self = [super initWithWindow:window];

    _callback = new DJLAddAccountWindowControllerCallback(self);

    [window setDelegate:self];

    _cookieStorage = [[BSHTTPCookieStorage alloc] init];

    _parametersForOp = [[NSMutableDictionary alloc] init];
    _gmailValidatorOps = new Array();

    [self _setup];

    return self;
}

- (void) dealloc
{
    if (_logFile != NULL) {
        fclose(_logFile);
        _logFile = NULL;
    }
    mc_foreacharray(AccountValidator, validator, _gmailValidatorOps) {
        validator->cancel();
    }
    MC_SAFE_RELEASE(_gmailValidatorOps);
    delete _callback;
}

- (void) _setup
{
    NSRect bounds = [[[self window] contentView] bounds];

    _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, bounds.size.width, bounds.size.height - 22) frameName:nil groupName:nil];
    [_webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_webView setFrameLoadDelegate:self];
    [_webView setResourceLoadDelegate:self];
    [_webView setUIDelegate:self];
    [[_webView windowScriptObject] setValue:self forKey:@"Controller"];
    [[[self window] contentView] addSubview:_webView];

    _googleWebView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, bounds.size.width, bounds.size.height - 22) frameName:nil groupName:nil];
    WebPreferences * prefs = [[WebPreferences alloc] init];
    [prefs setPrivateBrowsingEnabled:YES];
    [_googleWebView setPreferences:prefs];
    [_googleWebView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_googleWebView setFrameLoadDelegate:self];
    [_googleWebView setResourceLoadDelegate:self];
    [_googleWebView setPolicyDelegate:self];
    [_googleWebView setUIDelegate:self];
    [[[self window] contentView] addSubview:_googleWebView];
    [_googleWebView setHidden:YES];

    [self _loadHTML];
}

- (void) _loadHTML
{
    NSURL * url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"add-account" ofType:@"html"]];
    [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void) _unsetup
{
    [_googleWebView setFrameLoadDelegate:nil];
    [_googleWebView setResourceLoadDelegate:nil];
    [_googleWebView setPolicyDelegate:nil];
    [_googleWebView setUIDelegate:nil];
    [_googleWebView removeFromSuperview];
    _googleWebView = nil;

    [[_webView windowScriptObject] setValue:nil forKey:@"Controller"];
    [_webView setFrameLoadDelegate:nil];
    [_webView setResourceLoadDelegate:nil];
    [_webView setUIDelegate:nil];
    [_webView removeFromSuperview];
    _webView = nil;
}

- (void) _loadGmailAuthenticationWithHintEmail:(NSString *)hintEmail
{
    NSRect frame = [[self window] frame];
    CGFloat deltaY = 600 - frame.size.height;
    frame.size.width = 700;
    frame.size.height += deltaY;
    frame.origin.y -= deltaY;
    [[self window] setFrame:frame display:YES animate:YES];
    NSString * baseURLString = @"https://accounts.google.com/o/oauth2/auth";
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] init];
    parameters[@"response_type"] = @"code";
    parameters[@"client_id"] = CLIENT_ID;
    parameters[@"redirect_uri"] = @"http://localhost";
    parameters[@"scope"] = @"https://mail.google.com/ https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email";
    if (hintEmail != nil) {
        parameters[@"login_hint"] = hintEmail;
    }
    NSString * urlString = [NSString stringWithFormat:@"%@?%@", baseURLString, [parameters djlQueryString]];

    NSURL * url = [NSURL URLWithString:urlString];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:30];
    [[_googleWebView mainFrame] loadRequest:request];
    [_webView setHidden:YES];
    [_googleWebView setHidden:NO];
}

- (void) _loadOutlookAuthenticationWithHintEmail:(NSString *)hintEmail
{
    NSRect frame = [[self window] frame];
    CGFloat deltaY = 600 - frame.size.height;
    frame.size.width = 700;
    frame.size.height += deltaY;
    frame.origin.y -= deltaY;
    [[self window] setFrame:frame display:YES animate:YES];
    //https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=6731de76-14a6-49ae-97bc-6eba6914391e&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%2Fmyapp%2F&response_mode=query&scope=openid%20offline_access%20https%3A%2F%2Fgraph.microsoft.com%2Fmail.read&state=12345
    NSString * baseURLString = @"https://login.live.com/oauth20_authorize.srf";
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] init];
    parameters[@"response_type"] = @"code";
    parameters[@"client_id"] = MICROSOFT_CLIENT_ID;
    parameters[@"redirect_uri"] = @"http://localhost";
    parameters[@"scope"] = @"wl.imap wl.offline_access";
    NSString * urlString = [NSString stringWithFormat:@"%@?%@", baseURLString, [parameters djlQueryString]];

    NSURL * url = [NSURL URLWithString:urlString];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:30];
    [[_googleWebView mainFrame] loadRequest:request];
    [_webView setHidden:YES];
    [_googleWebView setHidden:NO];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    if (_googleWebView != sender) {
        return request;
    }

    if ([[[request URL] host] isEqualTo:@"localhost"]) {
        NSDictionary * parameters = [NSDictionary djlDictionaryWithQueryString:[[request URL] query]];
        NSString * code = parameters[@"code"];
        NSString * error = parameters[@"error"];
        _done = YES;
        if ([error isEqualTo:@"access_denied"]) {
            [self _jsShowGmailAuthenticationDoneWithError:[NSError errorWithDomain:DJLAddAccountWindowControllerErrorDomain code:DJLAddAccountWindowControllerErrorCancelled userInfo:nil]
                                                imapError:nil code:code];
        }
        else {
            [self _jsShowGmailAuthenticationDoneWithError:nil imapError:nil code:code];
        }
        return nil;
    }

    return request;
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    if (sender == _webView) {
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
    else {
        NSMutableArray * filteredMenu = [[NSMutableArray alloc] init];
        for(NSMenuItem * item in defaultMenuItems) {
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
                default:
                    if ([item isSeparatorItem]) {
                        if (![(NSMenuItem *) [filteredMenu lastObject] isSeparatorItem]) {
                            [filteredMenu addObject:item];
                        }
                    }
                    break;
            }
        }
        return filteredMenu;
    }
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (_googleWebView != sender) {
        return;
    }

    if (_done) {
        return;
    }

    [self _jsShowGmailAuthenticationDoneWithError:error imapError:nil code:nil];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    if (_googleWebView != webView) {
        return;
    }

    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            if ([[request URL] isFileURL] && [[[request URL] path] isEqualToString:[[NSBundle mainBundle] resourcePath]]) {
                [listener use];
                return;
            }

            [[NSWorkspace sharedWorkspace] openURL:[request URL]];
            [listener ignore];
            break;

        case WebNavigationTypeOther:
            default:
            [listener use];
            break;
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)newFrameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
    if (_googleWebView != webView) {
        return;
    }

    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            if ([[request URL] isFileURL] && [[[request URL] path] isEqualToString:[[NSBundle mainBundle] resourcePath]]) {
                [listener use];
                return;
            }

            [[NSWorkspace sharedWorkspace] openURL:[request URL]];
            [listener ignore];
            break;

        case WebNavigationTypeOther:
            default:
            [listener use];
            break;
    }
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
        [authorizedCommands addObjectsFromArray:@[
                                                  @"jsProviderWithEmail",
                                                  @"jsShowOAuth2Authentication",
                                                  @"jsRequestOAuth2Token",
                                                  @"jsHideOAuth2Authentication",
                                                  @"jsValidateAndAddGmailAccount",
                                                  @"jsValidateAndAddKnownAccount",
                                                  @"jsValidateAndUpdateKnownAccount",
                                                  @"jsCancelValidation",
                                                  @"jsCancelRequestToken",
                                                  @"jsUpdateOAuth2Account",
                                                  @"jsDialogSetup",
                                                  @"jsClose",
                                                  @"jsValidateCustomIMAPAccount",
                                                  @"jsValidateCustomSMTPAccount",
                                                  @"jsCheckExistingEmail",
                                                  @"jsAddCustomAccount",
                                                  @"jsChangeCustomAccountCredentials",
                                                  ]];
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

- (void) jsDialogSetup:(NSDictionary *)parameters
{
    NSString * uuid = parameters[@"uuid"];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    if (_hintEmail != nil) {
        result[@"email"] = _hintEmail;
    }
    if (_hintProviderIdentifier != nil) {
        result[@"provider-identifier"] = _hintProviderIdentifier;
    }
    result[@"well-known-imap-enabled"] = @([[NSUserDefaults standardUserDefaults] boolForKey:@"DJLWellKnownIMAPAccounts"]);
    result[@"custom-imap-enabled"] = @([[NSUserDefaults standardUserDefaults] boolForKey:@"DJLCustomIMAPAccounts"]);
    result[@"account-properties"] = _accountProperties;

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
}

- (void) jsCancelValidation:(NSDictionary *)parameters
{
    mc_foreacharray(AccountValidator, validator, _gmailValidatorOps) {
        validator->cancel();
    }
    _gmailValidatorOps->removeAllObjects();
}

- (void) jsProviderWithEmail:(NSDictionary *)parameters
{
    NSString * email = parameters[@"email"];

    AccountValidator * validator = new AccountValidator();
    validator->setEmail(MCO_FROM_OBJC(String, email));

    NSMutableDictionary * parametersCopy = [parameters mutableCopy];
    parametersCopy[@"type"] = @"provider";
    [self _jsValidateWithValidator:validator parameters:parametersCopy];

    MC_SAFE_RELEASE(validator);
}

- (void) _jsProviderWithEmailFailed:(NSDictionary *)parameters
{
    NSError * error = parameters[@"error"];
    NSString * message = [self _errorMessageWithError:error];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    result[@"error-message"] = message;

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
}

- (void) jsCheckExistingEmail:(NSDictionary *)parameters
{
    NSString * email = parameters[@"email"];

    NSError * error = [self _checkExistingEmailAddress:email];
    if (error != nil) {
        NSMutableDictionary * modifiedParameters = [parameters mutableCopy];
        modifiedParameters[@"error"] = error;
        [self _jsCheckExistingEmailFailed:modifiedParameters];
        return;
    }

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
}

- (void) _jsCheckExistingEmailFailed:(NSDictionary *)parameters
{
    NSError * error = parameters[@"error"];
    NSString * message = [self _errorMessageWithError:error];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    result[@"error-message"] = message;

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString * uuid = [parameters objectForKey:@"uuid"];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
}

- (void) jsHideOAuth2Authentication:(NSDictionary *)parameters
{
    [_webView setHidden:NO];
    [_googleWebView setHidden:YES];

    NSRect frame = [[self window] frame];
    CGFloat deltaY = SMALL_HEIGHT - frame.size.height;
    frame.size.width = 700;
    frame.size.height += deltaY;
    frame.origin.y -= deltaY;
    [[self window] setFrame:frame display:YES animate:YES];
}

- (void) jsShowOAuth2Authentication:(NSDictionary *)parameters
{
    _done = NO;

    [_webView setHidden:YES];
    [_googleWebView setHidden:NO];

    if ([parameters[@"provider"] isEqualToString:@"gmail"]) {
        [self _loadGmailAuthenticationWithHintEmail:parameters[@"hintEmail"]];
    }
    else if ([parameters[@"provider"] isEqualToString:@"outlook"]) {
        [self _loadOutlookAuthenticationWithHintEmail:parameters[@"hintEmail"]];
    }
    else {
        MCAssert(0);
    }
    _gmailAuthenticationParameters = parameters;
}

- (void) _jsShowGmailAuthenticationDoneWithError:(NSError *)error imapError:(NSString *)imapErrorString code:(NSString *)code
{
    NSDictionary * parameters = _gmailAuthenticationParameters;
    NSString * uuid = [parameters objectForKey:@"uuid"];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];

    if ([[error domain] isEqualToString:DJLAddAccountWindowControllerErrorDomain] && ([error code] == DJLAddAccountWindowControllerErrorCancelled)) {
        result[@"cancelled"] = @(YES);
    }

    NSString * message = [self _errorMessageWithError:error];
    if (message != nil) {
        result[@"error-message"] = message;
    }
    if (imapErrorString != nil) {
        result[@"imap-error-message"] = imapErrorString;
    }
    if (code != nil) {
        result[@"code"] = code;
    }

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
    _gmailAuthenticationParameters = nil;
}

- (NSString *) _errorMessageWithError:(NSError *)error
{
    if (error == nil) {
        return nil;
    }

    NSString * domain = [error domain];
    NSString * message = @"Your account could not be added. Please try later.";
    if ([domain isEqualToString:DJLAddAccountWindowControllerErrorDomain]) {
        switch ([error code]) {
            case DJLAddAccountWindowControllerErrorNonMatchingAccount:
            message = @"An unexpected error happened.";
            break;
            case DJLAddAccountWindowControllerErrorAccountAlreadyExisting:
            message = @"Your account has already been added to DejaLu before.";
            break;
            case DJLAddAccountWindowControllerErrorAccountNeedsLicense:
            message = @"You need to buy the application to add more accounts.";
            break;
            case DJLAddAccountWindowControllerErrorAliasAlreadyExists:
            message = @"An alias with that email already exists. You need to remove that alias first.";
            break;
            case DJLAddAccountWindowControllerErrorCancelled:
            message = @"The user cancelled.";
            break;
        }
    }

    return message;
}

- (void) jsCancelRequestToken:(NSDictionary *)parameters
{
    _requestTokenParameters = nil;
}

- (void) jsRequestOAuth2Token:(NSDictionary *)parameters
{
    _requestTokenParameters = parameters;
    NSString * code = parameters[@"code"];
    NSString * provider = parameters[@"provider"];
    if ([provider isEqualToString:@"gmail"]) {
        [DJLOAuth2Request startGoogleOAuth2WithParameters:@{@"code": code, @"client_id": CLIENT_ID, @"client_secret" : CLIENT_SECRET, @"grant_type": @"authorization_code", @"redirect_uri": @"http://localhost"}
                                               completion:^(NSDictionary * result, NSError * error) {
                                                   if (error != nil) {
                                                       [self _jsRequestTokenDoneWithError:error info:nil];
                                                       return;
                                                   }
                                                   LOG_ERROR("requested token: %s", [[result description] UTF8String]);

                                                   NSString * refreshToken = result[@"refresh_token"];
                                                   NSString * accessToken = result[@"access_token"];
                                                   [DJLProfileRequest startWithToken:accessToken provider:provider completion:^(NSDictionary * result, NSError * error) {
                                                       if (error != nil) {
                                                           [self _jsRequestTokenDoneWithError:error info:nil];
                                                           return;
                                                       }

                                                       NSMutableDictionary * info = [result mutableCopy];
                                                       info[@"refresh-token"] = refreshToken;
                                                       info[@"oauth2-token"] = accessToken;
                                                       info[@"display-name"] = result[@"name"];
                                                       info[@"email"] = result[@"email"];
                                                       [self _jsRequestTokenDoneWithError:nil info:info];
                                                   }];
                                               }];
    }
    else if ([provider isEqualToString:@"outlook"]) {
        [DJLOAuth2Request startOutlookOAuth2WithParameters:@{@"code": code, @"client_id": MICROSOFT_CLIENT_ID, @"client_secret" : MICROSOFT_CLIENT_SECRET, @"grant_type": @"authorization_code", @"redirect_uri": @"http://localhost"}
                                                completion:^(NSDictionary * result, NSError * error) {
                                                    if (error != nil) {
                                                        [self _jsRequestTokenDoneWithError:error info:nil];
                                                        return;
                                                    }
                                                    LOG_ERROR("requested token: %s", [[result description] UTF8String]);

                                                    NSString * refreshToken = result[@"refresh_token"];
                                                    NSString * accessToken = result[@"access_token"];
                                                    [DJLProfileRequest startWithToken:accessToken provider:provider completion:^(NSDictionary * result, NSError * error) {
                                                        if (error != nil) {
                                                            [self _jsRequestTokenDoneWithError:error info:nil];
                                                            return;
                                                        }

                                                        NSMutableDictionary * info = [result mutableCopy];
                                                        info[@"refresh-token"] = refreshToken;
                                                        info[@"oauth2-token"] = accessToken;
                                                        info[@"display-name"] = result[@"DisplayName"];
                                                        info[@"email"] = result[@"Id"];
                                                        [self _jsRequestTokenDoneWithError:nil info:info];
                                                    }];
                                                }];
    }
}

- (void) _jsRequestTokenDoneWithError:(NSError *)error info:(NSDictionary *)info
{
    if (_requestTokenParameters == nil) {
        return;
    }

    NSDictionary * parameters = _requestTokenParameters;
    NSString * uuid = [parameters objectForKey:@"uuid"];

    NSString * message = [self _errorMessageWithError:error];
    NSMutableDictionary * result = [info mutableCopy];
    if (result == nil) {
        result = [[NSMutableDictionary alloc] init];
    }
    result[@"error-message"] = message;

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
    _gmailAuthenticationParameters = nil;
}

- (void) jsValidateAndAddGmailAccount:(NSDictionary *)parameters
{
    NSString * email = parameters[@"email"];
    NSString * oauth2Token = parameters[@"oauth2-token"];

    AccountValidator * validator = new AccountValidator();
    validator->setCallback(_callback);
    validator->setEmail(MCO_FROM_OBJC(String, email));
    validator->setOAuth2Token(MCO_FROM_OBJC(String, oauth2Token));
    validator->setImapEnabled(true);
    validator->setSmtpEnabled(true);

    NSMutableDictionary * parametersCopy = [parameters mutableCopy];
    parametersCopy[@"type"] = @"gmail";
    [_parametersForOp setObject:parametersCopy forKey:[NSNumber numberWithUnsignedLong:(unsigned long) validator]];
    [self _jsValidateWithValidator:validator parameters:parametersCopy];

    MC_SAFE_RELEASE(validator);
}

- (void) jsValidateAndAddKnownAccount:(NSDictionary *)parameters
{
    NSString * email = parameters[@"email"];
    NSString * password = parameters[@"password"];

    AccountValidator * validator = new AccountValidator();
    validator->setEmail(MCO_FROM_OBJC(String, email));
    validator->setPassword(MCO_FROM_OBJC(String, password));
    validator->setImapEnabled(true);
    validator->setSmtpEnabled(true);

    NSMutableDictionary * parametersCopy = [parameters mutableCopy];
    parametersCopy[@"type"] = @"known";
    [self _jsValidateWithValidator:validator parameters:parametersCopy];

    MC_SAFE_RELEASE(validator);
}

- (void) jsValidateAndUpdateKnownAccount:(NSDictionary *)parameters
{
    NSString * email = parameters[@"email"];
    NSString * password = parameters[@"password"];

    AccountValidator * validator = new AccountValidator();
    validator->setEmail(MCO_FROM_OBJC(String, email));
    validator->setPassword(MCO_FROM_OBJC(String, password));
    validator->setImapEnabled(true);
    validator->setSmtpEnabled(true);

    NSMutableDictionary * parametersCopy = [parameters mutableCopy];
    parametersCopy[@"type"] = @"known-update";
    [self _jsValidateWithValidator:validator parameters:parametersCopy];

    MC_SAFE_RELEASE(validator);
}

- (void) _jsValidateWithValidator:(AccountValidator *)validator parameters:(NSDictionary *)parameters
{
    [self _setupLogFile];

    [_parametersForOp setObject:parameters forKey:[NSNumber numberWithUnsignedLong:(unsigned long) validator]];
    _gmailValidatorOps->addObject(validator);

    validator->setCallback(_callback);
    validator->setConnectionLogger(_callback);
    validator->start();
}

- (void) _jsValidateAndAddGmailAccountDone:(AccountValidator *)validator
{
    NSDictionary * parameters = [_parametersForOp objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) validator]];

    BOOL success =  NO;
    if ((validator->imapError() == mailcore::ErrorNone) && (validator->smtpError() == mailcore::ErrorNone)) {
        if ([parameters[@"type"] isEqualToString:@"provider"]) {
            // do nothing.
        }
        else if ([parameters[@"type"] isEqualToString:@"imap"]) {
            // do nothing.
        }
        else if ([parameters[@"type"] isEqualToString:@"smtp"]) {
            // do nothing.
        }
        else if ([parameters[@"type"] isEqualToString:@"gmail"]) {
            [self _setupGmailAccountWithParameters:parameters validator:validator];
        }
        else if ([parameters[@"type"] isEqualToString:@"known"]) {
            [self _setupKnownAccountWithParameters:parameters validator:validator];
        }
        else if ([parameters[@"type"] isEqualToString:@"known-update"]) {
            [self _updateKnownAccountWithParameters:parameters validator:validator];
        }
        success = YES;
    }

    NSString * uuid = [parameters objectForKey:@"uuid"];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    if ((validator->imapError() == mailcore::ErrorNoValidServerFound) && (validator->smtpError() == mailcore::ErrorNoValidServerFound)) {
        result[@"result"] = @"custom-provider";
    }
    else if (!success) {
        if (validator->imapLoginResponse() != NULL) {
            result[@"imap-error"] = MCO_TO_OBJC(validator->imapLoginResponse());
        }
        if ((validator->imapError() == mailcore::ErrorAuthentication) || (validator->smtpError() == mailcore::ErrorAuthentication)) {
            result[@"error-message"] = @"The password you entered is incorrect. Please verify you entered it correctly.";
        }
        else {
            result[@"error-message"] = @"Your account could not be added. Please retry later.";
        }
    }
    else if (validator->identifier() == NULL) {
        result[@"result"] = @"custom-provider";
        NetService * imapService = NULL;
        if (validator->imapServer() != NULL) {
            imapService = validator->imapServer();
        }
        NetService * smtpService = NULL;
        if (validator->smtpServer() != NULL) {
            smtpService = validator->smtpServer();
        }
        if (imapService != NULL) {
            result[@"imap-hostname"] = MCO_TO_OBJC(imapService->hostname());
            result[@"imap-port"] = @(imapService->port());
            result[@"imap-connection-type"] = @(imapService->connectionType());
        }
        if (smtpService != NULL) {
            result[@"smtp-hostname"] = MCO_TO_OBJC(smtpService->hostname());
            result[@"smtp-port"] = @(smtpService->port());
            result[@"smtp-connection-type"] = @(smtpService->connectionType());
        }
    }
    else {
        result[@"provider"] = MCO_TO_OBJC(validator->identifier());
        MailProvider * provider = MailProvidersManager::sharedManager()->providerForIdentifier(validator->identifier());
        NetService * imapService = NULL;
        if (provider->imapServices()->count() > 0) {
            imapService = (NetService *) provider->imapServices()->objectAtIndex(0);
        }
        NetService * smtpService = NULL;
        if (provider->smtpServices()->count() > 0) {
            smtpService = (NetService *) provider->smtpServices()->objectAtIndex(0);
        }
        result[@"result"] = @"success";
        if (imapService != NULL) {
            result[@"imap-hostname"] = MCO_TO_OBJC(imapService->hostname());
        }
        if (smtpService != NULL) {
            result[@"smtp-hostname"] = MCO_TO_OBJC(smtpService->hostname());
        }
    }
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
    _gmailValidatorOps->removeObject(validator);
    [_parametersForOp removeObjectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) validator]];
}

- (void) _setupGmailAccountWithParameters:(NSDictionary *)parameters
                                validator:(AccountValidator *)validator
{
    NSString * email = parameters[@"email"];
    NSString * displayName = parameters[@"display-name"];
    NSString * refreshToken = parameters[@"refresh-token"];

    NSString * folder = [[DJLPathManager sharedManager] accountsFolder];

    Account * account = new Account();
    account->setPath(MCO_FROM_OBJC(String, folder));
    account->accountInfo()->setProviderIdentifier(validator->identifier());
    account->accountInfo()->setEmail(MCO_FROM_OBJC(String, email));
    account->accountInfo()->setDisplayName(MCO_FROM_OBJC(String, displayName));
    account->accountInfo()->setOAuth2RefreshToken(MCO_FROM_OBJC(String, refreshToken));

    IMAPAccountInfo * imapInfo = account->accountInfo()->imapInfo();
    imapInfo->setHostname(validator->imapServer()->hostname());
    imapInfo->setPort(validator->imapServer()->port());
    imapInfo->setConnectionType(validator->imapServer()->connectionType());
    imapInfo->setEmail(MCO_FROM_OBJC(String, email));
    imapInfo->setUsername(MCO_FROM_OBJC(String, email));

    SMTPAccountInfo * smtpInfo = account->accountInfo()->smtpInfo();
    smtpInfo->setHostname(validator->smtpServer()->hostname());
    smtpInfo->setPort(validator->smtpServer()->port());
    smtpInfo->setConnectionType(validator->smtpServer()->connectionType());
    smtpInfo->setEmail(MCO_FROM_OBJC(String, email));
    smtpInfo->setUsername(MCO_FROM_OBJC(String, email));

    account->save();
    account->open();
    account->setDeliveryEnabled(true);

    AccountManager::sharedManager()->addAccount(account);
    AccountManager::sharedManager()->save();

    MC_SAFE_RELEASE(account);
}

- (void) _setupKnownAccountWithParameters:(NSDictionary *)parameters
                                validator:(AccountValidator *)validator
{
    NSString * email = parameters[@"email"];
    NSString * displayName = parameters[@"display-name"];
    NSString * password = parameters[@"password"];

    NSString * folder = [[DJLPathManager sharedManager] accountsFolder];

    Account * account = new Account();
    account->setPath(MCO_FROM_OBJC(String, folder));
    account->accountInfo()->setProviderIdentifier(validator->identifier());
    account->accountInfo()->setEmail(MCO_FROM_OBJC(String, email));
    account->accountInfo()->setDisplayName(MCO_FROM_OBJC(String, displayName));
    account->accountInfo()->setPassword(MCO_FROM_OBJC(String, password));

    IMAPAccountInfo * imapInfo = account->accountInfo()->imapInfo();
    imapInfo->setHostname(validator->imapServer()->hostname());
    imapInfo->setPort(validator->imapServer()->port());
    imapInfo->setConnectionType(validator->imapServer()->connectionType());
    imapInfo->setEmail(MCO_FROM_OBJC(String, email));
    imapInfo->setUsername(MCO_FROM_OBJC(String, email));

    SMTPAccountInfo * smtpInfo = account->accountInfo()->smtpInfo();
    smtpInfo->setHostname(validator->smtpServer()->hostname());
    smtpInfo->setPort(validator->smtpServer()->port());
    smtpInfo->setConnectionType(validator->smtpServer()->connectionType());
    smtpInfo->setEmail(MCO_FROM_OBJC(String, email));
    smtpInfo->setUsername(MCO_FROM_OBJC(String, email));

    account->save();
    account->open();
    account->setDeliveryEnabled(true);

    AccountManager::sharedManager()->addAccount(account);
    AccountManager::sharedManager()->save();

    MC_SAFE_RELEASE(account);
}

- (void) _updateKnownAccountWithParameters:(NSDictionary *)parameters
                                 validator:(AccountValidator *)validator
{
    NSString * password = parameters[@"password"];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];

    Account * account = AccountManager::sharedManager()->accountForEmail(MCO_FROM_OBJC(String, _hintEmail));
    account->accountInfo()->setPassword(MCO_FROM_OBJC(String, password));
    account->refreshFolder(account->folderIDForPath(account->inboxFolderPath()));

    NSString * uuid = parameters[@"uuid"];
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
}

- (NSError *) _checkExistingEmailAddress:(NSString *)email
{
    Account * account = AccountManager::sharedManager()->accountForEmail(MCO_FROM_OBJC(String, email));
    if (account != NULL) {
        return [NSError errorWithDomain:DJLAddAccountWindowControllerErrorDomain code:DJLAddAccountWindowControllerErrorAccountAlreadyExisting userInfo:nil];
    }
    bool exist = false;
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            mc_foreacharray(Address, address, account->accountInfo()->aliases()) {
                if (MCO_FROM_OBJC(String, email)->isEqual(address->mailbox())) {
                    exist = true;
                }
            }
        }
    }
    if (exist) {
        return [NSError errorWithDomain:DJLAddAccountWindowControllerErrorDomain code:DJLAddAccountWindowControllerErrorAliasAlreadyExists userInfo:nil];
    }

    return nil;
}

- (void) jsUpdateOAuth2Account:(NSDictionary *)parameters
{
    NSString * refreshToken = parameters[@"refresh-token"];

    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];

    Account * account = AccountManager::sharedManager()->accountForEmail(MCO_FROM_OBJC(String, _hintEmail));
    account->accountInfo()->setOAuth2RefreshToken(MCO_FROM_OBJC(String, refreshToken));
    account->refreshFolder(account->folderIDForPath(account->inboxFolderPath()));

    NSString * uuid = parameters[@"uuid"];
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[_webView windowScriptObject] callWebScriptMethod:@"postResult" withArguments:@[uuid, jsonString]];
}

- (void) jsClose:(NSDictionary *)parameters
{
    [self close];
}

- (void) jsValidateCustomIMAPAccount:(NSDictionary *)parameters
{
    NSString * login = parameters[@"login"];
    NSString * password = parameters[@"password"];
    NSString * hostname = parameters[@"hostname"];

    AccountValidator * validator = new AccountValidator();
    validator->setUsername(MCO_FROM_OBJC(String, login));
    validator->setPassword(MCO_FROM_OBJC(String, password));
    validator->setImapEnabled(true);
    validator->setSmtpEnabled(false);

    Array * services = Array::array();
    if ([hostname containsString:@":"]) {
        NSArray * components = [hostname componentsSeparatedByString:@":"];
        NSString * hostname = components[0];
        int port = [(NSString *)components[1] intValue];
        if (port == 143) {
            //try starttls, then cleartext
            NetService * netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeStartTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
            netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeClear);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
        }
        else if (port == 993) {
            // try ssl
            NetService * netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
        }
        else {
            // try ssl, starttls, cleartext
            NetService * netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
            netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeStartTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
            netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeClear);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
        }
    }
    else {
        // try 993, then 143 starttls, then 143 cleartext
        NetService * netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(993);
        netService->setConnectionType(ConnectionTypeTLS);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
        netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(143);
        netService->setConnectionType(ConnectionTypeStartTLS);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
        netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(143);
        netService->setConnectionType(ConnectionTypeClear);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
    }
    validator->setImapServices(services);

    NSMutableDictionary * parametersCopy = [parameters mutableCopy];
    parametersCopy[@"type"] = @"imap";
    [self _jsValidateWithValidator:validator parameters:parametersCopy];

    MC_SAFE_RELEASE(validator);
}

- (void) jsValidateCustomSMTPAccount:(NSDictionary *)parameters
{
    NSString * login = parameters[@"login"];
    NSString * password = parameters[@"password"];
    NSString * hostname = parameters[@"hostname"];

    AccountValidator * validator = new AccountValidator();
    validator->setUsername(MCO_FROM_OBJC(String, login));
    validator->setPassword(MCO_FROM_OBJC(String, password));
    validator->setImapEnabled(false);
    validator->setSmtpEnabled(true);

    Array * services = Array::array();
    if ([hostname containsString:@":"]) {
        NSArray * components = [hostname componentsSeparatedByString:@":"];
        NSString * hostname = components[0];
        int port = [(NSString *)components[1] intValue];
        if ((port == 25) || (port = 587)) {
            //try starttls, then cleartext
            NetService * netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeStartTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
            netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeClear);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
        }
        else if (port == 465) {
            // try ssl
            NetService * netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
        }
        else {
            // try ssl, starttls, cleartext
            NetService * netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
            netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeStartTLS);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
            netService = new NetService();
            netService->setHostname(MCO_FROM_OBJC(String, hostname));
            netService->setPort(port);
            netService->setConnectionType(ConnectionTypeClear);
            services->addObject(netService);
            MC_SAFE_RELEASE(netService);
        }
    }
    else {
        // try 587, then 465 starttls, then 25 cleartext
        NetService * netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(587);
        netService->setConnectionType(ConnectionTypeStartTLS);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
        netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(465);
        netService->setConnectionType(ConnectionTypeTLS);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
        netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(25);
        netService->setConnectionType(ConnectionTypeStartTLS);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
        netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(587);
        netService->setConnectionType(ConnectionTypeClear);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
        netService = new NetService();
        netService->setHostname(MCO_FROM_OBJC(String, hostname));
        netService->setPort(25);
        netService->setConnectionType(ConnectionTypeClear);
        services->addObject(netService);
        MC_SAFE_RELEASE(netService);
    }
    validator->setSmtpServices(services);

    NSMutableDictionary * parametersCopy = [parameters mutableCopy];
    parametersCopy[@"type"] = @"smtp";
    [self _jsValidateWithValidator:validator parameters:parametersCopy];

    MC_SAFE_RELEASE(validator);
}

- (void) jsAddCustomAccount:(NSDictionary *)parameters
{
    NSString * folder = [[DJLPathManager sharedManager] accountsFolder];

    Account * account = new Account();
    account->setPath(MCO_FROM_OBJC(String, folder));
    account->accountInfo()->setEmail(MCO_FROM_OBJC(String, parameters[@"email"]));
    account->accountInfo()->setDisplayName(MCO_FROM_OBJC(String, parameters[@"display-name"]));
    //account->accountInfo()->setPassword(MCO_FROM_OBJC(String, password));

    IMAPAccountInfo * imapInfo = account->accountInfo()->imapInfo();
    imapInfo->setHasSeparatePassword(true);
    imapInfo->setHostname(MCO_FROM_OBJC(String, parameters[@"imap-hostname"]));
    int imapPort = [(NSNumber *) parameters[@"imap-port"] intValue];
    imapInfo->setPort(imapPort);
    int imapConnectionType = [(NSNumber *) parameters[@"imap-connection-type"] intValue];
    imapInfo->setConnectionType((ConnectionType) imapConnectionType);
    imapInfo->setEmail(MCO_FROM_OBJC(String, parameters[@"email"]));
    imapInfo->setUsername(MCO_FROM_OBJC(String, parameters[@"imap-login"]));
    imapInfo->setPassword(MCO_FROM_OBJC(String, parameters[@"imap-password"]));

    SMTPAccountInfo * smtpInfo = account->accountInfo()->smtpInfo();
    smtpInfo->setHasSeparatePassword(true);
    smtpInfo->setHostname(MCO_FROM_OBJC(String, parameters[@"smtp-hostname"]));
    int smtpPort = [(NSNumber *) parameters[@"smtp-port"] intValue];
    smtpInfo->setPort(smtpPort);
    int smtpConnectionType = [(NSNumber *) parameters[@"smtp-connection-type"] intValue];
    smtpInfo->setConnectionType((ConnectionType) smtpConnectionType);
    smtpInfo->setEmail(MCO_FROM_OBJC(String, parameters[@"email"]));
    smtpInfo->setUsername(MCO_FROM_OBJC(String, parameters[@"smtp-login"]));
    smtpInfo->setPassword(MCO_FROM_OBJC(String, parameters[@"smtp-password"]));

    account->save();
    account->open();
    account->setDeliveryEnabled(true);

    AccountManager::sharedManager()->addAccount(account);
    AccountManager::sharedManager()->save();

    MC_SAFE_RELEASE(account);
}

- (void) jsChangeCustomAccountCredentials:(NSDictionary *)parameters
{
    Account * account = AccountManager::sharedManager()->accountForEmail(MCO_FROM_OBJC(String, parameters[@"email"]));

    IMAPAccountInfo * imapInfo = account->accountInfo()->imapInfo();
    imapInfo->setHasSeparatePassword(true);
    imapInfo->setHostname(MCO_FROM_OBJC(String, parameters[@"imap-hostname"]));
    int imapPort = [(NSNumber *) parameters[@"imap-port"] intValue];
    imapInfo->setPort(imapPort);
    int imapConnectionType = [(NSNumber *) parameters[@"imap-connection-type"] intValue];
    imapInfo->setConnectionType((ConnectionType) imapConnectionType);
    imapInfo->setUsername(MCO_FROM_OBJC(String, parameters[@"imap-login"]));
    imapInfo->setPassword(MCO_FROM_OBJC(String, parameters[@"imap-password"]));

    SMTPAccountInfo * smtpInfo = account->accountInfo()->smtpInfo();
    smtpInfo->setHasSeparatePassword(true);
    smtpInfo->setHostname(MCO_FROM_OBJC(String, parameters[@"smtp-hostname"]));
    int smtpPort = [(NSNumber *) parameters[@"smtp-port"] intValue];
    smtpInfo->setPort(smtpPort);
    int smtpConnectionType = [(NSNumber *) parameters[@"smtp-connection-type"] intValue];
    smtpInfo->setConnectionType((ConnectionType) smtpConnectionType);
    smtpInfo->setUsername(MCO_FROM_OBJC(String, parameters[@"smtp-login"]));
    smtpInfo->setPassword(MCO_FROM_OBJC(String, parameters[@"smtp-password"]));

    account->save();
    account->refreshFolder(account->folderIDForPath(account->inboxFolderPath()));
}

- (void) windowWillClose:(NSNotification *)notification
{
    if (_closed) {
        return;
    }
    [self _unsetup];
    _closed = YES;
    [self _cancelled];

    mc_foreacharray(AccountValidator, validator, _gmailValidatorOps) {
        validator->cancel();
    }

    [[self delegate] DJLAddAccountWindowControllerClosed:self];
}

- (void) _cancelled
{
    if (!_closed) {
        [self close];
    }
}

- (void) _setupLogFile
{
    if (_logFile != NULL) {
        return;
    }

    struct timeval tv;
    struct tm tm_value;
    gettimeofday(&tv, NULL);
    localtime_r(&tv.tv_sec, &tm_value);
    char * dateBuffer = NULL;
    asprintf(&dateBuffer, "%04u-%02u-%02u--%02u:%02u", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min);
    NSString * basename = [NSString stringWithFormat:@"add-account-%s.log", dateBuffer];
    NSString * path = [[[DJLPathManager sharedManager] logsFolder] stringByAppendingPathComponent:basename];
    _logFile = fopen([path fileSystemRepresentation], "wb");
}

- (void) _operationFinished:(Operation *)operation
{
    if (_gmailValidatorOps->containsObject(operation)) {
        [self _jsValidateAndAddGmailAccountDone:(AccountValidator *) operation];
    }
}

- (void) _logWithSender:(void *)sender connectionType:(MCOConnectionLogType)logType data:(NSData *)data
{
    if (_logFile == NULL) {
        return;
    }
    if (logType == MCOConnectionLogTypeSentPrivate) {
        return;
    }
    if (logType == (MCOConnectionLogType) -1) {
        return;
    }

    if (_logFile != NULL) {
        fwrite([data bytes], 1, [data length], _logFile);
    }
}

@end
