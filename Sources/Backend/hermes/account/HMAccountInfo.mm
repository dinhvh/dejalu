// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMAccountInfo.h"

#include "HMIMAPAccountInfo.h"
#include "HMSMTPAccountInfo.h"
#include "HMKeychain.h"

#import <WebKit/WebKit.h>

using namespace mailcore;
using namespace hermes;

AccountInfo::AccountInfo()
{
    mDisplayName = NULL;
    mEmail = NULL;
    mOAuth2RefreshToken = NULL;
    mPassword = NULL;
    mProviderIdentifier = NULL;
    mLoadedPassword = false;
    mLoadedOAuth2RefreshToken = false;
    mAliases = NULL;
    mDefaultAlias = NULL;
    mImapInfo = new IMAPAccountInfo();
    mSmtpInfo = new SMTPAccountInfo();
    mSignatures = new HashMap();
    mFavoriteFolders = NULL;
    mHasSeparatePassword = false;
}

AccountInfo::~AccountInfo()
{
    MC_SAFE_RELEASE(mFavoriteFolders);
    MC_SAFE_RELEASE(mSignatures);
    MC_SAFE_RELEASE(mOAuth2RefreshToken);
    MC_SAFE_RELEASE(mSmtpInfo);
    MC_SAFE_RELEASE(mImapInfo);
    MC_SAFE_RELEASE(mDefaultAlias);
    MC_SAFE_RELEASE(mAliases);
    MC_SAFE_RELEASE(mProviderIdentifier);
    MC_SAFE_RELEASE(mPassword);
    MC_SAFE_RELEASE(mEmail);
    MC_SAFE_RELEASE(mDisplayName);
}

void AccountInfo::importSerializable(mailcore::HashMap * serializable)
{
    setDisplayName((String *) serializable->objectForKey(MCSTR("displayName")));
    setEmail((String *) serializable->objectForKey(MCSTR("email")));
    setProviderIdentifier((String *) serializable->objectForKey(MCSTR("providerIdentifier")));
    if (serializable->objectForKey(MCSTR("aliases")) != NULL) {
        Array * aliases = Array::array();
        mc_foreacharray(HashMap, item, (Array *) serializable->objectForKey(MCSTR("aliases"))) {
            Address * address = Address::addressWithDisplayName((String *) item->objectForKey(MCSTR("displayName")),
                                                                (String *) item->objectForKey(MCSTR("email")));
            aliases->addObject(address);
        }
        setAliases(aliases);
    }
    setDefaultAlias((String *) serializable->objectForKey(MCSTR("defaultAlias")));
    mImapInfo->setProviderIdentifier(providerIdentifier());
    mSmtpInfo->setProviderIdentifier(providerIdentifier());
    mImapInfo->setEmail(email());
    mSmtpInfo->setEmail(email());
    mImapInfo->setUsername(email());
    mSmtpInfo->setUsername(email());
    if (providerIdentifier() != NULL) {
        String * passwordString = password();
        mImapInfo->setPassword(passwordString);
        mSmtpInfo->setPassword(passwordString);
        String * refreshToken = OAuth2RefreshToken();
        mImapInfo->setOAuth2RefreshToken(refreshToken);
        mSmtpInfo->setOAuth2RefreshToken(refreshToken);
    }
    if (serializable->objectForKey(MCSTR("imapInfo")) != NULL) {
        mImapInfo->importSerializable((HashMap *) serializable->objectForKey(MCSTR("imapInfo")));
    }
    mSmtpInfo->importSerializable((HashMap *) serializable->objectForKey(MCSTR("smtpInfo")));
    {
        mc_foreachhashmapKeyAndValue(String, email, String, signatureBase64Data, (HashMap *) serializable->objectForKey(MCSTR("signatures"))) {
            mSignatures->setObjectForKey(email, signatureBase64Data->decodedBase64Data());
        }
    }
    if (serializable->objectForKey(MCSTR("favoriteFolders")) != NULL) {
        setFavoriteFolders((Array *) serializable->objectForKey(MCSTR("favoriteFolders")));
    }
}

