// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "MCOAddress+DJL.h"

#import <AddressBook/AddressBook.h>

#import "NSString+DJL.h"

@implementation MCOAddress (DJL)

- (void) djlFirstName:(NSString * __autoreleasing *)firstName middleName:(NSString * __autoreleasing *)middleName lastName:(NSString * __autoreleasing *)lastName extension:(NSString * __autoreleasing *)extension
{
    NSString *fullName, *component;
    NSArray *commaComponents, *rawComponents;
    NSMutableArray *components;
    NSUInteger componentIndex, numberOfComponents;

    fullName = [self displayName];

    if (!fullName) {
        *firstName = nil;
        *middleName = nil;
        *lastName = nil;
        *extension = nil;
        return;
    }

    // If the name is in 'last, first' format, turn it into 'first last'
    commaComponents = [fullName componentsSeparatedByString:@","];
    if (([commaComponents count] > 1) && ![[NSString djlNameExtensions] containsObject:[[[commaComponents lastObject] djlTrimCommasSpacesQuotes] lowercaseString]]) {
        if ([commaComponents count] > 2) {
            // I have no idea what we should do in this case, so we'll just ignore
            // the problem and act as though there was just one comma.
            NSMutableArray *allButLastComponent;

            allButLastComponent = [commaComponents mutableCopy];
            [allButLastComponent removeLastObject];
            fullName = [NSString stringWithFormat:@"%@ %@", [commaComponents lastObject], [allButLastComponent componentsJoinedByString:@" "]];
        } else {
            fullName = [NSString stringWithFormat:@"%@ %@", [commaComponents objectAtIndex:1], [commaComponents objectAtIndex:0]];
        }
    }

    // separate into words, delete any empty words and strip off spaces and commas
    rawComponents = [fullName componentsSeparatedByString:@" "];
    numberOfComponents = [rawComponents count];
    components = [NSMutableArray arrayWithCapacity:numberOfComponents];

    for (componentIndex = 0; componentIndex < numberOfComponents; componentIndex++) {
        component = [rawComponents objectAtIndex:componentIndex];
        if (![component isEqualToString:@""]) {
            [components addObject:[component djlTrimCommasSpacesQuotes]];
        }
    }

    // Now identify first, last, middle, and extension
    switch ([components count]) {
        case 0:
            *firstName = nil;
            *middleName = nil;
            *lastName = nil;
            *extension = nil;
        case 1:
            *firstName = fullName;
            *middleName = nil;
            *lastName = nil;
            *extension = nil;
            break;
        case 2:
            *firstName = [components objectAtIndex:0];
            *middleName = nil;
            *lastName = [components objectAtIndex:1];
            *extension = nil;
            break;
        default:
        {
            NSString *lastComponent, *combinedComponents;
            int componentIndex;

            // look for an extension
            lastComponent = [components lastObject];
            if ([[NSString djlNameExtensions] containsObject:[lastComponent lowercaseString]]) {
                *extension = lastComponent;
                [components removeLastObject];
            } else {
                *extension = nil;
            }

            // consolidate surname(s) that have more than one word
            componentIndex = 1;
            while (componentIndex < [components count] - 1) {
                component = [components objectAtIndex:componentIndex];
                if ([[NSString djlPartialSurnames] containsObject:[component lowercaseString]]) {
                    combinedComponents = [NSString stringWithFormat:@"%@ %@", component, [components objectAtIndex:componentIndex+1]];
                    [components replaceObjectAtIndex:componentIndex withObject:combinedComponents];
                    [components removeObjectAtIndex:componentIndex+1];
                }
                componentIndex++;
            }

            // pick off the last name
            numberOfComponents = [components count];
            if (numberOfComponents > 3) {
                component = [components objectAtIndex:numberOfComponents-2];
                if (![component djlAppearsToBeAnInitial]) {
                    lastComponent = [components lastObject];
                    *lastName = [NSString stringWithFormat:@"%@ %@", component, lastComponent];
                    [components removeLastObject];
                    [components removeLastObject];
                } else {   // second-to-last component does appear to be an initial
                    *lastName = [components lastObject];
                    [components removeLastObject];
                }
            } else {  // fewer than three components
                *lastName = [components lastObject];
                [components removeLastObject];
            }

            // pick off the first name
            *firstName = [components objectAtIndex:0];
            [components removeObjectAtIndex:0];

            // whatever's left is the middle name
            if ([components count] > 0) {
                *middleName = [components componentsJoinedByString:@" "];
            } else {
                *middleName = nil;
            }
        }
    }

    // If the user puts surnames first, we have these reversed.
    // If we have a middle name or extension, this is probably way bogus.
    if (![MCOAddress _firstNameShouldBeFirst]) {
        NSString *swap;

        swap = *firstName;
        *firstName = *lastName;
        *lastName = swap;
    }
}

+ (BOOL) _firstNameShouldBeFirst {
    static int firstNameShouldBeFirst = -1;  // 0 = NO, 1 = YES, -1 = NOT YET SET
    if (firstNameShouldBeFirst == -1) {
        if ([[ABAddressBook sharedAddressBook] defaultNameOrdering] == kABLastNameFirst)
        {
            firstNameShouldBeFirst = 0;
        } else {
            firstNameShouldBeFirst = 1;
        }
    }
    return firstNameShouldBeFirst;
}

@end
