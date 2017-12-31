// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "WebResource+DJL.h"

@implementation WebResource (DJL)

- (NSString *) djlString
{
    CFStringEncoding encoding = kCFStringEncodingInvalidId;
    if ([self textEncodingName] != NULL) {
        encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef) [self textEncodingName]);
    }
    if (encoding == kCFStringEncodingInvalidId) {
        encoding = kCFStringEncodingUTF8; // 0x08000100
    }
    return [[NSString alloc] initWithData:[self data] encoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
}

@end
