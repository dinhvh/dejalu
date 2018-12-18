// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLConversationCellViewDelegate;

@interface DJLConversationCellContentView : NSTableCellView

@property (nonatomic, weak) id <DJLConversationCellViewDelegate> delegate;
@property (nonatomic, retain) NSDictionary * conversation;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign, getter=isChecked) BOOL checked;
@property (nonatomic, assign, getter=isCheckMode) BOOL checkMode;
@property (nonatomic, assign, getter=isNextCellSelected) BOOL nextCellSelected;
@property (nonatomic, assign) CGFloat vibrancy;
@property (nonatomic, retain) NSString * folderPath;

- (void) update;

@end
