// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLWebHTMLView.h"
#import "WebHTMLViewPrivate.h"

@interface WebHTMLView (MMViewerWebViewPrivate) <NSDraggingInfo>

- (WebView *) _webView;
- (void) paste:(id)sender;
- (void) copy:(id)sender;

@end

@interface DJLWebHTMLView : WebHTMLView

- (id<DJLWebHTMLViewDelegate>) _DJLWebHTMLView_UIDelegate;

@end

@implementation WebHTMLView (MMViewerWebHTMLView)
// We override in a category to substitute our own subclass instead of usual one

+ (id)allocWithZone:(NSZone *)zone {
    if (self == [WebHTMLView class]) {
        return [DJLWebHTMLView allocWithZone:zone];
    } else {
        return [super allocWithZone:zone];
    }
}

@end

@implementation DJLWebHTMLView

- (id) _DJLWebHTMLView_UIDelegate
{
    return [[self _webView] UIDelegate];
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
    if ([[self _DJLWebHTMLView_UIDelegate] respondsToSelector:@selector(DJLWebHTMLView:namesOfPromisedFilesDroppedAtDestination:)]) {
        NSArray * result;

        result = [[self _DJLWebHTMLView_UIDelegate] DJLWebHTMLView:[self _webView] namesOfPromisedFilesDroppedAtDestination:dropDestination];
        if (result != nil)
            return result;
    }

    return [super namesOfPromisedFilesDroppedAtDestination:dropDestination];
}

- (void) paste:(id)sender
{
    if ([[self _DJLWebHTMLView_UIDelegate] respondsToSelector:@selector(DJLWebHTMLView:paste:)]) {
        if ([[self _DJLWebHTMLView_UIDelegate] DJLWebHTMLView:[self _webView] paste:sender]) {
            return;
        }
    }

    [super paste:sender];
}

- (void) copy:(id)sender
{
    if ([[self _DJLWebHTMLView_UIDelegate] respondsToSelector:@selector(DJLWebHTMLView_beforeWriteToPasteboard:)]) {
        [[self _DJLWebHTMLView_UIDelegate] DJLWebHTMLView_beforeWriteToPasteboard:[self _webView]];
    }
    [super copy:sender];
    if ([[self _DJLWebHTMLView_UIDelegate] respondsToSelector:@selector(DJLWebHTMLView_afterWriteToPasteboard:)]) {
        [[self _DJLWebHTMLView_UIDelegate] DJLWebHTMLView_afterWriteToPasteboard:[self _webView]];
    }
}

- (void)dragImage:(NSImage *)anImage at:(NSPoint)imageLoc offset:(NSSize)mouseOffset event:(NSEvent *)theEvent pasteboard:(NSPasteboard *)pboard source:(id)sourceObject slideBack:(BOOL)slideBack
{
    if ([[self _DJLWebHTMLView_UIDelegate] respondsToSelector:@selector(DJLWebHTMLView_beforeWriteToPasteboard:)]) {
        [[self _DJLWebHTMLView_UIDelegate] DJLWebHTMLView_beforeWriteToPasteboard:[self _webView]];
    }
    // fix clipboard
    [[self _webView] writeSelectionWithPasteboardTypes:[pboard types] toPasteboard:pboard];
    if ([[self _DJLWebHTMLView_UIDelegate] respondsToSelector:@selector(DJLWebHTMLView_afterWriteToPasteboard:)]) {
        [[self _DJLWebHTMLView_UIDelegate] DJLWebHTMLView_afterWriteToPasteboard:[self _webView]];
    }

    [super dragImage:anImage at:imageLoc offset:mouseOffset event:theEvent pasteboard:(NSPasteboard *)pboard source:sourceObject slideBack:slideBack];
}

@end
