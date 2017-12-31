// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMSMTPAccountSender.h"

#include <libetpan/libetpan.h>
#include <sys/stat.h>

#include "HMSMTPAccountSenderDelegate.h"
#include "HMSMTPAccountInfo.h"
#include "HMConstants.h"
#include "HMOAuth2.h"

#include "DJLLog.h"

using namespace hermes;
using namespace mailcore;

SMTPAccountSender::SMTPAccountSender()
{
    mDelegate = NULL;
    mSession = NULL;
    mOperation = NULL;
    mAccountInfo = NULL;
    mSending = false;
    mFilename = NULL;
    mPath = NULL;
    mSettingUpSession = false;
    mRetrieveAuth2TokenTries = 0;
    pthread_mutex_init(&mProtocolLogFileLock, NULL);
    mProtocolLogFiles = chash_new(CHASH_DEFAULTSIZE, CHASH_COPYKEY);
    mLogEnabled = false;
}

SMTPAccountSender::~SMTPAccountSender()
{
    MC_SAFE_RELEASE(mPath);
    MC_SAFE_RELEASE(mFilename);
    MC_SAFE_RELEASE(mAccountInfo);
    MC_SAFE_RELEASE(mOperation);
    if (mSession != NULL) {
        mSession->setConnectionLogger(NULL);
    }
    MC_SAFE_RELEASE(mSession);
    chash_free(mProtocolLogFiles);
    pthread_mutex_destroy(&mProtocolLogFileLock);
}

void SMTPAccountSender::setPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mPath, path);
}

String * SMTPAccountSender::path()
{
    return mPath;
}

void SMTPAccountSender::setAccountInfo(SMTPAccountInfo * info)
{
    MC_SAFE_REPLACE_RETAIN(SMTPAccountInfo, mAccountInfo, info);
}

SMTPAccountInfo * SMTPAccountSender::accountInfo()
{
    return mAccountInfo;
}

void SMTPAccountSender::setDelegate(SMTPAccountSenderDelegate * delegate)
{
    mDelegate = delegate;
}

SMTPAccountSenderDelegate * SMTPAccountSender::delegate()
{
    return mDelegate;
}

void SMTPAccountSender::setLogEnabled(bool enabled)
{
    pthread_mutex_lock(&mProtocolLogFileLock);
    mLogEnabled = enabled;
    pthread_mutex_unlock(&mProtocolLogFileLock);
}

void SMTPAccountSender::setupSession()
{
    if (mSession != NULL) {
        sendMessageSetupSessionDone(hermes::ErrorNone);
        return;
    }

    if (mSettingUpSession) {
        LOG_ERROR("%s: setup session while setup session is not progress", MCUTF8(mAccountInfo->email()));
        return;
    }

    mSettingUpSession = true;
    mRetrieveAuth2TokenTries = 0;
    retain();
    LOG_ERROR("%s: getting oauth token", MCUTF8(mAccountInfo->email()));
    if (accountInfo()->password() != NULL) {
        setupSessionWithPassword();
    }
    else {
        retrieveOAuth2Token();
    }
}

void SMTPAccountSender::retrieveOAuth2Token()
{
    mRetrieveAuth2TokenTries ++;
    LOG_ERROR("%s: getting oauth2 token", MCUTF8(mAccountInfo->email()));
    //OAuth2GetTokenForEmail(accountInfo()->email(), &oauth2GetTokenCallback, (void *) this);
    OAuth2GetToken(accountInfo()->OAuth2RefreshToken(), accountInfo()->providerIdentifier(), &oauth2GetTokenCallback, (void *) this);
}

void SMTPAccountSender::oauth2GetTokenCallback(hermes::ErrorCode code, mailcore::String * oauth2Token, void * data)
{
    SMTPAccountSender * sender = (SMTPAccountSender *) data;
    LOG_ERROR("%s: got oauth2 token %i %s", MCUTF8(sender->mAccountInfo->email()), code, MCUTF8(oauth2Token));

    if ((code == ErrorConnection) && (sender->mRetrieveAuth2TokenTries <= 1)) {
        LOG_ERROR("%s: retry getting oauth2 token", MCUTF8(sender->mAccountInfo->email()));
        sender->retrieveOAuth2Token();
        return;
    }

    sender->setupSessionDone(code, oauth2Token);
}

