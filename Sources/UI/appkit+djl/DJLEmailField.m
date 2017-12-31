// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLEmailField.h"

#import <MailCore/MailCore.h>
#import "DJLAddressBookManager.h"

#import "DJLGenericCompletionWindowController.h"
#import "NSTokenTextView.h"

#warning PRIVATE API
@interface DJLNSTokenTextView : NSTokenTextView {
}

@end

@implementation NSTokenTextView (DJLViewerWebHTMLView)
// We override in a category to substitute our own subclass instead of usual one

+ (id)allocWithZone:(NSZone *)zone {
    if (self == [NSTokenTextView class]) {
        return [DJLNSTokenTextView allocWithZone:zone];
    } else {
        return [super allocWithZone:zone];
    }
}

@end

@interface NSTokenAttachmentCell

- (id) representedObject;

@end

@interface NSTokenAttachment

- (NSTokenAttachmentCell *) attachmentCell;

@end

@implementation DJLNSTokenTextView

static NSRange s_draggedSelection;
static NSTextView * s_draggedTextView = nil;
static BOOL s_dragging = NO;

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return NSDragOperationGeneric;
}

- (BOOL)dragSelectionWithEvent:(NSEvent *)event offset:(NSSize)mouseOffset slideBack:(BOOL)slideBack
{
    BOOL result;
    
    s_dragging = YES;
    s_draggedTextView = self;
    s_draggedSelection = [self selectedRange];
    result = [super dragSelectionWithEvent:event offset:mouseOffset slideBack:slideBack];
    s_dragging = NO;
    
    return result;
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
    if (!s_dragging) {
        s_draggedTextView = nil;
    }
    [super writeSelectionToPasteboard:pboard types:types];
    NSMutableString * result = [NSMutableString string];
    [[self textStorage] enumerateAttribute:NSAttachmentAttributeName inRange:[self selectedRange] options:0 usingBlock:^(id value, NSRange range, BOOL * stop) {
        NSTokenAttachment * attachment = value;
        //NSLog(@"%@", value);
        NSTokenAttachmentCell * cell = [attachment attachmentCell];
        NSString * str = [cell representedObject];
        if (str != nil) {
            if ([result length] != 0) {
                [result appendString:@"\t"];
            }
            [result appendString:str];
        }
    }];
    [pboard setString:result forType:NSStringPboardType];
    return YES;
}

- (BOOL) usesFontPanel
{
    return NO;
}

- (NSDictionary *) typingAttributes
{
    NSMutableDictionary * result;
    
    result = [NSMutableDictionary dictionary];
    [result setObject:[NSFont fontWithName:@"Helvetica Neue" size:15] forKey:NSFontAttributeName];
    
    return result;
}

@end


@interface DJLEmailField ()

- (void) _showCompletionIfNeeded;
- (void) _debugStringValue;
- (void) _addressManagerLoaded;

@end

@implementation DJLEmailField {
    CGFloat _maxHeight;
    BOOL _tokenEnabled;
    BOOL _tokenizing;
}

@synthesize maxHeight = _maxHeight;

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	
    [[self cell] setScrollable:YES];
	[[self cell] setWraps:YES];
	[[self cell] setLineBreakMode:NSLineBreakByWordWrapping];
	[self setStringValue:@""];

	return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void) _addressManagerLoaded
{
    [self _showCompletionIfNeeded];
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{
    if ([[self delegate] respondsToSelector:@selector(DJLEmailField_didEndEditing:)]) {
        [(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_didEndEditing:self];
    }
    return [super textShouldEndEditing:textObject];
}

- (void) sizeToFit
{
	NSRect r = NSMakeRect(0, 0, [self frame].size.width, MAXFLOAT);
	NSSize s = [[self cell] cellSizeForBounds:r];
	s.width = r.size.width;
    s.height += 2;

    if (_maxHeight != 0) {
        if (s.height > _maxHeight) {
            s.height = _maxHeight;
        }
    }
    if (s.height == [self frame].size.height) {
		NSText * text;
		text = [[self window] fieldEditor:YES forObject:self];
		NSRange range = [text selectedRange];
		[text scrollRangeToVisible:range];
		
        return;
    }
    
	[self setFrameSize:s];
    
    NSText * text;
    text = [[self window] fieldEditor:YES forObject:self];
    NSRange range = [text selectedRange];
    [text scrollRangeToVisible:range];
}

- (void)textDidChange:(NSNotification *)aNotification
{
    CGFloat previousHeight;
    
    [super textDidChange:aNotification];
    
    previousHeight = [self frame].size.height;
	[self sizeToFit];
    if (previousHeight == [self frame].size.height) {
        [self _showCompletionIfNeeded];
        return;
    }
    
	if ([[self delegate] respondsToSelector:@selector(DJLEmailField_sizeDidChange:)]) {
		[(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_sizeDidChange:self];
        [self _showCompletionIfNeeded];
	}
}

- (void) _debugStringValue
{

    NSTextView * text;
    text = (NSTextView *) [[self window] fieldEditor:YES forObject:self];
    NSRange range = [text selectedRange];

    unsigned int firstValidCharIndex;
    
    firstValidCharIndex = 0;
    NSString * str = [[text string] substringWithRange:range];
    for(unsigned int i = 0 ; i < [str length] ; i ++) {
        if ([str characterAtIndex:i] == 65532) {
            firstValidCharIndex = i + 1;
        }
    }
    [str substringFromIndex:firstValidCharIndex];
}

#define COMPLETION_WINDOW_HEIGHT 100

- (void) _showCompletionIfNeeded
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_showCompletionIfNeededAfterDelay) object:nil];
    [self performSelector:@selector(_showCompletionIfNeededAfterDelay) withObject:nil afterDelay:0.1];
}

