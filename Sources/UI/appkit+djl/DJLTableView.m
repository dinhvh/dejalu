// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLTableView.h"

@implementation DJLTableView

- (void) keyDown:(NSEvent *)theEvent
{
    if ([[self delegate] respondsToSelector:@selector(djl_tableView:keyPress:)]) {
        if ([(id <DJLTableViewDelegate>)[self delegate] djl_tableView:self keyPress:theEvent]) {
            return;
        }
    }
    [super keyDown:theEvent];
}

- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event
{
    if ([responder isKindOfClass:[NSSearchField class]]) {
        return YES;
    }
    else {
        return [super validateProposedFirstResponder:responder forEvent:event];
    }
}

- (BOOL) becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];
    if ([[self delegate] respondsToSelector:@selector(djl_tableViewBecomeFirstResponder:)]) {
        [(id <DJLTableViewDelegate>) [self delegate] djl_tableViewBecomeFirstResponder:self];
    }
    return result;
}

- (BOOL) resignFirstResponder
{
    BOOL result = [super resignFirstResponder];
    if ([[self delegate] respondsToSelector:@selector(djl_tableViewResignFirstResponder:)]) {
        [(id <DJLTableViewDelegate>) [self delegate] djl_tableViewResignFirstResponder:self];
    }
    return result;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint globalLocation = [theEvent locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];

    if (clickedRow != -1) {
        if ([[self delegate] respondsToSelector:@selector(djl_tableView:handleClickedRow:)]) {
            if ([(id <DJLTableViewDelegate>) [self delegate] djl_tableView:self handleClickedRow:clickedRow]) {
                return;
            }
        }
    }

    [super mouseDown:theEvent];

    if (clickedRow != -1) {
        if ([[self delegate] respondsToSelector:@selector(djl_tableView:didClickedRow:)]) {
            [(id <DJLTableViewDelegate>) [self delegate] djl_tableView:self didClickedRow:clickedRow];
        }
    }

    if (([theEvent modifierFlags] & NSControlKeyMask) != 0) {
        NSMenu * menu = [self menuForEvent:theEvent];
        if (menu != nil) {
            [NSMenu popUpContextMenu:menu withEvent:theEvent forView:self];
        }
    }
}

- (NSMenu *) menuForEvent:(NSEvent *)event
{
    NSPoint globalLocation = [event locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];
    if ([[self delegate] respondsToSelector:@selector(djl_tableView:menuForEvent:row:)]) {
        return [(id <DJLTableViewDelegate>) [self delegate] djl_tableView:self menuForEvent:event row:clickedRow];
    }
    return nil;
}

@end
