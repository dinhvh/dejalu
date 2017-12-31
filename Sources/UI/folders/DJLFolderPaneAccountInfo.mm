// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLFolderPaneAccountInfo.h"

#include "Hermes.h"

#import "DJLFolderPaneFolderInfo.h"
#import "DJLFolderPaneFoldersDisclosureInfo.h"

using namespace hermes;
using namespace mailcore;

@implementation DJLFolderPaneAccountInfo {
    UnifiedAccount * _unifiedAccount;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_unifiedAccount);
}

- (hermes::UnifiedAccount *) unifiedAccount
{
    return _unifiedAccount;
}

- (void) setUnifiedAccount:(hermes::UnifiedAccount *)unifiedAccount
{
    MC_SAFE_REPLACE_RETAIN(UnifiedAccount, _unifiedAccount, unifiedAccount);
}

static int compareFoldersWithScore(void * a, void * b, void * context)
{
    NSDictionary * foldersOrderScore = (__bridge NSDictionary *) context;
    String * s_a = (String *) a;
    String * s_b = (String *) b;

    int score_a = 100;
    int score_b = 100;

    if (foldersOrderScore[MCO_TO_OBJC(s_a)] != nil) {
        score_a = [(NSNumber *) foldersOrderScore[MCO_TO_OBJC(s_a)] intValue];
    }
    if (foldersOrderScore[MCO_TO_OBJC(s_b)] != nil) {
        score_b = [(NSNumber *) foldersOrderScore[MCO_TO_OBJC(s_b)] intValue];
    }

    if (score_a != score_b) {
        return score_a - score_b;
    }

    return s_a->caseInsensitiveCompare(s_b);
}

