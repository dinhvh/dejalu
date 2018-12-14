// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneAccountCellView.h"

#import "FBKVOController.h"
#import "DJLDarkMode.h"

@implementation DJLFolderPaneAccountCellView {
    NSTextField * _textField;
    FBKVOController * _kvoController;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    _textField = [[NSTextField alloc] initWithFrame:[self bounds]];
    [_textField setFont:[NSFont boldSystemFontOfSize:11]];
    [_textField setBezeled:NO];
    [_textField setBordered:NO];
    [_textField setDrawsBackground:NO];
    [_textField setEditable:NO];
    [self addSubview:_textField];
    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:self keyPath:@"effectiveAppearance" options:0 block:^(id observer, id object, NSDictionary *change) {
        [weakSelf _applyTextColor];
    }];
    [self _applyTextColor];
    return self;
}

- (void) _applyTextColor
{
    if ([DJLDarkMode isDarkModeForView:self]) {
        [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.7 alpha:1.0]];
    } else {
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