void SMTPAccountSender::setupSessionDone(hermes::ErrorCode code, mailcore::String * oauth2Token)
{
    mSettingUpSession = false;

    if (code != hermes::ErrorNone) {
        sendMessageSetupSessionDone(code);
        release();
        return;
    }

    mAccountInfo->setOAuth2Token(oauth2Token);

    LOG_ERROR("%s: set up session", MCUTF8(mAccountInfo->email()));

    mSession = new SMTPAsyncSession();
    mSession->setHostname(mAccountInfo->hostname());
    mSession->setPort(mAccountInfo->port());
    mSession->setConnectionType(mAccountInfo->connectionType());
    mSession->setUsername(mAccountInfo->username());
    //mSession->setPassword(mAccountInfo->password());
    mSession->setOAuth2Token(oauth2Token);
    mSession->setAuthType(AuthTypeXOAuth2);
    mSession->setConnectionLogger(this);

    sendMessageSetupSessionDone(hermes::ErrorNone);

    release();
}

void SMTPAccountSender::setupSessionWithPassword()
{
    mSettingUpSession = false;

    LOG_ERROR("%s: set up session", MCUTF8(mAccountInfo->email()));

    mSession = new SMTPAsyncSession();
    mSession->setHostname(mAccountInfo->hostname());
    mSession->setPort(mAccountInfo->port());
    mSession->setConnectionType(mAccountInfo->connectionType());
    mSession->setUsername(mAccountInfo->username());
    mSession->setPassword(mAccountInfo->password());
    mSession->setAuthType(AuthTypeSASLNone);
    mSession->setConnectionLogger(this);

    sendMessageSetupSessionDone(hermes::ErrorNone);

    release();
}

void SMTPAccountSender::sendMessage(mailcore::String * filename)
{
    MCAssert(!mSending);

    mSending = true;

    retain();

    MC_SAFE_REPLACE_COPY(String, mFilename, filename);
    setupSession();
}

void SMTPAccountSender::sendMessageSetupSessionDone(hermes::ErrorCode error)
{
    if (error != ErrorNone) {
        mSending = false;
        mDelegate->accountSenderMessageSendDone(this, error);
        release();
        return;
    }

    Data * messageData = Data::dataWithContentsOfFile(mFilename);
    if (messageData == NULL) {
        LOG_ERROR("%s: message disappeared", MCUTF8(mAccountInfo->email()));
        mSending = false;
        mDelegate->accountSenderMessageSendDone(this, hermes::ErrorNone);
        release();
        return;
    }

    mOperation = mSession->sendMessageOperation(messageData);
    mOperation->retain();
    mOperation->setCallback(this);
    mOperation->setSmtpCallback(this);
    mOperation->start();

    MC_SAFE_RELEASE(mFilename);
}

void SMTPAccountSender::bodyProgress(SMTPOperation * session, unsigned int current, unsigned int maximum)
{
    mDelegate->accountSenderProgress(this, current, maximum);
}

void SMTPAccountSender::operationFinished(Operation * op)
{
    mSending = false;
    hermes::ErrorCode error = (hermes::ErrorCode) mOperation->error();
    MC_SAFE_RELEASE(mOperation);
    mDelegate->accountSenderMessageSendDone(this, error);
    release();
}

void SMTPAccountSender::disconnect()
{
    if (mSession == NULL) {
        return;
    }
    SMTPOperation * op = mSession->disconnectOperation();
    op->start();
    if (mSession != NULL) {
        mSession->setConnectionLogger(NULL);
    }
    pthread_mutex_lock(&mProtocolLogFileLock);
    chashiter * iter = chash_begin(mProtocolLogFiles);
    while (iter != NULL) {
        chashdatum value;
        chash_value(iter, &value);
        FILE * f = (FILE *) value.data;
        fclose(f);
        iter = chash_next(mProtocolLogFiles, iter);
    }
    chash_clear(mProtocolLogFiles);
    pthread_mutex_unlock(&mProtocolLogFileLock);
    MC_SAFE_RELEASE(mSession);
}

