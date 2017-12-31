// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPUncacheOldMessagesSyncStep__
#define __dejalu__HMIMAPUncacheOldMessagesSyncStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBUidsOperation;
    
    class IMAPUncacheOldMessagesSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
        
    public:
        IMAPUncacheOldMessagesSyncStep();
        virtual ~IMAPUncacheOldMessagesSyncStep();
        
        virtual mailcore::IndexSet * messagesToUncache();
        virtual void setMessagesToUncache(mailcore::IndexSet * uids);

        virtual mailcore::String * trashFolderPath();
        virtual void setTrashFolderPath(mailcore::String * trashFolderPath);

        virtual mailcore::String * draftsFolderPath();
        virtual void setDraftsFolderPath(mailcore::String * draftsFolderPath);

        virtual void start();
        virtual void cancel();
        
    public:
        // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);
        
    private:
        mailcore::Operation * mUncacheOp;
        mailcore::IndexSet * mMessagesToUncache;
        mailcore::Operation * mPurgeDraftsOp;
        mailcore::String * mTrashFolderPath;
        mailcore::String * mDraftsFolderPath;
        mailcore::Operation * mMarkFirstSyncDoneOp;
        
        void markFirstSyncDone();
        void markFirstSyncDoneFinished();
        void uncacheUids();
        void uncacheUidsDone();
        void purgeDrafts();
        void purgeDraftsDone();
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPUncacheOldMessagesSyncStep__) */
