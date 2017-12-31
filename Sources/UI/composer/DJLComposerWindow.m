// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLComposerWindow.h"

@implementation DJLComposerWindow

- (void) sendEvent:(NSEvent *)theEvent
{
    if ([theEvent type] == NSKeyDown) {
        switch ([theEvent keyCode]) {
            case 36: {
                if (([theEvent modifierFlags] & NSCommandKeyMask) != 0) {
                    if ([[self delegate] respondsToSelector:@selector(DJLComposerWindowCommandEnterPressed:)]) {
                        if ([(id<DJLComposerWindowDelegate>)[self delegate] DJLComposerWindowCommandEnterPressed:self]) {
                            return;
                        }
                    }
                }
                break;
            }
        }
    }
    [super sendEvent:theEvent];
}

@end
