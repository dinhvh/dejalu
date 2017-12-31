// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMUnifiedAccount.h"

#include "HMAccount.h"
#include "HMAccountInfo.h"
#include "HMUnifiedMailStorageView.h"
#include "HMMailStorageView.h"
#include "HMUnifiedAccountObserver.h"

using namespace hermes;
using namespace mailcore;

enum {
    UNIFIED_FOLDER_ID_INBOX,
    UNIFIED_FOLDER_ID_ALLMAIL,
    UNIFIED_FOLDER_ID_ARCHIVE,
    UNIFIED_FOLDER_ID_SENT,
    UNIFIED_FOLDER_ID_TRASH,
    UNIFIED_FOLDER_ID_DRAFTS,
    UNIFIED_FOLDER_ID_IMPORTANT,
    UNIFIED_FOLDER_ID_SPAM,
    UNIFIED_FOLDER_ID_STARRED,
};

UnifiedAccount::UnifiedAccount()
{
    mAccounts = NULL;
    mObservers = carray_new(4);
    mPathToFolderID = new HashMap();
    mFolderIDToPath = new Array();
    mFolderIDToPath->addObject(MCSTR("inbox"));
    mFolderIDToPath->addObject(MCSTR("allmail"));
    mFolderIDToPath->addObject(MCSTR("archive"));
    mFolderIDToPath->addObject(MCSTR("sent"));
    mFolderIDToPath->addObject(MCSTR("trash"));
    mFolderIDToPath->addObject(MCSTR("drafts"));
    mFolderIDToPath->addObject(MCSTR("important"));
    mFolderIDToPath->addObject(MCSTR("spam"));
    mFolderIDToPath->addObject(MCSTR("starred"));
    mFolderIDOpenCount = new HashMap();
    mc_foreacharrayIndex(idx, String, path, mFolderIDToPath) {
        mPathToFolderID->setObjectForKey(path, Value::valueWithLongLongValue(idx));
    }
    mPendingGotFolders = 0;
    mPendingOpenViewsCount = new HashMap();
    mStorageViews = new HashMap();
    mOpenedPathCount = new HashMap();
    mPendingOpenFolderPath = new HashMap();
}

UnifiedAccount::~UnifiedAccount()
{
    MC_SAFE_RELEASE(mPendingOpenFolderPath);
    MC_SAFE_RELEASE(mOpenedPathCount);
    MC_SAFE_RELEASE(mStorageViews);
    MC_SAFE_RELEASE(mPendingOpenViewsCount);
    MC_SAFE_RELEASE(mFolderIDOpenCount);
    MC_SAFE_RELEASE(mFolderIDToPath);
    MC_SAFE_RELEASE(mPathToFolderID);
    mc_foreacharray(Account, account, mAccounts) {
        account->removeObserver(this);
    }
    carray_free(mObservers);
    MC_SAFE_RELEASE(mAccounts);
}

void UnifiedAccount::setAccounts(mailcore::Array * /* Account */ account)
{
    {
        mc_foreacharray(Account, account, mAccounts) {
            account->removeObserver(this);
        }
    }
    MC_SAFE_REPLACE_RETAIN(Array, mAccounts, account);
    mPendingGotFolders = 0;
    {
        mc_foreacharray(Account, account, mAccounts) {
            account->addObserver(this);
            if (account->folders() == NULL) {
                mPendingGotFolders ++;
            }
        }
    }
}

mailcore::Array * UnifiedAccount::accounts()
{
    return mAccounts;
}

void UnifiedAccount::addObserver(UnifiedAccountObserver * observer)
{
    carray_add(mObservers, observer, NULL);
}

void UnifiedAccount::removeObserver(UnifiedAccountObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            break;
        }
    }
}

Account * UnifiedAccount::singleAccount()
{
    return (Account *) mAccounts->lastObject();
}

mailcore::String * UnifiedAccount::shortDisplayName()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->shortDisplayName();
    }
    else {
        return NULL;
    }
}

int64_t UnifiedAccount::folderIDForPath(mailcore::String * path)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->folderIDForPath(path);
    }
    else {
        if (path == NULL) {
            return -1;
        }
        return ((Value *) mPathToFolderID->objectForKey(path))->longLongValue();
    }
}

