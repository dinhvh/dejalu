// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#include "Hermes.h"

@protocol DJLMainWindowControllerDelegate;

@interface DJLMainWindowController : NSWindowController

@property (nonatomic, weak) id <DJLMainWindowControllerDelegate> delegate;

- (void) composeMessage;

- (void) debugOpenAccountFolder;
- (void) debugActivity;

- (void) refresh;

- (IBAction) toggleSidebar:(id)sender;
- (IBAction) toggleDetails:(id)sender;
- (IBAction) showLabelsPanel:(id)sender;
- (IBAction) showLabelsAndArchivePanel:(id)sender;
- (IBAction) saveAllAttachments:(id)sender;

- (IBAction) printDocument:(id)sender;

- (IBAction) selectNextAccount:(id)sender;
- (IBAction) selectPreviousAccount:(id)sender;

@end

@protocol DJLMainWindowControllerDelegate

- (void) DJLMainWindowController:(DJLMainWindowController *)controller openLabelsPrefsForAccount:(hermes::Account *)account;
- (void) DJLMainWindowController:(DJLMainWindowController *)controller openAccountPrefs:(hermes::Account *)account;

@end
