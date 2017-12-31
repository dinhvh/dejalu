// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLHUDWindow.h"

@implementation DJLHUDWindow

static NSMutableArray * s_windows = nil;

+ (void) initialize
{
    s_windows = [[NSMutableArray alloc] init];
}

+ (NSWindow *) windowWithView:(NSView *)mainView
{
    NSWindow * fullScreenWindow = [[NSWindow alloc] initWithContentRect:(CGRect){ .size = [NSScreen mainScreen].frame.size }
                                                                styleMask:NSBorderlessWindowMask
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO
                                                                 screen:[NSScreen mainScreen]];
    
    fullScreenWindow.animationBehavior = NSWindowAnimationBehaviorNone;
    fullScreenWindow.backgroundColor = NSColor.clearColor;
    fullScreenWindow.movableByWindowBackground = NO;
    fullScreenWindow.ignoresMouseEvents = YES;
    fullScreenWindow.level = NSFloatingWindowLevel;
    fullScreenWindow.hasShadow = NO;
    fullScreenWindow.opaque = NO;
    //fullScreenWindow.contentView = NULL;
    NSRect frame = [mainView frame];
    frame.origin.x = (int) (([NSScreen mainScreen].frame.size.width - [mainView frame].size.width) / 2);
    frame.origin.y = (int) (([NSScreen mainScreen].frame.size.height - [mainView frame].size.height) / 3);
    [mainView setFrame:frame];
    [fullScreenWindow.contentView addSubview:mainView];
    [s_windows addObject:fullScreenWindow];
    [fullScreenWindow orderFront:nil];

    [self performSelector:@selector(_fadeWindow:) withObject:fullScreenWindow afterDelay:2.0];
    
    return fullScreenWindow;
}

+ (void) _fadeWindow:(NSWindow *)window
{
    NSView * mainView = [[[window contentView] subviews] objectAtIndex:0];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [window orderOut:nil];
        [s_windows removeObject:window];
    }];
    [[mainView animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

@end
