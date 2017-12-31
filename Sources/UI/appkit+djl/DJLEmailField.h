// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@class DJLGenericCompletionWindowController;

@interface DJLEmailField : NSTokenField

@property (nonatomic, assign) CGFloat maxHeight;

- (NSArray *) addresses;
- (void) setAddresses:(NSArray *)addresses;

- (BOOL) acceptTokenization;
- (void) tokenize;

// private
- (void) _setTokenEnabled:(BOOL)enabled;
- (BOOL) _tokenEnabled;

@end

@protocol DJLEmailFieldDelegate

- (void) DJLEmailField_shouldShowCompletion:(DJLEmailField *)field;
- (void) DJLEmailField_sizeDidChange:(DJLEmailField *)field;
- (void) DJLEmailField_enableCompletion:(DJLEmailField *)field;
- (void) DJLEmailField_disableCompletion:(DJLEmailField *)field;
- (void) DJLEmailField_didEndEditing:(DJLEmailField *)field;

@optional
- (void) DJLEmailField_becomeFirstResponder:(NSTextField *)field;
- (void) DJLEmailField_resignFirstResponder:(NSTextField *)field;

@end
