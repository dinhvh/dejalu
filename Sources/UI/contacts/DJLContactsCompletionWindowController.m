// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLContactsCompletionWindowController.h"

#import "DJLAddressBookManager.h"
#import "DJLEmailField.h"
#import "DJLContact.h"
#import <MailCore/MailCore.h>

@implementation DJLContactsCompletionWindowController {
    BOOL _acceptingCompletion;
    NSMutableArray * _contents;
}

- (id) init
{
    self = [super init];

    return self;
}

- (void) dealloc
{
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    NSDictionary * matchedContact = [_contents objectAtIndex:rowIndex];
    DJLContact * contact = matchedContact[@"contact"];
    NSString * groupName = matchedContact[@"group"];
    NSString * email = matchedContact[@"email"];
    if ([contact displayName] != nil) {
        return [NSString stringWithFormat:@"%@ <%@>", [contact displayName], email];
    }
    else if (groupName != nil) {
        return groupName;
    }
    else {
        return email;
    }
}

- (void) acceptCompletion
{
    NSInteger row;
    NSString * completion;

    if (_acceptingCompletion)
        return;
    
    row = [self selectedCompletionIndex];
    if (row >= [_contents count])
        return;
    
    _acceptingCompletion = YES;
    NSDictionary * matchedContact = [_contents objectAtIndex:row];

    NSString * groupName = matchedContact[@"group"];
    if (groupName != nil) {
        NSMutableArray * completionArray;

        [[DJLAddressBookManager sharedManager] useGroup:groupName];
        completionArray = [[NSMutableArray alloc] init];
        for(DJLContact * contact in matchedContact[@"members"]) {
            NSString * completion;

            MCOAddress * address = [MCOAddress addressWithDisplayName:[contact displayName] mailbox:[[contact emails] firstObject]];
            [[DJLAddressBookManager sharedManager] useAddress:address];
            completion = [address nonEncodedRFC822String];
            [completionArray addObject:completion];
        }
        [self replaceWithCompletion:[completionArray componentsJoinedByString:@"\t"]];

        [self cancelCompletion];
        _acceptingCompletion = NO;
    }

    DJLContact * contact = matchedContact[@"contact"];
    MCOAddress * address = [MCOAddress addressWithDisplayName:[contact displayName] mailbox:matchedContact[@"email"]];
    [[DJLAddressBookManager sharedManager] useAddress:address];
    completion = [address nonEncodedRFC822String];
    [self replaceWithCompletion:completion];

    [self cancelCompletion];
    _acceptingCompletion = NO;
}

- (NSUInteger) prepareTableViewContentsWithStringValue:(NSString *)value
{
    if ([value length] == 0) {
        _contents = [NSMutableArray array];
        return [_contents count];
    }

    NSString * valueWithoutSpace = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
    if ([valueWithoutSpace length] == 0) {
        _contents = [NSMutableArray array];
        return [_contents count];
    }

    NSArray * result = [[DJLAddressBookManager sharedManager] peopleWithPrefix:value];
    NSMutableArray * groups = [NSMutableArray array];

    NSMutableDictionary * contactDict = [NSMutableDictionary dictionary];
    for(NSDictionary * item in result) {
        DJLContact * contact = [item objectForKey:@"contact"];
        if (contact != nil) {
            NSString * key = [NSString stringWithFormat:@"%p", contact];
            NSMutableArray * array = [contactDict objectForKey:key];
            if (array == nil) {
                array = [NSMutableArray array];
                [contactDict setObject:array forKey:key];
            }
            [array addObject:item];
            continue;
        }
        NSString * groupName = [item objectForKey:@"group"];
        if (groupName != nil) {
            [groups addObject:item];
            continue;
        }
    }
    for(NSString * key in [contactDict allKeys]) {
        NSArray * array = [contactDict objectForKey:key];
        for(NSDictionary * item in array) {
            BOOL hasAllMatch = NO;
            if (item[@"match"] != nil) {
                // remove other keys.
                hasAllMatch = YES;
                DJLContact * contact = [item objectForKey:@"contact"];
                NSMutableArray * items = [NSMutableArray array];
                for(NSString * email in [contact emails]) {
                    [items addObject:@{@"contact": contact, @"email": email}];
                }
                [contactDict setObject:items forKey:key];
                break;
            }
        }
    }

    _contents = [NSMutableArray array];
    [_contents addObjectsFromArray:groups];
    for(NSString * key in contactDict) {
        NSArray * array = [contactDict objectForKey:key];
        for(NSDictionary * item in array) {
            [_contents addObject:item];
        }
    }
    [_contents sortUsingComparator:^NSComparisonResult(NSDictionary * item1, NSDictionary * item2) {
        NSString * groupName1 = [item1 objectForKey:@"group"];
        NSString * groupName2 = [item2 objectForKey:@"group"];
        NSString * email1 = [item1 objectForKey:@"email"];
        NSString * email2 = [item2 objectForKey:@"email"];
        time_t lastUse1 = 0;
        time_t lastUse2 = 0;
        if (groupName1 != nil) {
            lastUse1 = [[DJLAddressBookManager sharedManager] lastUseDateForGroup:groupName1];
        }
        if (groupName2 != nil) {
            lastUse2 = [[DJLAddressBookManager sharedManager] lastUseDateForGroup:groupName2];
        }
        if (email1 != nil) {
            lastUse1 = [[DJLAddressBookManager sharedManager] lastUseDateForEmail:email1];
        }
        if (email2 != nil) {
            lastUse2 = [[DJLAddressBookManager sharedManager] lastUseDateForEmail:email2];
        }
        if (lastUse1 > lastUse2) {
            return NSOrderedAscending;
        }
        else if (lastUse1 == lastUse2) {
            NSString * displayName1 = nil;
            if (email1 != nil) {
                DJLContact * contact = [item1 objectForKey:@"contact"];
                displayName1 = [contact displayName];
                if (displayName1 == nil) {
                    displayName1 = email1;
                }
            }
            else {
                displayName1 = groupName1;
            }
            NSString * displayName2 = nil;
            if (email2 != nil) {
                DJLContact * contact = [item2 objectForKey:@"contact"];
                displayName2 = [contact displayName];
                if (displayName2 == nil) {
                    displayName2 = email2;
                }
            }
            else {
                displayName1 = groupName1;
            }
            return [displayName1 caseInsensitiveCompare:displayName2];
        }
        else {
            return NSOrderedDescending;
        }
    }];

    return [_contents count];
}

@end
