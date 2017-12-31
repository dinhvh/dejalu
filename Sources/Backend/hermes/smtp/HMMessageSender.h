// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMessageSender__
#define __dejalu__HMMessageSender__

#include <MailCore/MailCore.h>

#include "HMConstants.h"
#include "HMSMTPAccountSenderDelegate.h"

#ifdef __cplusplus

namespace hermes {

    class IMAPAccountSynchronizer;
    class SMTPAccountSender;
    class SMTPAccountInfo;
    class MessageSenderDelegate;

    // This class will send an email and try to redetect the settings if it fails.

    class MessageSender : public mailcore::Object, public SMTPAccountSenderDelegate, public mailcore::OperationCallback {
        
    public:
        MessageSender();
        virtual ~MessageSender();

        virtual void setAccountInfo(SMTPAccountInfo * info);
        virtual SMTPAccountInfo * accountInfo();

        virtual void sendMessage(mailcore::String * filename);

        virtual MessageSenderDelegate * delegate();
        virtual void setDelegate(MessageSenderDelegate * delegate);

        virtual hermes::ErrorCode error();

    public: // SMTPAccountSenderDelegate
        virtual void accountSenderMessageSendDone(SMTPAccountSender * sender,
                                                  hermes::ErrorCode code);

        virtual void accountSenderProgress(SMTPAccountSender * sender,
                                           unsigned int current, unsigned int maximum);

    public: // OperationCallback
        virtual void operationFinished(mailcore::Operation * op);

    private:
        SMTPAccountInfo * mAccountInfo;
        MessageSenderDelegate * mDelegate;
        hermes::ErrorCode mError;
        mailcore::AccountValidator * mValidator;
        mailcore::String * mFilename;
        int mConnectionErrorCount;
        int mAuthenticationErrorCount;
        int mConnectionRetryState;

        void handleError();
        void autodetect();
        void autodetectDone();
        void trySendMessage();
        void fatalError(hermes::ErrorCode error);
        void handleOAuth2Error(hermes::ErrorCode error);
        void authenticationError(hermes::ErrorCode error);
        void connectionError(hermes::ErrorCode error);
        void sendError(hermes::ErrorCode error);
    };

    // 1. mark message as sending in progress
    // 1.bis. if offline, do nothing
    // 2. try to send
    // 2.bis.) on send success, unmark message as sending in progress, remove from drafts
    // 2.ter.) on send failure on well known errors, save to drafts, unmark message as sending in progress
    // 3. on send failure, autodetect
    // 3.bis) on autodetect failure, do nothing (similar to offline)
    // 4. if autodetect succeeded, try to send
    // 4.bis.) on send success, unmark message as sending in progress, remove from drafts
    // 5. if send failure, do nothing (similar to offline)
    // 5.ter.) on send failure on well known errors, save to drafts, unmark message as sending in progress
}

#endif

#endif /* defined(__dejalu__HMMessageSender__) */
