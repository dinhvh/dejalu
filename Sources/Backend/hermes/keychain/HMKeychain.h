// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMKeychain_h
#define HMKeychain_h

#include <MailCore/MailCore.h>

namespace hermes {
    void keychainSave(mailcore::String * service, mailcore::String * account, mailcore::String * password, mailcore::String * label);
    mailcore::String * keychainRetrieve(mailcore::String * service, mailcore::String * account);
    void keychainRemove(mailcore::String * service, mailcore::String * account);

    void keychainServerSave(mailcore::String * hostname, mailcore::String * protocol, int port, mailcore::String * username, mailcore::String * password);
    mailcore::String * keychainServerRetrieve(mailcore::String * hostname, mailcore::String * protocol, int port, mailcore::String * username);
    void keychainServerRemove(mailcore::String * hostname, mailcore::String * protocol, int port, mailcore::String * username);
};

#endif /* HMKeychain_h */
