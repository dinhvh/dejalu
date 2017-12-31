// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLConversationStatusView : NSButton

+ (void) setInteractionEnabled:(BOOL)enabled;

@property (nonatomic, assign, getter=isStar) BOOL star;
@property (nonatomic, retain) NSDictionary * conversation;

@end
