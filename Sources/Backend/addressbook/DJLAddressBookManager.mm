// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAddressBookManager.h"

#import <AddressBook/AddressBook.h>

#import "NSString+DJL.h"
#import "DJLContact.h"
#import "CGImage+DJL.h"
#import "DJLSingleton.h"
#import "DJLAssert.h"
#import "DJLPathManager.h"
#import "MCOAddress+DJL.h"
#import "DJLLog.h"

#include "HMSearchIndex.h"
#include "Hermes.h"

using namespace mailcore;
using namespace hermes;

@interface DJLAddressBookManager ()

- (void) _accountManagerHasNewContacts:(Account *)account;

@end

class DJLAddressBookManagerCallback : public Object, public OperationCallback, public AccountManagerObserver {
public:
    DJLAddressBookManagerCallback(DJLAddressBookManager * manager)
    {
        mManager = manager;
    }

    virtual ~DJLAddressBookManagerCallback()
    {
    }

    virtual void accountManagerHasNewContacts(AccountManager * manager, Account * account)
    {
        [mManager _accountManagerHasNewContacts:account];
    }

private:
    __weak DJLAddressBookManager * mManager;
};

@implementation DJLAddressBookManager {
    ABAddressBook * _addressBook;
    dispatch_queue_t _dispatchQueue;
    BOOL _loaded;
    DJLContactNameOrder _defaultNameOrder;
    SearchIndex * _index;
    NSDictionary * _peopleDict;
    NSArray * _contacts;
    NSArray * _emailContacts;
    NSArray * _groups;
    NSSet * _indexedEmailSet;
    DJLAddressBookManagerCallback * _callback;
    BOOL _scheduledIndexContacts;
    BOOL _indexingContacts;
    BOOL _pendingIndexContacts;
    BOOL _scheduledSaveLastAddresses;
    BOOL _savingLastAddresses;
    BOOL _pendingSaveLastAddresses;
    BOOL _firstIndexDone;
    NSMutableDictionary * _lastUse;
    NSMutableDictionary * _groupLastUse;
    NSMutableSet * _recentAddresses;
    pthread_mutex_t _lock;
    unsigned int _count;
}

+ (DJLAddressBookManager *) sharedManager
{
    DJLSINGLETON(DJLAddressBookManager);
}

- (id) init
{
    self = [super init];

    pthread_mutex_init(&_lock, NULL);

    _callback = new DJLAddressBookManagerCallback(self);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_changed) name:kABDatabaseChangedExternallyNotification object:nil];

    _dispatchQueue = dispatch_queue_create("DJLAddressBoookManager", DISPATCH_QUEUE_SERIAL);
    _loaded = NO;
    _defaultNameOrder = DJLContactNameOrderFirstNameFirst;

    AccountManager::sharedManager()->addObserver(_callback);
    _lastUse = [[NSMutableDictionary alloc] init];
    _groupLastUse = [[NSMutableDictionary alloc] init];
    _recentAddresses = [[NSMutableSet alloc] init];

    [self _loadLastAddresses];

    return self;
}

- (void) dealloc
{
    pthread_mutex_destroy(&_lock);
    MC_SAFE_RELEASE(_callback);
}

- (void) _changed
{
    LOG_ERROR("kABDatabaseChangedExternallyNotification changed");
    [self _scheduleIndexContacts];
}

- (NSArray *) _personsForGroup:(ABGroup *)group
{
    NSMutableArray * persons = [NSMutableArray array];
    for(ABRecord * member in [group members]) {
        if ([member isKindOfClass:[ABGroup class]]) {
            [persons addObject:[self _personsForGroup:(ABGroup *) member]];
        }
        else if ([member isKindOfClass:[ABPerson class]]) {
            [persons addObject:member];
        }
    }
    return persons;
}

- (void) loadImageForEmail:(NSString *)email size:(int)size loaded:(void (^)(CGImageRef))loaded
{
    email = [email lowercaseString];

    if (!_loaded) {
        loaded(nil);
        return;
    }

    NSString * uniqueID = [_peopleDict objectForKey:email];
    dispatch_async(_dispatchQueue, ^{
        ABPerson * person = nil;
        if (uniqueID != nil) {
            person = (ABPerson *) [_addressBook recordForUniqueId:uniqueID];
        }
        NSData * data = nil;
        if ([person isKindOfClass:[ABPerson class]]) {
            data = [person imageData];
        }
        CGImageRef image = NULL;
        if (data != NULL) {
            image = DJLCGImageCreateWithData((__bridge CFDataRef) data, size);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            loaded(image);
            if (image != NULL) {
                CGImageRelease(image);
            }
        });
    });
}

