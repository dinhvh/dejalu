// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

@interface NSDictionary (DJL)

+ (NSDictionary *) djlDictionaryWithQueryString:(NSString *)queryString;
- (NSString *) djlQueryString;

@end
