// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol DJLPreferencesToolbarViewDelegate;

@interface DJLPreferencesToolbarView : NSView

@property (nonatomic, retain) NSArray * icons;
@property (nonatomic, assign) int selectedIndex;
@property (nonatomic, weak) id <DJLPreferencesToolbarViewDelegate> delegate;

@end

@protocol DJLPreferencesToolbarViewDelegate <NSObject>

- (void) DJLPreferencesToolbarViewSelectionChanged:(DJLPreferencesToolbarView *)view;

@end
