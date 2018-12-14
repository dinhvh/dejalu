// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMAccountManager.h"

#include <libetpan/libetpan.h>
#include <dirent.h>

#include "HMAccountInfo.h"
#include "HMAccount.h"
#include "HMAccountManagerObserver.h"
#include "DJLLog.h"

using namespace mailcore;
using namespace hermes;

AccountManager * AccountManager::sharedManager()
{
    static AccountManager * instance = new AccountManager();
    return instance;
}

void AccountManager::addObserver(AccountManagerObserver * observer)
{
    carray_add(mObservers, (void *) observer, NULL);
}

void AccountManager::removeObserver(AccountManagerObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            break;
        }
    }
}

AccountManager::AccountManager()
{
    mResetDB = false;
    mObservers = carray_new(4);
    mPath = NULL;
    mAccounts = new Array();
    mLogEnabled = false;
}

AccountManager::~AccountManager()
{
    mc_foreacharray(Account, account, mAccounts) {
        account->removeObserver(this);
    }
    MC_SAFE_RELEASE(mAccounts);
    MC_SAFE_RELEASE(mPath);
    carray_free(mObservers);
}

void AccountManager::setLogEnabled(bool enabled)
{
    mLogEnabled = enabled;
    mc_foreacharray(Account, account, mAccounts) {
        account->setLogEnabled(mLogEnabled);
    }
}

void AccountManager::setQuickSyncEnabled(bool enabled)
{
    mQuickSyncEnabled = enabled;
    mc_foreacharray(Account, account, mAccounts) {
        account->setQuickSyncEnabled(mQuickSyncEnabled);
    }
}

void AccountManager::setPath(mailcore::String * path)
{
    MC_SAFE_REPLACE_COPY(String, mPath, path);
}

mailcore::String * AccountManager::path()
{
    return mPath;
}

void AccountManager::setResetDB()
{
    mResetDB = true;
}

void AccountManager::save()
{
    Array * list = Array::array();
    mc_foreacharray(Account, account, mAccounts) {
        list->addObject(account->accountInfo()->email());
    }
    String * filename = path()->stringByAppendingPathComponent(MCSTR("account-list.json"));
    JSON::objectToJSONData(list)->writeToFile(filename);
}

void AccountManager::load()
{
    Set * loaded = Set::set();

    Data * data = Data::dataWithContentsOfFile(path()->stringByAppendingPathComponent(MCSTR("account-list.json")));
    if (data != NULL) {
        Array * list = (Array *) JSON::objectFromJSONData(data);
        mc_foreacharray(String, email, list) {
            loadAccount(path()->stringByAppendingPathComponent(email), loaded);
        }
    }

    DIR * dir = opendir(path()->fileSystemRepresentation());
    if (dir == NULL) {
        return;
    }

    bool hasNew = false;
    struct dirent * ent;
    while ((ent = readdir(dir)) != NULL) {
        if ((strcmp(ent->d_name, ".") == 0) || (strcmp(ent->d_name, "..") == 0)) {
            continue;
        }

        String * subpath = path()->stringByAppendingPathComponent(String::stringWithFileSystemRepresentation(ent->d_name));
        if (ent->d_type == DT_DIR) {
            loadAccount(subpath, loaded);
            hasNew = true;
        }
    }
    closedir(dir);

    mResetDB = false;

    if (hasNew) {
        save();
    }
}

void AccountManager::loadAccount(mailcore::String * path, mailcore::Set * loaded)
{
    String * configPath = path->stringByAppendingPathComponent(MCSTR("account-info.json"));
    AccountInfo * accountInfo = new AccountInfo();
    if (!accountInfo->load(configPath)) {
        MC_SAFE_RELEASE(accountInfo);
        return;
    }
    if (loaded->containsObject(accountInfo->email()->lowercaseString())) {
        MC_SAFE_RELEASE(accountInfo);
        return;
    }
    fprintf(stderr, "load account %s\n", MCUTF8(path));
    if (mResetDB) {
        String * metaPath = path->stringByAppendingPathComponent(MCSTR("meta.json"));
        unlink(metaPath->fileSystemRepresentation());
    }

    Account * account = new Account();
    account->setAccountInfo(accountInfo);
    account->setPath(mPath);
    account->open();
    account->setDeliveryEnabled(true);
    account->setQuickSyncEnabled(mQuickSyncEnabled);

    addAccount(account);

    loaded->addObject(account->accountInfo()->email()->lowercaseString());

    MC_SAFE_RELEASE(account);
}

void AccountManager::addAccount(Account * account)
{
    account->setLogEnabled(mLogEnabled);
    account->addObserver(this);
    mAccounts->addObject(account);

    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountManagerObserver * observer = (AccountManagerObserver *) carray_get(mObservers, i);
        observer->accountManagerChanged(this);
    }
}

void AccountManager::moveAccountToIndex(Account * account, unsigned int idx)
{
    int originalIdx = mAccounts->indexOfObject(account);
    MCAssert(originalIdx != -1);
    mAccounts->insertObject(idx, account);
    if (idx > originalIdx) {
        mAccounts->removeObjectAtIndex(originalIdx);
    }
    else {
        mAccounts->removeObjectAtIndex(originalIdx + 1);
    }

    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountManagerObserver * observer = (AccountManagerObserver *) carray_get(mObservers, i);
        observer->accountManagerChanged(this);
    }
}

void AccountManager::removeAccount(Account * account)
{
    account->removeObserver(this);
    mAccounts->removeObject(account);

    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountManagerObserver * observer = (AccountManagerObserver *) carray_get(mObservers, i);
        observer->accountManagerChanged(this);
    }
}

mailcore::Array * AccountManager::accounts()
{
    return mAccounts;
}

Account * AccountManager::accountForEmail(mailcore::String * email)
{
    Account * result = NULL;
    mc_foreacharray(Account, account, mAccounts) {
        if (account->accountInfo()->email()->isEqual(email)) {
            result = account;
        }
    }
    return result;
}

void AccountManager::accountFolderUnseenChanged(Account * account, mailcore::String * folderPath)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountManagerObserver * observer = (AccountManagerObserver *) carray_get(mObservers, i);
        observer->accountManagerAccountUnseenChanged(this);
    }
}

void AccountManager::accountNotifyUnreadEmail(Account * account, mailcore::String * folderPath)
{
#warning should add delay
    LOG_ERROR("notify unread mail %s - %s", MCUTF8(account->accountInfo()->email()), MCUTF8(folderPath));
    if (folderPath->isEqual(MCSTR("INBOX"))) {
        for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
            AccountManagerObserver * observer = (AccountManagerObserver *) carray_get(mObservers, i);
            observer->accountManagerNotifyUnreadEmail(this, account);
        }
    }
}

void AccountManager::accountHasNewContacts(Account * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountManagerObserver * observer = (AccountManagerObserver *) carray_get(mObservers, i);
        observer->accountManagerHasNewContacts(this, account);
    }
}
