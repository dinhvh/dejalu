// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAttachmentsCollectionViewItem.h"

#import "DJLColoredView.h"

@interface DJLAttachmentsCollectionViewItem ()

@end

@implementation DJLAttachmentsCollectionViewItem {
    DJLColoredView * _selectionBackgroundView;
}

#define ATTACHMENT_HEIGHT 85
#define ATTACHMENT_WIDTH 150

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, ATTACHMENT_WIDTH, 85)];

    _selectionBackgroundView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(5, 5, ATTACHMENT_WIDTH - 10, ATTACHMENT_HEIGHT - 10)];
    [_selectionBackgroundView setBackgroundColor:[NSColor colorWithWhite:0.90 alpha:1.0]];
    [_selectionBackgroundView setHidden:YES];
    [view addSubview:_selectionBackgroundView];

    NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [textField setEditable:NO];
    [textField setBordered:NO];
    [textField setAlignment:NSCenterTextAlignment];
    [textField setFont:[NSFont fontWithName:@"Helvetica Neue" size:15]];
    [[textField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [textField setDrawsBackground:NO];
    //[[someTextField cell] setTruncatesLastVisibleLine:YES];
    [view addSubview:textField];
    [self setTextField:textField];
    NSImageView * imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [view addSubview:imageView];
    [self setImageView:imageView];
    [self setView:view];

    if ([self representedObject] != nil) {
        [self _reflectRepresentedObject];
    }
}

- (void) setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];
    [self _reflectRepresentedObject];
}

- (void) _reflectRepresentedObject
{
    NSString * filename = [self representedObject];
    [[self textField] setStringValue:[filename lastPathComponent]];
    [[self imageView] setImage:[[NSWorkspace sharedWorkspace] iconForFile:filename]];
}

#define ICON_SIZE 64
#define TEXT_SIZE 20

- (void) layoutViews
{
    NSRect bounds = [[self view] bounds];

    NSRect frame = NSMakeRect((bounds.size.width - ICON_SIZE) / 2, bounds.size.height - (ICON_SIZE), ICON_SIZE, ICON_SIZE);
    [[self imageView] setFrame:frame];
    [[self textField] sizeToFit];
    frame = [[self textField] frame];
    frame = NSMakeRect(10, 10, bounds.size.width - 20, frame.size.height);
    [[self textField] setFrame:frame];
}

- (void) setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [_selectionBackgroundView setHidden:!selected];
}

@end
