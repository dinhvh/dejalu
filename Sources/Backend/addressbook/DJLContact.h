// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import "RHAddressBook/AddressBook.h"
#elif TARGET_OS_MAC
#import <AddressBook/AddressBook.h>
#endif

#include <MailCore/MailCore.h>

#import "DJLContactTypes.h"

@interface DJLContact : NSObject

@property (nonatomic, copy) NSString * firstName;
@property (nonatomic, copy) NSString * middleName;
@property (nonatomic, copy) NSString * lastName;
@property (nonatomic, copy) NSString * companyName;
@property (nonatomic, assign) DJLContactNameOrder nameOrder;
@property (nonatomic, copy) NSArray * emails;
@property (nonatomic, copy) NSString * abUniqueID;

- (NSString *) displayName;
- (NSString *) firstNameFirstDisplayName;
- (NSString *) lastNameFirstDisplayName;
- (NSString *) shortFirstNameFirstDisplayName;
- (NSString *) shortLastNameFirstDisplayName;

#if !TARGET_OS_IPHONE
- (void) importABPerson:(ABPerson *)person existingEmails:(NSSet *)existingEmails;
#endif

#ifdef __cplusplus
- (void) importAddress:(mailcore::Address *)address;
#endif

@end
