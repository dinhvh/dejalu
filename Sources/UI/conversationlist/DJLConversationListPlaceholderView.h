// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

typedef enum DJLConversationListPlaceholderKind {
    DJLConversationListPlaceholderKindNone,
    DJLConversationListPlaceholderKindInboxZero,
    DJLConversationListPlaceholderKindEmpty,
    DJLConversationListPlaceholderKindLoading,
    DJLConversationListPlaceholderKindNotLoaded,
    DJLConversationListPlaceholderKindSearching,
    DJLConversationListPlaceholderKindNoAccounts,
} DJLConversationListPlaceholderKind;

@interface DJLConversationListPlaceholderView : NSView

@property (nonatomic, assign) DJLConversationListPlaceholderKind kind;

@end
