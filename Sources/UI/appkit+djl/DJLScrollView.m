// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLScrollView.h"

@implementation DJLScrollView {
    BOOL _dragging;
    BOOL _started;
}

@synthesize dragging = _dragging;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollStarted) name:NSScrollViewWillStartLiveScrollNotification object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollMoved) name:NSScrollViewDidLiveScrollNotification object:self];
    return self;
}

- (void) scrollWheel:(NSEvent *)theEvent
{
    _dragging = YES;
    if ([theEvent momentumPhase] != NSEventPhaseNone) {
        _dragging = NO;
    }
    [super scrollWheel:theEvent];
    _dragging = NO;
}

- (void) _scrollMoved
{
    if (!_dragging && _started) {
        _started = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:DJLScrollViewDidEndDraggingScrollNotification object:self];
    }
}

- (void) _scrollStarted
{
    _started = YES;
}

@end
