// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#define DJLScrollViewDidEndDraggingScrollNotification @"DJLScrollViewDidEndDraggingScrollNotification"

@interface DJLScrollView : NSScrollView

@property (nonatomic, readonly, getter=isDragging) BOOL dragging;

@end
