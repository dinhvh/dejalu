// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLComposerWebView.h"

@implementation DJLComposerWebView

- (BOOL) wantsPeriodicDraggingUpdates
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView_wantsPeriodicDraggingUpdates:)]) {
        return [(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView_wantsPeriodicDraggingUpdates:self];
    }

    return NO;
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:draggingEntered:)]) {
        NSDragOperation result;

        result = [(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self draggingEntered:sender];
        if (result != NSDragOperationNone)
            return result;
    }

    return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:draggingUpdated:)]) {
        NSDragOperation result;

        result = [(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self draggingUpdated:sender];
        if (result != NSDragOperationNone)
            return result;
    }

    return [super draggingUpdated:sender];
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:draggingEnded:)]) {
        if ([(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self draggingEnded:sender]) {
            //[super draggingEnded:sender];
            return;
        }
    }

    //[super draggingEnded:sender];
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:draggingExited:)]) {
        if ([(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self draggingExited:sender]) {
            [super draggingExited:sender];
            return;
        }
    }

    [super draggingExited:sender];
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:prepareForDragOperation:)]) {
        if ([(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self prepareForDragOperation:sender])
            return YES;
    }

    return [super prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:performDragOperation:)]) {
        if ([(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self performDragOperation:sender])
            return YES;
    }

    return [super performDragOperation:sender];
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self UIDelegate] respondsToSelector:@selector(DJLComposerWebView:concludeDragOperation:)]) {
        if ([(id <DJLComposerWebViewDelegate>) [self UIDelegate] DJLComposerWebView:self concludeDragOperation:sender])
            return;
    }

    [super concludeDragOperation:sender];
}

@end
