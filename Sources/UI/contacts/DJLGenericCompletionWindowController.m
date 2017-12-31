// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGenericCompletionWindowController.h"

#import "DJLColoredView.h"

@interface DJLGenericCompletionWindowController () <NSTableViewDataSource, NSTableViewDelegate>

- (void) _tokenize;
- (void) _selectIndex:(NSInteger)row delta:(NSInteger)delta;

@end

@implementation DJLGenericCompletionWindowController

@synthesize field = _field;
@synthesize menuLookEnabled = _menuLookEnabled;
@synthesize controlSize = _controlSize;
@synthesize deltaYPosition = _deltaYPosition;

- (id) init
{
    self = [super init];
    
    _menuLookEnabled = NO;
    _controlSize = NSRegularControlSize;
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //[_tableView release];
    //[_scrollView release];
    [self setWindow:nil];
    //[super dealloc];
}

- (void) _buildUI
{
    if ([self window] != nil)
        return;
    
    NSRect scrollFrame = NSMakeRect(0, 0, 100, 100);
    NSRect tableFrame = NSZeroRect;
    tableFrame.size = [NSScrollView contentSizeForFrameSize:scrollFrame.size horizontalScrollerClass:nil verticalScrollerClass:[NSScroller class] borderType:NSNoBorder controlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleOverlay];
    NSTableColumn *column = [[NSTableColumn alloc] init];
    [column setWidth:tableFrame.size.width];
    [column setEditable:NO];
    [[column dataCell] setFont:[NSFont fontWithName:@"Helvetica Neue" size:[NSFont systemFontSizeForControlSize:_controlSize]]];
    
    _tableView = [[NSTableView alloc] initWithFrame:tableFrame];
    [_tableView setRowHeight:22];
    [_tableView setAutoresizingMask:NSViewWidthSizable];
    [_tableView addTableColumn:column];
    //[column release];
    [_tableView setGridStyleMask:NSTableViewGridNone];
    [_tableView setCornerView:nil];
    [_tableView setHeaderView:nil];
    [_tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    [_tableView setTarget:self];
    [_tableView setAction:@selector(_completionSelected:)];
    //[_tableView setDoubleAction:@selector(tableAction:)];
    [_tableView setBackgroundColor:[NSColor clearColor]];
    NSTrackingArea * trackingArea;
    trackingArea = [[NSTrackingArea alloc] initWithRect:[_tableView bounds]
                                                options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInActiveApp
                                                  owner:self
                                               userInfo:nil];
    if (_menuLookEnabled) {
        [_tableView addTrackingArea:trackingArea];
    }
    //[trackingArea release];
    
    DJLColoredView * contentView;
    
    contentView = [[DJLColoredView alloc] initWithFrame:scrollFrame];
    if (_menuLookEnabled) {
        //[contentView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]];
        [contentView setBackgroundColor:[NSColor colorWithCalibratedWhite:1 alpha:1.0]];
        //[contentView setRoundedCorner:MMColoredViewRoundedCornerBottomLeft | MMColoredViewRoundedCornerBottomRight |
        // MMColoredViewRoundedCornerTopLeft | MMColoredViewRoundedCornerTopRight];
        //[contentView setCornerRadius:5.];
    }
    else {
        [contentView setBackgroundColor:[NSColor whiteColor]];
    }
    
    NSRect borderScrollFrame;
    borderScrollFrame = scrollFrame;
    if (_menuLookEnabled) {
        borderScrollFrame.origin = NSMakePoint(0, 5);
        borderScrollFrame.size.height -= 10;
    }
    NSScrollView * scrollView;
    
    if (_menuLookEnabled) {
        scrollView = [[NSScrollView alloc] initWithFrame:borderScrollFrame];
    }
    else {
        //scrollView = [[MMScrollNoCAView alloc] initWithFrame:borderScrollFrame];
        scrollView = [[NSScrollView alloc] initWithFrame:borderScrollFrame];
    }
    [scrollView setDrawsBackground:NO];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [scrollView setDocumentView:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_scrollerStyleChanged) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
    [self _scrollerStyleChanged];

    /*
    if (!_menuLookEnabled) {
        MMScroller * verticalScroller;
        MMScroller * horizontalScroller;
        
        verticalScroller = [[MMScroller alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        [scrollView setVerticalScroller:verticalScroller];
        [verticalScroller release];
        horizontalScroller = [[MMScroller alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        [scrollView setHorizontalScroller:horizontalScroller];
        [horizontalScroller release];
    }
     */
    //_scrollView = [scrollView retain];
    _scrollView = scrollView;
    
    NSWindow * popupWindow;
    popupWindow = [[NSWindow alloc] initWithContentRect:scrollFrame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    [popupWindow setHasShadow:YES];
    //[popupWindow setAlphaValue:0.88f];
    //[popupWindow setAlphaValue:0.95];
    [popupWindow setAlphaValue:0.95];
    [popupWindow setAcceptsMouseMovedEvents:YES];
    if (_menuLookEnabled) {
        [popupWindow setBackgroundColor:[NSColor clearColor]];
    }
    [popupWindow setContentView:contentView];
    [contentView addSubview:scrollView];
    [popupWindow setOpaque:NO];
    [popupWindow setLevel:NSPopUpMenuWindowLevel];
    
    [self setWindow:popupWindow];
    
    //[popupWindow release];
    //[contentView release];
    //[scrollView release];
    
    [self didBuildUI];
}

- (void) _scrollerStyleChanged
{
    [_scrollView setScrollerStyle:NSScrollerStyleOverlay];
}

- (void) didBuildUI
{
}

- (NSRange) _rangeToComplete
{
    NSText * text;
    NSUInteger firstValidCharIndex;
    NSUInteger lastValidCharIndex;
    
    text = (NSTextView *) [[[self field] window] fieldEditor:YES forObject:[self field]];
    NSRange range = [text selectedRange];
    NSInteger location = range.location + range.length;
    
    firstValidCharIndex = 0;
    NSString * str = [text string];
    //NSString * str = [[text string] substringToIndex:location];
    for(unsigned int i = 0 ; i < location ; i ++) {
        if ([str characterAtIndex:i] == 65532) {
            firstValidCharIndex = i + 1;
        }
    }
    lastValidCharIndex = [str length];
    for(NSInteger i = location ; i < [str length] ; i ++) {
        if ([str characterAtIndex:i] == 65532) {
            lastValidCharIndex = i;
            break;
        }
    }
    
    return NSMakeRange(firstValidCharIndex, lastValidCharIndex - firstValidCharIndex);
}

- (NSString *) _stringToComplete
{
    NSText * text;
    NSString * str;
    
    text = (NSTextView *) [[[self field] window] fieldEditor:YES forObject:[self field]];
    str = [text string];
    return [str substringWithRange:[self _rangeToComplete]];
}

- (void) complete
{
    [self _buildUI];
    
    _itemsCount = [self prepareTableViewContentsWithStringValue:[self _stringToComplete]];
	[_tableView reloadData];
    
//    if (!_menuLookEnabled) {
//        [(MMScroller *) [_scrollView verticalScroller] showScroller];
//    }

    if (_itemsCount > 0) {
        NSRect frame;
        NSRect windowFrame;
        CGFloat height;
        NSUInteger count;
        NSInteger selectedRow;
        
        count = _itemsCount;
        if (count > 20) {
            count = 20;
        }
        //height = count * 19;
        height = NSMaxY([_tableView rectOfRow:_itemsCount - 1]) + 1;
        //height = [_tableView frame].size.height;
        if (height > 400) {
            height = 400;
        }
        if (_menuLookEnabled) {
            height += 10;
        }
        frame = [_field convertRect:[_field bounds] toView:nil];
        windowFrame = [[_field window] frame];
        frame.origin.x += windowFrame.origin.x;
        frame.origin.y += windowFrame.origin.y - (height + 6 + _deltaYPosition);
        frame.size.height = height;
        
        NSTableColumn * column;
        column = [[_tableView tableColumns] objectAtIndex:0];
        [column setWidth:frame.size.width];
        
        _disableValidation = YES;
        selectedRow = [_tableView selectedRow];
        if (selectedRow == -1) {
            [self _selectIndex:0 delta:1];
        }
        else {
            [self _selectIndex:selectedRow delta:1];
            selectedRow = [_tableView selectedRow];
            if ([self respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
                if (![self tableView:_tableView shouldSelectRow:selectedRow]) {
                    [self _selectIndex:0 delta:1];
                    if (![self tableView:_tableView shouldSelectRow:selectedRow]) {
                        [_tableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
                    }
                }
            }
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowResignKey) name:NSWindowDidResignKeyNotification object:[[self field] window]];
        
        _disableValidation = NO;
        [[self window] setFrame:frame display:YES];
        [[[self field] window] addChildWindow:[self window] ordered:NSWindowAbove];
        [self showWindow:nil];
    }
    else {
        [self cancelCompletion];
    }
}

- (NSUInteger) prepareTableViewContentsWithStringValue:(NSString *)value
{
    return 0;
}

- (void) cancelCompletion
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:[[self field] window]];
    
    [_tableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    [[[self field] window] removeChildWindow:[self window]];
    [self setField:nil];
    [self close];
}

- (void) _windowResignKey
{
    [self cancelCompletion];
}

- (void) _selectIndex:(NSInteger)row delta:(NSInteger)delta
{
    if (row < 0)
        row = 0;
    if (row > _itemsCount - 1)
        row = _itemsCount - 1;
    
    if (delta == 0) {
        if ([self respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
            if (![self tableView:_tableView shouldSelectRow:row]) {
                return;
            }
        }
    }
    
    if ([self respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
        while (![self tableView:_tableView shouldSelectRow:row]) {
            if (delta < 0) {
                row --;
            }
            else {
                row ++;
            }
            
            if (row < 0)
                break;
            if (row > _itemsCount - 1)
                break;
        }
        
        if (row < 0)
            return;
        if (row > _itemsCount - 1)
            return;
    }
    
    _disableValidation = YES;
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    _disableValidation = NO;
    [_tableView scrollRowToVisible:row];
}

- (void) _shiftSelection:(NSInteger)delta
{
    [self _selectIndex:[_tableView selectedRow] + delta delta:delta];
}

- (void) previousCompletion
{
    [self _shiftSelection:-1];
}

- (void) nextCompletion
{
    [self _shiftSelection:1];
}

- (void) pageDown
{
    [self _shiftSelection:(int) (([_scrollView bounds].size.height / [_tableView rowHeight]) - 3)];
}

- (void) pageUp
{
    [self _shiftSelection:-(int) (([_scrollView bounds].size.height / [_tableView rowHeight]) - 3)];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return _itemsCount;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if (_disableValidation)
        return;
    
    [self acceptCompletion];
}

- (void) replaceWithAttributedCompletion:(NSAttributedString *)completion
{
    //unsigned int firstValidCharIndex;
    NSTextView * text;
    
    if (completion == nil) {
        //completion = [[[NSAttributedString alloc] initWithString:@""] autorelease];
        completion = [[NSAttributedString alloc] initWithString:@""];
    }
    
    text = (NSTextView *) [[[self field] window] fieldEditor:YES forObject:[self field]];
    NSRange range;
    range = [self _rangeToComplete];
    
    [[text textStorage] beginEditing];
    [[text textStorage] replaceCharactersInRange:range withAttributedString:completion];
    
    NSMutableDictionary * attr;
    attr = [[NSMutableDictionary alloc] init];
    [attr setObject:[[self field] font] forKey:NSFontAttributeName];
    [[text textStorage] addAttributes:attr range:NSMakeRange(range.location, [completion length])];
    
    [[text textStorage] endEditing];
    
    [text setTypingAttributes:attr];
    
    //[attr release];
    
    [self _tokenize];
    
    [text didChangeText];
    [text scrollRangeToVisible:[text selectedRange]];
}

- (void) replaceWithCompletion:(NSString *)completion
{
    //unsigned int firstValidCharIndex;
    NSTextView * text;
    
    if (completion == nil)
        completion = @"";
    
    text = (NSTextView *) [[[self field] window] fieldEditor:YES forObject:[self field]];
    NSRange range = [self _rangeToComplete];
    
    [[text textStorage] beginEditing];
    [[text textStorage] replaceCharactersInRange:range withString:completion];
    [[text textStorage] endEditing];
    
    [self _tokenize];
    
    [text didChangeText];
    [text scrollRangeToVisible:[text selectedRange]];
}

- (NSString *) originalStringToComplete
{
//    return [[[self _stringToComplete] copy] autorelease];
    return [[self _stringToComplete] copy];
}

- (void) _tokenize
{
    NSEvent * event;
    NSTextView * text;
    
    if (![[self field] isKindOfClass:[NSTokenField class]]) {
        return;
    }
    
    if (_isValidatingToken) {
        return;
    }
    
    _isValidatingToken = YES;
    text = (NSTextView *) [[[self field] window] fieldEditor:YES forObject:[self field]];
    event = [NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0, 0) modifierFlags:0 timestamp:0 windowNumber:[[self window] windowNumber] context:[NSGraphicsContext currentContext] characters:@"\n" charactersIgnoringModifiers:@"\n" isARepeat:NO keyCode:36];
    [text keyDown:event];
    _isValidatingToken = NO;
    [[text undoManager] removeAllActions];
}

- (BOOL) canAcceptCompletion
{
    if (![[self window] isVisible])
        return NO;
    
    if (_isValidatingToken)
        return NO;
    
    if (_itemsCount == 0)
        return NO;
    
    return YES;
}

- (void) acceptCompletion
{
}

- (NSInteger) selectedCompletionIndex
{
    return [_tableView selectedRow];
}

- (BOOL) control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    //MMLog(@"%@", NSStringFromSelector(command));
    if (command == @selector(cancelOperation:)) {
        [self cancelCompletion];
        return YES;
    }
    else if (command == @selector(moveUp:)) {
        if (![self canAcceptCompletion])
            return NO;
        
        [self previousCompletion];
        return YES;
    }
    else if (command == @selector(moveDown:)) {
        if (![self canAcceptCompletion])
            return NO;
        
        [self nextCompletion];
        return YES;
    }
    else if (command == @selector(scrollPageDown:)) {
        if (![self canAcceptCompletion])
            return NO;
        
        [self pageDown];
        return YES;
    }
    else if (command == @selector(scrollPageUp:)) {
        if (![self canAcceptCompletion])
            return NO;
        
        [self pageUp];
        return YES;
    }    
    else if (command == @selector(insertNewline:)) {
        if (![self canAcceptCompletion])
            return NO;
        
        [self acceptCompletion];
        return YES;
    }
    else if (command == @selector(insertTab:)) {
        if (![self canAcceptCompletion])
            return NO;
        
        [self acceptCompletion];
        return YES;
    }
    else if ((command == @selector(moveLeft:)) || (command == @selector(moveRight:))) {
        if (![[self field] isKindOfClass:[NSTokenField class]])
            return NO;
        
        if (![self canAcceptCompletion])
            return NO;
        
        [self acceptCompletion];
        return YES;
    }
    
    return NO;
}

- (void)mouseEntered:(NSEvent *)theEvent
{
}

- (void)mouseExited:(NSEvent *)theEvent
{
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSInteger row;
    
    row = [_tableView rowAtPoint:[_tableView convertPoint:[theEvent locationInWindow] fromView:nil]];
    if (row < 0)
        return;
    
    [self _selectIndex:row delta:0];
}

- (void) _completionSelected:(id)sender
{
    [self acceptCompletion];
}

@end