- (void) addAccount:(hermes::UnifiedAccount *)unifiedAccount
favoriteAllSpecialFolders:(BOOL)favoriteAllSpecialFolders
      singleAccount:(BOOL)singleAccount
{
    NSMutableDictionary * displayNames = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * countTypes = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * foldersOrderScore = [[NSMutableDictionary alloc] init];

    Set * foldersSet = Set::setWithArray(unifiedAccount->folders());
    BOOL hasInbox = (unifiedAccount->inboxFolderPath() != NULL);
    if (hasInbox) {
        displayNames[MCO_TO_OBJC(unifiedAccount->inboxFolderPath())] = @"Inbox";
        countTypes[MCO_TO_OBJC(unifiedAccount->inboxFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_UNREAD);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->inboxFolderPath())] = @1;
    }
    BOOL hasImportant = (unifiedAccount->importantFolderPath() != NULL);
    if (hasImportant) {
        displayNames[MCO_TO_OBJC(unifiedAccount->importantFolderPath())] = @"Important";
        countTypes[MCO_TO_OBJC(unifiedAccount->importantFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_UNREAD);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->importantFolderPath())] = @2;
    }
    BOOL hasStarred = (unifiedAccount->starredFolderPath() != NULL);
    if (hasStarred) {
        displayNames[MCO_TO_OBJC(unifiedAccount->starredFolderPath())] = @"Starred";
        countTypes[MCO_TO_OBJC(unifiedAccount->starredFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_COUNT);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->starredFolderPath())] = @3;
    }
    BOOL hasSent = (unifiedAccount->sentFolderPath() != NULL);
    if (hasSent) {
        displayNames[MCO_TO_OBJC(unifiedAccount->sentFolderPath())] = @"Sent";
        countTypes[MCO_TO_OBJC(unifiedAccount->sentFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_NONE);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->sentFolderPath())] = @4;
    }
    BOOL hasDrafts = (unifiedAccount->draftsFolderPath() != NULL);
    if (hasDrafts) {
        displayNames[MCO_TO_OBJC(unifiedAccount->draftsFolderPath())] = @"Drafts";
        countTypes[MCO_TO_OBJC(unifiedAccount->draftsFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_COUNT);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->draftsFolderPath())] = @5;
    }
    BOOL hasAllMail = (unifiedAccount->allMailFolderPath() != NULL);
    if (hasAllMail) {
        displayNames[MCO_TO_OBJC(unifiedAccount->allMailFolderPath())] = @"All Mail";
        countTypes[MCO_TO_OBJC(unifiedAccount->allMailFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_NONE);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->allMailFolderPath())] = @6;
    }
    BOOL hasArchive = (unifiedAccount->archiveFolderPath() != NULL);
    if (hasArchive) {
        displayNames[MCO_TO_OBJC(unifiedAccount->archiveFolderPath())] = @"Archive";
        countTypes[MCO_TO_OBJC(unifiedAccount->archiveFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_NONE);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->archiveFolderPath())] = @7;
    }
    BOOL hasTrash = (unifiedAccount->trashFolderPath() != NULL);
    if (hasTrash) {
        displayNames[MCO_TO_OBJC(unifiedAccount->trashFolderPath())] = @"Trash";
        countTypes[MCO_TO_OBJC(unifiedAccount->trashFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_NONE);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->trashFolderPath())] = @8;
    }
    BOOL hasSpam = (unifiedAccount->spamFolderPath() != NULL);
    if (hasSpam) {
        displayNames[MCO_TO_OBJC(unifiedAccount->spamFolderPath())] = @"Spam";
        countTypes[MCO_TO_OBJC(unifiedAccount->spamFolderPath())] = @(DJLFOLDERINFO_COUNT_TYPE_NONE);
        foldersOrderScore[MCO_TO_OBJC(unifiedAccount->spamFolderPath())] = @9;
    }

    Set * favoriteFoldersSet = Set::set();
    if (favoriteAllSpecialFolders) {
        favoriteFoldersSet->addObjectsFromArray(MCO_FROM_OBJC(Array, [foldersOrderScore allKeys]));
    }
    else {
        if (unifiedAccount->accounts()->count() == 1) {
            Account * account = (Account *) unifiedAccount->accounts()->objectAtIndex(0);
            if (account->inboxFolderPath() != NULL) {
                if ((account->accountInfo()->favoriteFolders() == NULL) || (account->accountInfo()->favoriteFolders()->count() == 0)) {
                    if (hasInbox) {
                        favoriteFoldersSet->addObject(unifiedAccount->inboxFolderPath());
                    }
                    if (hasStarred) {
                        favoriteFoldersSet->addObject(unifiedAccount->starredFolderPath());
                    }
                    if (hasSent) {
                        favoriteFoldersSet->addObject(unifiedAccount->sentFolderPath());
                    }
                    if (singleAccount) {
                        if (hasDrafts) {
                            favoriteFoldersSet->addObject(unifiedAccount->draftsFolderPath());
                        }
                        if (hasAllMail) {
                            favoriteFoldersSet->addObject(unifiedAccount->allMailFolderPath());
                        }
                        if (hasArchive) {
                            favoriteFoldersSet->addObject(unifiedAccount->archiveFolderPath());
                        }
                    }
                    account->accountInfo()->setFavoriteFolders(favoriteFoldersSet->allObjects());
                    account->save();
                }
                else {
                    favoriteFoldersSet->addObject(account->inboxFolderPath());
                }
            }
            favoriteFoldersSet->addObjectsFromArray(account->accountInfo()->favoriteFolders());
        }
        else {
            NSArray * favoriteFolders = [[NSUserDefaults standardUserDefaults] arrayForKey:@"DJLFavoriteFoldersForUnifiedInbox"];
            Array * mcFavoriteFolders = MCO_FROM_OBJC(Array, favoriteFolders);
            if (unifiedAccount->inboxFolderPath() != NULL) {
                if ((mcFavoriteFolders == NULL) || (mcFavoriteFolders->count() == 0)) {
                    if (hasInbox) {
                        favoriteFoldersSet->addObject(unifiedAccount->inboxFolderPath());
                    }
                    if (hasStarred) {
                        favoriteFoldersSet->addObject(unifiedAccount->starredFolderPath());
                    }
                    if (hasSent) {
                        favoriteFoldersSet->addObject(unifiedAccount->sentFolderPath());
                    }
                    if (hasDrafts) {
                        favoriteFoldersSet->addObject(unifiedAccount->draftsFolderPath());
                    }
                    if (hasAllMail) {
                        favoriteFoldersSet->addObject(unifiedAccount->allMailFolderPath());
                    }
                    if (hasArchive) {
                        favoriteFoldersSet->addObject(unifiedAccount->archiveFolderPath());
                    }
                    [[NSUserDefaults standardUserDefaults] setObject:MCO_TO_OBJC(favoriteFoldersSet->allObjects())
                                                              forKey:@"DJLFavoriteFoldersForUnifiedInbox"];
                }
            }
            else {
                favoriteFoldersSet->addObject(unifiedAccount->inboxFolderPath());
            }
            favoriteFoldersSet->addObjectsFromArray(mcFavoriteFolders);
        }
    }

    Array * favoriteFolders = favoriteFoldersSet->allObjects();
    favoriteFolders->sortArray(compareFoldersWithScore, (__bridge void *) foldersOrderScore);

    Set * basePaths = Set::set();

    DJLFolderPaneFolderInfo * favoritesRootInfo = [[DJLFolderPaneFolderInfo alloc] init];

    {
        mc_foreacharray(String, mcPath, favoriteFolders) {
            Array * mcPathComponents = unifiedAccount->componentsForFolderPath(mcPath);

            NSString * path = MCO_TO_OBJC(mcPath);
            {
                int count = 0;
                int countType = DJLFOLDERINFO_COUNT_TYPE_UNREAD;
                if (countTypes[path] != nil) {
                    countType = [(NSNumber *) countTypes[path] intValue];
                }
                switch (countType) {
                    case DJLFOLDERINFO_COUNT_TYPE_UNREAD:
                        count = unifiedAccount->unreadCountForFolderID(unifiedAccount->folderIDForPath(mcPath));
                        break;
                    case DJLFOLDERINFO_COUNT_TYPE_COUNT:
                        count = unifiedAccount->countForFolderID(unifiedAccount->folderIDForPath(mcPath));
                        break;
                }
                NSArray * pathComponents = MCO_TO_OBJC(mcPathComponents);
                NSString * displayName = displayNames[path];
                [favoritesRootInfo addPathComponents:pathComponents
                                         displayName:displayName
                                                path:path
                                               count:count
                                           countType:countType
                                         accountInfo:self];
            }

            basePaths->addObject(mcPath);
        }
    }

    Array * sortedFolders = foldersSet->allObjects()->sortedArray(compareFoldersWithScore, (__bridge void *) foldersOrderScore);

    DJLFolderPaneFolderInfo * foldersRootInfo = [[DJLFolderPaneFolderInfo alloc] init];

    {
        mc_foreacharray(String, mcPath, sortedFolders) {
            if (basePaths->containsObject(mcPath)) {
                continue;
            }

            Array * mcPathComponents = unifiedAccount->componentsForFolderPath(mcPath);

            NSString * path = MCO_TO_OBJC(mcPath);
            {
                int count = 0;
                int countType = DJLFOLDERINFO_COUNT_TYPE_UNREAD;
                if (countTypes[path] != nil) {
                    countType = [(NSNumber *) countTypes[path] intValue];
                }
                switch (countType) {
                    case DJLFOLDERINFO_COUNT_TYPE_UNREAD:
                        count = unifiedAccount->unreadCountForFolderID(unifiedAccount->folderIDForPath(mcPath));
                        break;
                    case DJLFOLDERINFO_COUNT_TYPE_COUNT:
                        count = unifiedAccount->countForFolderID(unifiedAccount->folderIDForPath(mcPath));
                        break;
                }
                NSArray * pathComponents = MCO_TO_OBJC(mcPathComponents);
                NSString * displayName = displayNames[path];
                [foldersRootInfo addPathComponents:pathComponents
                                       displayName:displayName
                                              path:path
                                             count:count
                                         countType:countType
                                       accountInfo:self];
            }
        }
    }

    [self setUnifiedAccount:unifiedAccount];
    [self setFavoritesRootInfo:favoritesRootInfo];
    [self setFoldersRootInfo:foldersRootInfo];
    DJLFolderPaneFoldersDisclosureInfo * foldersDisclosureInfo = [[DJLFolderPaneFoldersDisclosureInfo alloc] init];
    [foldersDisclosureInfo setAccountInfo:self];
    [self setFoldersDisclosureInfo:foldersDisclosureInfo];
}

@end
