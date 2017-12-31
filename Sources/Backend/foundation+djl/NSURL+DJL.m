// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "NSURL+DJL.h"

#import "NSDictionary+DJL.h"

@implementation NSURL (DJL)

- (NSDictionary *) djlQueryStringValues
{
    return [NSDictionary djlDictionaryWithQueryString:[self _query]];
}

- (NSArray *) _splitRecipientQuery
{
    NSString * resourceString;
    NSRange range;

    resourceString = [self resourceSpecifier];
    if (resourceString == nil)
        return [NSArray array];

    range = [resourceString rangeOfString:@"?"];
    if (range.location == NSNotFound) {
        return [NSArray arrayWithObject:resourceString];
    }
    else {
        NSString * queryString;
        NSString * mainRecipient;

        mainRecipient = [resourceString substringToIndex:range.location];
        queryString = [resourceString substringFromIndex:range.location + 1];

        return [NSArray arrayWithObjects:mainRecipient, queryString, nil];
    }
}

- (NSString *) djlRecipient
{
    NSArray * values;

    values = [self _splitRecipientQuery];
    if ([values count] == 0)
        return nil;

    return [values objectAtIndex:0];
}

- (NSString *) _query
{
    NSArray * components;

    components = [self _splitRecipientQuery];
    if ([components count] < 2)
        return nil;
    
    return [components objectAtIndex:1];
}

@end
