// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMessageQueueSender__
#define __dejalu__HMMessageQueueSender__

#include <MailCore/MailCore.h>
#include "HMMessageSenderDelegate.h"
#include "HMConstants.h"
#include "HMReachabilityObserver.h"

#ifdef __cplusplus

namespace hermes {

    class IMAPAccountSynchronizer;
    class SMTPAccountInfo;
    class MessageSender;
    class SMTPAccountSender;
    class MessageQueueSenderDelegate;

    // This class manages the queue of emails.

    class MessageQueueSender : public mailcore::Object,
    public MessageSenderDelegate,
    public ReachabilityObserver {

    public:
        MessageQueueSender();
        virtual ~MessageQueueSender();

        virtual void setAccountInfo(SMTPAccountInfo * info);
        virtual SMTPAccountInfo * accountInfo();

        virtual void setIMAPAccountSynchronizer(IMAPAccountSynchronizer * imapSynchronizer);
        IMAPAccountSynchronizer * imapAccountSynchronizer();

        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();

        virtual MessageQueueSenderDelegate * delegate();
        virtual void setDelegate(MessageQueueSenderDelegate * delegate);

        virtual void setLogEnabled(bool enabled);
        
        virtual void loadQueueFromDisk();

        virtual void sendMessage(mailcore::String * draftMessageID, mailcore::Data * messageData);
        virtual void removeMessageWithDraftMessageID(mailcore::String * draftMessageID);

        virtual bool isSending();
        virtual unsigned int currentMessageIndex();
        virtual unsigned int totalMessagesCount();
        virtual unsigned int currentMessageProgress();
        virtual unsigned int currentMessageProgressMax();
        virtual mailcore::String * currentMessageSubject();

        virtual void setDeliveryEnabled(bool enabled);

    public: // SMTPMessageSenderDelegate
        virtual void messageSenderSendDone(MessageSender * sender);
        virtual void messageSenderAccountInfoChanged(MessageSender * sender);
        virtual SMTPAccountSender * messageSenderAccountSender(MessageSender * sender);
        virtual void messageSenderProgress(MessageSender * sender,
                                           unsigned int current, unsigned int maximum);

    public: // ReachabilityObserver
        virtual void reachabilityChanged(Reachability * reachability);

    private:
        SMTPAccountInfo * mAccountInfo;
        mailcore::String * mQueueFolder;
        mailcore::String * mPath;
        mailcore::Array * mQueue;
        IMAPAccountSynchronizer * mIMAPSynchronizer;
        bool mSending;
        bool mDeliveryEnabled;
        hermes::MessageSender * mSender;
        SMTPAccountSender * mSMTPAccountSender;
        MessageQueueSenderDelegate * mDelegate;
        bool mRetryLaterScheduled;
        unsigned int mProgressCurrentMessageIndex;
        unsigned int mProgressTotalMessagesCount;
        unsigned int mCurrentMessageProgress;
        unsigned int mCurrentMessageProgressMax;
        mailcore::String * mCurrentMessageSubject;
        bool mLogEnabled;

        void sendNextMessage();
        mailcore::String * queueFilename();
        void removeItemFromQueue();
        void addItemToQueue(mailcore::String * draftMessageID, mailcore::Data * messageData);
        void setupAccountSender();
        void saveQueueToDisk();
        void disableAndRetryLater();
        void retryLater(void * context);
        void cancelRetryLater();
        mailcore::MessageParser * currentParsedMessage();
    };
    
}

#endif

#endif /* defined(__dejalu__HMMessageQueueSender__) */
