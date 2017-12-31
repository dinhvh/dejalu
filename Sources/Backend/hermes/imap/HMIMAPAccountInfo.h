// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPAccountInfo__
#define __dejalu__HMIMAPAccountInfo__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class IMAPAccountInfo : public mailcore::Object {

    public:
        IMAPAccountInfo();
        virtual ~IMAPAccountInfo();

        virtual void setProviderIdentifier(mailcore::String * provider);
        virtual mailcore::String * providerIdentifier();

        virtual void setHostname(mailcore::String * hostname);
        virtual mailcore::String * hostname();

        virtual void setPort(unsigned int port);
        virtual unsigned int port();

        virtual void setConnectionType(mailcore::ConnectionType type);
        virtual mailcore::ConnectionType connectionType();

        virtual void setEmail(mailcore::String * email);
        virtual mailcore::String * email();

        virtual void setUsername(mailcore::String * username);
        virtual mailcore::String * username();

        virtual void setPassword(mailcore::String * password);
        virtual mailcore::String * password();

        virtual void setOAuth2Token(mailcore::String * OAuth2Token);
        virtual mailcore::String * OAuth2Token();

        virtual void setOAuth2RefreshToken(mailcore::String * refreshToken);
        virtual mailcore::String * OAuth2RefreshToken();

        virtual void setHasSeparatePassword(bool hasSeparatePassword);
        virtual bool hasSeparatePassword();
        
    public: // subclass behavior
        IMAPAccountInfo(IMAPAccountInfo * other);
        virtual Object * copy();
        virtual mailcore::HashMap * serializable();
        virtual void importSerializable(mailcore::HashMap * serializable);

    private:
        mailcore::String * mProviderIdentifier;
        mailcore::String * mHostname;
        unsigned int mPort;
        mailcore::ConnectionType mConnectionType;
        mailcore::String * mEmail;
        mailcore::String * mUsername;
        mailcore::String * mPassword;
        mailcore::String * mOAuth2Token;
        mailcore::String * mOAuth2RefreshToken;
        bool mLoadedPassword;
        bool mHasSeparatePassword;

        void init();
        void readPasswordFromKeychain();
        void savePasswordToKeychain();
    };
}

#endif

#endif /* defined(__dejalu__HMIMAPAccountInfo__) */
