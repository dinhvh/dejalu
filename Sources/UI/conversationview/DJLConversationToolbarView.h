// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "DJLToolbarView.h"

@protocol DJLConversationToolbarViewDelegate;

@interface DJLConversationToolbarView : DJLToolbarView

@property (nonatomic, weak) id <DJLConversationToolbarViewDelegate> delegate;
@property (nonatomic, assign, getter=isDraft) BOOL draft;
@property (nonatomic, assign, getter=isWindowMode) BOOL windowMode;
@property (nonatomic, copy, readonly) NSString * searchString;

- (BOOL) isSearchFieldVisible;

- (void) focusSearch;

- (NSRect) labelButtonRect;

@end

@protocol DJLConversationToolbarViewDelegate <NSObject>

- (void) DJLConversationToolbarViewSaveAttachments:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewReply:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewForward:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewArchive:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewTrash:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewLabel:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewEditDraft:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewFocusWebView:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewSearch:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewCancelSearch:(DJLConversationToolbarView *)view;
- (void) DJLConversationToolbarViewSearchNext:(DJLConversationToolbarView *)view;

@end