- (NSArray *) peopleWithPrefix:(NSString *)prefix
{
    if (!_loaded) {
        return nil;
    }

    NSArray * keywords = [prefix componentsSeparatedByString:@" "];
    Array * mcKeywords = MCO_FROM_OBJC(Array, keywords);
    IndexSet * result = NULL;
    for(unsigned int i = 0 ; i < mcKeywords->count() ; i ++) {
        IndexSet * partialResult = _index->search((String *) mcKeywords->objectAtIndex(i));
        if (result == NULL) {
            result = partialResult;
        }
        else {
            result->intersectsIndexSet(partialResult);
        }
    }

    if (result == NULL) {
        return nil;
    }

    NSMutableArray * searchResult = [NSMutableArray array];
    mc_foreachindexset(idx, result) {
        switch (idx % 3) {
            case 0:
            {
                DJLContact * contact = [_contacts objectAtIndex:idx / 3];
                NSDictionary * matchedContact = @{@"contact": contact, @"match": @"name"};
                [searchResult addObject:matchedContact];
                break;
            }

            case 1:
            {
                NSDictionary * item = [_emailContacts objectAtIndex:(idx - 1) / 3];
                [searchResult addObject:item];
                break;
            }

            case 2:
            {
                NSDictionary * item = [_groups objectAtIndex:(idx - 2) / 3];
                [searchResult addObject:item];
                break;
            }
        }
    }

    return searchResult;
}

- (DJLContactNameOrder) defaultNameOrder
{
    pthread_mutex_lock(&_lock);
    DJLContactNameOrder result = _defaultNameOrder;
    pthread_mutex_unlock(&_lock);
    return result;
}

- (NSString *) uniqueIdForEmail:(NSString *)email
{
    return [_peopleDict objectForKey:email];
}

- (BOOL) hasPersonWithEmail:(NSString *)email
{
    return [_peopleDict objectForKey:email] != nil;
}

- (void) addAddress:(MCOAddress *)address withCompletion:(DJLAddAddressCompletionBlock)completionBlock
{
    MCOAddress * copy = [address copy];
    dispatch_async(_dispatchQueue, ^{
        NSString * uniqueId = [DJLAddressBookManager _addToAddressBook:copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock != NULL) {
                completionBlock(uniqueId);
            }
        });
    });
}

+ (NSString *) _addToAddressBook:(MCOAddress *)address
{
    ABPerson *abPerson;
    // Try to add this address to a card that matches the first and last name exactly.
    abPerson = [self _addEmailAddressToCardMatchingFirstAndLastNameFromFormattedAddress:address];
    if (!abPerson) {
        // Otherwise if we found either zero or more than one, add a new card.
        abPerson = [self _addAddressToAddressBook:address];
    }
    return [abPerson uniqueId];
}

+ (NSArray *) _addressBookRecordsForFirstName:(NSString *)firstName lastName:(NSString *)lastName
{
    NSArray *foundRecords = nil;

    if (firstName && lastName && ![firstName isEqualToString:@""] && ![lastName isEqualToString:@""]) {
        ABSearchElement *firstNameSearchElement, *lastNameSearchElement;
        ABSearchElement *combinedSearchElement;

        firstNameSearchElement = [ABPerson searchElementForProperty:kABFirstNameProperty label:nil key:nil value:firstName comparison:kABEqualCaseInsensitive];
        lastNameSearchElement = [ABPerson searchElementForProperty:kABLastNameProperty label:nil key:nil value:lastName comparison:kABEqualCaseInsensitive];
        combinedSearchElement = [ABSearchElement searchElementForConjunction:kABSearchAnd children:[NSArray arrayWithObjects:firstNameSearchElement, lastNameSearchElement, nil]];

        foundRecords = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:combinedSearchElement];
    }

    return foundRecords;
}

