// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "DJLToolbarView.h"

#include "Hermes.h"

@protocol DJLComposerToolbarViewDelegate;

@interface DJLComposerToolbarView : DJLToolbarView

@property (nonatomic, assign) id<DJLComposerToolbarViewDelegate> delegate;
@property (nonatomic, assign, getter=isSendButtonEnabled) BOOL sendButtonEnabled;
@property (nonatomic, copy, readonly) NSString * searchString;
@property (nonatomic, copy) NSString * emailAlias;

- (BOOL) isSearchFieldVisible;

- (void) focusSearch;

@end

@protocol DJLComposerToolbarViewDelegate <NSObject>

- (void) DJLComposerToolbarViewSendMessage:(DJLComposerToolbarView *)view;
- (void) DJLComposerToolbarViewAddAttachment:(DJLComposerToolbarView *)view;
- (void) DJLComposerToolbarViewFocusWebView:(DJLComposerToolbarView *)view;
- (void) DJLComposerToolbarViewCancelSearch:(DJLComposerToolbarView *)view;
- (void) DJLComposerToolbarViewSearch:(DJLComposerToolbarView *)view;
- (void) DJLComposerToolbarViewToggleCc:(DJLComposerToolbarView *)view;
- (void) DJLComposerToolbarView:(DJLComposerToolbarView *)view accountSelected:(hermes::Account *)account emailAlias:(NSString *)alias;
- (void) DJLComposerToolbarView:(DJLComposerToolbarView *)view giphySelected:(NSDictionary *)item;

@end