mailcore::HashMap * AccountInfo::serializable()
{
    HashMap * info = HashMap::hashMap();
    if (displayName() != NULL) {
        info->setObjectForKey(MCSTR("displayName"), displayName());
    }
    if (email() != NULL) {
        info->setObjectForKey(MCSTR("email"), email());
    }
    if (providerIdentifier() != NULL) {
        info->setObjectForKey(MCSTR("providerIdentifier"), providerIdentifier());
    }
    if (hasSeparatePassword()) {
        info->setObjectForKey(MCSTR("separatePasswords"), Value::valueWithBoolValue(true));
    }
    if (aliases() != NULL) {
        Array * serializedAliases = Array::array();
        mc_foreacharray(Address, address, aliases()) {
            HashMap * item = HashMap::hashMap();
            if (address->displayName() != NULL) {
                item->setObjectForKey(MCSTR("displayName"), address->displayName());
            }
            if (address->mailbox() != NULL) {
                item->setObjectForKey(MCSTR("email"), address->mailbox());
            }
            serializedAliases->addObject(item);
        }
        info->setObjectForKey(MCSTR("aliases"), serializedAliases);
    }
    if (defaultAlias() != NULL) {
        info->setObjectForKey(MCSTR("defaultAlias"), defaultAlias());
    }
    info->setObjectForKey(MCSTR("imapInfo"), mImapInfo->serializable());
    info->setObjectForKey(MCSTR("smtpInfo"), mSmtpInfo->serializable());
    HashMap * serializedSignature = HashMap::hashMap();
    mc_foreachhashmapKeyAndValue(String, email, Data, signatureData, mSignatures) {
        serializedSignature->setObjectForKey(email, signatureData->base64String());
    }
    info->setObjectForKey(MCSTR("signatures"), serializedSignature);
    if (favoriteFolders() != NULL) {
        info->setObjectForKey(MCSTR("favoriteFolders"), favoriteFolders());
    }
    return info;
}

bool AccountInfo::load(mailcore::String * path)
{
    Data * data = Data::dataWithContentsOfFile(path);
    if (data == NULL) {
        return false;
    }
    HashMap * info = (HashMap *) JSON::objectFromJSONData(data);
    if (info == NULL) {
        return false;
    }
    importSerializable(info);

    return true;
}

void AccountInfo::save(mailcore::String * path)
{
    HashMap * info = serializable();
    Data * data = JSON::objectToJSONData(info);
    data->writeToFile(path);
}

void AccountInfo::setDisplayName(mailcore::String * displayName)
{
    MC_SAFE_REPLACE_COPY(String, mDisplayName, displayName);
}

mailcore::String * AccountInfo::displayName()
{
    return mDisplayName;
}

void AccountInfo::setEmail(mailcore::String * email)
{
    MC_SAFE_REPLACE_COPY(String, mEmail, email);
    mImapInfo->setEmail(email);
    mSmtpInfo->setEmail(email);
}

mailcore::String * AccountInfo::email()
{
    return mEmail;
}

void AccountInfo::setPassword(mailcore::String * password)
{
    MC_SAFE_REPLACE_COPY(String, mPassword, password);
    mLoadedPassword = true;
    savePasswordToKeychain();
    if (providerIdentifier() != NULL) {
        mImapInfo->setPassword(password);
        mSmtpInfo->setPassword(password);
    }
}

mailcore::String * AccountInfo::password()
{
    if (!mLoadedPassword) {
        readPasswordFromKeychain();
    }
    return mPassword;
}

void AccountInfo::setOAuth2RefreshToken(mailcore::String * refreshToken)
{
    MC_SAFE_REPLACE_COPY(String, mOAuth2RefreshToken, refreshToken);
    mLoadedOAuth2RefreshToken = true;
    saveOAuth2RefreshTokenToKeychain();
    mImapInfo->setOAuth2RefreshToken(refreshToken);
    mSmtpInfo->setOAuth2RefreshToken(refreshToken);
}

mailcore::String * AccountInfo::OAuth2RefreshToken()
{
    if (!mLoadedOAuth2RefreshToken) {
        readOAuth2RefreshTokenFromKeychain();
    }
    return mOAuth2RefreshToken;
}

