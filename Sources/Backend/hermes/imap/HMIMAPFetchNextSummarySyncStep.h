// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFetchNextSummarySyncStep__
#define __dejalu__HMIMAPFetchNextSummarySyncStep__

#include "HMIMAPFolderSyncStep.h"

#include "HMIMAPSyncTypes.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBNextUIDToFetchOperation;
    class MailDBMessageRenderOperation;
    class MailDBOperation;
    class MailDBUIDToFetchOperation;
    class ActivityItem;
    
    class IMAPFetchNextSummarySyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
    public:
        IMAPFetchNextSummarySyncStep();
        virtual ~IMAPFetchNextSummarySyncStep();

        virtual uint32_t maxUid();
        virtual void setMaxUid(uint32_t maxUid);
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);

        virtual bool isUrgent();
        virtual void setUrgent(bool urgent);
        
        virtual bool fetched();
        virtual uint32_t uid();
        
        virtual void start();
        virtual void cancel();
        
    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);
        
    private:
        void nextUidToFetch();
        void nextUidToFetchDone();
        void tryRenderMessage();
        void tryRenderMessageDone();
        void fetchBodies();
        void fetchNextBody();
        void fetchNextBodyDone();
        void storeNextBody();
        void storeNextBodyDone();
        void markAsFetched();
        void markAsFetchedDone();
        void fetchUidInfo();
        void fetchUidInfoDone();
        void fetchFullMessage();
        void fetchFullMessageDone();
        void storeMessageParts();
        void storeMessagePartsDone();
        bool shouldFetchFullMessage();

        void debugCallbackError();

        MailDBNextUIDToFetchOperation * mNextUidOp;
        MailDBUIDToFetchOperation * mUidOp;
        uint32_t mUid;
        int64_t mMessageRowID;
        MailDBMessageRenderOperation * mRenderOp;
        mailcore::Array * mRequiredParts;
        unsigned int mBodyIndex;
        mailcore::IMAPFetchContentOperation * mFetchOp;
        mailcore::Data * mContent;
        mailcore::Operation * mStoreOp;
        mailcore::Operation * mMarkAsFetchedOp;
        mailcore::IMAPFetchContentOperation * mFetchFullOp;
        mailcore::Operation * mStoreMessagePartsOp;
        bool mFetched;
        uint32_t mMaxUid;
        ActivityItem * mActivity;
        bool mUrgent;
        bool mHasMessagePart;
        bool mShouldFetchFullMessage;
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFetchNextSummarySyncStep__) */
