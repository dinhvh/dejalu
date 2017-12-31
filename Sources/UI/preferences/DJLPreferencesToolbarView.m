// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPreferencesToolbarView.h"

#import "DJLPreferencesToolbarIconView.h"
#import "DJLGradientSeparatorLineView.h"

@implementation DJLPreferencesToolbarView {
    NSArray * _icons;
    int _selectedIndex;
    __weak id <DJLPreferencesToolbarViewDelegate> _delegate;
    NSMutableArray * _iconsViews;
}

@synthesize icons = _icons;
@synthesize selectedIndex = _selectedIndex;
@synthesize delegate = _delegate;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    NSRect frame = [self bounds];
    frame.size.height = 1;
    DJLGradientSeparatorLineView * separator = [[DJLGradientSeparatorLineView alloc] initWithFrame:frame];
    [separator setAutoresizingMask:NSViewWidthSizable];
    [self addSubview:separator];
    return self;
}

- (void) setIcons:(NSArray *)icons
{
    for(DJLPreferencesToolbarIconView * view in _iconsViews) {
        [view removeFromSuperview];
    }
    _icons = icons;
    _iconsViews = [[NSMutableArray alloc] init];
    int tag = 0;
    for(NSDictionary * iconInfo in _icons) {
        DJLPreferencesToolbarIconView * view = [[DJLPreferencesToolbarIconView alloc] initWithIcon:iconInfo[@"icon"] title:iconInfo[@"title"]];
        [view setTag:tag];
        [view setTarget:self];
        [view setAction:@selector(_clicked:)];
        [view sizeToFit];

        DJLPreferencesToolbarIconView * previousView = [_iconsViews lastObject];
        if (previousView != nil) {
            NSRect previousFrame = [previousView frame];
            NSRect frame = [view frame];
            frame.origin.x = NSMaxX(previousFrame);
            frame.origin.y = 1;
            [view setFrame:frame];
        }
        else {
            NSRect frame = [view frame];
            frame.origin.x = 10;
            frame.origin.y = 1;
            [view setFrame:frame];
        }

        [_iconsViews addObject:view];
        [self addSubview:view];
        tag ++;
    }

    _selectedIndex = -1;
    if ([_icons count] > 0) {
        [self setSelectedIndex:0];
    }
}

- (void) setSelectedIndex:(int)selectedIndex
{
    _selectedIndex = selectedIndex;
    for(DJLPreferencesToolbarIconView * view in _iconsViews) {
        [view setState:NSOffState];
    }
    if (_selectedIndex == -1) {
        [[self delegate] DJLPreferencesToolbarViewSelectionChanged:self];
        return;
    }
    DJLPreferencesToolbarIconView * view = _iconsViews[_selectedIndex];
    [view setState:NSOnState];
    [[self delegate] DJLPreferencesToolbarViewSelectionChanged:self];
}

- (void) _clicked:(id)sender
{
    DJLPreferencesToolbarIconView * view = sender;
    [self setSelectedIndex:(int) [view tag]];
}

@end