+ (ABPerson *) _addEmailAddressToCardMatchingFirstAndLastNameFromFormattedAddress:(MCOAddress *)address
{
    ABPerson *abPerson = nil;
    NSString *firstName, *lastName, *middleName, *extension;
    NSArray *existingCards;

    // Look up address based on first and last name.
    [address djlFirstName:&firstName middleName:&middleName lastName:&lastName extension:&extension];
    existingCards = [self _addressBookRecordsForFirstName:firstName lastName:lastName];

    // If we find exactly one then add this email address to that card
    if (1 == [existingCards count]) {
        ABMultiValue *emails;
        ABMutableMultiValue *newEmails;
        NSString *email = [address mailbox];
        NSString *newLabel = kABEmailHomeLabel;

        // Get the existing value for the email property, if any
        abPerson = [existingCards objectAtIndex:0];
        emails = [abPerson valueForProperty:kABEmailProperty];
        if (emails) {
            newEmails = [emails mutableCopy];
        } else {
            newEmails = [[ABMutableMultiValue alloc] init];
        }

        // Figure out what labels have been set already
        NSUInteger index;
        NSUInteger count = [newEmails count];
        BOOL hasWork = NO, hasHome = NO;

        for (index = 0; index < count; index++) {
            NSString *label = [newEmails labelAtIndex:index];
            if ([label isEqualToString:kABEmailWorkLabel]) {
                hasWork = YES;
            } else if ([label isEqualToString:kABEmailHomeLabel]) {
                hasHome = YES;
            }
        }

        if (hasHome && !hasWork) {
            newLabel = kABEmailWorkLabel;
        } else if (hasHome && hasWork) {
            newLabel = kABOtherLabel;
        }

        // Set the new property on the card and save it.
        [newEmails addValue:email withLabel:newLabel];
        [abPerson setValue:newEmails forProperty:kABEmailProperty];
        [[ABAddressBook sharedAddressBook] save];
    }

    return abPerson;
}

+ (ABPerson *) _addAddressToAddressBook:(MCOAddress *)address {
    ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
    ABPerson *addressBookRecord = [self _personWithAddress:address];
    [addressBook addRecord:addressBookRecord];
    [addressBook save];
    return addressBookRecord;
}

+ (ABPerson *) _personWithAddress:(MCOAddress *)address
{
    ABPerson *addressBookRecord = [[ABPerson alloc] init];
    ABMutableMultiValue *multiValue = [[ABMutableMultiValue alloc] init];
    if ([address mailbox] != nil) {
        [multiValue addValue:[address mailbox] withLabel:kABEmailWorkLabel];
    }
    [addressBookRecord setValue:multiValue forProperty:kABEmailProperty];

    NSString *firstName, *middleName, *lastName, *extension;
    [address djlFirstName:&firstName middleName:&middleName lastName:&lastName extension:&extension];
    if (firstName && ![firstName isEqualToString:@""]) {
        [addressBookRecord setValue:firstName forProperty:kABFirstNameProperty];
    }
    if (middleName && ![middleName isEqualToString:@""]) {
        [addressBookRecord setValue:middleName forProperty:kABMiddleNameProperty];
    }
    if (lastName && ![lastName isEqualToString:@""]) {
        [addressBookRecord setValue:lastName forProperty:kABLastNameProperty];
    }
    if (extension && ![extension isEqualToString:@""]) {
        [addressBookRecord setValue:extension forProperty:kABSuffixProperty];
    }
    return addressBookRecord;
}

- (void) _accountManagerHasNewContacts:(Account *)account
{
    int count = 0;
    if (account->addresses() != NULL) {
        count = account->addresses()->count();
    }
    //NSLog(@"account %s has new contacts: %i contacts", MCUTF8(account->accountInfo()->email()), count);
    [self _scheduleIndexContacts];
}

- (void) _scheduleIndexContacts
{
    if (_indexingContacts) {
        _pendingIndexContacts = YES;
        return;
    }

    if (_scheduledIndexContacts) {
        return;
    }
    _scheduledIndexContacts = YES;
    [self performSelector:@selector(_indexContacts) withObject:nil afterDelay:1.0];
}