void AccountInfo::setProviderIdentifier(mailcore::String * provider)
{
    MC_SAFE_REPLACE_COPY(String, mProviderIdentifier, provider);
    mImapInfo->setProviderIdentifier(provider);
    mSmtpInfo->setProviderIdentifier(provider);
}

mailcore::String * AccountInfo::providerIdentifier()
{
    return mProviderIdentifier;
}

IMAPAccountInfo * AccountInfo::imapInfo()
{
    return mImapInfo;
}

SMTPAccountInfo * AccountInfo::smtpInfo()
{
    return mSmtpInfo;
}

void AccountInfo::readPasswordFromKeychain()
{
    String * password = hermes::keychainRetrieve(MCSTR("me.dejalu.password"), mEmail);
    MC_SAFE_REPLACE_COPY(String, mPassword, password);
}

void AccountInfo::savePasswordToKeychain()
{
    if (mPassword != NULL) {
        String * description = String::stringWithUTF8Format("Authentication Information (%s)", MCUTF8(mEmail));
        hermes::keychainSave(MCSTR("me.dejalu.password"), mEmail, mPassword, description);
    }
}

void AccountInfo::readOAuth2RefreshTokenFromKeychain()
{
    String * password = hermes::keychainRetrieve(MCSTR("me.dejalu.oauth2-refresh-token"), mEmail);
    MC_SAFE_REPLACE_COPY(String, mOAuth2RefreshToken, password);
}

void AccountInfo::saveOAuth2RefreshTokenToKeychain()
{
    if (mOAuth2RefreshToken != NULL) {
        String * description = String::stringWithUTF8Format("Authentication Information (%s)", MCUTF8(mEmail));
        hermes::keychainSave(MCSTR("me.dejalu.oauth2-refresh-token"), mEmail, mOAuth2RefreshToken, description);
    }
}

void AccountInfo::setAliases(mailcore::Array * /* Address */ aliases)
{
    MC_SAFE_REPLACE_RETAIN(Array, mAliases, aliases);
}

mailcore::Array * /* Address */ AccountInfo::aliases()
{
    return mAliases;
}

void AccountInfo::setDefaultAlias(mailcore::String * email)
{
    MC_SAFE_REPLACE_COPY(String, mDefaultAlias, email);
}

mailcore::String * AccountInfo::defaultAlias()
{
    return mDefaultAlias;
}

mailcore::Data * AccountInfo::signatureForEmail(mailcore::String * email)
{
    Data * signature = (Data *) mSignatures->objectForKey(email);
    if (signature == NULL && email->isEqual(mEmail)) {
        String * signatureString = MCSTR("<div>--&nbsp;</div><div>Sent with <a href=\"https://dejalu.me?sig\">DejaLu</a></div>");
        Data * signatureMainData = signatureString->dataUsingEncoding("utf-8");
        WebResource * mainResource = [[WebResource alloc] initWithData:MCO_TO_OBJC(signatureMainData)
                                                                   URL:[NSURL fileURLWithPath:@"/"]
                                                              MIMEType:@"text/html"
                                                      textEncodingName:@"utf-8"
                                                             frameName:nil];
        WebArchive * archive = [[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil];
        signature = MCO_FROM_OBJC(Data, [archive data]);
    }
    else if (signature == NULL) {
        return signatureForEmail(mEmail);
    }
    return signature;
}

void AccountInfo::setEmailSignature(mailcore::String * email, mailcore::Data * data)
{
    if (data == NULL) {
        mSignatures->removeObjectForKey(email);
    }
    else {
        mSignatures->setObjectForKey(email, data);
    }
}

mailcore::Array * /* String */ AccountInfo::favoriteFolders()
{
    return mFavoriteFolders;
}

void AccountInfo::setFavoriteFolders(mailcore::Array * /* String */ favoriteFolders)
{
    MC_SAFE_REPLACE_COPY(Array, mFavoriteFolders, favoriteFolders);
}

void AccountInfo::setHasSeparatePassword(bool hasSeparatePassword)
{
    mHasSeparatePassword = hasSeparatePassword;
    mImapInfo->setHasSeparatePassword(hasSeparatePassword);
    mSmtpInfo->setHasSeparatePassword(hasSeparatePassword);
}

bool AccountInfo::hasSeparatePassword()
{
    return mHasSeparatePassword;
}
