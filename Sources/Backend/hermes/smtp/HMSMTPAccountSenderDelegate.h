// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMSMTPAccountSenderDelegate__
#define __dejalu__HMSMTPAccountSenderDelegate__

#include "HMConstants.h"

#ifdef __cplusplus

namespace hermes {

    class SMTPAccountSender;

    class SMTPAccountSenderDelegate {
    public:
        virtual void accountSenderMessageSendDone(SMTPAccountSender * sender,
                                                  hermes::ErrorCode code) {}

        virtual void accountSenderProgress(SMTPAccountSender * sender,
                                           unsigned int current, unsigned int maximum) {}
    };

}

#endif

#endif /* defined(__dejalu__HMSMTPAccountSenderDelegate__) */
