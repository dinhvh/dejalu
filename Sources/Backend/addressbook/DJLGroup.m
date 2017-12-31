// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGroup.h"

@implementation DJLGroup {
    NSString * _name;
    NSArray * _abContactsUniqueIDs;
}

@synthesize name = _name;
@synthesize abContactsUniqueIDs = _abContactsUniqueIDs;

- (void) importABGroup:(ABGroup *)group
{
    // TODO: needs to be implemented.
}

@end
