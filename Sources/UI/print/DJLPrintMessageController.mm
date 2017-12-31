// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrintMessageController.h"

#import <WebKit/WebKit.h>

#import "MCOCIDURLProtocol.h"
#import "DJLLog.h"
#import "DJLWindow.h"
#import "DJLColoredView.h"

#include "Hermes.h"

using namespace hermes;
using namespace mailcore;

@interface DJLPrintMessageController () <WebPolicyDelegate, WebResourceLoadDelegate, WebUIDelegate, WebFrameLoadDelegate>

@end

@implementation DJLPrintMessageController {
    WebView * _webView;
    NSString * _htmlString;
    NSPrintInfo * _printInfo;
    NSString * _headerHTMLString;
}
- (id) init
{
    self = [super init];
    _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 1000) frameName:nil groupName:nil];

    NSPrintInfo * printInfo;

    printInfo = [[NSPrintInfo sharedPrintInfo] copy];
    [printInfo setHorizontalPagination:NSFitPagination];
    [printInfo setHorizontallyCentered:NO];
    [printInfo setVerticallyCentered:NO];
    NSRect imageableBounds = [printInfo imageablePageBounds];
    NSSize paperSize = [printInfo paperSize];
    if (NSWidth(imageableBounds) > paperSize.width) {
        imageableBounds.origin.x = 0;
        imageableBounds.size.width = paperSize.width;
    }
    if (NSHeight(imageableBounds) > paperSize.height) {
        imageableBounds.origin.y = 0;
        imageableBounds.size.height = paperSize.height;
    }
    [printInfo setBottomMargin:NSMinY(imageableBounds)];
    [printInfo setTopMargin:paperSize.height - NSMinY(imageableBounds) - NSHeight(imageableBounds)];
    [printInfo setLeftMargin:NSMinX(imageableBounds)];
    [printInfo setRightMargin:paperSize.width - NSMinX(imageableBounds) - NSWidth(imageableBounds)];
    _printInfo = printInfo;

    return self;
}

- (void) printMessageWithHTML:(NSString *)html header:(NSString *)header
{
    _htmlString = html;
    _headerHTMLString = header;

    NSString * filename = [[NSBundle mainBundle] pathForResource:@"print-message-view" ofType:@"html"];
    NSString * htmlString = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    [[_webView mainFrame] loadHTMLString:htmlString baseURL:[[NSBundle mainBundle] resourceURL]];

    [_webView setPolicyDelegate:self];
    [_webView setResourceLoadDelegate:self];
    [_webView setUIDelegate:self];
    [_webView setFrameLoadDelegate:self];
    [[_webView windowScriptObject] setValue:self forKey:@"Controller"];
}

#pragma mark webview delegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcLoadHTML" withArguments:@[_htmlString, _headerHTMLString]];

    NSPrintOperation * op = [[[_webView mainFrame] frameView] printOperationWithPrintInfo:_printInfo];
    [op runOperation];
}

@end
