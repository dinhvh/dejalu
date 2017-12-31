// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPPushMessagesStep__
#define __dejalu__HMIMAPPushMessagesStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {

    class MailDBNextMessageToPushOperation;
    class ActivityItem;

    class IMAPPushMessagesStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {

    public:
        IMAPPushMessagesStep();
        virtual ~IMAPPushMessagesStep();

        virtual void setDraftBehaviorEnabled(bool enabled);
        virtual bool isDraftBehaviorEnabled();

        virtual void setTrashFolderPath(mailcore::String * trashFolderPath);
        virtual mailcore::String * trashFolderPath();

        virtual void setDraftsFolderPath(mailcore::String * draftsFolderPath);
        virtual mailcore::String * draftsFolderPath();

        virtual void start();

        virtual bool isDone();

        virtual int64_t messageRowID();

    public: // override
        virtual void cancel();
        virtual void notifyDelegateDone();

    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);

    private:
        void fetchMessageToPush();
        void fetchMessageToPushDone();
        void pushMessage();
        void pushMessageDone();
        void markMessageAsPushed();
        void markMessageAsPushedDone();
        void deleteDraftMessages();
        void deleteDraftMessagesDone();

        MailDBNextMessageToPushOperation * mMessageToPushOp;
        mailcore::IMAPAppendMessageOperation * mAppendOp;
        mailcore::Operation * mSetPushedOp;
        bool mDone;
        int64_t mMessageRowID;
        mailcore::String * mFilename;
        bool mDraftBehaviorEnabled;
        mailcore::IndexSet * mDraftsMessagesRowIDsToDelete;
        ActivityItem * mActivity;
        mailcore::String * mTrashFolderPath;
        mailcore::String * mDraftsFolderPath;
        mailcore::Operation * mPurgeOp;
    };

}

#endif

#endif /* defined(__dejalu__HMIMAPPushMessagesStep__) */
