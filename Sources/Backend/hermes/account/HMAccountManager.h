// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMAccountManager_hpp
#define HMAccountManager_hpp

#include <stdio.h>

#include <MailCore/MailCore.h>

#include "HMAccountObserver.h"

#ifdef __cplusplus

namespace hermes {

    class AccountManagerObserver;
    class Account;

    class AccountManager : public mailcore::Object, public AccountObserver {

    public:
        static AccountManager * sharedManager();

        virtual void setLogEnabled(bool enabled);

        virtual void addObserver(AccountManagerObserver * observer);
        virtual void removeObserver(AccountManagerObserver * observer);

        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();

        virtual void setResetDB();
        virtual void save();
        virtual void load();

        virtual void addAccount(Account * account);
        virtual void moveAccountToIndex(Account * account, unsigned int idx);
        virtual void removeAccount(Account * account);

        virtual Account * accountForEmail(mailcore::String * email);

        virtual mailcore::Array * accounts();

    public: // Account observer
        virtual void accountFolderUnseenChanged(Account * account, mailcore::String * folderPath);
        virtual void accountNotifyUnreadEmail(Account * account, mailcore::String * folderPath);
        virtual void accountHasNewContacts(Account * account);

    private:
        AccountManager();
        ~AccountManager();

        bool mResetDB;
        carray * mObservers;
        mailcore::String * mPath;
        mailcore::Array * mAccounts;
        bool mLogEnabled;

        void loadAccount(mailcore::String * path, mailcore::Set * loaded);
    };

}

#endif

#endif /* HMAccountManager_hpp */
