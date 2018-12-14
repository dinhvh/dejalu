// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationListPlaceholderView.h"

#import "NSImage+DJLColored.h"
#import "DJLColoredProgressIndicator.h"
#import "DJLDarkMode.h"
#import "FBKVOController.h"

@implementation DJLConversationListPlaceholderView {
    NSImage * _noMessagesImage;
    NSImage * _notLoadedImage;
    NSImage * _loadingImage;
    NSImage * _searchingImage;
    NSImage * _inboxZeroImage;
    DJLColoredProgressIndicator * _progressIndicator;
    FBKVOController * _kvoController;
}

@synthesize kind = _kind;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    _kind = DJLConversationListPlaceholderKindNone;
    CGFloat x = (int) (([self bounds].size.width - 32) / 2);
    _progressIndicator = [[DJLColoredProgressIndicator alloc] initWithFrame:NSMakeRect(x, [self bounds].size.height - 280, 32, 32)];
    [_progressIndicator setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin];
    [_progressIndicator setColor:[NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
    [_progressIndicator setHidden:YES];
    [self addSubview:_progressIndicator];
    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:self keyPath:@"effectiveAppearance" options:0 block:^(id observer, id object, NSDictionary * change) {
        _noMessagesImage = nil;
        _notLoadedImage = nil;
        _loadingImage = nil;
        _searchingImage = nil;
        _inboxZeroImage = nil;
        [weakSelf setNeedsDisplay:YES];
    }];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    if (_kind == DJLConversationListPlaceholderKindNone) {
        return;
    }

    NSColor * color;
    NSColor * textColor;
    if ([DJLDarkMode isDarkModeForView:self]) {
        color = [NSColor colorWithCalibratedWhite:1.0 alpha:0.3];
        textColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.4];
    } else {
        color = [NSColor colorWithCalibratedWhite:0.0 alpha:0.3];
        textColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.4];
    }

    //int iconSize = 0;
    int top = 0;
    int textTop = 0;
    NSImage * image = nil;
    NSString * text = nil;
    switch (_kind) {
        case DJLConversationListPlaceholderKindInboxZero:
            //iconSize = 200;
            if (_inboxZeroImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_InboxZero_128"];
                //originImage = [originImage copy];
                //[originImage setSize:NSMakeSize(iconSize, iconSize)];
                NSImage * img = [originImage djl_imageWithColor:color];
                _inboxZeroImage = img;
            }
            top = 180;
            textTop = 370;
            text = @"No messages";
            image = _inboxZeroImage;
            break;
        case DJLConversationListPlaceholderKindEmpty:
            if (_noMessagesImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_Empty_128"];
                NSImage * img = [originImage djl_imageWithColor:color];
                _noMessagesImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"No messages";
            image = _noMessagesImage;
            break;
        case DJLConversationListPlaceholderKindLoading:
            if (_loadingImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_GettingEmail_128"];
                NSImage * img = [originImage djl_imageWithColor:color];
                _loadingImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"";
            image = _loadingImage;
            break;
        case DJLConversationListPlaceholderKindNotLoaded:
            if (_notLoadedImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_NetworkErrorOff_128"];
                NSImage * img = [originImage djl_imageWithColor:color];
                _notLoadedImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"Not loaded";
            image = _notLoadedImage;
            break;
        case DJLConversationListPlaceholderKindSearching:
            if (_searchingImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_Search_128"];
                NSImage * img = [originImage djl_imageWithColor:color];
                _searchingImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"Searching";
            image = _searchingImage;
            break;
        case DJLConversationListPlaceholderKindNoAccounts:
            if (_noMessagesImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_Empty_128"];
                NSImage * img = [originImage djl_imageWithColor:color];
                _noMessagesImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"No accounts";
            image = _noMessagesImage;
            break;
        default:
            // Do nothing.
            break;
    }

    NSRect bounds = [self bounds];
    NSSize imageSize = [image size];
    NSRect rect = NSMakeRect((bounds.size.width - imageSize.width) / 2, bounds.size.height - top, imageSize.width, imageSize.height);
    rect = NSIntegralRect(rect);
    [image drawInRect:rect];

    NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:NSTextAlignmentCenter];
    [text drawInRect:NSMakeRect(0, bounds.size.height - textTop, bounds.size.width, 200)
      withAttributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:18], NSParagraphStyleAttributeName: paragraphStyle, NSForegroundColorAttributeName: textColor}];
}

- (void) setKind:(DJLConversationListPlaceholderKind)kind
{
    _kind = kind;
    [self setNeedsDisplay:YES];
    if (_kind == DJLConversationListPlaceholderKindSearching) {
        [_progressIndicator setHidden:NO];
        [_progressIndicator startAnimation:nil];
    }
    else {
        [_progressIndicator setHidden:YES];
        [_progressIndicator stopAnimation:nil];
    }
}

@end
