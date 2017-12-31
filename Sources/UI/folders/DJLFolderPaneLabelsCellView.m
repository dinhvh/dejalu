// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneLabelsCellView.h"

@implementation DJLFolderPaneLabelsCellView {
    NSTextField * _textField;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    _textField = [[NSTextField alloc] initWithFrame:[self bounds]];
    [_textField setFont:[NSFont systemFontOfSize:14]];
    [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
    //[_textField setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_textField setBezeled:NO];
    [_textField setBordered:NO];
    [_textField setDrawsBackground:NO];
    [_textField setEditable:NO];
    [self addSubview:_textField];

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

- (void) _applyColor
{
    if (_emphasized) {
        if (_selected) {
            [_textField setTextColor:[NSColor whiteColor]];
        }
        else {
            [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
        }
    }
    else {
        [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
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

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
    [_textField sizeToFit];
    NSRect frame = [_textField frame];
    frame.size.width = [self bounds].size.width;
    frame.origin.y = ([self bounds].size.height - frame.size.height) / 2;
    frame = NSIntegralRect(frame);
    [_textField setFrame:frame];
}

@end
