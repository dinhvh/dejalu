// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLGiphyViewControllerDelegate;

@interface DJLGiphyViewController : NSViewController

@property (nonatomic, assign) id<DJLGiphyViewControllerDelegate> delegate;

- (void) makeFirstResponder;
- (void) prepareSize;

@end

@protocol DJLGiphyViewControllerDelegate <NSObject>

- (void) DJLGiphyViewControllerClosed:(DJLGiphyViewController *)controller;
- (void) DJLGiphyViewController:(DJLGiphyViewController *)controller itemSelected:(NSDictionary *)item;
- (void) DJLGiphyViewController:(DJLGiphyViewController *)controller hasHeight:(CGFloat)height;

@end
