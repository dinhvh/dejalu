// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLConversationStatusView.h"

#include "DJLLog.h"

#import "DJLTableView.h"
#import "DJLWindow.h"

#define LOG(...) DJLLogWithID("statusview", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("statusview", __VA_ARGS__)

static void pathStar(CGContextRef context, unsigned int points, CGPoint center, CGFloat innerRadius, CGFloat outerRadius)
{
    CGFloat arcPerPoint = 2.0f * M_PI / points;
    CGFloat theta = M_PI / 2.0f;
    
    // Move to starting point (tip at 90 degrees on outside of star)
    CGPoint pt = CGPointMake(center.x - (outerRadius * cosf(theta)), center.y - (outerRadius * sinf(theta)));
    CGContextMoveToPoint(context, pt.x, pt.y);
    
    for (int i = 0; i < points; i = i + 1) {
        // Calculate next inner point (moving clockwise), accounting for crossing of 0 degrees
        theta = theta - (arcPerPoint / 2.0f);
        if (theta < 0.0f) {
            theta = theta + (2 * M_PI);
        }
        pt = CGPointMake(center.x - (innerRadius * cosf(theta)), center.y - (innerRadius * sinf(theta)));
        CGContextAddLineToPoint(context, pt.x, pt.y);
        
        // Calculate next outer point (moving clockwise), accounting for crossing of 0 degrees
        theta = theta - (arcPerPoint / 2.0f);
        if (theta < 0.0f) {
            theta = theta + (2 * M_PI);
        }
        pt = CGPointMake(center.x - (outerRadius * cosf(theta)), center.y - (outerRadius * sinf(theta)));
        CGContextAddLineToPoint(context, pt.x, pt.y);
    }
    CGContextClosePath(context);
}

static void strokeStar(CGContextRef context, unsigned int points, CGPoint position, CGColorRef strokeColor, CGFloat innerRadius, CGFloat outerRadius)
{
    CGContextSaveGState(context);
    CGContextSetStrokeColorWithColor(context, strokeColor);
    pathStar(context, points, position, innerRadius, outerRadius);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

static void fillStar(CGContextRef context, unsigned int points, CGPoint position, CGColorRef fillColor, CGFloat innerRadius, CGFloat outerRadius)
{
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, fillColor);
    pathStar(context, points, position, innerRadius, outerRadius);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

@interface DJLConversationStatusViewCell : NSButtonCell

@end

@implementation DJLConversationStatusViewCell

- (BOOL) acceptsFirstResponder
{
    return NO;
}

@end

@implementation DJLConversationStatusView {
    NSTrackingArea * _area;
    BOOL _over;
    BOOL _tracking;
    BOOL _clickingInside;
    NSDictionary * _conversation;
    BOOL _star;
}

static BOOL s_interactionEnabled = NO;

@synthesize star = _star;

+ (void) setInteractionEnabled:(BOOL)enabled
{
    s_interactionEnabled = enabled;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    [self setCell:[[DJLConversationStatusViewCell alloc] init]];
    [self updateTrackingAreas];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_flagsChanged:) name:DJLWINDOW_FLAGS_CHANGED object:nil];
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) _flagsChanged:(NSNotification *)notification
{
    if (_over && !_tracking) {
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSNumber * nbUnread = [_conversation objectForKey:@"unread"];
    NSNumber * nbStarred = [_conversation objectForKey:@"starred"];
    
    if (![self isStar]) {
        NSRect rect = NSMakeRect(7, 9, 10, 10);
        if ([nbUnread boolValue]) {
            NSColor * color = nil;
            if (_tracking) {
                if (_clickingInside) {
                    color = [NSColor colorWithCalibratedRed:0.6 green:0.6 blue:1.0 alpha:1.0];
                    CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], rect);
                    CGContextSetStrokeColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
                    CGContextStrokePath([[NSGraphicsContext currentContext] CGContext]);
                }
                else {
                    color = [NSColor colorWithCalibratedRed:0.4 green:0.4 blue:1.0 alpha:1.0];
                    CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], rect);
                    CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
                    CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
                }
            }
            else {
                if (_over) {
                    color = [NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.7 alpha:1.0];
                }
                else {
                    color = [NSColor colorWithCalibratedRed:0.4 green:0.4 blue:1.0 alpha:1.0];
                }
                CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], rect);
                CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
                CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
            }
        }
        else {
            NSColor * color = nil;
            if (_clickingInside) {
                color = [NSColor colorWithCalibratedRed:0.6 green:0.6 blue:1.0 alpha:1.0];
                CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], rect);
                CGContextSetFillColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
                CGContextFillPath([[NSGraphicsContext currentContext] CGContext]);
            }
            else if (_over) {
                color = [NSColor colorWithCalibratedRed:0.6 green:0.6 blue:1.0 alpha:1.0];
                CGContextAddEllipseInRect([[NSGraphicsContext currentContext] CGContext], rect);
                CGContextSetStrokeColorWithColor([[NSGraphicsContext currentContext] CGContext], [color CGColor]);
                CGContextStrokePath([[NSGraphicsContext currentContext] CGContext]);
            }
        }
    }
    else {
        if ([nbStarred boolValue]) {
            NSColor * color = nil;
            NSColor * borderColor = nil;
            if (_tracking) {
                if (_clickingInside) {
                    color = [NSColor clearColor];
                    borderColor = [NSColor colorWithCalibratedRed:0.80 green:0.75 blue:0.0 alpha:1.0];
                }
                else {
                    color = [NSColor colorWithCalibratedRed:0.80 green:0.75 blue:0.0 alpha:1.0];
                    borderColor = color;
                }
            }
            else {
                if (_over) {
                    color = [NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.0 alpha:1.0];
                    borderColor = color;
                } else {
                    color = [NSColor colorWithCalibratedRed:0.80 green:0.75 blue:0.0 alpha:1.0];
                    borderColor = color;
                }
            }
            fillStar([[NSGraphicsContext currentContext] CGContext], 5, CGPointMake(12, 12), [color CGColor], 3, 6);
            strokeStar([[NSGraphicsContext currentContext] CGContext], 5, CGPointMake(12, 12), [borderColor CGColor], 3, 6);
        }
        else {
            // starred state
            NSColor * color = nil;
            NSColor * borderColor = nil;
            BOOL drawStar = NO;
            if (_clickingInside) {
                drawStar = YES;
                color = [NSColor colorWithCalibratedRed:0.80 green:0.75 blue:0.0 alpha:1.0];
                borderColor = color;
            }
            else if (_over) {
                drawStar = YES;
                color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.6 alpha:0];
                borderColor = [NSColor colorWithCalibratedRed:0.80 green:0.75 blue:0.0 alpha:1.0];
            }
            if (drawStar) {
                fillStar([[NSGraphicsContext currentContext] CGContext], 5, CGPointMake(12, 12), [color CGColor], 3, 6);
                strokeStar([[NSGraphicsContext currentContext] CGContext], 5, CGPointMake(12, 12), [borderColor CGColor], 3, 6);
            }
        }
    }
}

