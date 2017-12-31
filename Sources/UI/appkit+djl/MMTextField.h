// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol MMTextFieldDelegate

- (void) MMTextField_becomeFirstResponder:(NSTextField *)field;
- (void) MMTextField_resignFirstResponder:(NSTextField *)field;

@end

@interface MMTextField : NSTextField {
}

@end
