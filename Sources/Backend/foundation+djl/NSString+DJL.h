// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

@interface NSString (DJL)

- (NSString *) djlURLEncode;
- (NSString *) djlURLDecode;

- (NSString *) djl_stringByStrippingCombiningMarks;
- (NSString *) djl_stringForCompletion;

+ (NSArray *) djlNameExtensions;
- (NSString *)djlTrimCommasSpacesQuotes;
+ (NSArray *) djlPartialSurnames;
- (BOOL) djlAppearsToBeAnInitial;

- (BOOL) djlIsValidEmail;

- (NSString *) djlUncheckedShortDisplayName;
- (NSString *) djlShortEmailDisplayNameWithAllEmails:(NSArray *)emails;

- (NSURL *) djlURL;

@end