mailcore::String * UnifiedAccount::pathForFolderID(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->pathForFolderID(folderID);
    }
    else {
        if (folderID == -1) {
            return NULL;
        }
        return (String *) mFolderIDToPath->objectAtIndex((int) folderID);
    }
}

int UnifiedAccount::unreadCountForFolderID(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->unreadCountForFolderID(folderID);
    }
    else {
        if (folderID == -1) {
            return NULL;
        }
        int value = 0;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                value += account->unreadCountForFolderID(accountFolderID);
            }
        }
        return value;
    }
}

int UnifiedAccount::starredCountForFolderID(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->starredCountForFolderID(folderID);
    }
    else {
        if (folderID == -1) {
            return NULL;
        }
        int value = 0;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                value += account->starredCountForFolderID(accountFolderID);
            }
        }
        return value;
    }
}

int UnifiedAccount::countForFolderID(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->countForFolderID(folderID);
    }
    else {
        if (folderID == -1) {
            return NULL;
        }
        int value = 0;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                value += account->countForFolderID(accountFolderID);
            }
        }
        return value;
    }
}

mailcore::String * UnifiedAccount::inboxFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->inboxFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_INBOX);
    }
}

mailcore::String * UnifiedAccount::allMailFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->allMailFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_ALLMAIL);
    }
}

mailcore::String * UnifiedAccount::archiveFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->archiveFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_ARCHIVE);
    }
}

mailcore::String * UnifiedAccount::sentFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->sentFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_SENT);
    }
}

mailcore::String * UnifiedAccount::trashFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->trashFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_TRASH);
    }
}

mailcore::String * UnifiedAccount::draftsFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->draftsFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_DRAFTS);
    }
}

mailcore::String * UnifiedAccount::importantFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->importantFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_IMPORTANT);
    }
}

mailcore::String * UnifiedAccount::spamFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->spamFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_SPAM);
    }
}

mailcore::String * UnifiedAccount::starredFolderPath()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->starredFolderPath();
    }
    else {
        return (String *) mFolderIDToPath->objectAtIndex(UNIFIED_FOLDER_ID_STARRED);
    }
}

mailcore::Array * UnifiedAccount::folders()
{
    if (mAccounts->count() == 1) {
        return singleAccount()->folders();
    }
    else {
        return mFolderIDToPath;
    }
}

mailcore::Array * UnifiedAccount::componentsForFolderPath(mailcore::String * path)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->componentsForFolderPath(path);
    }
    else {
        return Array::arrayWithObject(path);
    }
}

void UnifiedAccount::setSearchKeywords(mailcore::Array * keywords)
{
    mc_foreacharray(Account, account, mAccounts) {
        account->setSearchKeywords(keywords);
    }
}

mailcore::Array * UnifiedAccount::searchKeywords()
{
    Account * account = (Account *) mAccounts->lastObject();
    return account->searchKeywords();
}

bool UnifiedAccount::isSearching()
{
    bool result = false;
    mc_foreacharray(Account, account, mAccounts) {
        result = result || account->isSearching();
    }
    return result;
}

void UnifiedAccount::disableSync()
{
    mc_foreacharray(Account, account, mAccounts) {
        account->disableSync();
    }
}

void UnifiedAccount::enableSync()
{
    mc_foreacharray(Account, account, mAccounts) {
        account->enableSync();
    }
}

int64_t UnifiedAccount::folderIDForAccount(hermes::Account * account, int64_t folderID)
{
    String * path = NULL;
    switch (folderID) {
        case UNIFIED_FOLDER_ID_INBOX:
            path = account->inboxFolderPath();
            break;
        case UNIFIED_FOLDER_ID_ALLMAIL:
            path = account->allMailFolderPath();
            break;
        case UNIFIED_FOLDER_ID_ARCHIVE:
            path = account->archiveFolderPath();
            break;
        case UNIFIED_FOLDER_ID_SENT:
            path = account->sentFolderPath();
            break;
        case UNIFIED_FOLDER_ID_TRASH:
            path = account->trashFolderPath();
            break;
        case UNIFIED_FOLDER_ID_DRAFTS:
            path = account->draftsFolderPath();
            break;
        case UNIFIED_FOLDER_ID_IMPORTANT:
            path = account->importantFolderPath();
            break;
        case UNIFIED_FOLDER_ID_SPAM:
            path = account->spamFolderPath();
            break;
        case UNIFIED_FOLDER_ID_STARRED:
            path = account->starredFolderPath();
            break;
    }
    if (path == NULL) {
        return -1;
    }

    return account->folderIDForPath(path);
}

