// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@protocol DJLWebHTMLViewDelegate<NSObject>

@optional
- (NSArray *)DJLWebHTMLView:(WebView *)webView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination;
- (BOOL)DJLWebHTMLView:(WebView *)webView paste:(id)sender;
- (void) DJLWebHTMLView_beforeWriteToPasteboard:(WebView *)webView;
- (void) DJLWebHTMLView_afterWriteToPasteboard:(WebView *)webView;

@end
