// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFetchNextAttachmentSyncStep__
#define __dejalu__HMIMAPFetchNextAttachmentSyncStep__

#include "HMIMAPFolderSyncStep.h"

#ifdef __cplusplus

namespace hermes {

    class MailDBNextUIDToFetchOperation;
    class MailDBMessageRenderOperation;
    class MailDBOperation;
    class MailDBUIDToFetchOperation;
    class MailDBRetrievePartOperation;
    class ActivityItem;

    class IMAPFetchNextAttachmentSyncStep : public IMAPFolderSyncStep, public mailcore::OperationCallback {
    public:
        IMAPFetchNextAttachmentSyncStep();
        virtual ~IMAPFetchNextAttachmentSyncStep();

        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);

        virtual mailcore::String * partID();
        virtual void setPartID(mailcore::String * partID);

        virtual bool isUrgent();
        virtual void setUrgent(bool urgent);
        
        virtual bool fetched();

        virtual void start();
        virtual void cancel();

    public: // OperationCallback implementation.
        virtual void operationFinished(mailcore::Operation * op);

    private:
        int64_t mMessageRowID;
        mailcore::String * mPartID;
        uint32_t mUid;
        mailcore::Encoding mEncoding;
        bool mFetched;
        MailDBRetrievePartOperation * mRetrievePartOp;
        MailDBUIDToFetchOperation * mUidOp;
        ActivityItem * mActivity;
        mailcore::IMAPFetchContentOperation * mFetchOp;
        mailcore::Data * mContent;
        mailcore::Operation * mStoreOp;
        bool mUrgent;

        void fetchUidInfo();
        void fetchUidInfoDone();
        void retrievePartData();
        void retrievePartDataDone();
        void fetchPart();
        void fetchPartDone();
        void storePart();
        void storePartDone();
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFetchNextAttachmentSyncStep__) */
