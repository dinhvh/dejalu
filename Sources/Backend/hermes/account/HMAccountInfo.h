// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMAccountInfo_hpp
#define HMAccountInfo_hpp

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class IMAPAccountInfo;
    class SMTPAccountInfo;

    class AccountInfo : public mailcore::Object {
    public:
        AccountInfo();
        virtual ~AccountInfo();

        virtual bool load(mailcore::String * path);
        virtual void save(mailcore::String * path);

        virtual void setDisplayName(mailcore::String * displayName);
        virtual mailcore::String * displayName();

        virtual void setEmail(mailcore::String * email);
        virtual mailcore::String * email();

        virtual void setProviderIdentifier(mailcore::String * provider);
        virtual mailcore::String * providerIdentifier();

        virtual void setPassword(mailcore::String * password);
        virtual mailcore::String * password();

        virtual void setOAuth2RefreshToken(mailcore::String * refreshToken);
        virtual mailcore::String * OAuth2RefreshToken();

        // name, email, default
        virtual void setAliases(mailcore::Array * /* Address */ aliases);
        virtual mailcore::Array * /* Address */ aliases();

        virtual void setDefaultAlias(mailcore::String * email);
        virtual mailcore::String * defaultAlias();

        virtual mailcore::Data * signatureForEmail(mailcore::String * email);
        virtual void setEmailSignature(mailcore::String * email, mailcore::Data * data);

        virtual mailcore::Array * /* String */ favoriteFolders();
        virtual void setFavoriteFolders(mailcore::Array * /* String */ favoriteFolders);

        virtual void setHasSeparatePassword(bool hasSeparatePassword);
        virtual bool hasSeparatePassword();

        virtual IMAPAccountInfo * imapInfo();
        virtual SMTPAccountInfo * smtpInfo();

        // serialization.
        virtual mailcore::HashMap * serializable();
        virtual void importSerializable(mailcore::HashMap * serializable);

    private:
        mailcore::String * mDisplayName;
        mailcore::String * mEmail;
        mailcore::String * mPassword;
        bool mLoadedPassword;
        mailcore::String * mOAuth2RefreshToken;
        bool mLoadedOAuth2RefreshToken;
        mailcore::String * mProviderIdentifier;
        IMAPAccountInfo * mImapInfo;
        SMTPAccountInfo * mSmtpInfo;
        mailcore::Array * mAliases;
        mailcore::String * mDefaultAlias;
        mailcore::HashMap * mSignatures;
        mailcore::Array * mFavoriteFolders;
        bool mHasSeparatePassword;

        void readPasswordFromKeychain();
        void savePasswordToKeychain();
        void readOAuth2RefreshTokenFromKeychain();
        void saveOAuth2RefreshTokenToKeychain();
    };

}

#endif

#endif /* HMAccountInfo_hpp */
