// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

@class DJLFolderPaneFoldersDisclosureInfo;
@class DJLFolderPaneFolderInfo;

namespace hermes {
    class UnifiedAccount;
}

@interface DJLFolderPaneAccountInfo : NSObject

@property (nonatomic, assign) hermes::UnifiedAccount * unifiedAccount;
@property (nonatomic, retain) DJLFolderPaneFoldersDisclosureInfo * foldersDisclosureInfo;
@property (nonatomic, retain) DJLFolderPaneFolderInfo * favoritesRootInfo;
@property (nonatomic, retain) DJLFolderPaneFolderInfo * foldersRootInfo;

- (void) addAccount:(hermes::UnifiedAccount *)unifiedAccount
favoriteAllSpecialFolders:(BOOL)favoriteAllSpecialFolders
      singleAccount:(BOOL)singleAccount;

@end