bool UnifiedAccount::shouldShowProgressForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->shouldShowProgressForFolder(folderID);
    }
    else {
        bool result = false;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                result = result || account->shouldShowProgressForFolder(accountFolderID);
            }
        }
        return result;
    }
}

bool UnifiedAccount::canLoadMoreForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->canLoadMoreForFolder(folderID);
    }
    else {
        bool result = false;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                result = result || account->canLoadMoreForFolder(accountFolderID);
            }
        }
        return result;
    }
}

void UnifiedAccount::refreshFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        singleAccount()->refreshFolder(folderID);
    }
    else {
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                account->refreshFolder(accountFolderID);
            }
        }
    }
}

unsigned int UnifiedAccount::headersProgressValueForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->headersProgressValueForFolder(folderID);
    }
    else {
        unsigned int value = 0;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                value += account->headersProgressValueForFolder(accountFolderID);
            }
        }
        return value;
    }
}

unsigned int UnifiedAccount::headersProgressMaxForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->headersProgressMaxForFolder(folderID);
    }
    else {
        unsigned int value = 0;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                value += account->headersProgressMaxForFolder(accountFolderID);
            }
        }
        return value;
    }
}

bool UnifiedAccount::loadMoreForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->loadMoreForFolder(folderID);
    }
    else {
        bool result = false;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                result = result || account->loadMoreForFolder(accountFolderID);
            }
        }
        return result;
    }
}

void UnifiedAccount::resetMessagesToLoadForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        singleAccount()->resetMessagesToLoadForFolder(folderID);
    }
    else {
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                account->resetMessagesToLoadForFolder(accountFolderID);
            }
        }
    }
}

bool UnifiedAccount::messagesToLoadCanBeResetForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->messagesToLoadCanBeResetForFolder(folderID);
    }
    else {
        bool result = false;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                result = result || account->messagesToLoadCanBeResetForFolder(accountFolderID);
            }
        }
        return result;
    }
}

void UnifiedAccount::setWaitingLoadMoreForFolder(int64_t folderID, bool waitingLoadMore)
{
    if (mAccounts->count() == 1) {
        singleAccount()->setWaitingLoadMoreForFolder(folderID, waitingLoadMore);
    }
    else {
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                account->setWaitingLoadMoreForFolder(accountFolderID, waitingLoadMore);
            }
        }
    }
}

bool UnifiedAccount::isWaitingLoadMoreForFolder(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->isWaitingLoadMoreForFolder(folderID);
    }
    else {
        bool result = false;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                result = result || account->isWaitingLoadMoreForFolder(accountFolderID);
            }
        }
        return result;
    }
}

void UnifiedAccount::markFolderAsSeen(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        singleAccount()->markFolderAsSeen(folderID);
    }
    else {
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                account->markFolderAsSeen(accountFolderID);
            }
        }
    }
}

bool UnifiedAccount::isFolderUnseen(int64_t folderID)
{
    if (mAccounts->count() == 1) {
        return singleAccount()->isFolderUnseen(folderID);
    }
    else {
        bool result = false;
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                result = result || account->isFolderUnseen(accountFolderID);
            }
        }
        return result;
    }
}

UnifiedMailStorageView * UnifiedAccount::openViewForSearchKeywords(mailcore::Array * keywords)
{
    UnifiedMailStorageView * result = new UnifiedMailStorageView();
    Array * views = new Array();
    mc_foreacharray(Account, account, mAccounts) {
        MailStorageView * view = account->openViewForSearchKeywords(keywords);
        views->addObject(view);
    }
    result->setStorageViews(views);
    MC_SAFE_RELEASE(views);
    result->autorelease();
    return result;
}

void UnifiedAccount::closeViewForSearch(UnifiedMailStorageView * view)
{
    mc_foreacharrayIndex(idx, MailStorageView, storageView, view->storageViews()) {
        Account * account = (Account *) mAccounts->objectAtIndex(idx);
        account->closeViewForSearch(storageView);
    }
}