- (void) _indexContacts
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_indexContacts) object:nil];
    _scheduledIndexContacts = NO;

    _indexingContacts = YES;

    NSArray * recentAddresses = [_recentAddresses allObjects];

    int totalCount = 0;
    Array * contactsArrays = new Array();
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        if (account->addresses() != NULL) {
            contactsArrays->addObject(account->addresses());
            totalCount += account->addresses()->count();
        }
    }
    LOG_ERROR("indexing %i contacts", totalCount);

    NSTimeInterval timeStart = [NSDate timeIntervalSinceReferenceDate];
    __weak DJLAddressBookManager * weakSelf = self;
    dispatch_async(_dispatchQueue, ^{
        DJLAddressBookManager * strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        @autoreleasepool {
            if (strongSelf->_addressBook == nil) {
                strongSelf->_addressBook = [ABAddressBook addressBook];
            }
            NSInteger defaultNameOrdering = [strongSelf->_addressBook defaultNameOrdering];
            pthread_mutex_lock(&strongSelf->_lock);
            if (defaultNameOrdering == kABFirstNameFirst) {
                strongSelf->_defaultNameOrder = DJLContactNameOrderFirstNameFirst;
            }
            else {
                strongSelf->_defaultNameOrder = DJLContactNameOrderLastNameFirst;
            }
            pthread_mutex_unlock(&strongSelf->_lock);

            NSMutableDictionary * peopleDict = [[NSMutableDictionary alloc] init];
            NSMutableArray * contacts = [[NSMutableArray alloc] init];
            NSMutableArray * emailContacts = [[NSMutableArray alloc] init];
            NSMutableArray * groups = [[NSMutableArray alloc] init];
            NSMutableDictionary * contactDict = [[NSMutableDictionary alloc] init];

            NSString * folder = [[DJLPathManager sharedManager] applicationDataFolder];
            folder = [folder stringByAppendingPathComponent:@"AddressBook"];
            [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];

            NSString * filename = [folder stringByAppendingPathComponent:@"adressbook.index.tmp.journal"];
            [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
            filename = [folder stringByAppendingPathComponent:@"adressbook.index.tmp"];
            [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
            SearchIndex * index = new SearchIndex(MCO_FROM_OBJC(String, filename));
            index->open();
            index->beginTransaction();

            // index address book
            NSArray * people = [strongSelf->_addressBook people];
            NSMutableSet * existingEmails = [[NSMutableSet alloc] init];;
            for(ABPerson * person in people) {
                DJLContact * contact = [[DJLContact alloc] init];
                [contact importABPerson:person existingEmails:existingEmails];
                if ([[contact emails] count] == 0) {
                    continue;
                }

                for(NSString * email in [contact emails]) {
                    [existingEmails addObject:[email lowercaseString]];
                }
                [contactDict setObject:contact forKey:[person uniqueId]];

                unsigned int idx = (unsigned int) [contacts count];
                [contacts addObject:contact];
                NSMutableString * stringToIndex = [NSMutableString string];
                if ([contact firstName] != nil) {
                    [stringToIndex appendString:[contact firstName]];
                }
                [stringToIndex appendString:@" "];
                if ([contact middleName] != nil) {
                    [stringToIndex appendString:[contact middleName]];
                }
                [stringToIndex appendString:@" "];
                if ([contact lastName] != nil) {
                    [stringToIndex appendString:[contact lastName]];
                }
                [stringToIndex appendString:@" "];
                if ([contact companyName] != nil) {
                    [stringToIndex appendString:[contact companyName]];
                }

                index->setStringForID(idx * 3, [stringToIndex mco_mcString]);
                for(NSString * email in [contact emails]) {
                    if ([peopleDict objectForKey:[email lowercaseString]] != nil) {
                        continue;
                    }
                    NSDictionary * matchedContact = @{@"contact": contact, @"email": email};
                    idx = (unsigned int) [emailContacts count];
                    [emailContacts addObject:matchedContact];
                    index->setStringsForID(idx * 3 + 1, Array::arrayWithObject([email mco_mcString]));
                    [peopleDict setObject:[person uniqueId] forKey:[email lowercaseString]];
                }
            }

            // index groups
            NSArray * abGroups = [strongSelf->_addressBook groups];
            for(ABGroup * group in abGroups) {
                NSArray * persons = [strongSelf _personsForGroup:group];
                NSMutableArray * members = [NSMutableArray array];
                for(ABPerson * person in persons) {
                    DJLContact * contact = [contactDict objectForKey:[person uniqueId]];
                    if (contact == nil) {
                        continue;
                    }
                    [members addObject:contact];
                }

                NSString * groupName = [group valueForProperty:kABGroupNameProperty];
                if (groupName == nil) {
                    groupName = @"Unnamed group";
                }
                NSDictionary * matchedGroup = @{@"group": groupName, @"members": members};
                unsigned int idx = (unsigned int) [groups count];
                [groups addObject:matchedGroup];
                index->setStringsForID(idx * 3 + 2, Array::arrayWithObject([groupName mco_mcString]));
                //NSLog(@"index: %i %@", idx, groupName);
            }

            // index recipients of accounts
            mc_foreacharray(Array, addresses, contactsArrays) {
                mc_foreacharray(Address, address, addresses) {
                    DJLContact * contact = [[DJLContact alloc] init];
                    [contact importAddress:address];
                    NSString * email = [contact emails][0];
                    if ([existingEmails containsObject:[email lowercaseString]]) {
                        continue;
                    }
                    [existingEmails addObject:[email lowercaseString]];
                    unsigned int idx = (unsigned int) [contacts count];
                    [contacts addObject:contact];
                    if (address->displayName() != NULL) {
                        index->setStringForID(idx * 3, address->displayName());
                    }
                    NSDictionary * matchedContact = @{@"contact": contact, @"email": email};
                    idx = (unsigned int) [emailContacts count];
                    [emailContacts addObject:matchedContact];
                    index->setStringsForID(idx * 3 + 1, Array::arrayWithObject([email mco_mcString]));
                }
            }

            // index recent address
            for(MCOAddress * address in recentAddresses) {
                DJLContact * contact = [[DJLContact alloc] init];
                Address * mcAddress = MCO_FROM_OBJC(Address, address);
                [contact importAddress:mcAddress];
                NSString * email = [contact emails][0];
                if ([existingEmails containsObject:[email lowercaseString]]) {
                    continue;
                }
                [existingEmails addObject:[email lowercaseString]];
                unsigned int idx = (unsigned int) [contacts count];
                [contacts addObject:contact];
                if (mcAddress->displayName() != NULL) {
                    index->setStringForID(idx * 3, mcAddress->displayName());
                }
                NSDictionary * matchedContact = @{@"contact": contact, @"email": email};
                idx = (unsigned int) [emailContacts count];
                [emailContacts addObject:matchedContact];
                index->setStringsForID(idx * 3 + 1, Array::arrayWithObject([email mco_mcString]));
            }

            index->commitTransaction();
            index->close();
            MC_SAFE_RELEASE(index);

            contactsArrays->release();

            dispatch_async(dispatch_get_main_queue(), ^{

                if (_index != NULL) {
                    _index->close();
                    MC_SAFE_RELEASE(_index);
                }
                NSString * finalFilename = [folder stringByAppendingPathComponent:@"adressbook.index"];
                [[NSFileManager defaultManager] removeItemAtPath:finalFilename error:NULL];
                [[NSFileManager defaultManager] moveItemAtPath:filename toPath:finalFilename error:NULL];
                NSString * tmp = [folder stringByAppendingPathComponent:@"adressbook.index.tmp.journal"];
                [[NSFileManager defaultManager] removeItemAtPath:tmp error:NULL];
                tmp = [folder stringByAppendingPathComponent:@"adressbook.index.journal"];
                [[NSFileManager defaultManager] removeItemAtPath:tmp error:NULL];
                _index = new SearchIndex(MCO_FROM_OBJC(String, finalFilename));
                _index->open();

                _loaded = YES;
                _peopleDict = peopleDict;
                _contacts = contacts;
                _emailContacts = emailContacts;
                _groups = groups;
                _indexedEmailSet = existingEmails;
                _count = (unsigned int) [_contacts count];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:DJLADDRESSBOOKMANAGER_LOADED object:strongSelf];
                
                //NSLog(@"Indexing address book time: %g", [NSDate timeIntervalSinceReferenceDate] - timeStart);
                LOG_ERROR("Indexing address book time: %g", [NSDate timeIntervalSinceReferenceDate] - timeStart);
                
                _indexingContacts = NO;
                
                if (_pendingIndexContacts) {
                    _pendingIndexContacts = NO;
                    [self _scheduleIndexContacts];
                }
            });
        }
    });
}

