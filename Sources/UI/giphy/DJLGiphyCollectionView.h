// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLGiphyCollectionView;

@interface DJLGiphyCollectionView : NSCollectionView

@end

@protocol DJLGiphyCollectionViewDelegate

- (void) DJLGiphyCollectionView:(DJLGiphyCollectionView *)view selectItem:(NSDictionary *)item;

@end
