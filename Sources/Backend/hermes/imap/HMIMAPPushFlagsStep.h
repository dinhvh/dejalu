// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFolderFlagsPushStep__
#define __dejalu__HMIMAPFolderFlagsPushStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBLocalMessagesChanges;
    class MailDBMessagesLocalChangesOperation;
    class ActivityItem;
    
    class IMAPPushFlagsStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
        
    public:
        IMAPPushFlagsStep();
        virtual ~IMAPPushFlagsStep();
        
        virtual void start();

    public: // override
        virtual void cancel();
        virtual void notifyDelegateDone();

    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);
        
    private:
        void localChangesFetched();
        void startPushFlags();
        void pushFlags();
        void pushFlagsDone();
        void pushLabels();
        void pushLabelsDone();
        void expunge();
        void expungeDone();
        void removeLocalChanges();
        void removeLocalChangesDone();

    private:
        MailDBMessagesLocalChangesOperation * mLocalChangesOp;
        mailcore::IMAPOperation * mStoreOp;
        mailcore::IMAPOperation * mStoreLabelsOp;
        mailcore::Operation * mRemoveLocalChangesOp;
        MailDBLocalMessagesChanges * mChanges;
        int mState;
        ActivityItem * mActivity;
        unsigned int mCurrentLabelsAddedIndex;
        unsigned int mCurrentLabelsRemovedIndex;
        mailcore::Array * mAddedKeys;
        mailcore::Array * mRemovedKeys;
        bool mNeedsExpunge;
        mailcore::IMAPOperation * mExpungeOp;
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFolderFlagsPushStep__) */
