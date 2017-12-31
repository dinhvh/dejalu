// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <WebKit/WebKit.h>

@protocol DJLComposerWebViewDelegate;

@interface DJLComposerWebView : WebView

@end

@protocol DJLComposerWebViewDelegate

- (BOOL) DJLComposerWebView_wantsPeriodicDraggingUpdates:(DJLComposerWebView *)webView;
- (NSDragOperation) DJLComposerWebView:(DJLComposerWebView *)webView draggingEntered:(id < NSDraggingInfo >)sender;
- (NSDragOperation) DJLComposerWebView:(DJLComposerWebView *)webView draggingUpdated:(id < NSDraggingInfo >)sender;
- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView draggingEnded:(id < NSDraggingInfo >)sender;
- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView draggingExited:(id < NSDraggingInfo >)sender;

- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView prepareForDragOperation:(id < NSDraggingInfo >)sender;
- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView performDragOperation:(id < NSDraggingInfo >)sender;
- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView concludeDragOperation:(id < NSDraggingInfo >)sender;

@end
