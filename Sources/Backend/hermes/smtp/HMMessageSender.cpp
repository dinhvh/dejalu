// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMessageSender.h"

#include "HMSMTPAccountInfo.h"
#include "HMMessageSenderDelegate.h"
#include "HMSMTPAccountSender.h"
#include "HMUtils.h"

#include "DJLLog.h"

using namespace hermes;
using namespace mailcore;

enum {
    CONNECTION_STATE_SHOULD_RETRY,
    CONNECTION_STATE_SHOULD_AUTODETECT,
    CONNECTION_STATE_SHOULD_FAIL,
};

MessageSender::MessageSender()
{
    mAccountInfo = NULL;
    mDelegate = NULL;
    mError = hermes::ErrorNone;
    mValidator = NULL;
    mFilename = NULL;
    mConnectionErrorCount = 0;
    mAuthenticationErrorCount = 0;
    mConnectionRetryState = CONNECTION_STATE_SHOULD_RETRY;
}

MessageSender::~MessageSender()
{
    MC_SAFE_RELEASE(mAccountInfo);
    MC_SAFE_RELEASE(mValidator);
    MC_SAFE_RELEASE(mFilename);
}

void MessageSender::setAccountInfo(SMTPAccountInfo * info)
{
    MC_SAFE_REPLACE_RETAIN(SMTPAccountInfo, mAccountInfo, info);
}

MessageSenderDelegate * MessageSender::delegate()
{
    return mDelegate;
}

void MessageSender::setDelegate(MessageSenderDelegate * delegate)
{
    mDelegate = delegate;
}

hermes::ErrorCode MessageSender::error()
{
    return mError;
}

SMTPAccountInfo * MessageSender::accountInfo()
{
    return mAccountInfo;
}

void MessageSender::sendMessage(mailcore::String * filename)
{
    MC_SAFE_REPLACE_COPY(String, mFilename, filename);
    trySendMessage();
}

void MessageSender::trySendMessage()
{
    retain();
    SMTPAccountSender * sender = delegate()->messageSenderAccountSender(this);
    sender->setDelegate(this);
    sender->sendMessage(mFilename);
}

void MessageSender::accountSenderMessageSendDone(SMTPAccountSender * sender,
                                                 hermes::ErrorCode code)
{
    if (code != hermes::ErrorNone) {
        mError = code;
        handleError();
        release();
        return;
    }

    mError = code;
    delegate()->messageSenderSendDone(this);
    release();
}

void MessageSender::accountSenderProgress(SMTPAccountSender * sender,
                                          unsigned int current, unsigned int maximum)
{
    delegate()->messageSenderProgress(this, current, maximum);
}

void MessageSender::handleError()
{
    if (isAuthenticationError(mError)) {
        if (mAccountInfo->OAuth2Token() != NULL) {
            LOG_ERROR("%s: oauth authentication error: %i", MCUTF8(mAccountInfo->email()), mError);
            handleOAuth2Error(mError);
        }
        else {
            LOG_ERROR("%s: authentication error: %i", MCUTF8(mAccountInfo->email()), mError);
            authenticationError(mError);
        }
        return;
    }
    else if (isFatalError(mError)) {
        fatalError(mError);
        return;
    }
    else if (isSendError(mError)) {
        sendError(mError);
        return;
    }

    if (mConnectionErrorCount == 0) {
        mConnectionRetryState = CONNECTION_STATE_SHOULD_RETRY;
    }

    mConnectionErrorCount = 1;
    // retry once.
    // then, try to autodetect.
    // then, fail.
    switch (mConnectionRetryState) {
        case CONNECTION_STATE_SHOULD_RETRY:
        {
            LOG_ERROR("%s: connection error, retry", MCUTF8(mAccountInfo->email()));
            if (mAccountInfo->providerIdentifier() == NULL) {
                mConnectionRetryState = CONNECTION_STATE_SHOULD_FAIL;
            }
            else {
                mConnectionRetryState = CONNECTION_STATE_SHOULD_AUTODETECT;
            }
            SMTPAccountSender * sender = delegate()->messageSenderAccountSender(this);
            sender->disconnect();

            trySendMessage();
            break;
        }
        case CONNECTION_STATE_SHOULD_AUTODETECT:
        {
            LOG_ERROR("%s: connection error, autodetect", MCUTF8(mAccountInfo->email()));
            mConnectionRetryState = CONNECTION_STATE_SHOULD_FAIL;
            SMTPAccountSender * sender = delegate()->messageSenderAccountSender(this);
            sender->disconnect();

            autodetect();
            break;
        }
        case CONNECTION_STATE_SHOULD_FAIL:
        {
            LOG_ERROR("%s: connection error, failed", MCUTF8(mAccountInfo->email()));
            SMTPAccountSender * sender = delegate()->messageSenderAccountSender(this);
            sender->disconnect();

            connectionError(mError);
            break;
        }
    }
}