- (void) _loadLastAddresses
{
    __weak DJLAddressBookManager * weakSelf = self;
    dispatch_async(_dispatchQueue, ^{
        DJLAddressBookManager * strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        NSArray * recentAddressesFromDisk = nil;
        NSDictionary * lastUseFromDisk = nil;
        NSDictionary * groupLastUseFromDisk = nil;
        NSString * folder = [[DJLPathManager sharedManager] applicationDataFolder];
        folder = [folder stringByAppendingPathComponent:@"AddressBook"];
        NSString * filename = [folder stringByAppendingPathComponent:@"last-addresses.json"];

        Data * data = Data::dataWithContentsOfFile([filename mco_mcString]);
        if (data != NULL) {
            HashMap * readInfo = (HashMap *) hermes::objectWithFastSerializedData(data);
            if (readInfo != NULL) {
                Array * mcRecentAddresses = (Array *) readInfo->objectForKey(MCSTR("recent"));
                HashMap * mcLastUse = (HashMap *) readInfo->objectForKey(MCSTR("use"));
                HashMap * mcGroupLastUse = (HashMap *) readInfo->objectForKey(MCSTR("groupUse"));
                recentAddressesFromDisk = MCO_TO_OBJC(mcRecentAddresses);
                lastUseFromDisk = MCO_TO_OBJC(mcLastUse);
                groupLastUseFromDisk = MCO_TO_OBJC(mcGroupLastUse);
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (recentAddressesFromDisk != nil && lastUseFromDisk != nil) {
                [strongSelf->_recentAddresses addObjectsFromArray:recentAddressesFromDisk];
                [strongSelf->_lastUse addEntriesFromDictionary:lastUseFromDisk];
                [strongSelf->_groupLastUse addEntriesFromDictionary:groupLastUseFromDisk];
            }

            [strongSelf _scheduleIndexContacts];
        });
    });
}

