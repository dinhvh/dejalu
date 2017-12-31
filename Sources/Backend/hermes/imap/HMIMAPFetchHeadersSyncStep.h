// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFetchHeadersListSyncStep__
#define __dejalu__HMIMAPFetchHeadersListSyncStep__

#include "HMIMAPFolderSyncStep.h"
#include "HMIMAPSyncTypes.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBAddMessagesOperation;
    class ActivityItem;
    
    class IMAPFetchHeadersSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback, public mailcore::IMAPOperationCallback {
        
    public:
        IMAPFetchHeadersSyncStep();
        virtual ~IMAPFetchHeadersSyncStep();
        
        virtual void setUids(mailcore::IndexSet * uids);
        virtual mailcore::IndexSet * uids();
        
        virtual void setMaxCount(unsigned int maxCount);
        virtual unsigned int maxCount();

        virtual void setDraftsFolderID(int64_t folderID);
        virtual int64_t draftsFolderID();
        
        virtual mailcore::IndexSet * remainingUids();
        virtual mailcore::IndexSet * fetchedUids();
        virtual mailcore::IndexSet * rowsIDs();
        virtual unsigned int headersProgressMax();
        virtual unsigned int headersProgressValue();
        virtual bool isUnseen();
        
        virtual void start();
        virtual void cancel();
        
    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);
        
    public: // IMAPOperationCallback implementation.
        virtual void itemProgress(mailcore::IMAPOperation * session, unsigned int current, unsigned int maximum);
        
    private:
        void fetched();
        void stored();

    private:
        mailcore::IMAPFetchMessagesOperation * mFetchOp;
        MailDBAddMessagesOperation * mStorageOp;
        mailcore::IndexSet * mRowsIDs;
        mailcore::IndexSet * mUids;
        mailcore::IndexSet * mRemainingUids;
        mailcore::IndexSet * mFetchedUids;
        unsigned int mMaxCount;
        unsigned int mHeadersProgressMax;
        unsigned int mHeadersProgressValue;
        ActivityItem * mActivity;
        bool mUnseen;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFetchHeadersListSyncStep__) */
