// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationRowView.h"

@implementation DJLConversationRowView {
    BOOL _lastSelectedRow;
}

@synthesize firstSelectedRow = _firstSelectedRow;
@synthesize lastSelectedRow = _lastSelectedRow;

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    return self;
}

- (void) setSelected:(BOOL)selected
{
    [super setSelected:selected];
    //[self setNeedsDisplay:YES];
}

- (void) setLastSelectedRow:(BOOL)lastSelectedRow
{
    _lastSelectedRow = lastSelectedRow;
    //[self setNeedsDisplay:YES];
}

- (void) setFirstSelectedRow:(BOOL)firstSelectedRow
{
    _firstSelectedRow = firstSelectedRow;
    //[self setNeedsDisplay:YES];
}

@end
