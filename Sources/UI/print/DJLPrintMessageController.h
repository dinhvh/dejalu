// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <AppKit/AppKit.h>

#include "Hermes.h"

@protocol DJLPrintMessageControllerDelegate;

@interface DJLPrintMessageController : NSObject

- (void) printMessageWithHTML:(NSString *)html header:(NSString *)header;

@end
