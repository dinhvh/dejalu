// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#include "Hermes.h"

@interface DJLPreferencesWindowController : NSWindowController

- (void) showLabelsForAccount:(hermes::Account *)account;

- (IBAction) createLink:(id)sender;

@end
