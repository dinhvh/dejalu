// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationCellContentView.h"

#import "DJLConversationCellView.h"
#import "DJLColoredView.h"
#import "DJLDarkMode.h"
#import "FBKVOController.h"

@implementation DJLConversationCellContentView {
    DJLConversationCellView * _mainView;
    NSVisualEffectView * _effectView;
    DJLColoredView * _opaqueView;
    BOOL _selected;
    BOOL _checked;
    BOOL _checkMode;
    BOOL _nextCellSelected;
    CGFloat _vibrancy;
    NSString * _folderPath;
    FBKVOController * _kvoController;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    _opaqueView = [[DJLColoredView alloc] initWithFrame:[self bounds]];
    [_opaqueView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    _effectView = [[NSVisualEffectView alloc] initWithFrame:[self bounds]];
    [_effectView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [_effectView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    _mainView = [[DJLConversationCellView alloc] initWithFrame:[self bounds]];
    [_mainView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_effectView addSubview:_opaqueView];
    [_effectView addSubview:_mainView];
    [self addSubview:_effectView];
    _vibrancy = 1.0;

   return self;
}

- (void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    if ([self superview] == nil) {
        _kvoController = nil;
    } else {
        _kvoController = [FBKVOController controllerWithObserver:self];
        __weak typeof(self) weakSelf = self;
        [_kvoController observe:weakSelf keyPath:@"effectiveAppearance" options:0 block
                               :^(id observer, id object, NSDictionary *change) {
                                   [weakSelf _applyVibrancy];
                               }];
        [self _applyVibrancy];
    }
}

- (id <DJLConversationCellViewDelegate>) delegate
{
    return [_mainView delegate];
}

- (void) setDelegate:(id<DJLConversationCellViewDelegate>)delegate
{
    [_mainView setDelegate:delegate];
}

- (NSDictionary *) conversation
{
    return [_mainView conversation];
}

- (void) setConversation:(NSDictionary *)conversation
{
    [_mainView setConversation:conversation];
}

- (NSString *) folderPath
{
    return [_mainView folderPath];
}

- (void) setFolderPath:(NSString *)path
{
    [_mainView setFolderPath:path];
}

- (void) setSelected:(BOOL)selected
{
    if (_selected == selected) {
        return;
    }
    _selected = selected;
    [_mainView setSelected:_selected];
    [self _applyVibrancy];
}

- (BOOL) isSelected
{
    return _selected;
}

- (void) setChecked:(BOOL)checked
{
    if (_checked == checked) {
        return;
    }
    _checked = checked;
    [_mainView setChecked:_checked];
    [self _applyVibrancy];
}

- (BOOL) isChecked
{
    return _checked;
}

- (void) setCheckMode:(BOOL)checkMode
{
    [_mainView setCheckMode:checkMode];
}

- (BOOL) isCheckMode
{
    return [_mainView isCheckMode];
}

- (void) setNextCellSelected:(BOOL)nextCellSelected
{
    if (_nextCellSelected == nextCellSelected) {
        return;
    }
    _nextCellSelected = nextCellSelected;
    [_mainView setNextCellSelected:_nextCellSelected];
}

- (BOOL) isNextCellSelected
{
    return _nextCellSelected;
}

- (CGFloat) vibrancy
{
    return _vibrancy;
}

- (void) setVibrancy:(CGFloat)vibrancy
{
    if (_vibrancy == vibrancy) {
        return;
    }
    _vibrancy = vibrancy;
    [self _applyVibrancy];
}

- (BOOL) _isFocused
{
    if (![NSApp isActive]) {
        NSLog(@"app not active");
        return NO;
    }
    if ([NSApp keyWindow] != [self window]) {
        NSLog(@"not the same window %@", [self window]);
        return NO;
    }
    NSView * parentView = self;
    NSLog(@"parent view? %@", parentView);
    while (parentView != nil) {
        NSLog(@"parent view? %@", parentView);
        if ([[self window] firstResponder] == parentView) {
            return YES;
        }
        parentView = [parentView superview];
    }
    return NO;
}

- (void) _applyVibrancy
{
    if (_selected) {
        [_mainView setVibrancy:_vibrancy];
        [_opaqueView setAlphaValue:1.0];
        if ([DJLDarkMode isDarkModeSupported]) {
            [_effectView setMaterial:NSVisualEffectMaterialSidebar];
        } else {
            [_effectView setMaterial:NSVisualEffectMaterialTitlebar];
        }
        if ([DJLDarkMode isDarkModeForView:self]) {
            [_opaqueView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.08 alpha:1.0]];
        } else {
            [_opaqueView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
        }
    }
    else {
        [_mainView setVibrancy:_vibrancy];
        [_opaqueView setAlphaValue:1.0 - _vibrancy];
        if ([DJLDarkMode isDarkModeSupported]) {
            [_effectView setMaterial:NSVisualEffectMaterialSidebar];
        } else {
            [_effectView setMaterial:NSVisualEffectMaterialLight];
        }
        if ([DJLDarkMode isDarkModeForView:self]) {
            [_opaqueView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.08 alpha:1.0]];
        } else {
            [_opaqueView setBackgroundColor:[NSColor whiteColor]];
        }
    }
    [self update];
}

- (void) update
{
    [_mainView update];
}

@end
