// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneRowView.h"

#import "DJLFolderPaneFolderCellView.h"
#import "DJLFolderPaneLabelsCellView.h"

@implementation DJLFolderPaneRowView

- (void) setSelected:(BOOL)selected
{
    [super setSelected:selected];
    for(NSView * view in [self subviews]) {
        if ([view isKindOfClass:[DJLFolderPaneFolderCellView class]]) {
            [(DJLFolderPaneFolderCellView *) view setSelected:selected];
        }
        else if ([view isKindOfClass:[DJLFolderPaneLabelsCellView class]]) {
            [(DJLFolderPaneLabelsCellView *) view setSelected:selected];
        }
    }
}

- (void) setEmphasized:(BOOL)emphasized
{
    [super setEmphasized:emphasized];
    for(NSView * view in [self subviews]) {
        if ([view isKindOfClass:[DJLFolderPaneFolderCellView class]]) {
            [(DJLFolderPaneFolderCellView *) view setEmphasized:emphasized];
        }
        else if ([view isKindOfClass:[DJLFolderPaneLabelsCellView class]]) {
            [(DJLFolderPaneLabelsCellView *) view setEmphasized:emphasized];
        }
    }
}

- (void) addSubview:(NSView *)view
{
    [super addSubview:view];
    if ([view isKindOfClass:[DJLFolderPaneFolderCellView class]]) {
        [(DJLFolderPaneFolderCellView *) view setEmphasized:[self isEmphasized]];
    }
    else if ([view isKindOfClass:[DJLFolderPaneLabelsCellView class]]) {
        [(DJLFolderPaneLabelsCellView *) view setEmphasized:[self isEmphasized]];
    }
    if ([view isKindOfClass:[DJLFolderPaneFolderCellView class]]) {
        [(DJLFolderPaneFolderCellView *) view setSelected:[self isSelected]];
    }
    else if ([view isKindOfClass:[DJLFolderPaneLabelsCellView class]]) {
        [(DJLFolderPaneLabelsCellView *) view setSelected:[self isSelected]];
    }
}

@end
