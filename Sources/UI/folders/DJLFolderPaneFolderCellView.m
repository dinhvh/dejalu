// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneFolderCellView.h"

@implementation DJLFolderPaneFolderCellView {
    NSTextField * _textField;
    NSTextField * _countTextField;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    _textField = [[NSTextField alloc] initWithFrame:[self bounds]];
    [_textField setFont:[NSFont systemFontOfSize:14]];
    [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
    [_textField setBezeled:NO];
    [_textField setBordered:NO];
    [_textField setDrawsBackground:NO];
    [_textField setEditable:NO];
    [self addSubview:_textField];

    _countTextField = [[NSTextField alloc] initWithFrame:[self bounds]];
    [_countTextField setFont:[NSFont systemFontOfSize:11]];
    [_countTextField setTextColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
    [_countTextField setBezeled:NO];
    [_countTextField setBordered:NO];
    [_countTextField setDrawsBackground:NO];
    [_countTextField setEditable:NO];
    [self addSubview:_countTextField];

    _selectable = YES;

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setSelected:(BOOL)selected
{
    _selected = selected;
    [self _applyColor];
}

- (void) setEmphasized:(BOOL)emphasized
{
    _emphasized = emphasized;
    [self _applyColor];
}

- (void) setSelectable:(BOOL)selectable
{
    _selectable = selectable;
    [self _applyColor];
}

- (void) _applyColor
{
    if (_emphasized) {
        if (_selected) {
            [_textField setTextColor:[NSColor whiteColor]];
            [_countTextField setTextColor:[NSColor whiteColor]];
        }
        else {
            if (_selectable) {
                [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
                [_countTextField setTextColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
            }
            else {
                [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
                [_countTextField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
            }
        }
    }
    else {
        if (_selectable) {
            [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
            [_countTextField setTextColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
        }
        else {
            [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
            [_countTextField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
        }
    }
}

- (void) setDisplayName:(NSString *)displayName
{
    _displayName = displayName;
    [_textField setStringValue:displayName];
    NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
    [style setLineBreakMode:NSLineBreakByTruncatingTail];
    NSDictionary * attr = @{NSParagraphStyleAttributeName: style};
    NSAttributedString * attrStr = [[NSAttributedString alloc] initWithString:displayName attributes:attr];
    [_textField setAttributedStringValue:attrStr];
    [self resizeSubviewsWithOldSize:NSZeroSize];
}

- (void) setCount:(int)count
{
    _count = count;
    if (count == 0) {
        [_countTextField setStringValue:@""];
    }
    else {
        [_countTextField setStringValue:[NSString stringWithFormat:@"%i", count]];
    }
    [self resizeSubviewsWithOldSize:NSZeroSize];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
    [_countTextField sizeToFit];
    NSRect frame = [_countTextField frame];
    frame.origin.y = ([self bounds].size.height - frame.size.height) / 2;
    frame.origin.x = [self bounds].size.width - frame.size.width;
    frame = NSIntegralRect(frame);
    [_countTextField setFrame:frame];

    [_textField sizeToFit];
    frame = [_textField frame];
    frame.size.width = [self bounds].size.width - [_countTextField frame].size.width - 5;
    if (frame.size.width < 0) {
        frame.size.width = 0;
    }
    frame.origin.y = ([self bounds].size.height - frame.size.height) / 2;
    frame = NSIntegralRect(frame);
    [_textField setFrame:frame];

    frame = [_countTextField frame];
    frame.origin.y = [_textField frame].origin.y;
    [_countTextField setFrame:frame];
    //frame.origin.y = [_textField frame].origin.y + [_textField frame].size.height - frame.size.height;
}

@end
