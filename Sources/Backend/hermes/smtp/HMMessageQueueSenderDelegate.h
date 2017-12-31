// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMMessageQueueSenderDelegate_h
#define dejalu_HMMessageQueueSenderDelegate_h

#ifdef __cplusplus

namespace hermes {

    class MessageQueueSender;

    class MessageQueueSenderDelegate {
    public:
        virtual void messageQueueSenderSendDone(MessageQueueSender * sender) {}
        virtual void messageQueueSenderSendingStateChanged(MessageQueueSender * sender) {}
        virtual void messageQueueSenderSent(MessageQueueSender * sender, mailcore::MessageParser * parsedMessage) {}
        virtual void messageQueueSenderAccountInfoChanged(MessageQueueSender * sender) {}
        virtual void messageQueueSenderProgress(MessageQueueSender * sender) {}

        virtual void messageQueueSenderNotifyAuthenticationError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
        virtual void messageQueueSenderNotifyConnectionError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
        virtual void messageQueueSenderNotifyFatalError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
        // There's an error with that specific message.
        virtual void messageQueueSenderNotifySendError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
    };
    
}

#endif

#endif
