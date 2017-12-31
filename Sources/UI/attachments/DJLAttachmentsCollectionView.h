// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLAttachmentsCollectionViewDelegate;

@interface DJLAttachmentsCollectionView : NSCollectionView

@end

@protocol DJLAttachmentsCollectionViewDelegate

@optional
- (BOOL)DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view keyPress:(NSEvent *)event;
- (BOOL) DJLAttachmentsCollectionView_wantsPeriodicDraggingUpdates:(DJLAttachmentsCollectionView *)view;
- (NSDragOperation) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingEntered:(id < NSDraggingInfo >)sender;
- (NSDragOperation) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingUpdated:(id < NSDraggingInfo >)sender;
- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingEnded:(id < NSDraggingInfo >)sender;
- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view draggingExited:(id < NSDraggingInfo >)sender;

- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view prepareForDragOperation:(id < NSDraggingInfo >)sender;
- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view performDragOperation:(id < NSDraggingInfo >)sender;
- (BOOL) DJLAttachmentsCollectionView:(DJLAttachmentsCollectionView *)view concludeDragOperation:(id < NSDraggingInfo >)sender;

@end
