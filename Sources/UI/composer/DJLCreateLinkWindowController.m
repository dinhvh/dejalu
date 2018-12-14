// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLCreateLinkWindowController.h"

#import "DJLWindow.h"
#import "DJLColoredView.h"
#import "FBKVOController.h"
#import "DJLDarkMode.h"

@interface DJLCreateLinkWindowController () <DJLWindowDelegate>

@end

@implementation DJLCreateLinkWindowController {
    NSTextField * _urlLabel;
    NSTextField * _urlField;
    NSButton * _okButton;
    NSButton * _cancelButton;
    NSTextField * _errorMessageLabel;
    NSWindow * _parentWindow;
    FBKVOController * _kvoController;
}

#define DIALOG_WIDTH 350
#define DIALOG_HEIGHT 105

- (id) init
{
    DJLWindow * window = [[DJLWindow alloc] initWithContentRect:NSMakeRect(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT) styleMask:NSTitledWindowMask | NSTexturedBackgroundWindowMask backing:NSBackingStoreBuffered defer:YES];
    [window setDelegate:self];
    [window setTrafficLightAlternatePositionEnabled:NO];
    [window setTitlebarAppearsTransparent:YES];
    self = [super initWithWindow:window];

    [self _setupDialog];

    return self;
}

- (void) _setupDialog
{
    NSView * contentView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT)];
    [[self window] setContentView:contentView];
    _urlLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 62, DIALOG_WIDTH - 40, 22)];
    [_urlLabel setAutoresizingMask:NSViewMinYMargin];
    [_urlLabel setAlignment:NSTextAlignmentRight];
    [_urlLabel setEditable:NO];
    [_urlLabel setBezeled:NO];
    [_urlLabel setStringValue:@"Link"];
    [_urlLabel setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [_urlLabel sizeToFit];
    [contentView addSubview:_urlLabel];

    CGFloat x;
    x = NSMaxX([_urlLabel frame]);
    _urlField = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 10, 60, DIALOG_WIDTH - x - 20 - 10, 24)];
    [_urlField setAutoresizingMask:NSViewMinYMargin];
    [_urlField setFont:[NSFont fontWithName:@"Helvetica Neue" size:13]];
    [contentView addSubview:_urlField];

    _errorMessageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, DIALOG_WIDTH - 40, 0)];
    [_errorMessageLabel setHidden:YES];
    [_errorMessageLabel setEditable:NO];
    [_errorMessageLabel setBordered:NO];
    [_errorMessageLabel setTextColor:[NSColor colorWithCalibratedRed:0.75 green:0.25 blue:0.25 alpha:1.0]];
    [contentView addSubview:_errorMessageLabel];

    _okButton = [[NSButton alloc] initWithFrame:NSMakeRect(DIALOG_WIDTH - 20 - 100, 20, 100, 25)];
    [_okButton setBezelStyle:NSRoundRectBezelStyle];
    [_okButton setTitle:@"OK"];
    [_okButton setTarget:self];
    [_okButton setKeyEquivalent:@"\r"];
    [_okButton setAction:@selector(_okAction)];
    [contentView addSubview:_okButton];
    _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(DIALOG_WIDTH - 20 - 200 - 10, 20, 100, 25)];
    [_cancelButton setBezelStyle:NSRoundRectBezelStyle];
    [_cancelButton setTitle:@"Cancel"];
    [_cancelButton setTarget:self];
    [_cancelButton setAction:@selector(_cancelAction)];
    [contentView addSubview:_cancelButton];

    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:self keyPath:@"effectiveAppearance" options:0 block
                           :^(id observer, id object, NSDictionary *change) {
                               [weakSelf _applyDarkMode];
                           }];
    [self _applyDarkMode];
}

- (void) _applyDarkMode
{
    if ([DJLDarkMode isDarkModeForView:[[self window] contentView]]) {
        [(DJLColoredView *)[[self window] contentView] setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
    } else {
        [(DJLColoredView *)[[self window] contentView] setBackgroundColor:[NSColor whiteColor]];
    }
}

- (void) _showError:(NSString *)errorString
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_dialogDidResize) name:NSWindowDidResizeNotification object:[self window]];

    if (errorString == nil) {
        // hide error
        [_errorMessageLabel setHidden:YES];

        NSRect frame = [[self window] frame];
        CGFloat delta = DIALOG_HEIGHT - frame.size.height;
        frame.origin.y -= delta;
        frame.size.height += delta;
        [[self window] setFrame:frame display:YES animate:YES];
    }
    else {
        // show error
        [_errorMessageLabel setStringValue:errorString];
        [_errorMessageLabel setHidden:NO];
        NSSize size = [_errorMessageLabel sizeThatFits:NSMakeSize(260, MAXFLOAT)];

        NSRect frame = [[self window] frame];
        CGFloat delta = (DIALOG_HEIGHT + size.height) - frame.size.height;
        frame.origin.y -= delta;
        frame.size.height += delta;
        [[self window] setFrame:frame display:YES animate:YES];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:[self window]];
}

- (void) _dialogDidResize
{
    NSSize size = [[self window] frame].size;
    NSRect frame = [_errorMessageLabel frame];
    frame.size.height = size.height - DIALOG_HEIGHT;
    [_errorMessageLabel setFrame:frame];
}


- (void) beginSheetWithWindow:(NSWindow *)window url:(NSURL *)url
{
    if (url != nil) {
        [_urlField setStringValue:[url absoluteString]];
    }
    else {
        [_urlField setStringValue:@""];
    }
    _parentWindow = window;
    [_parentWindow beginSheet:[self window] completionHandler:^(NSModalResponse response) {
    }];
}

- (void) _okAction
{
    if ([[_urlField stringValue] length] == 0) {
        [self _showError:@"Please enter a valid link."];
        return;
    }

    NSURL * url = nil;
    url = [NSURL URLWithString:[_urlField stringValue]];
    if (url != nil) {
        if ([url scheme] == nil) {
            url = [NSURL URLWithString:[@"http://" stringByAppendingString:[_urlField stringValue]]];
        }
    }
    if (url == nil) {
        [self _showError:@"The link is not correct. Please make sure you typed a correct link."];
        return;
    }

    [[self window] orderOut:nil];
    [_parentWindow endSheet:[self window]];
    [[self delegate] DJLCreateLinkWindowController:self createLink:url];
}

- (void) _cancelAction
{
    [[self window] orderOut:nil];
    [_parentWindow endSheet:[self window]];
    [[self delegate] DJLCreateLinkWindowControllerCancelled:self];
}

- (BOOL) DJLWindowEscKeyPressed:(DJLWindow *)window
{
    [self _cancelAction];
    return YES;
}

@end