void UnifiedAccount::setViews(UnifiedMailStorageView * unifiedStorageView, int64_t folderID)
{
    Array * views = new Array();
    if (mAccounts->count() == 1) {
        MailStorageView * view = singleAccount()->viewForFolder(folderID);
        views->addObject(view);
    }
    else {
        mc_foreacharray(Account, account, mAccounts) {
            int64_t accountFolderID = folderIDForAccount(account, folderID);
            if (accountFolderID != -1) {
                MailStorageView * view = account->viewForFolder(accountFolderID);
                views->addObject(view);
            }
            else {
                //fprintf(stderr, "could not open storage view for %s: %i\n", MCUTF8(account->accountInfo()->email()), (int) folderID);
                MailStorageView * view = new MailStorageView();
                view->autorelease();
                views->addObject(view);
            }
        }
    }
    unifiedStorageView->setStorageViews(views);
    MC_SAFE_RELEASE(views);
}

void UnifiedAccount::openViewForFolder(int64_t folderID)
{
    Value * vCount = (Value *) mFolderIDOpenCount->objectForKey(Value::valueWithLongLongValue(folderID));
    int count = 0;
    if (vCount != NULL) {
        count = vCount->intValue();
    }
    count ++;
    {
        Account * account = (Account *) mAccounts->objectAtIndex(0);
        //fprintf(stderr, "open %s %s %i -> %i\n", MCUTF8(account->accountInfo()->email()), MCUTF8(mAccounts), (int) folderID, count);
    }
    mFolderIDOpenCount->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(count));

    if (count == 1) {
        if (mAccounts->count() == 1) {
            singleAccount()->openViewForFolder(folderID);
        }
        else {
            mc_foreacharrayIndex(accountIndex, Account, account, mAccounts) {
                int64_t accountFolderID = folderIDForAccount(account, folderID);
                if (accountFolderID != -1) {
                    account->openViewForFolder(accountFolderID);
                }
                else {
                    Set * openedFolders = (Set *) mPendingOpenViewsCount->objectForKey(account->accountInfo()->email());
                    if (openedFolders == NULL) {
                        openedFolders = Set::set();
                        mPendingOpenViewsCount->setObjectForKey(account->accountInfo()->email(), openedFolders);
                    }
                    Value * vFolderID = Value::valueWithLongLongValue(folderID);
                    openedFolders->addObject(vFolderID);
                }
            }
        }

        UnifiedMailStorageView * unifiedStorageView = new UnifiedMailStorageView();
        setViews(unifiedStorageView, folderID);
        mStorageViews->setObjectForKey(Value::valueWithLongLongValue(folderID), unifiedStorageView);
        MC_SAFE_RELEASE(unifiedStorageView);
    }
}

void UnifiedAccount::openPendingFolders(Account * account)
{
    Set * openedFolders = (Set *) mPendingOpenViewsCount->objectForKey(account->accountInfo()->email());
    if (openedFolders == NULL) {
        return;
    }

    mc_foreacharray(Value, vFolderID, openedFolders->allObjects()) {
        int64_t folderID = vFolderID->longLongValue();
        int64_t accountFolderID = folderIDForAccount(account, folderID);
        account->openViewForFolder(accountFolderID);
        UnifiedMailStorageView * unifiedStorageView = (UnifiedMailStorageView *) mStorageViews->objectForKey(vFolderID);
        setViews(unifiedStorageView, folderID);
    }

    mPendingOpenViewsCount->removeObjectForKey(account->accountInfo()->email());
}

UnifiedMailStorageView * UnifiedAccount::viewForFolder(int64_t folderID)
{
    return (UnifiedMailStorageView *) mStorageViews->objectForKey(Value::valueWithLongLongValue(folderID));
}

void UnifiedAccount::closeView(hermes::UnifiedMailStorageView * view)
{
    mc_foreachhashmapKeyAndValue(Value, key, UnifiedMailStorageView, currentView, mStorageViews) {
        if (currentView == view) {
            closeViewForFolder(key->longLongValue());
            break;
        }
    }
}

