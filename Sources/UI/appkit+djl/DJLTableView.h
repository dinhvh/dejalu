// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLTableViewDelegate <NSObject>

@optional
- (BOOL) djl_tableView:(NSTableView *)tableView keyPress:(NSEvent *)event;
- (void) djl_tableViewBecomeFirstResponder:(NSTableView *)tableView;
- (void) djl_tableViewResignFirstResponder:(NSTableView *)tableView;
- (void) djl_tableView:(NSTableView *)tableView didClickedRow:(NSInteger)row;
- (BOOL) djl_tableView:(NSTableView *)tableView handleClickedRow:(NSInteger)row;
- (NSMenu *) djl_tableView:(NSTableView *)tableView menuForEvent:(NSEvent *)event row:(NSInteger)row;

@end

@interface DJLTableView : NSTableView

@end
