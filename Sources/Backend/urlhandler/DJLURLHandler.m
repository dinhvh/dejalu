// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLURLHandler.h"

#import "NSURL+DJL.h"
#import "NSString+DJL.h"

enum {
    PENDING_URL,
    PENDING_MAIL_WEBPAGE,
    PENDING_MAIL_WEBLINK,
};

@implementation DJLURLHandler {
    int _pendingType;
    NSAppleEventDescriptor * _pendingDescriptor;
    NSAppleEventDescriptor * _pendingReplyEvent;
}

@synthesize ready = _ready;
@synthesize delegate = _delegate;

+ (instancetype) sharedManager
{
    static DJLURLHandler *sharedInstance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        sharedInstance = [[DJLURLHandler alloc] init];
    });

    return sharedInstance;
}

- (id) init
{
    self = [super init];
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(_handleURL:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(_handleMailWebPageEvent:replyEvent:) forEventClass:'mail' andEventID:'mlpg'];
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(_handleMailWebLinkEvent:replyEvent:) forEventClass:'mail' andEventID:'mllk'];
    return self;
}

- (void) registerAsDefault
{
    NSString * bundleID = [[NSBundle mainBundle] bundleIdentifier];
    LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (__bridge CFStringRef)bundleID);
    LSSetDefaultHandlerForURLScheme((CFStringRef)@"message", (__bridge CFStringRef)bundleID);
}

- (void) registerMailAsDefault
{
    NSString * bundleID = @"com.apple.mail";
    LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (__bridge CFStringRef)bundleID);
    LSSetDefaultHandlerForURLScheme((CFStringRef)@"message", (__bridge CFStringRef)bundleID);
}

- (BOOL) isRegisteredAsDefault
{
    NSString * handler;
    BOOL result;

    NSString * bundleID = [[NSBundle mainBundle] bundleIdentifier];
    handler = CFBridgingRelease(LSCopyDefaultHandlerForURLScheme((__bridge CFStringRef) @"mailto"));
    result = [bundleID isEqualToString:handler];

    if (result) {
        handler = CFBridgingRelease(LSCopyDefaultHandlerForURLScheme((CFStringRef) @"message"));
        if (![bundleID isEqualToString:handler]) {
            [self registerAsDefault];
        }
    }

    return result;
}

- (void) _handleURL:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    _pendingType = PENDING_URL;
    _pendingDescriptor = [event copy];
    _pendingReplyEvent = [replyEvent copy];

    [self _handleURLAfterLoad];
}

