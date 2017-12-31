// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLToolbarViewValidationDelegate;

@interface DJLToolbarView : NSView

@property (nonatomic, assign, getter=isHighlighted, readonly) BOOL highlighted;

@property (nonatomic, retain) NSArray * viewsToFade;
@property (nonatomic, assign) CGFloat separatorAlphaValue;
@property (nonatomic, assign) CGFloat vibrancy;
@property (nonatomic, assign) id <DJLToolbarViewValidationDelegate> validationDelegate;

- (NSRect) toolbarRect;
- (CGFloat) currentViewToFadeAlphaValue;

- (void) setButtonValidation:(NSButton *)button selector:(SEL)selector;
- (void) validate;

@end

@protocol DJLToolbarViewValidationDelegate

- (BOOL) DJLToolbarView:(DJLToolbarView *)toolbar validate:(SEL)selector;

@end
