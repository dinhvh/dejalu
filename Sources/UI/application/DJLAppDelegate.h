// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu * _helpMenu;
    IBOutlet NSMenu * _windowsMenu;
}

+ (void) addAccount;

- (IBAction) debugOpenAccountFolder:(id)sender;
- (IBAction) debugCrash:(id)sender;
- (IBAction) debugCell:(id)sender;
- (IBAction) debugNextAvatarIcon:(id)sender;
- (IBAction) debugEnableWellKnownIMAP:(id)sender;
- (IBAction) debugEnableCustomIMAP:(id)sender;

- (IBAction) debugActivity:(id)sender;

- (IBAction) refresh:(id)sender;
- (IBAction) composeMessage:(id)sender;
- (IBAction) checkForUpdates:(id)sender;

- (IBAction) showLicense:(id)sender;
- (IBAction) openPreferences:(id)sender;

- (void) addAccount;

- (void) toggleShowSenderAvatar;

@end