- (void) _scheduleSaveLastAddresses
{
    if (_savingLastAddresses) {
        _pendingSaveLastAddresses = YES;
        return;
    }

    if (_scheduledSaveLastAddresses) {
        return;
    }
    _scheduledSaveLastAddresses = YES;
    [self performSelector:@selector(_saveLastAddresses) withObject:nil afterDelay:1.0];
}

- (void) _saveLastAddresses
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_saveLastAddresses) object:nil];
    _scheduledSaveLastAddresses = NO;

    _savingLastAddresses = YES;

    NSArray * recentAddresses = [_recentAddresses allObjects];
    NSDictionary * lastUse = [_lastUse copy];;
    NSDictionary * groupLastUse = [_groupLastUse copy];;

    __weak DJLAddressBookManager * weakSelf = self;
    dispatch_async(_dispatchQueue, ^{
        DJLAddressBookManager * strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        NSString * folder = [[DJLPathManager sharedManager] applicationDataFolder];
        folder = [folder stringByAppendingPathComponent:@"AddressBook"];
        NSString * filename = [folder stringByAppendingPathComponent:@"last-addresses.json"];

        // save recent addresses
        HashMap * infoToWrite = HashMap::hashMap();
        infoToWrite->setObjectForKey(MCSTR("recent"), MCO_FROM_OBJC(Array, recentAddresses));
        infoToWrite->setObjectForKey(MCSTR("use"), MCO_FROM_OBJC(HashMap, lastUse));
        infoToWrite->setObjectForKey(MCSTR("groupUse"), MCO_FROM_OBJC(HashMap, groupLastUse));
        Data * data = hermes::fastSerializedData(infoToWrite);
        //Data * data = JSON::objectToJSONData(infoToWrite->serializable());
        data->writeToFile([filename mco_mcString]);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!strongSelf->_firstIndexDone) {
                strongSelf->_firstIndexDone = YES;
                [strongSelf _scheduleIndexContacts];
            }

            strongSelf->_savingLastAddresses = NO;

            if (strongSelf->_pendingSaveLastAddresses) {
                strongSelf->_pendingSaveLastAddresses = NO;
                [strongSelf _scheduleSaveLastAddresses];
            }
        });
    });
}

- (void) useAddress:(MCOAddress *)address
{
    if ([address mailbox] == nil) {
        return;
    }

    time_t timestamp = time(NULL);
    [_lastUse setObject:[NSNumber numberWithLongLong:timestamp] forKey:[address mailbox]];
#warning recent addresses should be scoped to 50?

    if (![_indexedEmailSet containsObject:[address mailbox]]) {
        [_recentAddresses addObject:address];
        [self _scheduleIndexContacts];
    }
    [self _scheduleSaveLastAddresses];
}

- (time_t) lastUseDateForEmail:(NSString *)email
{
    NSNumber * nbTimestamp = [_lastUse objectForKey:email];
    if (nbTimestamp == nil) {
        return 0;
    }
    return [nbTimestamp longLongValue];
}

- (void) useGroup:(NSString *)groupName
{
    time_t timestamp = time(NULL);
    [_groupLastUse setObject:[NSNumber numberWithLongLong:timestamp] forKey:groupName];
    [self _scheduleSaveLastAddresses];
}

- (time_t) lastUseDateForGroup:(NSString *)groupName
{
    NSNumber * nbTimestamp = [_groupLastUse objectForKey:groupName];
    if (nbTimestamp == nil) {
        return 0;
    }
    return [nbTimestamp longLongValue];
}

- (unsigned int) count
{
    return _count;
}

@end
