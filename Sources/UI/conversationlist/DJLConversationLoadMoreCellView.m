// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationLoadMoreCellView.h"

@implementation DJLConversationLoadMoreCellView {
    BOOL _syncing;
    NSProgressIndicator * _progressView;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    _progressView = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    [_progressView setStyle:NSProgressIndicatorSpinningStyle];
    [_progressView setIndeterminate:YES];
    [_progressView setDisplayedWhenStopped:NO];
    [self addSubview:_progressView];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSString * description = @"More emails available on the server";
    NSMutableDictionary * attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSFont systemFontOfSize:14] forKey:NSFontAttributeName];
    [attributes setObject:[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] forKey:NSForegroundColorAttributeName];
    NSSize size = [description sizeWithAttributes:attributes];
    NSPoint point = NSMakePoint(ceilf([self bounds].size.width - size.width) / 2, ceilf([self bounds].size.height - size.height) / 2);
    [description drawAtPoint:point withAttributes:attributes];
    
    NSRect frame = NSMakeRect(point.x + size.width + 5, point.y, 16, 16);
    [_progressView setFrame:frame];
}

- (BOOL) isSyncing
{
    return _syncing;
}

- (void) setSyncing:(BOOL)syncing
{
    _syncing = syncing;
    if (_syncing) {
        [_progressView startAnimation:nil];
    }
    else {
        [_progressView stopAnimation:nil];
    }
}

@end
