// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

@interface NSData (DJL)

+ (NSData *) djlDataUsingWebSafeBase64:(NSString *)base64Str;
- (NSString *) djlUTF8String;

@end
