// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLActivityFolderCellView : NSView

@property (nonatomic, copy) NSString * folderPath;
@property (nonatomic, copy) NSString * urgentTask;
@property (nonatomic, copy) NSString * syncState;
@property (nonatomic, assign) BOOL syncing;

@end