- (void) _handleURLAfterLoad
{
    if (![self isReady])
        return;

    if (_pendingType != PENDING_URL)
        return;

    if ((_pendingDescriptor == nil) || (_pendingReplyEvent == nil))
        return;

    NSAppleEventDescriptor * descriptor;
    NSAppleEventDescriptor * replyEvent;

    descriptor = _pendingDescriptor;
    replyEvent = _pendingReplyEvent;

    NSString * urlString = [[descriptor paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL * url = [NSURL URLWithString:urlString];

    [self openURL:url];

    _pendingDescriptor = nil;
    _pendingReplyEvent = nil;
}

- (void) _handleMailToURL:(NSURL *)url
{
    NSDictionary * values;
    NSString * mainRecipient;
    NSString * to;
    NSString * cc;
    NSString * bcc;
    NSString * subject;
    NSString * body;

    mainRecipient = [url djlRecipient];
    to = nil;
    cc = nil;
    bcc = nil;
    subject = nil;
    body = nil;

    values = [url djlQueryStringValues];
    // do this because this is a small dictionary and because of case insensitivity
    for(NSString * key in values) {
        if ([key caseInsensitiveCompare:@"to"] == NSOrderedSame) {
            to = [values objectForKey:key];
        }
        else if ([key caseInsensitiveCompare:@"cc"] == NSOrderedSame) {
            cc = [values objectForKey:key];
        }
        else if ([key caseInsensitiveCompare:@"bcc"] == NSOrderedSame) {
            bcc = [values objectForKey:key];
        }
        else if ([key caseInsensitiveCompare:@"subject"] == NSOrderedSame) {
            subject = [values objectForKey:key];
        }
        else if ([key caseInsensitiveCompare:@"body"] == NSOrderedSame) {
            body = [values objectForKey:key];
        }
    }

    //NSLog(@"%@ %@ %@ %@ %@ %@", mainRecipient, to, cc, bcc, subject, body);
    if ([mainRecipient length] > 0) {
        to = mainRecipient;
    }

    [[self delegate] DJLURLHandler:self composeMessageWithTo:to cc:cc bcc:bcc subject:subject body:body];
    //[[MMMainWindowController sharedController] composeMessageWithTo:to cc:cc bcc:bcc subject:subject body:body];
}

- (void) _handleOtherURL:(NSURL *)url
{
    [[self delegate] DJLURLHandler:self composeMessageWithTo:nil cc:nil bcc:nil subject:nil body:[url absoluteString]];
    //[[MMMainWindowController sharedController] composeMessageWithTo:nil cc:nil bcc:nil subject:nil body:[url absoluteString]];
}

- (void) _handleMailWebPageEvent:(NSAppleEventDescriptor *)descriptor replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    _pendingType = PENDING_MAIL_WEBPAGE;
    _pendingDescriptor = [descriptor copy];
    _pendingReplyEvent = [replyEvent copy];

    [self _handleMailWebPageEventAfterLoad];
}

- (void) _handleMailWebPageEventAfterLoad
{
    if (![self isReady])
        return;

    if (_pendingType != PENDING_MAIL_WEBPAGE)
        return;

    if ((_pendingDescriptor == nil) || (_pendingReplyEvent == nil))
        return;

    NSAppleEventDescriptor * descriptor;
    NSAppleEventDescriptor * replyEvent;

    descriptor = _pendingDescriptor;
    replyEvent = _pendingReplyEvent;

    BOOL shouldSuppressSenderLine = NO;

    NSData *archiveData = [[descriptor paramDescriptorForKeyword:keyDirectObject] data];
    NSString *subject = [[descriptor paramDescriptorForKeyword:'urln'] stringValue];
    // NSString *address = [[descriptor paramDescriptorForKeyword:'usln'] stringValue];  // not used
    NSString *supressSenderLine = [[descriptor paramDescriptorForKeyword:'suln'] stringValue];

    if ([[supressSenderLine lowercaseString] isEqualToString:@"yes"]) {
        shouldSuppressSenderLine = YES;
    }

    WebArchive * archive = [[WebArchive alloc] initWithData:archiveData];
    [[self delegate] DJLURLHandler:self composeMessageWithTo:nil cc:nil bcc:nil subject:subject archive:archive];

    _pendingDescriptor = nil;
    _pendingReplyEvent = nil;
}

- (void) _handleMailWebLinkEvent:(NSAppleEventDescriptor *)descriptor replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    _pendingType = PENDING_MAIL_WEBLINK;
    _pendingDescriptor = [descriptor copy];
    _pendingReplyEvent = [replyEvent copy];

    [self _handleMailWebLinkEventAfterLoad];
}

- (void) _handleMailWebLinkEventAfterLoad
{
    if (![self isReady])
        return;

    if (_pendingType != PENDING_MAIL_WEBLINK)
        return;

    if ((_pendingDescriptor == nil) || (_pendingReplyEvent == nil))
        return;

    NSAppleEventDescriptor * descriptor;
    NSAppleEventDescriptor * replyEvent;

    descriptor = _pendingDescriptor;
    replyEvent = _pendingReplyEvent;

    NSString * urlString = [[descriptor paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSString *subject = [[descriptor paramDescriptorForKeyword:'urln'] stringValue];

    NSString * htmlStr = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlString, urlString];
    [[self delegate] DJLURLHandler:self composeMessageWithTo:nil cc:nil bcc:nil subject:subject htmlBody:htmlStr];
    
    _pendingDescriptor = nil;
    _pendingReplyEvent = nil;
}

- (void) _handleMessageURL:(NSURL *)url
{
    NSString * msgID;

    msgID = [url resourceSpecifier];
    if ([msgID hasPrefix:@"//"]) {
        msgID = [msgID substringFromIndex:2];
    }
    msgID = [msgID djlURLDecode];
    if (([msgID hasPrefix:@"<"]) && ([msgID hasSuffix:@">"])) {
        msgID = [msgID substringWithRange:NSMakeRange(1, [msgID length] - 2)];
    }
    [[self delegate] DJLURLHandler:self openMessageWithMessageID:msgID];
}

- (void) openURL:(NSURL *)url
{
    if ([[url scheme] caseInsensitiveCompare:@"mailto"] == NSOrderedSame) {
        [self _handleMailToURL:url];
    }
    else if ([[url scheme] caseInsensitiveCompare:@"message"] == NSOrderedSame) {
        [self _handleMessageURL:url];
    }
}

@end
