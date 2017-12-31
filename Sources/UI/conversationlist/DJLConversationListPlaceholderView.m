// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationListPlaceholderView.h"

#import "NSImage+DJLColored.h"
#import "DJLColoredProgressIndicator.h"

@implementation DJLConversationListPlaceholderView {
    NSImage * _noMessagesImage;
    NSImage * _notLoadedImage;
    NSImage * _loadingImage;
    NSImage * _searchingImage;
    NSImage * _inboxZeroImage;
    DJLColoredProgressIndicator * _progressIndicator;
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
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    if (_kind == DJLConversationListPlaceholderKindNone) {
        return;
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
                NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
                _inboxZeroImage = img;
            }
            top = 180;
            textTop = 370;
            text = @"No messages";
            image = _inboxZeroImage;
            break;
        case DJLConversationListPlaceholderKindEmpty:
            //iconSize = 130;
            if (_noMessagesImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_Empty_128"];
//                originImage = [originImage copy];
//                [originImage setSize:NSMakeSize(iconSize, iconSize)];
                NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
                _noMessagesImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"No messages";
            image = _noMessagesImage;
            break;
        case DJLConversationListPlaceholderKindLoading:
            //iconSize = 100;
            if (_loadingImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_GettingEmail_128"];
//                originImage = [originImage copy];
//                [originImage setSize:NSMakeSize(iconSize, iconSize)];
                NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
                _loadingImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"";
            image = _loadingImage;
            break;
        case DJLConversationListPlaceholderKindNotLoaded:
//            iconSize = 100;
            if (_notLoadedImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_NetworkErrorOff_128"];
//                originImage = [originImage copy];
//                [originImage setSize:NSMakeSize(iconSize, iconSize)];
                NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
                _notLoadedImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"Not loaded";
            image = _notLoadedImage;
            break;
        case DJLConversationListPlaceholderKindSearching:
//            iconSize = 100;
            if (_searchingImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_Search_128"];
//                originImage = [originImage copy];
//                [originImage setSize:NSMakeSize(iconSize, iconSize)];
                NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
                _searchingImage = img;
            }
            top = 180;
            textTop = 400;
            text = @"Searching";
            image = _searchingImage;
            break;
        case DJLConversationListPlaceholderKindNoAccounts:
            //iconSize = 130;
            if (_noMessagesImage == nil) {
                NSImage * originImage = [NSImage imageNamed:@"DejaLu_Empty_128"];
                //                originImage = [originImage copy];
                //                [originImage setSize:NSMakeSize(iconSize, iconSize)];
                NSImage * img = [originImage djl_imageWithColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
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
      withAttributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:18], NSParagraphStyleAttributeName: paragraphStyle, NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.0 alpha:0.4]}];
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
