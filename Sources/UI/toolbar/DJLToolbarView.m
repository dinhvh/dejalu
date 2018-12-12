// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLToolbarView.h"

#import "DJLGradientSeparatorLineView.h"
#import "DJLColoredView.h"
#import "DJLDarkMode.h"
#import "FBKVOController.h"
#import "DJLPopoverButton.h"

@interface DJLToolbarView ()

@property (nonatomic, assign, getter=isHighlighted) BOOL highlighted;

@end

@implementation DJLToolbarView {
    NSTrackingArea * _area;
    NSPoint _initialLocation;
    DJLGradientSeparatorLineView * _separatorView;
    BOOL _movingAllowed;
    CGFloat _vibrancy;
    DJLColoredView * _opaqueView;
    BOOL _dragging;
    NSMutableDictionary * _validation;
    BOOL _appStarted;
    FBKVOController * _kvoController;
    BOOL _forceWhiteBackground;
}

@synthesize viewsToFade = _viewsToFade;
@synthesize highlighted = _highlighted;
@synthesize validationDelegate = _validationDelegate;
@synthesize forceWhiteBackground = _forceWhiteBackground;

static NSTimeInterval s_startTime = 0;

+ (void) initialize
{
    s_startTime = [NSDate timeIntervalSinceReferenceDate];
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    _vibrancy = 1.0;

    _validation = [[NSMutableDictionary alloc] init];

    _opaqueView = [[DJLColoredView alloc] initWithFrame:[self bounds]];
    [_opaqueView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_opaqueView setAlphaValue:0.0];
    [self addSubview:_opaqueView];

    NSRect separatorFrame = [self bounds];
    separatorFrame.size.height = 1;
    _separatorView = [[DJLGradientSeparatorLineView alloc] initWithFrame:separatorFrame];
    [_separatorView setAutoresizingMask:NSViewWidthSizable];
    [_separatorView setAlphaValue:0.0];
    [self addSubview:_separatorView];

    [self setHighlighted:NO];
    [self updateTrackingAreas];
    [self _setup];

    if ([NSDate timeIntervalSinceReferenceDate] - s_startTime < 10) {
        _appStarted = YES;
        [self performSelector:@selector(_delayedAppStartHighlight) withObject:nil afterDelay:10];
    }

    _kvoController = [FBKVOController controllerWithObserver:self];
    [_kvoController observe:self keyPath:@"effectiveAppearance" options:0 block:^(id observer, id object, NSDictionary * change) {
        [self _applyDarkMode];
    }];
    [self _applyDarkMode];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeTrackingArea:_area];
}

- (void) _applyDarkMode
{
    if ([DJLDarkMode isDarkModeForView:self] && !_forceWhiteBackground) {
        [_opaqueView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.08 alpha:1.0]];
    } else {
        [_opaqueView setBackgroundColor:[NSColor whiteColor]];
    }
}

- (void) setForceWhiteBackground:(BOOL)forceWhiteBackground
{
    _forceWhiteBackground = forceWhiteBackground;
    [self _applyDarkMode];
}

- (void) viewDidMoveToWindow
{
    [self _updateHighlight];
    [self _applyDarkMode];
}

- (void) _delayedAppStartHighlight
{
    _appStarted = NO;
    [self _updateHighlight];
}

- (void) _setup
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didBecomeActive) name:NSApplicationDidBecomeActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didBecomeKey) name:NSWindowDidBecomeKeyNotification object:[self window]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didResignActive) name:NSApplicationDidResignActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didResignKey) name:NSWindowDidResignKeyNotification object:[self window]];
}

- (void) _didBecomeActive
{
    [self _updateHighlight];
}

- (void) _didBecomeKey
{
    [self _updateHighlight];
}

- (void) _didResignActive
{
    [self _updateHighlight];
}

- (void) _didResignKey
{
    [self _updateHighlight];
}

- (NSRect) toolbarRect
{
    return [self bounds];
}

- (void) _updateHighlight
{
    NSRect rect = [self convertRect:[self toolbarRect] toView:nil];
    rect = [[self window] convertRectToScreen:rect];
    BOOL mouseOver = NSPointInRect([NSEvent mouseLocation], rect);
    [self setHighlighted:([NSApp isActive] && [[self window] isKeyWindow] && mouseOver) || _appStarted];

    for(NSView * view in [self viewsToFade]) {
        if ([view isKindOfClass:[DJLPopoverButton class]]) {
            [(DJLPopoverButton *)view setForceWhiteBackground:_forceWhiteBackground];
        }
    }
}

