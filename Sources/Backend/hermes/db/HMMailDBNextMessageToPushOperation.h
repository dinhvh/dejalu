// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBNextMessageToPushOperation__
#define __dejalu__HMMailDBNextMessageToPushOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBNextMessageToPushOperation : public MailDBOperation {
    public:
        MailDBNextMessageToPushOperation();
        virtual ~MailDBNextMessageToPushOperation();

        virtual void setFolderID(int64_t aFolderID);
        virtual int64_t folderID();

        virtual void setDraftBehaviorEnabled(bool enabled);
        virtual bool isDraftBehaviorEnabled();

        virtual mailcore::String * filename();
        virtual int64_t messageRowID();
        virtual mailcore::IndexSet * draftsMessagesRowIDsToDelete();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
        mailcore::String * mFilename;
        int64_t mMessageRowID;
        bool mDraftBehaviorEnabled;
        mailcore::IndexSet * mDraftsMessagesRowIDsToDelete;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBNextMessageToPushOperation__) */
