// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneFolderInfo.h"

@implementation DJLFolderPaneFolderInfo {
    NSMutableArray * _children;
}

- (id) init
{
    self = [super init];
    return self;
}

- (DJLFolderPaneFolderInfo *) addPathComponents:(NSArray *)components
                                    displayName:(NSString *)displayName
                                           path:(NSString *)path
                                          count:(int)count
                                      countType:(int)countType
                                    accountInfo:(DJLFolderPaneAccountInfo *)accountInfo
{
    if (displayName != nil) {
        DJLFolderPaneFolderInfo * folderInfo = [[DJLFolderPaneFolderInfo alloc] init];
        [folderInfo setAccountInfo:accountInfo];
        [folderInfo setDisplayName:displayName];
        [folderInfo setCount:count];
        [folderInfo setCountType:countType];
        [folderInfo setFolderPath:path];
        [self addSubFolderInfo:folderInfo];
        return folderInfo;
    }
    else {
        if ([components count] == 0) {
            return self;
        }
        NSString * component = components[0];
        NSArray * remainingComponents = [components subarrayWithRange:NSMakeRange(1, [components count] - 1)];
        BOOL componentSelectable = ([components count] == 1);

        DJLFolderPaneFolderInfo * previousInfo = [_children lastObject];
        DJLFolderPaneFolderInfo * folderInfo = nil;
        if ((previousInfo != nil) && [[previousInfo displayName] isEqualToString:component]) {
            folderInfo = previousInfo;
        }
        else {
            folderInfo = [[DJLFolderPaneFolderInfo alloc] init];
            [folderInfo setAccountInfo:accountInfo];
            [folderInfo setDisplayName:component];
            [self addSubFolderInfo:folderInfo];
        }
        if (componentSelectable) {
            [folderInfo setCount:count];
            [folderInfo setCountType:countType];
            [folderInfo setFolderPath:path];
        }
        return [folderInfo addPathComponents:remainingComponents
                                 displayName:displayName
                                        path:path
                                       count:count
                                   countType:countType
                                 accountInfo:accountInfo];
    }
}

- (DJLFolderPaneFolderInfo *) findFolderInfoForPath:(NSString *)folderPath
{
    if ([folderPath isEqualToString:[self folderPath]]) {
        return self;
    }
    for(DJLFolderPaneFolderInfo * info in [self children]) {
        DJLFolderPaneFolderInfo * result = [info findFolderInfoForPath:folderPath];
        if (result != nil) {
            return result;
        }
    }
    return nil;
}

- (void) addSubFolderInfo:(DJLFolderPaneFolderInfo *)info
{
    if (_children == nil) {
        _children = [[NSMutableArray alloc] init];
    }
    [info setParent:self];
    [_children addObject:info];
}

- (NSArray *) children
{
    return _children;
}

@end
