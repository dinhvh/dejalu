// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFetchMessageListSyncStepDelegate__
#define __dejalu__HMIMAPFetchMessageListSyncStepDelegate__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBUidsOperation;
    class ActivityItem;
    
    class IMAPFetchMessageListSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
        
    public:
        IMAPFetchMessageListSyncStep();
        virtual ~IMAPFetchMessageListSyncStep();
        
        virtual void setMessagesCount(unsigned int messagesCount);
        virtual unsigned int messagesCount();
        
        virtual void setMaxFetchCount(unsigned int maxFetchCount);
        virtual unsigned int maxFetchCount();
        
        virtual void start();
        virtual void cancel();
        
        virtual mailcore::IndexSet * uids();
        virtual mailcore::IndexSet * cachedUids();
        
    private:
        mailcore::IMAPFetchMessagesOperation * mFetchOp;
        MailDBUidsOperation * mCachedUidsOp;
        mailcore::IndexSet * mUids;
        mailcore::IndexSet * mCachedUids;
        unsigned int mMessagesCount;
        unsigned int mMaxFetchCount;
        ActivityItem * mActivity;
        
        void fetchRemoteUids();
        void fetchedRemoteUids();
        void fetchCachedUids();
        void fetchedCachedUids();
        
        // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFetchMessageListSyncStep__) */