void MessageSender::autodetect()
{
    retain();
    mValidator = new AccountValidator();
    mValidator->setEmail(mAccountInfo->email());
    mValidator->setUsername(mAccountInfo->username());
    mValidator->setPassword(mAccountInfo->password());
    mValidator->setOAuth2Token(mAccountInfo->OAuth2Token());
    LOG_ERROR("%s: autodetect account: %s %s %s\n", MCUTF8(mAccountInfo->email()), MCUTF8(mAccountInfo->username()), MCUTF8(mAccountInfo->password()), MCUTF8(mAccountInfo->OAuth2Token()));
    mValidator->setSmtpEnabled(true);
    mValidator->setCallback(this);

    mValidator->start();
}

void MessageSender::autodetectDone()
{
    if (mValidator->smtpError() != mailcore::ErrorNone) {
        mError = (hermes::ErrorCode) mValidator->smtpError();
        MC_SAFE_RELEASE(mValidator);

        handleError();

        release();
        return;
    }

    // Not sure why it is happening.
    if (mValidator->smtpServer() == NULL) {
        mError = ErrorNoValidServerFound;
        MC_SAFE_RELEASE(mValidator);

        handleError();

        release();
        return;
    }

    SMTPAccountInfo * accountInfo = (SMTPAccountInfo *) mAccountInfo->copy();
    LOG_ERROR("%s: found %s:%i\n", MCUTF8(mAccountInfo->email()), MCUTF8(mValidator->smtpServer()->hostname()), mValidator->smtpServer()->port());
    accountInfo->setHostname(mValidator->smtpServer()->hostname());
    accountInfo->setPort(mValidator->smtpServer()->port());
    accountInfo->setConnectionType(mValidator->smtpServer()->connectionType());
    MC_SAFE_REPLACE_COPY(SMTPAccountInfo, mAccountInfo, accountInfo);
    delegate()->messageSenderAccountInfoChanged(this);

    MC_SAFE_RELEASE(mValidator);

    trySendMessage();
    release();
}

void MessageSender::fatalError(hermes::ErrorCode error)
{
    //mDelegate->messageSenderNotifyFatalError(this, error);
    mError = error;
    delegate()->messageSenderSendDone(this);
}

void MessageSender::handleOAuth2Error(hermes::ErrorCode error)
{
    if (mAuthenticationErrorCount == 0) {
        LOG_ERROR("retry OAuth2 authentication");
        mAuthenticationErrorCount = 1;
        SMTPAccountSender * sender = delegate()->messageSenderAccountSender(this);
        sender->disconnect();
        trySendMessage();
    }
    else {
        LOG_ERROR("authentication failed");
        authenticationError(error);
    }
}

void MessageSender::authenticationError(hermes::ErrorCode error)
{
    //mDelegate->messageSenderNotifyAuthenticationError(this, error);
    mError = error;
    delegate()->messageSenderSendDone(this);
}

void MessageSender::connectionError(hermes::ErrorCode error)
{
    //fprintf(stderr, "connection error!\n");
    //mDelegate->messageSenderNotifyConnectionError(this, error);
    mError = error;
    delegate()->messageSenderSendDone(this);
}

void MessageSender::sendError(hermes::ErrorCode error)
{
    //fprintf(stderr, "send error!\n");
    //mDelegate->messageSenderNotifyConnectionError(this, error);
    mError = error;
    delegate()->messageSenderSendDone(this);
}

void MessageSender::operationFinished(Operation * op)
{
    autodetectDone();
}
