// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationCellContentView.h"

#import "DJLConversationCellView.h"
#import "DJLColoredView.h"

@implementation DJLConversationCellContentView {
    DJLConversationCellView * _mainView;
    NSVisualEffectView * _effectView;
    DJLColoredView * _opaqueView;
    BOOL _selected;
    BOOL _nextCellSelected;
    CGFloat _vibrancy;
    NSString * _folderPath;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    _opaqueView = [[DJLColoredView alloc] initWithFrame:[self bounds]];
    [_opaqueView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    _effectView = [[NSVisualEffectView alloc] initWithFrame:[self bounds]];
    [_effectView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [_effectView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_effectView setMaterial:NSVisualEffectMaterialLight];
    _mainView = [[DJLConversationCellView alloc] initWithFrame:[self bounds]];
    [_mainView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [_effectView addSubview:_opaqueView];
    [_effectView addSubview:_mainView];
    [self addSubview:_effectView];
    BOOL enableVibrancy = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLEnableVibrancy"];
    _vibrancy = enableVibrancy ? 1.0 : 0.0;
    [_mainView setVibrancy:enableVibrancy ? 1.0 : 0.0];
    [_opaqueView setAlphaValue:enableVibrancy ? 0.0 : 1.0];
    return self;
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
    BOOL enableVibrancy = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLEnableVibrancy"];
    vibrancy = enableVibrancy ? vibrancy : 0.0;
    
    if (_vibrancy == vibrancy) {
        return;
    }
    _vibrancy = vibrancy;
    [self _applyVibrancy];
}

- (void) _applyVibrancy
{
    if (_selected) {
        [_mainView setVibrancy:_vibrancy];
        [_opaqueView setAlphaValue:1.0];
        [_effectView setMaterial:NSVisualEffectMaterialTitlebar];
    }
    else {
        [_mainView setVibrancy:_vibrancy];
        [_opaqueView setAlphaValue:1.0 - _vibrancy];
        [_effectView setMaterial:NSVisualEffectMaterialLight];
    }
    [self update];
}

- (void) update
{
    [_mainView update];
}

@end
