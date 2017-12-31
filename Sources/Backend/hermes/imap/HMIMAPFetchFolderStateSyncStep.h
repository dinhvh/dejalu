// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__MMIMAPFetchMessageCountSyncStep__
#define __dejalu__MMIMAPFetchMessageCountSyncStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {
    
    class ActivityItem;
    
    class IMAPFetchFolderStateSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
        
    public:
        IMAPFetchFolderStateSyncStep();
        virtual ~IMAPFetchFolderStateSyncStep();
        
        virtual void start();
        virtual void cancel();
        
        virtual unsigned int count();
        virtual uint32_t uidNext();
        
    private:
        mailcore::IMAPFolderInfoOperation * mFolderInfoOp;
        mailcore::Operation * mValidateFolderOp;
        unsigned int mCount;
        uint32_t mUidNext;
        uint32_t mUidValidity;
        ActivityItem * mActivity;

        // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);

        void folderInfo();
        void folderInfoDone();
        void validateFolder();
        void validateFolderDone();
    };
    
}

#endif

#endif /* defined(__dejalu__MMFolderCountSyncStep__) */
