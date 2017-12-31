// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLFolderPaneFolderCellView : NSView

@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign, getter=isEmphasized) BOOL emphasized;
@property (nonatomic, copy) NSString * displayName;
@property (nonatomic, assign) int count;
@property (nonatomic, assign) BOOL selectable;

@end
