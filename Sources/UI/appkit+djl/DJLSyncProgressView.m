// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLSyncProgressView.h"

#import "DJLGradientView.h"

@implementation DJLSyncProgressView {
    double _progressValue;
    double _progressMax;
    NSString * _text;
    DJLGradientView * _backgroundView;
    NSProgressIndicator * _progressView;
}

@synthesize progressValue = _progressValue;
@synthesize progressMax = _progressMax;
@synthesize text = _text;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    NSRect subviewFrame = [self bounds];
    subviewFrame.origin.y = subviewFrame.size.height - 10;
    subviewFrame.size.height = 10;
    _backgroundView = [[DJLGradientView alloc] initWithFrame:subviewFrame];
    [_backgroundView setStartColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.9]];
    [_backgroundView setEndColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
    [_backgroundView setAngle:90];
    [_backgroundView setAutoresizingMask:NSViewWidthSizable];
    [self addSubview:_backgroundView];
    subviewFrame = [self bounds];
    subviewFrame.origin.x = 20;
    subviewFrame.size.width -= 40;
    subviewFrame.origin.y = 10;
    subviewFrame.size.height = 10;
    _progressView = [[NSProgressIndicator alloc] initWithFrame:subviewFrame];
    [_progressView setControlSize:NSMiniControlSize];
    [_progressView setAutoresizingMask:NSViewWidthSizable];
    [_progressView setStyle:NSProgressIndicatorBarStyle];
    [_progressView setIndeterminate:YES];
    [_progressView startAnimation:nil];
    [self addSubview:_progressView];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect frame = [self bounds];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.9] setFill];
    frame.size.height -= 10;
    NSRectFill(frame);
    NSString * progressString = nil;
    progressString = [self text];
    NSMutableDictionary * attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSFont systemFontOfSize:14] forKey:NSFontAttributeName];
    [attributes setObject:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0] forKey:NSForegroundColorAttributeName];
    NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
    [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
    NSSize size = [progressString sizeWithAttributes:attributes];
    if (size.width > [self bounds].size.width - 40) {
        size.width = [self bounds].size.width - 40;
    }
    NSPoint point = NSMakePoint(ceilf([self bounds].size.width - size.width) / 2, [self bounds].size.height - 25);
    NSRect rect = NSZeroRect;
    rect.origin = point;
    rect.size = size;
    [progressString drawInRect:rect withAttributes:attributes];
}

- (void) setProgressMax:(double)progressMax
{
    _progressMax = progressMax;
    [self setNeedsDisplay:YES];

    if (_progressMax != 0) {
        [_progressView setIndeterminate:NO];
        [_progressView setMaxValue:_progressMax];
        [_progressView setDoubleValue:_progressValue];
    }
    else {
        [_progressView setIndeterminate:YES];
    }
}

- (void) setProgressValue:(double)progressValue
{
    _progressValue = progressValue;
    [self setNeedsDisplay:YES];
    [_progressView setDoubleValue:_progressValue];
}

- (void) setText:(NSString *)text
{
    _text = text;
    [self setNeedsDisplay:YES];
}

@end
