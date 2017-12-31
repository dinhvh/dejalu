// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#include <MailCore/MailCore.h>

@protocol DJLConversationCellViewDelegate;

@interface DJLConversationCellView : NSView

@property (nonatomic, weak) id <DJLConversationCellViewDelegate> delegate;
@property (nonatomic, retain) NSDictionary * conversation;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign) CGFloat vibrancy;
@property (nonatomic, retain) NSString * folderPath;

- (void) update;

@end

@protocol DJLConversationCellViewDelegate <NSObject>

- (void) DJLConversationCellViewStarClicked:(DJLConversationCellView *)view;
- (void) DJLConversationCellViewUnreadClicked:(DJLConversationCellView *)view;

@end

