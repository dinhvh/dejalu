// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLContact.h"

#import "DJLAddressBookManager.h"

@implementation DJLContact {
    NSString * _firstName;
    NSString * _middleName;
    NSString * _lastName;
    NSString * _companyName;
    DJLContactNameOrder _nameOrder;
    NSArray * _emails;
    NSString * _abUniqueID;
    NSString * _displayName;
}

@synthesize firstName = _firstName;
@synthesize middleName = _middleName;
@synthesize lastName = _lastName;
@synthesize companyName = _companyName;
@synthesize nameOrder = _nameOrder;
@synthesize emails = _emails;
@synthesize abUniqueID = _abUniqueID;

- (NSString *) displayName
{
    if (_displayName != nil) {
        return _displayName;
    }
    DJLContactNameOrder nameOrder = _nameOrder;
    if (_nameOrder == DJLContactNameOrderDefault) {
#if !TARGET_OS_IPHONE
        nameOrder = [[DJLAddressBookManager sharedManager] defaultNameOrder];
#endif
    }
    if (([self firstName] == nil) && ([self lastName] == nil)) {
        return [self companyName];
    }
    if (nameOrder == DJLContactNameOrderFirstNameFirst) {
        return [self firstNameFirstDisplayName];
    }
    else {
        return [self lastNameFirstDisplayName];
    }
    return nil;
}

- (NSString *) firstNameFirstDisplayName
{
    NSMutableArray * nameComponents = [NSMutableArray array];
    if (_firstName != nil) {
        [nameComponents addObject:_firstName];
    }
    if (_middleName != nil) {
        [nameComponents addObject:_middleName];
    }
    if (_lastName != nil) {
        [nameComponents addObject:_lastName];
    }
    if ([nameComponents count] > 0) {
        return [nameComponents componentsJoinedByString:@" "];
    }
    else {
        return nil;
    }
}

- (NSString *) lastNameFirstDisplayName
{
    NSMutableArray * nameComponents = [NSMutableArray array];
    if (_lastName != nil) {
        [nameComponents addObject:_lastName];
    }
    if (_middleName != nil) {
        [nameComponents addObject:_middleName];
    }
    if (_firstName != nil) {
        [nameComponents addObject:_firstName];
    }
    if ([nameComponents count] > 0) {
        return [nameComponents componentsJoinedByString:@" "];
    }
    else {
        return nil;
    }
}

- (NSString *) shortFirstNameFirstDisplayName
{
    NSMutableArray * nameComponents = [NSMutableArray array];
    if (_firstName != nil) {
        [nameComponents addObject:_firstName];
    }
    if (_lastName != nil) {
        [nameComponents addObject:_lastName];
    }
    if ([nameComponents count] > 0) {
        return [nameComponents componentsJoinedByString:@" "];
    }
    else {
        return nil;
    }
}

- (NSString *) shortLastNameFirstDisplayName
{
    NSMutableArray * nameComponents = [NSMutableArray array];
    if (_lastName != nil) {
        [nameComponents addObject:_lastName];
    }
    if (_firstName != nil) {
        [nameComponents addObject:_firstName];
    }
    if ([nameComponents count] > 0) {
        return [nameComponents componentsJoinedByString:@" "];
    }
    else {
        return nil;
    }
}

#if !TARGET_OS_IPHONE
- (void) importABPerson:(ABPerson *)person existingEmails:(NSSet *)existingEmails
{
    NSString * firstName = [person valueForProperty:kABFirstNameProperty];
    NSString * lastName = [person valueForProperty:kABLastNameProperty];
    NSString * middleName = [person valueForProperty:kABMiddleNameProperty];
    ABMultiValue * multiValue = [person valueForProperty:kABEmailProperty];
    NSMutableArray * emails = [NSMutableArray array];
    for(unsigned int i = 0 ; i < [multiValue count] ; i ++) {
        NSString * email = [multiValue valueAtIndex:i];
        if ([existingEmails containsObject:[email lowercaseString]]) {
            continue;
        }
        [emails addObject:email];
    }
    NSString * companyName = [person valueForProperty:kABOrganizationProperty];
    int flags = [[person valueForProperty:kABPersonFlags] intValue];
    DJLContactNameOrder nameOrdering = DJLContactNameOrderDefault;
    if ((nameOrdering & kABFirstNameFirst) != 0) {
        nameOrdering = DJLContactNameOrderFirstNameFirst;
    }
    else if ((nameOrdering & kABLastNameFirst) != 0) {
        nameOrdering = DJLContactNameOrderLastNameFirst;
    }
    BOOL isCompany = (flags & kABShowAsCompany) != 0;
    
    [self setFirstName:firstName];
    [self setMiddleName:middleName];
    [self setLastName:lastName];
    if (isCompany) {
        [self setCompanyName:companyName];
    }
    [self setNameOrder:nameOrdering];
    [self setEmails:emails];
    [self setAbUniqueID:[person uniqueId]];
}
#endif

- (void) importAddress:(mailcore::Address *)address
{
    _displayName = MCO_TO_OBJC(address->displayName());
    [self setEmails:@[MCO_TO_OBJC(address->mailbox())]];
}

@end
