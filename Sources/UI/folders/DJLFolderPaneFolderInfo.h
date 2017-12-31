// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

@class DJLFolderPaneAccountInfo;
@class DJLFolderPaneFolderInfo;

enum {
    DJLFOLDERINFO_COUNT_TYPE_NONE,
    DJLFOLDERINFO_COUNT_TYPE_UNREAD,
    DJLFOLDERINFO_COUNT_TYPE_COUNT,
};

@interface DJLFolderPaneFolderInfo : NSObject

@property (nonatomic, assign) DJLFolderPaneAccountInfo * accountInfo;
@property (nonatomic, copy) NSString * folderPath;
@property (nonatomic, copy) NSString * displayName;
@property (nonatomic, assign) int count;
@property (nonatomic, assign) int countType;
@property (nonatomic, assign) DJLFolderPaneFolderInfo * parent;

- (DJLFolderPaneFolderInfo *) addPathComponents:(NSArray *)components
                                    displayName:(NSString *)displayName
                                           path:(NSString *)path
                                          count:(int)count
                                      countType:(int)countType
                                    accountInfo:(DJLFolderPaneAccountInfo *)accountInfo;

- (void) addSubFolderInfo:(DJLFolderPaneFolderInfo *)info;
- (NSArray *) children;

- (DJLFolderPaneFolderInfo *) findFolderInfoForPath:(NSString *)folderPath;

@end
