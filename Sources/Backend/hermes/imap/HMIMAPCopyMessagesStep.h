// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPCopyMessagesStep__
#define __dejalu__HMIMAPCopyMessagesStep__

#include "HMIMAPFolderSyncStep.h"
#include "HMIMAPSyncTypes.h"

#ifdef __cplusplus

namespace hermes {

    class MailDBUidsToCopyOperation;
    class MailDBOperation;

    class IMAPCopyMessagesStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
    public:
        IMAPCopyMessagesStep();
        virtual ~IMAPCopyMessagesStep();

        virtual void setDeleteOriginal(int deleteOriginal);
        virtual int deleteOriginal();

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        virtual void start();

    public: // override
        virtual void cancel();
        virtual void notifyDelegateDone();

    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);

    private:
        void fetchUidsMessagesToCopy();
        void fetchUidsMessagesToCopyDone();
        void copyMessagesFromNextFolder();
        void copyMessagesFromNextFolderDone();
        void markAsDeleted();
        void markAsDeletedDone();
        void markCopyAsDeleted();
        void markCopyAsDeletedDone();
        void runExpunge(int64_t expungeFolderID);
        void runExpungeDone();
        void removeAction();
        void removeActionDone();
        void nextFolder();
        void copyMessages();
        void copyMessagesDone();

        int mDeleteOriginal;
        mailcore::HashMap * mMessagesPerFolders;
        mailcore::Array * mFolders;
        unsigned int mFolderIndex;
        MailDBUidsToCopyOperation * mUidsOp;
        mailcore::HashMap * mUidMapping;
        mailcore::IMAPCopyMessagesOperation * mCopyOp;
        mailcore::IMAPOperation * mFlagOp;
        mailcore::Operation * mRemoveCopyMessagesOp;
        mailcore::IndexSet * mUidSet;
        mailcore::IMAPOperation * mExpungeOp;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPCopyMessagesStep__) */
