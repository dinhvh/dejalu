// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationCellView.h"

#include <MailCore/MailCore.h>

#import "DJLTableView.h"
#import "DJLConversationStatusView.h"
#import "DJLAvatarManager.h"
#import "FBKVOController.h"
#import "DJLUIConstants.h"
#import "DJLAssert.h"

using namespace mailcore;

@interface DJLConversationCellSnippetView : NSView

@property (nonatomic, retain) NSDictionary * conversation;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign) CGFloat vibrancy;
@property (nonatomic, retain) NSString * folderPath;

@end

@implementation DJLConversationCellSnippetView {
    BOOL _selected;
    NSDictionary * _conversation;
    CGFloat _vibrancy;
    NSString * _folderPath;
}

@synthesize selected = _Selected;
@synthesize conversation = _conversation;
@synthesize vibrancy = _vibrancy;
@synthesize folderPath = _folderPath;

- (void) setVibrancy:(CGFloat)vibrancy
{
    _vibrancy = vibrancy;
    [self setNeedsDisplay:YES];
}

- (void) setSelected:(BOOL)selected
{
    _selected = selected;
    [self setNeedsDisplay:YES];
}

- (BOOL) isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSMutableArray * filteredLabels = [[NSMutableArray alloc] init];
    static NSMutableSet * s_defaultLabelSet = nil;
    if (s_defaultLabelSet == nil) {
        s_defaultLabelSet = [[NSMutableSet alloc] init];
        [s_defaultLabelSet addObject:@"\\Sent"];
        [s_defaultLabelSet addObject:@"\\Inbox"];
        [s_defaultLabelSet addObject:@"\\Important"];
        [s_defaultLabelSet addObject:@"\\Starred"];
        [s_defaultLabelSet addObject:@"\\Trash"];
        [s_defaultLabelSet addObject:@"\\Spam"];
        [s_defaultLabelSet addObject:@"\\Draft"];
        [s_defaultLabelSet addObject:@"\\All"];
    }

    int attachmentsCount = [(NSNumber *) _conversation[@"attachments-count"] intValue];

    for(NSString * label in [_conversation objectForKey:@"labels"]) {
        if ([label isEqualToString:_folderPath]) {
            continue;
        }
        if ([s_defaultLabelSet containsObject:label]) {
            continue;
        }
        [filteredLabels addObject:label];
    }

    CGFloat avatarSize = 30;
    CGFloat statusMargin = 15;
    NSColor * previewColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    if (_selected) {
        previewColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    }

    NSFont * snippetFont = [NSFont systemFontOfSize:12];
    NSMutableDictionary * snippetAttr = [NSMutableDictionary dictionary];
    [snippetAttr setObject:snippetFont forKey:NSFontAttributeName];
    [snippetAttr setObject:previewColor forKey:NSForegroundColorAttributeName];

    CGFloat y = 29;

    NSArray * msgs = [_conversation objectForKey:@"messages"];
    DJLAssert([msgs count] == 1);
    NSDictionary * msgInfo = [msgs objectAtIndex:0];
    NSString * snippet = [msgInfo objectForKey:@"snippet"];
    if ([snippet isEqualToString:@""]) {
        snippet = @"No message content";
    }
    if (snippet == nil) {
        snippet = @"";
    }
    NSString * sender = [msgInfo objectForKey:@"sender"];
    if (sender == nil) {
        sender = @"";
    }
    NSMutableAttributedString * attrStr = [[NSMutableAttributedString alloc] init];
    [attrStr appendAttributedString:[[NSAttributedString alloc] initWithString:snippet attributes:snippetAttr]];
    NSRect rect = [self bounds];
    rect.size.width -= 30;
    if (([filteredLabels count] > 0) || (attachmentsCount > 0)) {
        rect.size.height = 18;
    }
    else {
        rect.size.height = 35;
    }
    rect.origin.x = 10;
    rect.origin.y = y;
    rect.size.width -= (avatarSize + 5) + statusMargin;
    rect.origin.x += (avatarSize + 5) + statusMargin;
    [attrStr drawWithRect:rect options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];

    CGFloat x = 10 + (avatarSize + 5) + statusMargin + 1;
    NSMutableDictionary * labelAttr = [NSMutableDictionary dictionary];
    [labelAttr setObject:[NSFont systemFontOfSize:10] forKey:NSFontAttributeName];
    if (_selected) {
        [labelAttr setObject:[NSColor colorWithWhite:0.2 alpha:1.0] forKey:NSForegroundColorAttributeName];
    }
    else {
        [labelAttr setObject:[NSColor colorWithWhite:0.6 alpha:1.0] forKey:NSForegroundColorAttributeName];
    }

    NSColor * color = nil;
    if (_selected) {
        color = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];
    }
    else {
        color = [NSColor colorWithCalibratedWhite:0.8 - _vibrancy * 0.2 alpha:1.0];
    }

    if (attachmentsCount > 0) {
        NSImage * image = [NSImage imageNamed:@"DejaLu_Attachment_16"];
        NSRect originRect = NSZeroRect;
        originRect.size = [image size];
        NSRect rect = NSMakeRect(x, 50, 0, 0);
        rect.size = originRect.size;
        [image drawInRect:rect fromRect:originRect operation:NSCompositeSourceOver fraction:0.6 respectFlipped:YES hints:nil];
        x += originRect.size.width;

        NSString * attachmentString = nil;
        NSString * attachmentFilename = _conversation[@"attachment-filename"];
        if (attachmentFilename == nil) {
            if (attachmentsCount == 1) {
                attachmentString = @"1 Attachment";
            }
            else {
                attachmentString = [NSString stringWithFormat:@"%i Attachments", attachmentsCount];
            }
        }
        else {
            if (attachmentsCount == 1) {
                attachmentString = attachmentFilename;
            }
            else {
                attachmentString = [NSString stringWithFormat:@"%@ and %i more",
                                    attachmentFilename, (attachmentsCount - 1)];
            }
        }
        NSSize size = [attachmentString sizeWithAttributes:labelAttr];
        if ((size.width > 200) && (attachmentFilename != nil)) {
            if (attachmentsCount == 1) {
                attachmentString = @"1 Attachment";
            }
            else {
                attachmentString = [NSString stringWithFormat:@"%i Attachments", attachmentsCount];
            }
            size = [attachmentString sizeWithAttributes:labelAttr];
        }

        rect.origin.x = x + 5;
        rect.origin.y = 50 + 12;
        rect.size.width = self.bounds.size.width - statusMargin - rect.origin.x;
        rect.size.height = size.height;

        NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
        NSMutableDictionary * attr = [labelAttr mutableCopy];
        attr[NSParagraphStyleAttributeName] = paragraphStyle;
        [attachmentString drawWithRect:rect options:0 attributes:attr];

        x += (int) size.width + 10;
    }

    for(NSString * label in filteredLabels) {
        [color setStroke];
        NSString * decodedLabel = MCO_TO_OBJC(MCO_FROM_OBJC(String, label)->mUTF7DecodedString());
        NSSize size = [decodedLabel sizeWithAttributes:labelAttr];
        if (size.width > 100) {
            size.width = 100;
        }
        if (size.width + x + 30 > [self bounds].size.width) {
            break;
        }
        rect.origin.x = x;
        rect.origin.y = 50;
        rect.size.width = (int) size.width + 10;
        rect.size.height = (int) size.height + 4;
        NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:5 yRadius:5];
        [path stroke];
        rect.origin.x = x + 5;
        rect.origin.y = 50 + 12;
        rect.size.width = size.width;
        rect.size.height = size.height;
        NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        NSMutableDictionary * attr = [labelAttr mutableCopy];
        attr[NSParagraphStyleAttributeName] = paragraphStyle;
        NSAttributedString * attrStr = [[NSAttributedString alloc] initWithString:decodedLabel attributes:attr];
        [attrStr drawWithRect:rect options:0];

        x += (int) size.width + 15;
    }
}

