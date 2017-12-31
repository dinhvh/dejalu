// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "NSString+DJL.h"

@implementation NSString (DJL)

- (NSString *) djl_stringByStrippingCombiningMarks
{
    NSMutableString * result = [self mutableCopy];
    
    if (CFStringTransform((CFMutableStringRef) result, NULL, kCFStringTransformStripCombiningMarks, false)) {
        return result;
    }
    else {
        return self;
    }
}

- (NSString *) djl_stringForCompletion
{
    return [[self djl_stringByStrippingCombiningMarks] lowercaseString];
}

- (NSString *) djlURLEncode
{
    CFStringRef string = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef) self, NULL, CFSTR("$&+,/:;=?@[]#!'()* "), kCFStringEncodingUTF8);
    return (NSString *)CFBridgingRelease(string);
}

- (NSString *) djlURLDecode
{
    return [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

+ (NSArray *) djlNameExtensions
{
    static NSArray *nameExtensions = nil;

    if (!nameExtensions) {
        nameExtensions = [[NSArray alloc] initWithObjects:@"jr.", @"sr.", @"iii", @"m.d.", @"md", @"d.d.s.", @"dds", @"ph.d.", @"phd", @"m.b.a.", @"mba", @"esq.", @"esq", @"jr", @"sr", @"ii", @"iv", @"v", @"vi", @"vii", @"viii", @"ix", nil];
    }
#define LONGEST_NAME_EXTENSION_LENGTH   6
    return nameExtensions;
}

// Removes commas and space from both front and back.
- (NSString *)djlTrimCommasSpacesQuotes {
    NSInteger startPosition, endPosition;
    NSUInteger length;
    unichar character;
    NSString *trimmedString;
    BOOL hasStartingQuote, hasEndingQuote;

    length = [self length];
    if (length == 0) {
        return @"";
    }

    startPosition = 0;
    hasStartingQuote = NO;
    character = [self characterAtIndex:0];
    while ((character == ',') || (character == ' ') || (character == '\"')) {
        startPosition++;
        if (character == '\"') {
            hasStartingQuote = !hasStartingQuote;
        }
        if (startPosition == length) {
            break;
        }
        character = [self characterAtIndex:startPosition];
    }

    endPosition = length - 1;
    hasEndingQuote = NO;
    character = [self characterAtIndex:endPosition];
    while ((character == ',') || (character == ' ') || (character == '\"')) {
        endPosition--;
        if (character == '\"') {
            hasEndingQuote = !hasEndingQuote;
        }
        if (endPosition <= startPosition) {
            break;
        }
        character = [self characterAtIndex:endPosition];
    }
    if (startPosition > endPosition) {
        return @"";
    }
    trimmedString = [self substringWithRange:NSMakeRange(startPosition, endPosition - startPosition + 1)];

    // Add the deleted quote back in if they weren't matched with each other
    if (hasStartingQuote && !hasEndingQuote) {
        trimmedString = [NSString stringWithFormat:@"\"%@", trimmedString];
    } else if (!hasStartingQuote && hasEndingQuote) {
        trimmedString = [NSString stringWithFormat:@"%@\"", trimmedString];
    }

    return trimmedString;
}

+ (NSArray *) djlPartialSurnames {
    static NSArray *partialSurnames = nil;

    if (!partialSurnames) {
        partialSurnames = [[NSArray alloc] initWithObjects:@"de", @"den", @"der", @"di", @"do", @"du", @"la", @"le", @"les", @"van", @"von", nil];
    }
    return partialSurnames;
}

- (BOOL)djlAppearsToBeAnInitial {
    NSUInteger length;

    length = [self length];
    if (length == 1) {
        return YES;
    }
    if ((length == 2) && ([self characterAtIndex:1] == '.')) {
        return YES;
    }
    return NO;
}

- (BOOL) djlIsValidEmail
{
    NSArray * components;

    components = [self componentsSeparatedByString:@"@"];
    if ([components count] < 2) {
        return NO;
    }

    for(NSString * component in components) {
        if ([component length] == 0) {
            return NO;
        }
    }

    return YES;
}

- (NSString *) djlUncheckedShortDisplayName
{
    NSString * email = [self lowercaseString];
    NSRange range = [email rangeOfString:@"@"];
    if (range.location == NSNotFound) {
        return email;
    }
    NSString * displayName = [email substringFromIndex:range.location + 1];
    if ([displayName length] == 0) {
        return email;
    }
    return displayName;
}

- (NSString *) djlShortEmailDisplayNameWithAllEmails:(NSArray *)emails;
{
    NSString * uncheckedShortDisplayName = [self djlUncheckedShortDisplayName];
    BOOL hasOther = NO;
    for(NSString * otherEmail in emails) {
        if (![self isEqualToString:otherEmail]) {
            NSString * otherUncheckedShortDisplayName = [otherEmail djlUncheckedShortDisplayName];
            if ([uncheckedShortDisplayName isEqualToString:otherUncheckedShortDisplayName]) {
                hasOther = YES;
                break;
            }
        }
    }
    if (hasOther) {
        return self;
    }
    else {
        return uncheckedShortDisplayName;
    }
}

static NSMutableArray * s_standardHostSuffixes  = nil;

static inline void _setupStandardHostSuffixes() {

    if (s_standardHostSuffixes != nil) {
        return;
    }

    s_standardHostSuffixes = [[NSMutableArray alloc] init];
    [s_standardHostSuffixes addObject:@"ac"];
    [s_standardHostSuffixes addObject:@"ae"];
    [s_standardHostSuffixes addObject:@"aero"];
    [s_standardHostSuffixes addObject:@"ag"];
    [s_standardHostSuffixes addObject:@"am"];
    [s_standardHostSuffixes addObject:@"asia"];
    [s_standardHostSuffixes addObject:@"at"];
    [s_standardHostSuffixes addObject:@"be"];
    [s_standardHostSuffixes addObject:@"biz"];
    [s_standardHostSuffixes addObject:@"bz"];
    [s_standardHostSuffixes addObject:@"cc"];
    [s_standardHostSuffixes addObject:@"ch"];
    [s_standardHostSuffixes addObject:@"co"];
    [s_standardHostSuffixes addObject:@"co.uk"];
    [s_standardHostSuffixes addObject:@"com"];
    [s_standardHostSuffixes addObject:@"com.fr"];
    [s_standardHostSuffixes addObject:@"cx"];
    [s_standardHostSuffixes addObject:@"cz"];
    [s_standardHostSuffixes addObject:@"de"];
    [s_standardHostSuffixes addObject:@"es"];
    [s_standardHostSuffixes addObject:@"eu"];
    [s_standardHostSuffixes addObject:@"fm"];
    [s_standardHostSuffixes addObject:@"fr"];
    [s_standardHostSuffixes addObject:@"gd"];
    [s_standardHostSuffixes addObject:@"gr"];
    [s_standardHostSuffixes addObject:@"gs"];
    [s_standardHostSuffixes addObject:@"hn"];
    [s_standardHostSuffixes addObject:@"ht"];
    [s_standardHostSuffixes addObject:@"hu"];
    [s_standardHostSuffixes addObject:@"im"];
    [s_standardHostSuffixes addObject:@"in"];
    [s_standardHostSuffixes addObject:@"info"];
    [s_standardHostSuffixes addObject:@"io"];
    [s_standardHostSuffixes addObject:@"it"];
    [s_standardHostSuffixes addObject:@"jobs"];
    [s_standardHostSuffixes addObject:@"jp"];
    [s_standardHostSuffixes addObject:@"ki"];
    [s_standardHostSuffixes addObject:@"kr"];
    [s_standardHostSuffixes addObject:@"la"];
    [s_standardHostSuffixes addObject:@"lc"];
    [s_standardHostSuffixes addObject:@"li"];
    [s_standardHostSuffixes addObject:@"lt"];
    [s_standardHostSuffixes addObject:@"lu"];
    [s_standardHostSuffixes addObject:@"ly"];
    [s_standardHostSuffixes addObject:@"md"];
    [s_standardHostSuffixes addObject:@"me"];
    [s_standardHostSuffixes addObject:@"mn"];
    [s_standardHostSuffixes addObject:@"mobi"];
    [s_standardHostSuffixes addObject:@"ms"];
    [s_standardHostSuffixes addObject:@"mu"];
    [s_standardHostSuffixes addObject:@"mx"];
    [s_standardHostSuffixes addObject:@"name"];
    [s_standardHostSuffixes addObject:@"net"];
    [s_standardHostSuffixes addObject:@"nf"];
    [s_standardHostSuffixes addObject:@"nl"];
    [s_standardHostSuffixes addObject:@"nu"];
    [s_standardHostSuffixes addObject:@"org"];
    [s_standardHostSuffixes addObject:@"pk"];
    [s_standardHostSuffixes addObject:@"pl"];
    [s_standardHostSuffixes addObject:@"ro"];
    [s_standardHostSuffixes addObject:@"ru"];
    [s_standardHostSuffixes addObject:@"sc"];
    [s_standardHostSuffixes addObject:@"se"];
    [s_standardHostSuffixes addObject:@"sg"];
    [s_standardHostSuffixes addObject:@"sh"];
    [s_standardHostSuffixes addObject:@"si"];
    [s_standardHostSuffixes addObject:@"sk"];
    [s_standardHostSuffixes addObject:@"tc"];
    [s_standardHostSuffixes addObject:@"tel"];
    [s_standardHostSuffixes addObject:@"tk"];
    [s_standardHostSuffixes addObject:@"tv"];
    [s_standardHostSuffixes addObject:@"us"];
    [s_standardHostSuffixes addObject:@"xxx"];
}

- (BOOL) _hasHostSuffix:(NSString *)hostname
{
    BOOL result = NO;
    _setupStandardHostSuffixes();
    @autoreleasepool {
        for(NSString * suffix in s_standardHostSuffixes) {
            if ([hostname hasSuffix:[@"." stringByAppendingString:suffix]]) {
                result = YES;
                break;
            }
        }
    }

    return result;
}

- (NSURL *) djlURL
{
    NSURL * url = [NSURL URLWithString:self];
    if ([url scheme] != nil) {
        return url;
    }

    NSArray * components = [self componentsSeparatedByString:@"/"];
    if ([components count] == 0) {
        return nil;
    }
    url = [NSURL URLWithString:[@"http://" stringByAppendingString:self]];
    if (![self _hasHostSuffix:[url host]] && ![[[url host] lowercaseString] hasPrefix:@"www."]) {
        return nil;
    }
    return url;
}

@end
