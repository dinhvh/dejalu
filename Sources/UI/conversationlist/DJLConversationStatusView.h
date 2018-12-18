// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

typedef enum {
    DJLConversationStatusViewTypeStar,
    DJLConversationStatusViewTypeRead,
    DJLConversationStatusViewTypeChecked,
} DJLConversationStatusViewType;

@interface DJLConversationStatusView : NSButton

+ (void) setInteractionEnabled:(BOOL)enabled;

//@property (nonatomic, assign, getter=isStar) BOOL star;
@property (nonatomic, assign) DJLConversationStatusViewType type;
@property (nonatomic, retain) NSDictionary * conversation;
@property (nonatomic, assign, getter=isChecked) BOOL checked;

@end