void SMTPAccountSender::log(void * sender, ConnectionLogType logType, Data * buffer)
{
    bool enabled;
    pthread_mutex_lock(&mProtocolLogFileLock);
    enabled = mLogEnabled;
    pthread_mutex_unlock(&mProtocolLogFileLock);
    if (!enabled) {
        return;
    }

    if (logType != ConnectionLogTypeSentPrivate) {
        //initLog();

        pthread_mutex_lock(&mProtocolLogFileLock);
        chashdatum key;
        chashdatum value;
        struct timeval tv;
        struct tm tm_value;

        key.data = &sender;
        key.len = sizeof(sender);
        int r = chash_get(mProtocolLogFiles, &key, &value);
        FILE * f = NULL;
        if (r == 0) {
            f = (FILE *) value.data;
        }
        else {
            gettimeofday(&tv, NULL);
            localtime_r(&tv.tv_sec, &tm_value);
            char * dateBuffer = NULL;
            asprintf(&dateBuffer, "%04u-%02u-%02u--%02u:%02u", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min);

            String * path = String::stringWithUTF8Format("%s/%s/Logs", MCUTF8(mPath), MCUTF8(accountInfo()->email()), sender);
            mkdir(path->fileSystemRepresentation(), 0700);
            int count = 0;
            while (1) {
                struct stat statInfo;
                if (count == 0) {
                    path = String::stringWithUTF8Format("%s/%s/Logs/smtp-%s.log", MCUTF8(mPath), MCUTF8(accountInfo()->email()), dateBuffer);
                }
                else {
                    path = String::stringWithUTF8Format("%s/%s/Logs/smtp -%s-%i.log", MCUTF8(mPath), MCUTF8(accountInfo()->email()), dateBuffer, count);
                }
                if (stat(path->fileSystemRepresentation(), &statInfo) < 0) {
                    break;
                }
                count ++;
            }
            free(dateBuffer);

            f = fopen(path->fileSystemRepresentation(), "wb");
            value.data = f;
            value.len = 0;
            chash_set(mProtocolLogFiles, &key, &value, NULL);
        }

        gettimeofday(&tv, NULL);
        localtime_r(&tv.tv_sec, &tm_value);
        char * dateBuffer = NULL;
        asprintf(&dateBuffer, "%04u-%02u-%02u %02u:%02u:%02u.%03u", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min, tm_value.tm_sec, (int) (tv.tv_usec / 1000));

        HashMap * logInfo = new HashMap();
        if (buffer != NULL) {
            String * str = buffer->stringWithCharset("utf-8");
            if (str != NULL) {
                logInfo->setObjectForKey(MCSTR("data"), str);
            }
        }
        logInfo->setObjectForKey(MCSTR("date"), String::stringWithUTF8Characters(dateBuffer));
        free(dateBuffer);

        String * type = NULL;
        switch (logType) {
            case ConnectionLogTypeReceived:
                type = MCSTR("recv");
                break;
            case ConnectionLogTypeSent:
                type = MCSTR("sent");
                break;
            case ConnectionLogTypeSentPrivate:
                type = MCSTR("sentpriv");
                break;
            case ConnectionLogTypeErrorParse:
                type = MCSTR("errorparse");
                break;
            case ConnectionLogTypeErrorReceived:
                type = MCSTR("errorecv");
                break;
            case ConnectionLogTypeErrorSent:
                type = MCSTR("errorsent");
                break;
        }
        if (type != NULL) {
            logInfo->setObjectForKey(MCSTR("type"), type);
        }

        Data * json = JSON::objectToJSONData(logInfo);
        fwrite(json->bytes(), 1, json->length(), f);
        fputs("\n", f);
        MC_SAFE_RELEASE(logInfo);
        fflush(f);
        pthread_mutex_unlock(&mProtocolLogFileLock);
    }
}
