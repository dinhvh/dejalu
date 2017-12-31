// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMUnifiedAccountManager_hpp
#define HMUnifiedAccountManager_hpp

#include <MailCore/MailCore.h>
#include <libetpan/libetpan.h>

#include "HMAccountManagerObserver.h"
#include "HMAccountObserver.h"

namespace hermes {

    class UnifiedAccountManagerObserver;
    class UnifiedAccount;

    class UnifiedAccountManager : public mailcore::Object, public AccountManagerObserver, public AccountObserver {

    public:
        static UnifiedAccountManager * sharedManager();

        virtual void addObserver(UnifiedAccountManagerObserver * observer);
        virtual void removeObserver(UnifiedAccountManagerObserver * observer);

        virtual UnifiedAccount * accountForEmail(mailcore::String * email);

        virtual UnifiedAccount * unifiedAccount();
        virtual mailcore::Array * /* UnifiedAccount */ accounts();

    public: // AccountManager observer
        virtual void accountManagerChanged(AccountManager * manager);

    public: // Account observer
        virtual void accountGotFolders(Account * account);

    private:
        UnifiedAccountManager();
        ~UnifiedAccountManager();
        void setupAccounts();

        carray * mObservers;
        mailcore::Array * mAccounts;
        UnifiedAccount * _unifiedAccount;
    };
    
}

#endif /* HMUnifiedAccountManager_hpp */
