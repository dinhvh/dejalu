// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMAccountManagerObserver_h
#define HMAccountManagerObserver_h

#ifdef __cplusplus

namespace hermes {

    class AccountManager;
    class Account;

    class AccountManagerObserver {
    public:
        virtual void accountManagerChanged(AccountManager * manager) {}
        virtual void accountManagerAccountUnseenChanged(AccountManager * manager) {}
        virtual void accountManagerNotifyUnreadEmail(AccountManager * manager, Account * account) {}
        virtual void accountManagerHasNewContacts(AccountManager * manager, Account * account) {}

    };

}

#endif

#endif /* HMAccountManagerObserver_h */