- (void) mouseDown:(NSEvent *)theEvent
{
    NSRect windowFrame = [[self window] frame];

    _dragging = YES;
    _initialLocation = [NSEvent mouseLocation];

    _initialLocation.x -= windowFrame.origin.x;
    _initialLocation.y -= windowFrame.origin.y;

    while (1) {
        NSEvent * event = [NSApp nextEventMatchingMask:(NSLeftMouseUpMask|NSLeftMouseDraggedMask)
                                             untilDate:[NSDate distantFuture]
                                                inMode:NSEventTrackingRunLoopMode
                                               dequeue:YES];
        if ([event type] == NSLeftMouseDragged) {
            [self mouseDragged:event];
        }
        else if ([event type] == NSLeftMouseUp) {
            break;
        }
    }

    [self mouseUp:theEvent];
}

- (void) mouseUp:(NSEvent *)theEvent
{
    _dragging = NO;
    [self _updateHighlight];
}

- (void) mouseDragged:(NSEvent *)theEvent
{
    if (!_dragging) {
        return;
    }

    NSPoint currentLocation;
    NSPoint newOrigin;

    NSRect  screenFrame = [[NSScreen mainScreen] frame];
    NSRect  windowFrame = [self frame];

    currentLocation = [NSEvent mouseLocation];
    newOrigin.x = currentLocation.x - _initialLocation.x;
    newOrigin.y = currentLocation.y - _initialLocation.y;

    // Don't let window get dragged up under the menu bar
    if ((newOrigin.y + windowFrame.size.height) > (screenFrame.origin.y + screenFrame.size.height)) {
        newOrigin.y = screenFrame.origin.y + (screenFrame.size.height - windowFrame.size.height);
    }

    //go ahead and move the window to the new location
    [[self window] setFrameOrigin:newOrigin];
}

#define UNHIGHLIGHTED_VALUE 0.15

- (void) setHighlighted:(BOOL)highlighted
{
    _highlighted = highlighted;
    if ([self isHighlighted]) {
        for(NSView * view in [self viewsToFade]) {
            [[view animator] setAlphaValue:1.0];
        }
    }
    else {
        for(NSView * view in [self viewsToFade]) {
            [[view animator] setAlphaValue:UNHIGHLIGHTED_VALUE];
        }
    }
}

- (CGFloat) currentViewToFadeAlphaValue
{
    if (_highlighted) {
        return 1.0;
    }
    else {
        return UNHIGHLIGHTED_VALUE;
    }
}

- (void) setSeparatorAlphaValue:(CGFloat)alphaValue
{
    [_separatorView setAlphaValue:alphaValue];
}

- (CGFloat) separatorAlphaValue
{
    return [_separatorView alphaValue];
}

- (void) updateTrackingAreas
{
    if (_area != nil) {
        [self removeTrackingArea:_area];
    }
    _area = [[NSTrackingArea alloc] initWithRect:[self toolbarRect] options:NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited /* | NSTrackingMouseMoved */ owner:self userInfo:nil];
    [self addTrackingArea:_area];
}

- (void) mouseEntered:(NSEvent *)theEvent
{
    [super mouseEntered:theEvent];
    [self _updateHighlight];
}

- (void) mouseExited:(NSEvent *)theEvent
{
    [super mouseExited:theEvent];
    [self _updateHighlight];
}

- (CGFloat) vibrancy
{
    return _vibrancy;
}

- (void) setVibrancy:(CGFloat)vibrancy
{
    _vibrancy = vibrancy;
    [_opaqueView setAlphaValue:1.0 - _vibrancy];
    //[self setNeedsDisplay:YES];
}

- (void) setButtonValidation:(NSButton *)button selector:(SEL)selector
{
    [_validation setObject:NSStringFromSelector(selector) forKey:[NSValue valueWithPointer:(void *) button]];
}

- (void) validate
{
    for(NSValue * buttonPointer in _validation) {
        NSButton * button = (NSButton *) [buttonPointer pointerValue];
        SEL selector = NSSelectorFromString([_validation objectForKey:buttonPointer]);
        BOOL enabled = [[self validationDelegate] DJLToolbarView:self validate:selector];
        [button setEnabled:enabled];
    }
}

@end
