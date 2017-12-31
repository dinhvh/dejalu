// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

#import <AddressBook/AddressBook.h>

@interface DJLGroup : NSObject

@property (nonatomic, copy) NSString * name;
@property (nonatomic, copy) NSArray * abContactsUniqueIDs;

- (void) importABGroup:(ABGroup *)group;

@end
