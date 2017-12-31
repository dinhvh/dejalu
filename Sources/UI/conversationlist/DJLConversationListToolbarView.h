// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "Hermes.h"
#import "DJLToolbarView.h"

typedef enum DJLConversationListToolbarViewErrorKind {
    DJLConversationListToolbarViewErrorKindNone,
    DJLConversationListToolbarViewErrorKindOffline,
    DJLConversationListToolbarViewErrorKindError,
} DJLConversationListToolbarViewErrorKind;

@protocol DJLConversationListToolbarViewDelegate;

@interface DJLConversationListToolbarView : DJLToolbarView

@property (nonatomic, weak) id <DJLConversationListToolbarViewDelegate> delegate;
@property (nonatomic, assign) DJLConversationListToolbarViewErrorKind error;
@property (nonatomic, assign) CGFloat leftMargin;

- (void) setFolderPath:(NSString *)path;

@end


@protocol DJLConversationListToolbarViewDelegate <NSObject>

- (void) DJLConversationListToolbarViewCompose:(DJLConversationListToolbarView *)toolbar;
- (void) DJLConversationListToolbarViewSearch:(DJLConversationListToolbarView *)toolbar;
- (hermes::UnifiedAccount *) DJLConversationListToolbarViewAccount:(DJLConversationListToolbarView *)toolbar;
//- (NSString *) DJLConversationListToolbarViewSelectedPath:(DJLConversationListToolbarView *)toolbar;
- (void) DJLConversationListToolbarView:(DJLConversationListToolbarView *)toolbar
                        selectedAccount:(hermes::UnifiedAccount *)account
                           selectedPath:(NSString *)path;
- (void) DJLConversationListToolbarViewShowError:(DJLConversationListToolbarView *)toolbar;
- (void) DJLConversationListToolbarView:(DJLConversationListToolbarView *)toolbar
                     openFoldersManager:(hermes::Account *)account;

@end
