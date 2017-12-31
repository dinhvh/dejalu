// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLSourceList.h"

#import "DJLTableView.h"
#import "PXSourceListDelegateDataSourceProxy.h"

@interface PXSourceList (Private)

- (PXSourceListDelegateDataSourceProxy *)delegateDataSourceProxy;

@end

@implementation DJLSourceList

- (id) _pxSourceListDelegate
{
    return [[self delegateDataSourceProxy] delegate];
}

- (void) keyDown:(NSEvent *)theEvent
{
    if ([[self _pxSourceListDelegate] respondsToSelector:@selector(djl_tableView:keyPress:)]) {
        if ([(id <DJLTableViewDelegate>)[self _pxSourceListDelegate] djl_tableView:self keyPress:theEvent]) {
            return;
        }
    }
    [super keyDown:theEvent];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint globalLocation = [theEvent locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];

    if (clickedRow != -1) {
        if ([[self _pxSourceListDelegate] respondsToSelector:@selector(djl_tableView:handleClickedRow:)]) {
            if ([(id <DJLTableViewDelegate>) [self _pxSourceListDelegate] djl_tableView:self handleClickedRow:clickedRow]) {
                return;
            }
        }
    }

    [super mouseDown:theEvent];

    if (clickedRow != -1) {
        if ([[self _pxSourceListDelegate] respondsToSelector:@selector(djl_tableView:didClickedRow:)]) {
            [(id <DJLTableViewDelegate>) [self _pxSourceListDelegate] djl_tableView:self didClickedRow:clickedRow];
        }
    }

    if (([theEvent modifierFlags] & NSControlKeyMask) != 0) {
        NSMenu * menu = [self menuForEvent:theEvent];
        if (menu != nil) {
            [NSMenu popUpContextMenu:menu withEvent:theEvent forView:self];
        }
    }
}

@end
