// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrefsGeneralViewController.h"

#import "DJLURLHandler.h"
#import "DJLDarkMode.h"

@interface DJLCheckboxButtonCell  : NSButtonCell

@end

@implementation DJLCheckboxButtonCell

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    if ([DJLDarkMode isDarkModeForView:[self controlView]]) {
        [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] setFill];
    } else {
        [[NSColor whiteColor] setFill];
    }
    NSRectFill(cellFrame);

    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSetShouldSmoothFonts(ctx, true);
    [super drawWithFrame:cellFrame inView:controlView];
}

@end

@interface DJLPrefsGeneralViewController ()

@end

@implementation DJLPrefsGeneralViewController {
    NSButton * _makeDefaultButton;
    NSButton * _playSoundButton;
    NSButton * _zenNotificationsButton;
    NSButton * _showSenderAvatarButton;
    NSButton * _showStatusItemButton;
    NSButton * _quickSyncButton;
    NSTextField * _zenDescription;
}

- (NSImage *) icon
{
    return [NSImage imageNamed:@"DejaLu_GeneralSettings_Light_32"];
}

- (NSString *) title
{
    return @"General";
}

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSZeroRect];
    [self setView:view];

    _makeDefaultButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_makeDefaultButton setCell:[[DJLCheckboxButtonCell alloc] init]];
    [_makeDefaultButton setButtonType:NSSwitchButton];
    [_makeDefaultButton setTitle:@"Default email reader"];
    [_makeDefaultButton setFont:[NSFont systemFontOfSize:12]];
    [_makeDefaultButton sizeToFit];
    [_makeDefaultButton setTarget:self];
    [_makeDefaultButton setAction:@selector(_makeDefaultChanged:)];
    [[self view] addSubview:_makeDefaultButton];

    _playSoundButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_playSoundButton setCell:[[DJLCheckboxButtonCell alloc] init]];
    [_playSoundButton setButtonType:NSSwitchButton];
    [_playSoundButton setTitle:@"Play sound"];
    [_playSoundButton setFont:[NSFont systemFontOfSize:12]];
    [_playSoundButton sizeToFit];
    [_playSoundButton setTarget:self];
    [_playSoundButton setAction:@selector(_playSoundChanged:)];
    [[self view] addSubview:_playSoundButton];

    _zenNotificationsButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_zenNotificationsButton setCell:[[DJLCheckboxButtonCell alloc] init]];
    [_zenNotificationsButton setButtonType:NSSwitchButton];
    [_zenNotificationsButton setTitle:@"Zen notifications"];
    [_zenNotificationsButton setFont:[NSFont systemFontOfSize:12]];
    [_zenNotificationsButton sizeToFit];
    [_zenNotificationsButton setTarget:self];
    [_zenNotificationsButton setAction:@selector(_zenNotificationsChanged:)];
    [[self view] addSubview:_zenNotificationsButton];

    _showSenderAvatarButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_showSenderAvatarButton setCell:[[DJLCheckboxButtonCell alloc] init]];
    [_showSenderAvatarButton setButtonType:NSSwitchButton];
    [_showSenderAvatarButton setTitle:@"Show sender avatar"];
    [_showSenderAvatarButton setFont:[NSFont systemFontOfSize:12]];
    [_showSenderAvatarButton sizeToFit];
    [_showSenderAvatarButton setTarget:self];
    [_showSenderAvatarButton setAction:@selector(_showSenderAvatarChanged:)];
    [[self view] addSubview:_showSenderAvatarButton];

    _showStatusItemButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_showStatusItemButton setCell:[[DJLCheckboxButtonCell alloc] init]];
    [_showStatusItemButton setButtonType:NSSwitchButton];
    [_showStatusItemButton setTitle:@"Show menu bar icon"];
    [_showStatusItemButton setFont:[NSFont systemFontOfSize:12]];
    [_showStatusItemButton sizeToFit];
    [_showStatusItemButton setTarget:self];
    [_showStatusItemButton setAction:@selector(_showStatusItemChanged:)];
    [[self view] addSubview:_showStatusItemButton];

    _quickSyncButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_quickSyncButton setCell:[[DJLCheckboxButtonCell alloc] init]];
    [_quickSyncButton setButtonType:NSSwitchButton];
    [_quickSyncButton setTitle:@"Quick sync"];
    [_quickSyncButton setFont:[NSFont systemFontOfSize:12]];
    [_quickSyncButton sizeToFit];
    [_quickSyncButton setTarget:self];
    [_quickSyncButton setAction:@selector(_quickSyncChanged:)];
    [[self view] addSubview:_quickSyncButton];

    _zenDescription = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_zenDescription setBordered:NO];
    [_zenDescription setEditable:NO];
    [_zenDescription setSelectable:NO];
    [_zenDescription setTextColor:[NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
    [_zenDescription setFont:[NSFont systemFontOfSize:10]];
    [_zenDescription setStringValue:@"When Zen notifications setting is enabled, the dock icon notification will appear only if there are emails that you've never seen in list."];
    [_zenDescription sizeToFit];
    NSRect frame = [_zenDescription frame];
    if (frame.size.width > 400) {
        NSSize size = [_zenDescription sizeThatFits:NSMakeSize(400, MAXFLOAT)];
        frame.size = size;
        [_zenDescription setFrame:frame];
    }
    [[self view] addSubview:_zenDescription];
}

- (void) viewDidShow
{
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"SoundEnabled"];
    [_playSoundButton setState:enabled ? NSOnState : NSOffState];
    [_makeDefaultButton setState:[[DJLURLHandler sharedManager] isRegisteredAsDefault] ? NSOnState : NSOffState];
    enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"ZenNotifications"];
    [_zenNotificationsButton setState:enabled ? NSOnState : NSOffState];
    BOOL showSenderAvatar = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLShowSenderAvatar"];
    [_showSenderAvatarButton setState:showSenderAvatar ? NSOnState : NSOffState];
    BOOL showStatusItem = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLShowStatusItem"];
    [_showStatusItemButton setState:showStatusItem ? NSOnState : NSOffState];
    BOOL quickSync = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLQuickSync"];
    [_quickSyncButton setState:quickSync ? NSOnState : NSOffState];
}

