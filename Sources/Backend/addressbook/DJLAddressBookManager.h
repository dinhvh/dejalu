// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <MailCore/MailCore.h>

#import "DJLContactTypes.h"

#define DJLADDRESSBOOKMANAGER_LOADED @"DJLADDRESSBOOKMANAGER_LOADED"

typedef void (^DJLAddAddressCompletionBlock)(NSString * personUniqueId);

@interface DJLAddressBookManager : NSObject

+ (DJLAddressBookManager *) sharedManager;
- (void) loadImageForEmail:(NSString *)email size:(int)size loaded:(void (^)(CGImageRef))loaded;
- (NSArray *) peopleWithPrefix:(NSString *)prefix;
- (DJLContactNameOrder) defaultNameOrder;
- (NSString *) uniqueIdForEmail:(NSString *)email;
- (BOOL) hasPersonWithEmail:(NSString *)email;
- (void) addAddress:(MCOAddress *)address withCompletion:(DJLAddAddressCompletionBlock)completionBlock;
- (void) useAddress:(MCOAddress *)address;
- (void) useGroup:(NSString *)groupName;

- (time_t) lastUseDateForEmail:(NSString *)email;
- (time_t) lastUseDateForGroup:(NSString *)groupName;

- (unsigned int) count;

@end
