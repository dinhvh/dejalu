// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "MMTextField.h"


@implementation MMTextField

- (BOOL) becomeFirstResponder
{
    BOOL result;
    
    result = [super becomeFirstResponder];
    
    if (result) {
        if ([[self delegate] respondsToSelector:@selector(MMTextField_becomeFirstResponder:)]) {
            [(id <MMTextFieldDelegate>) [self delegate] MMTextField_becomeFirstResponder:self];
        }
    }
    
    return result;
}

- (BOOL) resignFirstResponder
{
    BOOL result;
    
    result = [super resignFirstResponder];
    
    if (result) {
        if ([[self delegate] respondsToSelector:@selector(MMTextField_resignFirstResponder:)]) {
            [(id <MMTextFieldDelegate>) [self delegate] MMTextField_resignFirstResponder:self];
        }
    }
    
    return result;
}

@end
