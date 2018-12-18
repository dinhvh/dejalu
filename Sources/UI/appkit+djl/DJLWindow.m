// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLWindow.h"

#import "FBKVOController.h"

@implementation DJLWindow {
}

@synthesize trafficLightAlternatePositionEnabled = _trafficLightAlternatePositionEnabled;

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
    self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation];
    _trafficLightAlternatePositionEnabled = YES;
    [self _setup];
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) _setup
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(_layoutTrafficLightsAndContent) name:NSWindowDidResizeNotification object:self];
    [nc addObserver:self selector:@selector(_layoutTrafficLightsAndContent) name:NSWindowDidMoveNotification object:self];
    [nc addObserver:self selector:@selector(_layoutTrafficLightsAndContent) name:NSWindowDidEndSheetNotification object:self];
    [nc addObserver:self selector:@selector(_layoutTrafficLightsAndContent) name:NSWindowDidExitFullScreenNotification object:self];
    [nc addObserver:self selector:@selector(_layoutTrafficLightsAndContent) name:NSWindowWillEnterFullScreenNotification object:self];
    [nc addObserver:self selector:@selector(_layoutTrafficLightsAndContent) name:NSWindowWillExitFullScreenNotification object:self];
    [self _layoutTrafficLightsAndContent];
}

- (void)beginSheet:(NSWindow *)sheetWindow completionHandler:(void (^)(NSModalResponse returnCode))handler
{
    [self _workaroundSheetLayoutTrafficLights];
    [super beginSheet:sheetWindow completionHandler:handler];
}

- (void) setTrafficLightAlternatePositionEnabled:(BOOL)trafficLightAlternatePositionEnabled
{
    _trafficLightAlternatePositionEnabled = trafficLightAlternatePositionEnabled;
    [self _setup];
}

- (void) _workaroundSheetLayoutTrafficLights
{
    [self performSelector:@selector(_layoutTrafficLightsAndContent) withObject:nil afterDelay:0.0 inModes:@[@"_NSMoveTimerRunLoopMode"]];
}

- (void) _layoutTrafficLightsAndContent
{
    if (!_trafficLightAlternatePositionEnabled) {
        return;
    }

    NSView * titleViewContainer = nil;
    for (id view in [[[self contentView] superview] subviews]) {
        // find the NSTitlebarContainerView
        if (![view isKindOfClass:NSClassFromString(@"NSTitlebarContainerView")]) {
            continue;
        }
        titleViewContainer = view;
    }

    NSButton * closeButton = [self standardWindowButton:NSWindowCloseButton];
    NSRect frame = [titleViewContainer frame];
    frame.size.height = 29;
    frame.origin.y = [[titleViewContainer superview] bounds].size.height - 29 + 1;
    [titleViewContainer setFrame:frame];
    frame = [closeButton frame];
    frame.origin.x = 12;
    [closeButton setFrame:frame];
    NSButton * minimizeButton = [self standardWindowButton:NSWindowMiniaturizeButton];
    frame = [minimizeButton frame];
    frame.origin.x = 32;
    [minimizeButton setFrame:frame];
    NSButton * zoomButton = [self standardWindowButton:NSWindowZoomButton];
    frame = [zoomButton frame];
    frame.origin.x = 52;
    [zoomButton setFrame:frame];
}

- (void) flagsChanged:(NSEvent *)theEvent
{
    [super flagsChanged:theEvent];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DJLWINDOW_FLAGS_CHANGED object:self];
}

- (void) sendEvent:(NSEvent *)theEvent
{
    if ([theEvent type] == NSKeyDown) {
        switch ([theEvent keyCode]) {
            case 49: {
                if ([[self delegate] respondsToSelector:@selector(DJLWindowSpaceKeyPressed:)]) {
                    if ([(id<DJLWindowDelegate>)[self delegate] DJLWindowSpaceKeyPressed:self]) {
                        return;
                    }
                }
                break;
            }
            case 53: {
                if ([[self delegate] respondsToSelector:@selector(DJLWindowEscKeyPressed:)]) {
                    if ([(id<DJLWindowDelegate>)[self delegate] DJLWindowEscKeyPressed:self]) {
                        return;
                    }
                }
                break;
            }
        }
    }
    [super sendEvent:theEvent];
}

- (void) setMinSize:(NSSize)minSize
{
    [super setMinSize:minSize];
    [self _layoutTrafficLightsAndContent];
}

- (void) setMaxSize:(NSSize)maxSize
{
    [super setMaxSize:maxSize];
    [self _layoutTrafficLightsAndContent];
}

- (void) setTitle:(NSString *)title
{
    [super setTitle:title];
    [self _layoutTrafficLightsAndContent];
}

@end
