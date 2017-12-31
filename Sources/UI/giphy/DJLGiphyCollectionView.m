// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGiphyCollectionView.h"

#import "DJLGiphyCollectionViewItem.h"

@interface DJLGiphyCollectionView () <DJLGiphyCollectionViewItemDelegate>

@end

@implementation DJLGiphyCollectionView

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    return self;
}

- (NSCollectionViewItem *)newItemForRepresentedObject:(id)object
{
    NSDictionary * giphyItem = object;
    DJLGiphyCollectionViewItem * item = [[DJLGiphyCollectionViewItem alloc] init];
    [item setDelegate:self];
    [item setRepresentedObject:giphyItem];
    [item layoutViews];
    return item;
}

- (void) keyDown:(NSEvent *)theEvent
{
    if ([theEvent keyCode] == 36) {
        NSUInteger idx = [[self selectionIndexes] firstIndex];
        if (idx == NSNotFound) {
            return;
        }
        NSDictionary * item = [self content][idx];
        [(id <DJLGiphyCollectionViewDelegate>)[self delegate] DJLGiphyCollectionView:self selectItem:item];
    }
    else {
        [super keyDown:theEvent];
    }
}

- (void) DJLGiphyCollectionViewItem:(DJLGiphyCollectionViewItem *)item clickedWithEvent:(NSEvent *)event
{
    NSDictionary * info = [item representedObject];
    [(id <DJLGiphyCollectionViewDelegate>)[self delegate] DJLGiphyCollectionView:self selectItem:info];
}

@end