@end

@implementation DJLConversationCellView {
    NSDictionary * _conversation;
    DJLConversationStatusView * _starView;
    DJLConversationStatusView * _unreadView;
    DJLConversationCellSnippetView * _snippetView;
    BOOL _tracked;
    __weak id <DJLConversationCellViewDelegate> _delegate;
    FBKVOController * _kvoController;
    BOOL _selected;
    BOOL _nextCellSelected;
    CGFloat _vibrancy;
}

@synthesize delegate = _delegate;
@synthesize vibrancy = _vibrancy;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    _starView = [[DJLConversationStatusView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [_starView setStar:YES];
    [_starView setTarget:self];
    [_starView setAction:@selector(_clicked:)];

    _unreadView = [[DJLConversationStatusView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [_unreadView setTarget:self];
    [_unreadView setAction:@selector(_clicked:)];

    _snippetView = [[DJLConversationCellSnippetView alloc] initWithFrame:[self bounds]];
    //[_snippetView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [self addSubview:_snippetView];

    [self _layoutStatusViews];
    [self addSubview:_starView];
    [self addSubview:_unreadView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(avatarUpdated:)
                                                 name:DJLAVATARMANAGER_UPDATED
                                               object:nil];
    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:[NSUserDefaults standardUserDefaults] keyPath:@"ShowCellDebugInfo" options:0 block:^(id observer, id object, NSDictionary * change) {
        [weakSelf setNeedsDisplay:YES];
    }];
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) avatarUpdated:(NSNotification *)notification
{
    NSDictionary * info = [notification userInfo];
    if (info == nil) {
        [self setNeedsDisplay:YES];
        return;
    }

    NSString * email = [info objectForKey:@"email"];
    if ([email isEqualToString:[_conversation objectForKey:@"sender"]]) {
        [self setNeedsDisplay:YES];
    }
}

- (void) _layoutStatusViews
{
    NSRect buttonFrame = [self bounds];
    buttonFrame.size.width = 25;
    buttonFrame.size.height = 25;
    buttonFrame.origin.y = [self bounds].size.height - 33;
    [_starView setFrame:buttonFrame];
    buttonFrame.size.width = 25;
    buttonFrame.size.height = 25;
    buttonFrame.origin.y = (int) ([self bounds].size.height / 2) - 12;
    [_unreadView setFrame:buttonFrame];
}

- (void) resizeSubviewsWithOldSize:(NSSize)oldSize
{
    [self _layoutStatusViews];
    [_snippetView setFrame:[self bounds]];
    [_snippetView setNeedsDisplay:YES];
}

- (BOOL) _isFocused
{
    if (![NSApp isActive]) {
        return NO;
    }
    if ([NSApp keyWindow] != [self window]) {
        return NO;
    }
    NSView * parentView = self;
    while (parentView != nil) {
        if ([[self window] firstResponder] == parentView) {
            return YES;
        }
        parentView = [parentView superview];
    }
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (_conversation == nil) {
        return;
    }

    if (_selected) {
        NSColor * color = nil;
        if ([self _isFocused]) {
            if (_vibrancy == 0.0) {
                color = DJL_SELECTION_OVERLAY_FOCUS_COLOR;
            }
            else {
                color = DJL_SELECTION_OVERLAY_FOCUS_COLOR_FOR_VIBRANCY;
            }
        }
        else {
            color = DJL_SELECTION_OVERLAY_UNFOCUS_COLOR;
        }
        [color setFill];
        NSRectFill([self bounds]);
    }

    NSNumber * nbUnread = [_conversation objectForKey:@"unread"];
    BOOL isRead = ![nbUnread boolValue];
    //NSNumber * nbStarred = [_conversation objectForKey:@"starred"];
    
    CGFloat avatarSize = 30;
    CGFloat statusMargin = 15;
    NSString * avatarEmail = [_conversation objectForKey:@"sender"];
    NSImage * image = nil;
    if (avatarEmail != nil) {
        image = [[DJLAvatarManager sharedManager] avatarForEmail:avatarEmail size:avatarSize];
    }
    
    NSRect bounds = [self bounds];
    
    CGFloat initialY = bounds.size.height;
    
    NSSize textSize;
    NSRect rect;
    CGFloat y = initialY;
    
    CGFloat dateWidth = 0;

    NSString * dateStr = nil;
    time_t date = [(NSNumber *) [_conversation objectForKey:@"timestamp"] longLongValue];
    time_t currentDate = time(NULL);
    struct tm gmDate;
    struct tm gmCurrentDate;
    gmtime_r(&date, &gmDate);
    gmtime_r(&currentDate, &gmCurrentDate);
    if (currentDate - date < 60) {
        dateStr = @"Now";
    }
    else if (currentDate - date < 60 * 60) {
        dateStr = [NSString stringWithFormat:@"%lim", (currentDate - date) / 60];
    }
    else if (currentDate - date < 12 * 60 * 60) {
        dateStr = [NSString stringWithFormat:@"%lih", (currentDate - date) / (60 * 60)];
    }

    if (dateStr == nil) {
        dateStr = [_conversation objectForKey:@"datestr"];
    }
    if (dateStr != NULL) {
        NSFont * dateFont = [NSFont systemFontOfSize:12];
        NSMutableDictionary * dateAttr = [NSMutableDictionary dictionary];
        [dateAttr setObject:dateFont forKey:NSFontAttributeName];
        if (_selected) {
            [dateAttr setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
        }
        else {
            [dateAttr setObject:[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] forKey:NSForegroundColorAttributeName];
        }
        NSAttributedString * dateAttrStr = [[NSAttributedString alloc] initWithString:dateStr attributes:dateAttr];
        textSize = [dateAttrStr size];
        dateWidth = textSize.width;
        
        rect = bounds;
        y -= textSize.height + 2;
        rect.size.width = dateWidth;
        rect.size.height = textSize.height;
        rect.origin.x = bounds.size.width - 20 - dateWidth;
        rect.origin.y = y - 2 - 5;
        [dateAttrStr drawWithRect:rect options:0];
    }
    
    y = initialY - 5;
    
    NSColor * sendersColor = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
    NSColor * separatorColor = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
    if (isRead && !_selected) {
        sendersColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];
        separatorColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    }
    NSString * listID = [_conversation objectForKey:@"listid"];
    NSMutableString * senders = [NSMutableString string];
    if (listID != nil) {
        [senders appendString:listID];
    }
    else {
        for(NSString * sender in [_conversation objectForKey:@"senders"]) {
            if ([senders length] != 0) {
                [senders appendString:@", "];
            }
            [senders appendString:sender];
        }
    }
    NSFont * sendersFont = [NSFont boldSystemFontOfSize:14];
    NSMutableDictionary * sendersAttr = [NSMutableDictionary dictionary];
    [sendersAttr setObject:sendersColor forKey:NSForegroundColorAttributeName];
    [sendersAttr setObject:sendersFont forKey:NSFontAttributeName];
    NSAttributedString * sendersAttrStr = [[NSAttributedString alloc] initWithString:senders attributes:sendersAttr];

    NSFont * subjectFont = [NSFont systemFontOfSize:14];
    NSMutableDictionary * subjectAttr = [NSMutableDictionary dictionary];
    [subjectAttr setObject:subjectFont forKey:NSFontAttributeName];
    [subjectAttr setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    NSString * subject = [_conversation objectForKey:@"subject"];
    if (subject == nil) {
        subject = @"";
    }
    NSAttributedString * subjectAttrStr = [[NSAttributedString alloc] initWithString:subject attributes:subjectAttr];

    NSMutableDictionary * separatorAttr = [NSMutableDictionary dictionary];
    [separatorAttr setObject:separatorColor forKey:NSForegroundColorAttributeName];
    [separatorAttr setObject:subjectFont forKey:NSFontAttributeName];
    NSAttributedString * separatorAttrStr = [[NSAttributedString alloc] initWithString:@" - " attributes:separatorAttr];

    NSMutableAttributedString * sendersSubjectsAttrStr = [[NSMutableAttributedString alloc] init];
    [sendersSubjectsAttrStr appendAttributedString:sendersAttrStr];
    if ([subjectAttrStr length] != 0) {
        [sendersSubjectsAttrStr appendAttributedString:separatorAttrStr];
        [sendersSubjectsAttrStr appendAttributedString:subjectAttrStr];
    }

    textSize = [sendersSubjectsAttrStr size];

    BOOL drawSubjectSeparately = NO;
    CGFloat maxWidth = bounds.size.width - (30 + dateWidth + 5) - ((avatarSize + 5) + statusMargin);
    if (textSize.width > maxWidth) {
        if ([subjectAttrStr length] != 0) {
            drawSubjectSeparately = YES;
        }
    }

    if (drawSubjectSeparately) {
        [sendersSubjectsAttrStr setAttributedString:separatorAttrStr];
        [sendersSubjectsAttrStr appendAttributedString:subjectAttrStr];

        NSSize senderSize = [sendersAttrStr size];
        NSSize subjectSize = [sendersSubjectsAttrStr size];

        if (senderSize.width < maxWidth / 2) {
            subjectSize.width = maxWidth - senderSize.width;
        }
        else if (subjectSize.width < maxWidth / 2) {
            senderSize.width = maxWidth - subjectSize.width;
        }
        else {
            senderSize.width = (int) maxWidth / 2;
            subjectSize.width = maxWidth - senderSize.width;
        }

        rect = bounds;
        y -= textSize.height + 5;
        rect.size.width = senderSize.width;
        rect.size.height = textSize.height;
        rect.origin.x = 10;
        rect.origin.y = y;
        rect.origin.x += (avatarSize + 5) + statusMargin;

        CGFloat nextX = NSMaxX(rect);

        [sendersAttrStr drawWithRect:rect options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];

        rect = bounds;
        rect.size.width = subjectSize.width;
        rect.size.height = textSize.height;
        rect.origin.x = nextX;
        rect.origin.y = y;

        [sendersSubjectsAttrStr drawWithRect:rect options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
    }
    else {
        rect = bounds;
        y -= textSize.height + 5;
        rect.size.width = maxWidth;
        rect.size.height = textSize.height;
        rect.origin.x = 10;
        rect.origin.y = y;
        rect.origin.x += (avatarSize + 5) + statusMargin;
        
        [sendersSubjectsAttrStr drawWithRect:rect options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
    }

    y -= textSize.height + 5;
    
    NSColor * previewColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    if (_selected) {
        previewColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    }

    NSFont * senderFont = [NSFont boldSystemFontOfSize:12];
    NSMutableDictionary * senderAttr = [NSMutableDictionary dictionary];
    [senderAttr setObject:senderFont forKey:NSFontAttributeName];
    [senderAttr setObject:previewColor forKey:NSForegroundColorAttributeName];
    NSFont * snippetFont = [NSFont systemFontOfSize:12];
    NSMutableDictionary * snippetAttr = [NSMutableDictionary dictionary];
    [snippetAttr setObject:snippetFont forKey:NSFontAttributeName];
    [snippetAttr setObject:previewColor forKey:NSForegroundColorAttributeName];

    [NSGraphicsContext saveGraphicsState];
    NSBezierPath * path = [[NSBezierPath alloc] init];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(8 + statusMargin + avatarSize / 2., (int) ((bounds.size.height - avatarSize) / 2.) + avatarSize / 2.) radius:avatarSize / 2. startAngle:0 endAngle:360];
    [path addClip];
    if (image == nil) {
        [[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(8 + statusMargin, /*bounds.size.height - 24 - 6 */ (int) ((bounds.size.height - avatarSize) / 2), avatarSize, avatarSize));
        if ([senders length] > 0) {
            NSFont * avatarFont = [NSFont systemFontOfSize:18];
            NSString * senderFirstLetter = [[senders substringToIndex:1] uppercaseString];
            NSDictionary * avatarAttr = @{NSFontAttributeName: avatarFont, NSForegroundColorAttributeName: [NSColor colorWithWhite:0.4 alpha:1.0]};
            NSSize size = [senderFirstLetter sizeWithAttributes:avatarAttr];
            NSPoint position = NSMakePoint((avatarSize - size.width) / 2, (avatarSize - size.height) / 2);
            [senderFirstLetter drawAtPoint:NSMakePoint(8 + statusMargin + position.x, (int) ((bounds.size.height - avatarSize) / 2) + position.y) withAttributes:avatarAttr];
        }
    }
    else {
        [image drawAtPoint:NSMakePoint(8 + statusMargin, (int) ((bounds.size.height - avatarSize) / 2)) fromRect:NSMakeRect(0, 0, avatarSize, avatarSize) operation:NSCompositeSourceOver fraction:1.0];
    }
    [NSGraphicsContext restoreGraphicsState];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowCellDebugInfo"]) {
        NSFont * font = [NSFont boldSystemFontOfSize:20];
        NSMutableDictionary * attr = [NSMutableDictionary dictionary];
        [attr setObject:font forKey:NSFontAttributeName];
        [attr setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
        NSString * str = [NSString stringWithFormat:@"%@", [_conversation objectForKey:@"id"]];
        [str drawAtPoint:NSMakePoint(0, bounds.size.height - 30) withAttributes:attr];
    }

    // Separator line. Do not draw it above or below selection highlight.
    if (!_nextCellSelected && !_selected) {
        path = [[NSBezierPath alloc] init];
        [path moveToPoint:NSMakePoint(60, 0)];
        [path lineToPoint:NSMakePoint(bounds.size.width, 0)];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.15] setStroke];
        [path stroke];
    }
}

- (void) setConversation:(NSDictionary *)conversation
{
    _conversation = conversation;
    //NSLog(@"%@", _conversation);
    //[[self textField] setStringValue:@""];
    [_starView setConversation:_conversation];
    [_unreadView setConversation:_conversation];
    [_snippetView setConversation:_conversation];
}

- (NSDictionary *) conversation
{
    return _conversation;
}

- (void) _clicked:(id)sender
{
    if (sender == _starView) {
        [[self delegate] DJLConversationCellViewStarClicked:self];
    }
    else {
        [[self delegate] DJLConversationCellViewUnreadClicked:self];
    }
}

- (BOOL) isSelected
{
    return _selected;
}

- (void) setSelected:(BOOL)selected
{
    if (_selected == selected) {
        return;
    }
    _selected = selected;
    [_snippetView setSelected:_selected];
    [self setNeedsDisplay:YES];
}

- (BOOL) isNextCellSelected
{
    return _nextCellSelected;
}

- (void) setNextCellSelected:(BOOL)nextCellSelected
{
    if (_nextCellSelected == nextCellSelected) {
        return;
    }
    _nextCellSelected = nextCellSelected;
    [self setNeedsDisplay:YES];
}

- (void) setVibrancy:(CGFloat)vibrancy
{
    if (_vibrancy == vibrancy) {
        return;
    }
    _vibrancy = vibrancy;
    [_snippetView setVibrancy:vibrancy];
    [self setNeedsDisplay:YES];
}

- (void) setFolderPath:(NSString *)folderPath
{
    [_snippetView setFolderPath:folderPath];
}

- (NSString *) folderPath
{
    return [_snippetView folderPath];
}

- (void) update
{
    [self setNeedsDisplay:YES];
    [_snippetView setNeedsDisplay:YES];
}

@end
