// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPreferencesWindowController.h"

#import <GoogleAnalyticsTracker/GoogleAnalyticsTracker.h>

#import "DJLWindow.h"
#import "DJLColoredView.h"
#import "DJLPreferencesToolbarView.h"
#import "DJLPrefsGeneralViewController.h"
#import "DJLPrefsAccountsViewController.h"
#import "DJLPrefsLabelsViewController.h"
#import "DJLPrefsAliasesViewController.h"
#import "DJLPrefsSignatureViewController.h"

@interface DJLPreferencesWindowController () <NSWindowDelegate, DJLPreferencesToolbarViewDelegate>

@end

@implementation DJLPreferencesWindowController {
    DJLPreferencesToolbarView * _toolbar;
    NSMutableArray * _viewControllers;
    DJLPrefsGeneralViewController * _prefsGeneralViewController;
    DJLPrefsAccountsViewController * _prefsAccountsViewController;
    DJLPrefsLabelsViewController * _prefsLabelsViewController;
    DJLPrefsAliasesViewController * _prefsAliasesViewController;
    DJLPrefsSignatureViewController * _prefsSignatureViewController;
    DJLPreferencesViewController * _currentController;
}

- (id) init
{
    NSWindow * window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 400)
                                                      styleMask:NSTitledWindowMask | /* NSResizableWindowMask | */NSClosableWindowMask | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask | NSFullSizeContentViewWindowMask
                                                        backing:NSBackingStoreBuffered defer:YES];
    NSRect frame;
    [window setTitlebarAppearsTransparent:YES];
    [window center];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setReleasedWhenClosed:NO];

    frame = [window frame];
    frame.origin = CGPointZero;
    DJLColoredView * contentView = [[DJLColoredView alloc] initWithFrame:frame];
    [contentView setAutoresizingMask:NSViewHeightSizable];
    [window setContentView:contentView];
    [contentView setWantsLayer:YES];

    self = [super initWithWindow:window];

    [window setDelegate:self];

    [self _setup];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) _updateUI
{
    _prefsGeneralViewController = [[DJLPrefsGeneralViewController alloc] initWithNibName:nil bundle:nil];
    _prefsAccountsViewController = [[DJLPrefsAccountsViewController alloc] initWithNibName:nil bundle:nil];
    _prefsLabelsViewController = [[DJLPrefsLabelsViewController alloc] initWithNibName:nil bundle:nil];
    _prefsAliasesViewController = [[DJLPrefsAliasesViewController alloc] initWithNibName:nil bundle:nil];
    _prefsSignatureViewController = [[DJLPrefsSignatureViewController alloc] initWithNibName:nil bundle:nil];
    _viewControllers = [[NSMutableArray alloc] init];
    [self _register:_prefsGeneralViewController];
    [self _register:_prefsAccountsViewController];
    [self _register:_prefsLabelsViewController];
    [self _register:_prefsAliasesViewController];
    [self _register:_prefsSignatureViewController];

    NSMutableArray * icons = [NSMutableArray array];
    for(DJLPreferencesViewController * controller in _viewControllers) {
        [icons addObject:@{@"icon": [controller icon], @"title": [controller title]}];
    }
    [_toolbar setIcons:icons];
}

- (void) _setup
{
    NSRect bounds = [[[self window] contentView] bounds];
    _toolbar = [[DJLPreferencesToolbarView alloc] initWithFrame:NSMakeRect(0, bounds.size.height - 87, bounds.size.width, 65)];
    [_toolbar setAutoresizingMask:NSViewMinYMargin];
    [_toolbar setDelegate:self];
    NSView * contentView = [[self window] contentView];
    [contentView addSubview:_toolbar];

    [self _updateUI];
}

- (void) _register:(DJLPreferencesViewController *)controller
{
    if (controller == nil) {
        return;
    }
    [_viewControllers addObject:controller];
}

- (void) showLabelsForAccount:(hermes::Account *)account
{
    [_toolbar setSelectedIndex:2];
    [_prefsLabelsViewController setAccount:account];
}

- (IBAction) createLink:(id)sender
{
    if (_currentController == _prefsSignatureViewController) {
        [_prefsSignatureViewController createLink:sender];
    }
}

- (void) DJLPreferencesToolbarViewSelectionChanged:(DJLPreferencesToolbarView *)view
{
    [_currentController viewDidHide];
    [[_currentController view] removeFromSuperview];
    if ([_toolbar selectedIndex] == -1) {
        _currentController = nil;
        return;
    }
    NSView * contentView = [[self window] contentView];
    _currentController = [_viewControllers objectAtIndex:[_toolbar selectedIndex]];
    NSRect frame = [contentView bounds];
    frame.size.height -= 87;
    [[_currentController view] setFrame:frame];
    [[_currentController view] setAutoresizingMask:NSViewHeightSizable];
    [contentView addSubview:[_currentController view]];
    [_currentController viewDidShow];

    NSRect windowFrame = [[self window] frame];
    CGFloat diff = 87 + [_currentController height] - windowFrame.size.height;
    windowFrame.origin.y -= diff;
    windowFrame.size.height = 87 + [_currentController height];
    [[self window] setFrame:windowFrame display:YES animate:YES];
}

- (void) showWindow:(id)sender
{
    [super showWindow:sender];
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"Preferences" action:@"Open" label:@"Open the app preferences" value:@(0)];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
}

- (void)windowWillClose:(NSNotification *)notification
{
    [_currentController viewDidHide];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return [_currentController validateMenuItem:menuItem];
}

@end
