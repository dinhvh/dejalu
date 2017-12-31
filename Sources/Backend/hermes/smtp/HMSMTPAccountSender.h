// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMSMTPAccountSender__
#define __dejalu__HMSMTPAccountSender__

#include <libetpan/libetpan.h>
#include <MailCore/MailCore.h>

#include "HMConstants.h"

#ifdef __cplusplus

namespace hermes {

    // This class will send an email.

    class SMTPAccountSenderDelegate;
    class SMTPAccountInfo;

    class SMTPAccountSender : public mailcore::Object,
    public mailcore::OperationCallback,
    public mailcore::SMTPOperationCallback,
    public mailcore::ConnectionLogger {

    public:
        SMTPAccountSender();
        virtual ~SMTPAccountSender();

        virtual void setAccountInfo(SMTPAccountInfo * info);
        virtual SMTPAccountInfo * accountInfo();

        virtual void setDelegate(SMTPAccountSenderDelegate * delegate);
        virtual SMTPAccountSenderDelegate * delegate();

        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();

        virtual void setLogEnabled(bool enabled);

        virtual void sendMessage(mailcore::String * filename);

        virtual void disconnect();

    public: // implements OperationCallback
        virtual void operationFinished(mailcore::Operation * op);

    public: // implements SMTPOperationCallback
        void bodyProgress(mailcore::SMTPOperation * session, unsigned int current, unsigned int maximum);

    public: // implements ConnectionLogger
        virtual void log(void * sender, mailcore::ConnectionLogType logType, mailcore::Data * buffer);

    private:
        mailcore::SMTPAsyncSession * mSession;
        SMTPAccountSenderDelegate * mDelegate;
        mailcore::SMTPOperation * mOperation;
        SMTPAccountInfo * mAccountInfo;
        bool mSending;
        mailcore::String * mFilename;
        mailcore::String * mPath;
        bool mSettingUpSession;
        int mRetrieveAuth2TokenTries;
        pthread_mutex_t mProtocolLogFileLock;
        chash * mProtocolLogFiles;
        bool mLogEnabled;

        void setupSession();
        void setupSessionDone(hermes::ErrorCode error, mailcore::String * oauth2Token);
        void setupSessionWithPassword();
        void sendMessageSetupSessionDone(hermes::ErrorCode error);
        void processQueue();
        void retrieveOAuth2Token();
        static void oauth2GetTokenCallback(hermes::ErrorCode code, mailcore::String * oauth2Token, void * data);
    };

}

#endif

#endif /* defined(__dejalu__HMSMTPAccountSender__) */
