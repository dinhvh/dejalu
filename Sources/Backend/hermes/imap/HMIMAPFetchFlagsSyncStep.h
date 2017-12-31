// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFetchFlagsSyncStep__
#define __dejalu__HMIMAPFetchFlagsSyncStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {
    
    class ActivityItem;
    class MailDBCheckFolderSeenOperation;
    
    class IMAPFetchFlagsSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
        
    public:
        IMAPFetchFlagsSyncStep();
        virtual ~IMAPFetchFlagsSyncStep();
        
        virtual void setUids(mailcore::IndexSet * uids);
        virtual mailcore::IndexSet * uids();
        
        virtual void setMaxCount(unsigned int maxCount);
        virtual unsigned int maxCount();
        
        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);
        
        virtual mailcore::IndexSet * remainingUids();
        virtual mailcore::IndexSet * fetchedUids();
        virtual bool isSeen();
        
        virtual void start();
        virtual void cancel();

    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);
        
    private:
        void fetched();
        void stored();
        void checkFolderSeen();
        void checkFolderSeenDone();

    private:
        mailcore::IMAPFetchMessagesOperation * mFetchOp;
        mailcore::Operation * mStorageOp;
        mailcore::IndexSet * mUids;
        mailcore::IndexSet * mRemainingUids;
        mailcore::IndexSet * mFetchedUids;
        unsigned int mMaxCount;
        ActivityItem * mActivity;
        MailDBCheckFolderSeenOperation * mCheckFolderSeenOp;
        bool mSeen;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFetchFlagsSyncStep__) */
