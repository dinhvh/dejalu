// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLRefreshOverlayView.h"

#import "DJLColoredProgressIndicator.h"

@implementation DJLRefreshOverlayView {
    DJLColoredProgressIndicator * _progressView;
    BOOL _started;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];

    _progressView = [[DJLColoredProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [_progressView setColor:[NSColor whiteColor]];
    [self addSubview:_progressView];
    [_progressView setHidden:YES];

    return self;
}

- (NSString *) _text
{
    return @"Refreshing";
}

- (void) sizeToFit
{
    NSDictionary * attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue Bold" size:14]};
    NSSize size = [[self _text] sizeWithAttributes:attr];
    size.height += 20;
    size.width += 30 + 30;
    NSRect frame = [self frame];
    frame.size = size;
    [self setFrame:frame];

    frame.size.width = 20;
    frame.size.height = 20;
    frame.origin.x = [self bounds].size.width - 30;
    frame.origin.y = [self bounds].size.height - 31;
    [_progressView setHidden:YES];
    [_progressView setFrame:frame];
}

- (void) drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0 alpha:0.75] setFill];
    NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:20 yRadius:20];
    [path fill];

    NSDictionary * attr = @{NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue Bold" size:14], NSForegroundColorAttributeName: [NSColor whiteColor]};
    NSRect rect = [self bounds];
    if (_started) {
        rect.origin.x += 20;
        rect.size.height -= 8;
        [[self _text] drawInRect:rect withAttributes:attr];
    }
    else {
        NSSize size = [@"Refresh" sizeWithAttributes:attr];
        rect.origin.x = (int) (([self bounds].size.width - size.width) / 2.0);
        rect.size.height -= 8;
        [@"Refresh" drawInRect:rect withAttributes:attr];
    }
}

- (void) startAnimation
{
    _started = YES;
    [_progressView setHidden:NO];
    [_progressView startAnimation:nil];
    [self _refreshDisplay];
}

- (void) stopAnimation
{
    _started = NO;
    [_progressView setHidden:YES];
    [_progressView stopAnimation:nil];
    [self performSelector:@selector(_refreshDisplay) withObject:nil afterDelay:0.5];
}

- (void) _refreshDisplay
{
    [self setNeedsDisplay:YES];
}

@end