void UnifiedAccount::closeViewForFolder(int64_t folderID)
{
    Value * vCount = (Value *) mFolderIDOpenCount->objectForKey(Value::valueWithLongLongValue(folderID));
    MCAssert(vCount != NULL);
    int count = vCount->intValue();
    count --;
    {
        Account * account = (Account *) mAccounts->objectAtIndex(0);
        //fprintf(stderr, "close %s %s %i -> %i\n", MCUTF8(account->accountInfo()->email()), MCUTF8(mAccounts), (int) folderID, count);
    }
    if (count == 0) {
        mFolderIDOpenCount->removeObjectForKey(Value::valueWithLongLongValue(folderID));
    }
    else {
        mFolderIDOpenCount->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(count));
    }

    if (count == 0) {
        if (mAccounts->count() == 1) {
            singleAccount()->closeViewForFolder(folderID);
        }
        else {
            mc_foreacharray(Account, account, mAccounts) {
                int64_t accountFolderID = folderIDForAccount(account, folderID);
                if (accountFolderID != -1) {
                    account->closeViewForFolder(accountFolderID);
                }
                else {
                    Set * openedFolders = (Set *) mPendingOpenViewsCount->objectForKey(account->accountInfo()->email());
                    MCAssert(openedFolders != NULL);
                    Value * vFolderID = Value::valueWithLongLongValue(folderID);
                    openedFolders->removeObject(vFolderID);
                    if (openedFolders->count() == 0) {
                        mPendingOpenViewsCount->removeObjectForKey(account->accountInfo()->email());
                    }
                }
            }
        }
        mStorageViews->removeObjectForKey(Value::valueWithLongLongValue(folderID));
    }
}

void UnifiedAccount::accountGotFolders(Account * account)
{
    mPendingGotFolders --;
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountGotFolders(this, accountIndex);
    }

    openPendingFolders(account);
}

void UnifiedAccount::accountFoldersUpdated(Account * account)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountFoldersUpdated(this, accountIndex);
    }
}

void UnifiedAccount::accountFetchSummaryDone(Account * account, hermes::ErrorCode error, int64_t messageRowID)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountFetchSummaryDone(this, accountIndex, error, messageRowID);
    }
}

void UnifiedAccount::accountFetchPartDone(Account * account, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountFetchPartDone(this, accountIndex, error, messageRowID, partID);
    }
}

void UnifiedAccount::accountStateUpdated(Account * account)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountStateUpdated(this, accountIndex);
    }
}

void UnifiedAccount::accountLocalMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountLocalMessageSaved(this, accountIndex, folderID, messageID, messageRowID, willPushToServer);
    }
}

void UnifiedAccount::accountPushMessageDone(Account * account, hermes::ErrorCode error, int64_t messageRowID)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountPushMessageDone(this, accountIndex, error, messageRowID);
    }
}

void UnifiedAccount::accountMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID)
{
    int accountIndex = mAccounts->indexOfObject(account);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
        observer->accountMessageSaved(this, accountIndex, folderID, messageID);
    }
}

void UnifiedAccount::accountSyncDone(Account * account, hermes::ErrorCode error, mailcore::String * folderPath)
{
    int accountIndex = mAccounts->indexOfObject(account);
    if (mAccounts->count() == 1) {
        for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
            UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
            observer->accountSyncDone(this, accountIndex, error, folderPath);
        }
    }
    else {
        for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
            UnifiedAccountObserver * observer = (UnifiedAccountObserver *) carray_get(mObservers, i);
            int64_t folderID = -1;
            if (folderPath->isEqual(account->inboxFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_INBOX;
            }
            else if (folderPath->isEqual(account->allMailFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_ALLMAIL;
            }
            else if (folderPath->isEqual(account->archiveFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_ARCHIVE;
            }
            else if (folderPath->isEqual(account->sentFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_SENT;
            }
            else if (folderPath->isEqual(account->trashFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_TRASH;
            }
            else if (folderPath->isEqual(account->draftsFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_TRASH;
            }
            else if (folderPath->isEqual(account->importantFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_IMPORTANT;
            }
            else if (folderPath->isEqual(account->spamFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_SPAM;
            }
            else if (folderPath->isEqual(account->starredFolderPath())) {
                folderID = UNIFIED_FOLDER_ID_STARRED;
            }
            String * mainPath = pathForFolderID(folderID);
            observer->accountSyncDone(this, accountIndex, error, mainPath);
        }
    }
}