- (void) viewDidLayout
{
    CGFloat width;
    width = [_makeDefaultButton frame].size.width;
    if ([_playSoundButton frame].size.width > width) {
        width = [_playSoundButton frame].size.width;
    }
    if ([_zenNotificationsButton frame].size.width > width) {
        width = [_zenNotificationsButton frame].size.width;
    }
    if ([_showSenderAvatarButton frame].size.width > width) {
        width = [_showSenderAvatarButton frame].size.width;
    }
    if ([_zenDescription frame].size.width > width) {
        width = [_zenDescription frame].size.width;
    }
    CGFloat x = ([[self view] frame].size.width - width) / 2;
    CGRect frame = [_makeDefaultButton frame];
    frame.origin.x = (int) x;
    frame.origin.y = [[self view] bounds].size.height - 40;
    [_makeDefaultButton setFrame:frame];
    frame = [_playSoundButton frame];
    frame.origin.x = (int) x;
    frame.origin.y = [[self view] bounds].size.height - 70;
    [_playSoundButton setFrame:frame];
    frame = [_showSenderAvatarButton frame];
    frame.origin.x = (int) x;
    frame.origin.y = [[self view] bounds].size.height - 100;
    [_showSenderAvatarButton setFrame:frame];
    frame = [_showStatusItemButton frame];
    frame.origin.x = (int) x;
    frame.origin.y = [[self view] bounds].size.height - 130;
    [_showStatusItemButton setFrame:frame];
    frame = [_quickSyncButton frame];
    frame.origin.x = (int) x;
    frame.origin.y = [[self view] bounds].size.height - 160;
    [_quickSyncButton setFrame:frame];
    frame = [_zenNotificationsButton frame];
    frame.origin.x = (int) x;
    frame.origin.y = [[self view] bounds].size.height - 190;
    [_zenNotificationsButton setFrame:frame];
    frame = [_zenDescription frame];
    frame.origin.x = (int) x + 10;
    frame.origin.y = [[self view] bounds].size.height - 195 - frame.size.height;
    [_zenDescription setFrame:frame];
}

- (CGFloat) height
{
    return 220 + [_zenDescription frame].size.height;
}

- (void) _playSoundChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([_playSoundButton state] == NSOnState) forKey:@"SoundEnabled"];
}

- (void) _makeDefaultChanged:(id)sender
{
    if ([_makeDefaultButton state] == NSOnState) {
        [[DJLURLHandler sharedManager] registerAsDefault];
    }
    else {
        [[DJLURLHandler sharedManager] registerMailAsDefault];
    }
}

- (void) _zenNotificationsChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([_zenNotificationsButton state] == NSOnState) forKey:@"ZenNotifications"];
}

- (void) _showSenderAvatarChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([_showSenderAvatarButton state] == NSOnState) forKey:@"DJLShowSenderAvatar"];
}

- (void) _showStatusItemChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([_showStatusItemButton state] == NSOnState) forKey:@"DJLShowStatusItem"];
}

- (void) _quickSyncChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([_quickSyncButton state] == NSOnState) forKey:@"DJLQuickSync"];
}

@end