- (void) _showCompletionIfNeededAfterDelay
{
    if ([[self delegate] respondsToSelector:@selector(DJLEmailField_shouldShowCompletion:)]) {
        [(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_shouldShowCompletion:self];
    }
}

- (NSArray *) addresses
{
    NSMutableArray * addresses = [NSMutableArray array];
    NSArray * rfc822Strings = [self objectValue];
    for(NSString * emailString in rfc822Strings) {
        MCOAddress * address = [MCOAddress addressWithNonEncodedRFC822String:emailString];
        if (address != nil) {
            [addresses addObject:address];
        }
    }
    return addresses;
}

- (void) setAddresses:(NSArray *)addresses
{
	NSMutableArray * array;

	array = [[NSMutableArray alloc] init];
	
    for(MCOAddress * address in addresses) {
        [array addObject:[address nonEncodedRFC822String]];
    }
    [self setObjectValue:array];
}

- (void) _setTokenEnabled:(BOOL)enabled
{
    _tokenEnabled = enabled;
}

- (BOOL) _tokenEnabled
{
    return _tokenEnabled;
}

- (BOOL) becomeFirstResponder
{
    BOOL result;
    
    result = [super becomeFirstResponder];
    
    if (result) {
        if ([[self delegate] respondsToSelector:@selector(DJLEmailField_becomeFirstResponder:)]) {
            [(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_becomeFirstResponder:self];
        }
    }
    
    return result;
}

- (BOOL) resignFirstResponder
{
    BOOL result;
    
    result = [super resignFirstResponder];
    
    if (result) {
        if ([[self delegate] respondsToSelector:@selector(DJLEmailField_resignFirstResponder:)]) {
            [(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_resignFirstResponder:self];
        }
    }
    
    return result;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    NSText * editor;
    
    editor = [[self window] fieldEditor:NO forObject:self];
    NSRect editorFrame;
    NSRect viewFrame;
    editorFrame = [(NSTextView *) editor frame];
    viewFrame = [[(NSTextView *) editor superview] bounds];
    CGEventRef cgEvent;
    CGFloat dy;
    cgEvent = [theEvent CGEvent];
    dy = CGEventGetDoubleValueField(cgEvent, kCGScrollWheelEventPointDeltaAxis1);
    viewFrame.origin.y -= dy;
    if (viewFrame.origin.y < 0)
        viewFrame.origin.y = 0;
    if (viewFrame.origin.y > editorFrame.size.height - viewFrame.size.height) {
        viewFrame.origin.y = editorFrame.size.height - viewFrame.size.height;
    }
    [[(NSTextView *) editor superview] setBounds:viewFrame];
}

- (BOOL) acceptTokenization
{
    NSText *currentEditor;
    NSString * str;
    BOOL result;
    
    result = NO;
    currentEditor = [self currentEditor];
    str = [[(NSTextView *) currentEditor textStorage] string];
    for(unsigned int i = 0 ; i < [str length] ; i ++) {
        unichar ch;
        
        ch = [str characterAtIndex:i];
        if (ch != 65532) {
            result = YES;
        }
    }
    return result;
}

- (void) tokenize
{
    NSEvent * event;
    NSTextView * text;
    
    if (_tokenizing)
        return;
    
    _tokenizing = YES;
    
    [(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_enableCompletion:self];
    text = (NSTextView *) [[self window] fieldEditor:YES forObject:self];
    event = [NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0, 0) modifierFlags:0 timestamp:0 windowNumber:[[self window] windowNumber] context:[NSGraphicsContext currentContext] characters:@"\n" charactersIgnoringModifiers:@"\n" isARepeat:NO keyCode:36];
    [text keyDown:event];
    [(id <DJLEmailFieldDelegate>) [self delegate] DJLEmailField_disableCompletion:self];
    //[_completionWindowController setField:nil];
    
    _tokenizing = NO;
}

#if 0
+ (NSRange) mmDraggedSelection
{
    return s_draggedSelection;
}

+ (NSTextView *) mmDraggedTextView
{
    return s_draggedTextView;
}
#endif

@end
