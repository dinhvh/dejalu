// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMSMTPAccountInfo.h"

#include "HMKeychain.h"

using namespace hermes;
using namespace mailcore;

void SMTPAccountInfo::init()
{
    mProviderIdentifier = NULL;
    mHostname = NULL;
    mPort = 465;
    mConnectionType = ConnectionTypeTLS;
    mEmail = NULL;
    mUsername = NULL;
    mPassword = NULL;
    mOAuth2Token = NULL;
    mOAuth2RefreshToken = NULL;
    mHasSeparatePassword = false;
}

SMTPAccountInfo::SMTPAccountInfo()
{
    init();
}

SMTPAccountInfo::SMTPAccountInfo(SMTPAccountInfo * other)
{
    init();
    setProviderIdentifier(other->providerIdentifier());
    setHostname(other->hostname());
    setPort(other->port());
    setConnectionType(other->connectionType());
    setEmail(other->email());
    setUsername(other->username());
    setPassword(other->password());
    setOAuth2Token(other->OAuth2Token());
    setOAuth2RefreshToken(other->OAuth2RefreshToken());
}

SMTPAccountInfo::~SMTPAccountInfo()
{
    MC_SAFE_RELEASE(mProviderIdentifier);
    MC_SAFE_RELEASE(mHostname);
    MC_SAFE_RELEASE(mEmail);
    MC_SAFE_RELEASE(mUsername);
    MC_SAFE_RELEASE(mPassword);
    MC_SAFE_RELEASE(mOAuth2Token);
    MC_SAFE_RELEASE(mOAuth2RefreshToken);
}

void SMTPAccountInfo::setProviderIdentifier(mailcore::String * provider)
{
    MC_SAFE_REPLACE_COPY(String, mProviderIdentifier, provider);
}

mailcore::String * SMTPAccountInfo::providerIdentifier()
{
    return mProviderIdentifier;
}

void SMTPAccountInfo::setHostname(mailcore::String * hostname)
{
    MC_SAFE_REPLACE_COPY(String, mHostname, hostname);
}

mailcore::String * SMTPAccountInfo::hostname()
{
    return mHostname;
}

void SMTPAccountInfo::setPort(unsigned int port)
{
    mPort = port;
}

unsigned int SMTPAccountInfo::port()
{
    return mPort;
}

void SMTPAccountInfo::setConnectionType(mailcore::ConnectionType type)
{
    mConnectionType = type;
}

mailcore::ConnectionType SMTPAccountInfo::connectionType()
{
    return mConnectionType;
}

void SMTPAccountInfo::setEmail(mailcore::String * email)
{
    MC_SAFE_REPLACE_COPY(String, mEmail, email);
}

mailcore::String * SMTPAccountInfo::email()
{
    return mEmail;
}

void SMTPAccountInfo::setUsername(mailcore::String * username)
{
    MC_SAFE_REPLACE_COPY(String, mUsername, username);
}

mailcore::String * SMTPAccountInfo::username()
{
    return mUsername;
}

void SMTPAccountInfo::setPassword(mailcore::String * password)
{
    MC_SAFE_REPLACE_COPY(String, mPassword, password);
    mLoadedPassword = true;
    savePasswordToKeychain();
}

mailcore::String * SMTPAccountInfo::password()
{
    if (!mLoadedPassword) {
        readPasswordFromKeychain();
    }
    return mPassword;
}

void SMTPAccountInfo::setOAuth2Token(mailcore::String * OAuth2Token)
{
    MC_SAFE_REPLACE_COPY(String, mOAuth2Token, OAuth2Token);
}

mailcore::String * SMTPAccountInfo::OAuth2Token()
{
    return mOAuth2Token;
}

void SMTPAccountInfo::setOAuth2RefreshToken(mailcore::String * refreshToken)
{
    MC_SAFE_REPLACE_COPY(String, mOAuth2RefreshToken, refreshToken);
}

mailcore::String * SMTPAccountInfo::OAuth2RefreshToken()
{
    return mOAuth2RefreshToken;
}

Object * SMTPAccountInfo::copy()
{
    return new SMTPAccountInfo(this);
}

mailcore::HashMap * SMTPAccountInfo::serializable()
{
    HashMap * info = HashMap::hashMap();
    if (hostname() != NULL) {
        info->setObjectForKey(MCSTR("hostname"), hostname());
    }
    info->setObjectForKey(MCSTR("port"), String::stringWithUTF8Format("%u", port()));
    String * connectionTypeStr = NULL;
    switch (connectionType()) {
        case ConnectionTypeClear:
        default:
            break;
        case ConnectionTypeStartTLS:
            connectionTypeStr = MCSTR("starttls");
            break;
        case ConnectionTypeTLS:
            connectionTypeStr = MCSTR("tls");
            break;
    }
    if (connectionTypeStr != NULL) {
        info->setObjectForKey(MCSTR("connectionType"), connectionTypeStr);
    }
    if (providerIdentifier() == NULL) {
        if (username() != NULL) {
            info->setObjectForKey(MCSTR("username"), username());
        }
    }
    return info;
}

void SMTPAccountInfo::importSerializable(mailcore::HashMap * serializable)
{
    setHostname((String *) serializable->objectForKey(MCSTR("hostname")));
    unsigned int port = 0;
    String * portStr = (String *) serializable->objectForKey(MCSTR("port"));
    if (portStr != NULL) {
        port = (unsigned int) strtoul(portStr->UTF8Characters(), NULL, 10);
    }
    setPort(port);
    ConnectionType connectionType = ConnectionTypeClear;
    String * connectionTypeStr = (String *) serializable->objectForKey(MCSTR("connectionType"));
    if (connectionTypeStr != NULL) {
        if (connectionTypeStr->isEqual(MCSTR("tls"))) {
            connectionType = ConnectionTypeTLS;
        }
        else if (connectionTypeStr->isEqual(MCSTR("starttls"))) {
            connectionType = ConnectionTypeStartTLS;
        }
    }
    setConnectionType(connectionType);
    if (providerIdentifier() == NULL) {
        setUsername((String *) serializable->objectForKey(MCSTR("username")));
    }
}

void SMTPAccountInfo::setHasSeparatePassword(bool hasSeparatePassword)
{
    mHasSeparatePassword = hasSeparatePassword;
}

bool SMTPAccountInfo::hasSeparatePassword()
{
    return mHasSeparatePassword;
}

void SMTPAccountInfo::readPasswordFromKeychain()
{
    String * protocol;
    if (connectionType() == ConnectionTypeTLS) {
        protocol = MCSTR("smtps");
    }
    else {
        protocol = MCSTR("smtp");
    }
    String * password = hermes::keychainServerRetrieve(hostname(), protocol, port(), username());
    MC_SAFE_REPLACE_COPY(String, mPassword, password);
}

void SMTPAccountInfo::savePasswordToKeychain()
{
    if (!mHasSeparatePassword) {
        return;
    }
    if (mPassword != NULL) {
        String * protocol;
        if (connectionType() == ConnectionTypeTLS) {
            protocol = MCSTR("smtps");
        }
        else {
            protocol = MCSTR("smtp");
        }
        hermes::keychainServerSave(hostname(), protocol, port(), username(), password());
    }
}
