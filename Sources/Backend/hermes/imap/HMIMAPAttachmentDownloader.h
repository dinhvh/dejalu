// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPAttachmentDownloader__
#define __dejalu__HMIMAPAttachmentDownloader__

#ifdef __cplusplus

#include <MailCore/MailCore.h>
#include "HMConstants.h"

namespace hermes {
    class IMAPAccountSynchronizer;
    class MailDBRetrievePartOperation;
    class Account;

    class IMAPAttachmentDownloader : public mailcore::Operation, public mailcore::OperationCallback {
    public:
        IMAPAttachmentDownloader();
        virtual ~IMAPAttachmentDownloader();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        virtual void setMessageRowID(int64_t messageRowID);
        virtual int64_t messageRowID();

        virtual void setUniqueID(mailcore::String * uniqueID);
        virtual mailcore::String * uniqueID();

        virtual void setDownloadFolder(mailcore::String * downloadFolder);
        virtual mailcore::String * downloadFolder();

        virtual void setCallback(mailcore::OperationCallback * callback);
        virtual mailcore::OperationCallback * callback();

        virtual void start();

        virtual void notifyDownloadFinished(hermes::ErrorCode error);

        virtual mailcore::String * partID();
        // optional
        virtual void setFilename(mailcore::String * filename);
        virtual mailcore::String * filename();
        //virtual bool succeeded();
        virtual hermes::ErrorCode error();

    public: // OperationCallback
        virtual void operationFinished(mailcore::Operation * op);

    public: // private for Account
        virtual void setAccount(Account * account);
        Account * account();

    private:
        int64_t mMessageRowID;
        int64_t mFolderID;
        mailcore::String * mPartID;
        mailcore::String * mUniqueID;
        mailcore::String * mDownloadFolder;
        mailcore::OperationCallback * mCallback;
        Account * mAccount;
        MailDBRetrievePartOperation * mRetrievePartOp;
        //bool mSucceeded;
        bool mTriedFetch;
        mailcore::String * mFilename;
        hermes::ErrorCode mError;

        void retrievePart();
        void retrievePartDone();
    };
}

#endif

#endif /* defined(__dejalu__HMIMAPAttachmentDownloader__) */
