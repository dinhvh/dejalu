// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAttachmentsCollectionView.h"

#import "DJLAttachmentsCollectionViewItem.h"

@implementation DJLAttachmentsCollectionView

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self registerForDraggedTypes:@[NSFilenamesPboardType, NSFilesPromisePboardType]];
    [self setBackgroundColors:@[[NSColor whiteColor]]];
    return self;
}

- (NSCollectionViewItem *)newItemForRepresentedObject:(id)object
{
    NSURL * fileURL = object;
    DJLAttachmentsCollectionViewItem * item = [[DJLAttachmentsCollectionViewItem alloc] init];
    [item setRepresentedObject:fileURL];
    [item layoutViews];
    return item;
}

- (BOOL) resignFirstResponder
{
    [self setSelectionIndexes:[NSIndexSet indexSet]];
    return [super resignFirstResponder];
}

- (void) keyDown:(NSEvent *)theEvent
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:keyPress:)]) {
        if ([(id <DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self keyPress:theEvent]) {
            return;
        }
    }
    [super keyDown:theEvent];
}

- (BOOL) wantsPeriodicDraggingUpdates
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView_wantsPeriodicDraggingUpdates:)]) {
        return [(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView_wantsPeriodicDraggingUpdates:self];
    }

    return NO;
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:draggingEntered:)]) {
        NSDragOperation result;

        result = [(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self draggingEntered:sender];
        if (result != NSDragOperationNone)
            return result;
    }

    return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:draggingUpdated:)]) {
        NSDragOperation result;

        result = [(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self draggingUpdated:sender];
        if (result != NSDragOperationNone)
            return result;
    }

    return [super draggingUpdated:sender];
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:draggingEnded:)]) {
        if ([(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self draggingEnded:sender]) {
            //[super draggingEnded:sender];
            return;
        }
    }

    //[super draggingEnded:sender];
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:draggingExited:)]) {
        if ([(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self draggingExited:sender]) {
            [super draggingExited:sender];
            return;
        }
    }

    [super draggingExited:sender];
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:prepareForDragOperation:)]) {
        if ([(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self prepareForDragOperation:sender])
            return YES;
    }

    return [super prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:performDragOperation:)]) {
        if ([(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self performDragOperation:sender])
            return YES;
    }

    return [super performDragOperation:sender];
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(DJLAttachmentsCollectionView:concludeDragOperation:)]) {
        if ([(id<DJLAttachmentsCollectionViewDelegate>)[self delegate] DJLAttachmentsCollectionView:self concludeDragOperation:sender])
            return;
    }

    [super concludeDragOperation:sender];
}

@end
