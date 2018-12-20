// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMUnifiedAccountManager.h"

#include "HMAccountManager.h"
#include "HMUnifiedAccount.h"
#include "HMAccount.h"
#include "HMAccountInfo.h"
#include "HMUnifiedAccountManagerObserver.h"

using namespace mailcore;
using namespace hermes;

UnifiedAccountManager * UnifiedAccountManager::sharedManager()
{
    static UnifiedAccountManager * instance = new UnifiedAccountManager();
    return instance;
}

UnifiedAccountManager::UnifiedAccountManager()
{
    mObservers = carray_new(4);
    mAccounts = new Array();
    _unifiedAccount = NULL;
    AccountManager::sharedManager()->addObserver(this);
    setupAccounts();
}

UnifiedAccountManager::~UnifiedAccountManager()
{
    AccountManager::sharedManager()->removeObserver(this);
    MC_SAFE_RELEASE(_unifiedAccount);
    MC_SAFE_RELEASE(mAccounts);
    carray_free(mObservers);
}

void UnifiedAccountManager::addObserver(UnifiedAccountManagerObserver * observer)
{
    carray_add(mObservers, (void *) observer, NULL);
}

void UnifiedAccountManager::removeObserver(UnifiedAccountManagerObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            break;
        }
    }
}

UnifiedAccount * UnifiedAccountManager::accountForEmail(mailcore::String * email)
{
    UnifiedAccount * result = NULL;
    mc_foreacharray(UnifiedAccount, account, mAccounts) {
        Account * singleAccount = (Account *) account->accounts()->objectAtIndex(0);
        if (singleAccount->accountInfo()->email()->isEqual(email)) {
            result = account;
        }
    }
    return result;
}

UnifiedAccount * UnifiedAccountManager::unifiedAccount()
{
    return _unifiedAccount;
}

mailcore::Array * UnifiedAccountManager::accounts()
{
    return mAccounts;
}

void UnifiedAccountManager::accountManagerChanged(AccountManager * manager)
{
    setupAccounts();
}

void UnifiedAccountManager::setupAccounts()
{
    HashMap * accountHash = new HashMap();
    mAccounts->removeAllObjects();

    Array * accounts = new Array();
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        UnifiedAccount * unified = new UnifiedAccount();
        unified->setAccounts(Array::arrayWithObject(account));
        mAccounts->addObject(unified);
        MC_SAFE_RELEASE(unified);

        accounts->addObject(account);
    }

    MC_SAFE_RELEASE(accountHash);
    MC_SAFE_RELEASE(_unifiedAccount);
    if (accounts->count() > 0) {
        _unifiedAccount = new UnifiedAccount();
        _unifiedAccount->setAccounts(accounts);
    }
    MC_SAFE_RELEASE(accounts);

    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedAccountManagerObserver * observer = (UnifiedAccountManagerObserver *) carray_get(mObservers, i);
        observer->unifiedAccountManagerChanged(this);
    }
}