- (void) updateTrackingAreas
{
    if (_area != nil) {
        [self removeTrackingArea:_area];
    }
    if ([self superview] == nil) {
        _area = nil;
    }
    if (_over) {
        _over = NO;
        [self setNeedsDisplay];
    }
    NSRect rect = [self bounds];
    rect.size.height = 25;
    _area = [[NSTrackingArea alloc] initWithRect:rect options:NSTrackingActiveInKeyWindow | NSTrackingMouseEnteredAndExited /*| NSTrackingMouseMoved*/ owner:self userInfo:nil];
    [self addTrackingArea:_area];
}

- (void) mouseEntered:(NSEvent *)theEvent
{
    _over = YES;
    [self setNeedsDisplay];
}

- (void) mouseExited:(NSEvent *)theEvent
{
    _over = NO;
    [self setNeedsDisplay];
}

- (void) setConversation:(NSDictionary *)conversation
{
    _conversation = conversation;
    [self setNeedsDisplay];
}

- (NSDictionary *) conversation
{
    return _conversation;
}

- (void) mouseDown:(NSEvent *)theEvent
{
    if (!s_interactionEnabled) {
        return;
    }
    
    if (!_over) {
        return;
    }
    
    _tracking = YES;
    _clickingInside = YES;
    [self setNeedsDisplay];
    NSEvent * event;
    
    NSRect rect = [self bounds];
    rect.size.height = 25;
    
    while (1) {
        event = [NSApp nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSFlagsChangedMask)
                                   untilDate:[NSDate distantFuture]
                                      inMode:NSEventTrackingRunLoopMode
                                     dequeue:YES];
        if ([event type] == NSLeftMouseUp) {
            break;
        }
        
        if ([event type] == NSFlagsChanged) {
            [self setNeedsDisplay];
        }
        BOOL oldValue = _clickingInside;
        NSPoint globalLocation = [event locationInWindow];
        NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
        _clickingInside = NSPointInRect(localLocation, rect);
        if (_clickingInside != oldValue) {
            [self setNeedsDisplay];
        }
    }
    
    BOOL clickedInside = _clickingInside;
    _tracking = NO;
    _clickingInside = NO;
    
    if (clickedInside) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[self target] performSelector:[self action] withObject:self];
#pragma clang diagnostic pop
    }
    
    [self setNeedsDisplay];
}

@end
