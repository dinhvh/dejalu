// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMIMAPFetchNextSourceSyncStep_hpp
#define HMIMAPFetchNextSourceSyncStep_hpp

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {

    class MailDBUIDToFetchOperation;

    class IMAPFetchNextSourceSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
    public:
        IMAPFetchNextSourceSyncStep();
        virtual ~IMAPFetchNextSourceSyncStep();

        virtual void setMessageRowID(int64_t messageRowID);
        virtual int64_t messageRowID();

        virtual mailcore::Data * messageData();

        virtual void start();

    public: // override
        virtual void cancel();

    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);

    private:
        MailDBUIDToFetchOperation * mUidOp;
        mailcore::IMAPFetchContentOperation * mFetchOp;
        int64_t mMessageRowID;
        mailcore::Data * mMessageData;
        
        void uidFetched();
        void sourceFetched();
    };
    
}

#endif

#endif /* HMIMAPFetchNextSourceSyncStep_hpp */
