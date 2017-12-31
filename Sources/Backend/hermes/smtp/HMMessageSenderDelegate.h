// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMMessageSenderDelegate_h
#define dejalu_HMMessageSenderDelegate_h

#include "HMConstants.h"

#ifdef __cplusplus

namespace hermes {

    class SMTPAccountSender;
    class MessageSender;

    class MessageSenderDelegate {
    public:
        virtual void messageSenderSendDone(MessageSender * sender) {}

        virtual void messageSenderProgress(MessageSender * sender,
                                           unsigned int current, unsigned int maximum) {}

        virtual void messageSenderAccountInfoChanged(MessageSender * sender) {}

        virtual SMTPAccountSender * messageSenderAccountSender(MessageSender * sender) { return NULL; }
    };
    
}

#endif

#endif
