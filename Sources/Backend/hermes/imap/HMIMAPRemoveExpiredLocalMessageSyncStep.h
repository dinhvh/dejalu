// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPRemoveExpiredLocalMessageSyncStep__
#define __dejalu__HMIMAPRemoveExpiredLocalMessageSyncStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {

    class MailDBUidsOperation;

    class IMAPRemoveExpiredLocalMessageSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {

    public:
        IMAPRemoveExpiredLocalMessageSyncStep();
        virtual ~IMAPRemoveExpiredLocalMessageSyncStep();

        virtual void start();
        virtual void cancel();

    public:
        // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);

    private:
        mailcore::Operation * mRemoveExpiredLocalMessageOp;

        void removeExpiredLocalMessage();
        void removeExpiredLocalMessageDone();
    };

}

#endif

#endif /* defined(__dejalu__HMIMAPRemoveExpiredLocalMessageSyncStep__) */
