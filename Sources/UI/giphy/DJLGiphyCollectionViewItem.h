// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@class DJLGiphyCollectionViewItem;

@protocol DJLGiphyCollectionViewItemDelegate

- (void) DJLGiphyCollectionViewItem:(DJLGiphyCollectionViewItem *)item clickedWithEvent:(NSEvent *)event;

@end

@interface DJLGiphyCollectionViewItem : NSCollectionViewItem

@property (nonatomic, assign) id <DJLGiphyCollectionViewItemDelegate> delegate;

- (void) layoutViews;

@end
