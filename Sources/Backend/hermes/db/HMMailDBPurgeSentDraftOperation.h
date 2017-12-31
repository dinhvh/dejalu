// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBPurgeSentDraftOperation__
#define __dejalu__HMMailDBPurgeSentDraftOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBPurgeSentDraftOperation : public MailDBOperation {
    public:
        MailDBPurgeSentDraftOperation();
        virtual ~MailDBPurgeSentDraftOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        virtual void setTrashFolderID(int64_t trashFolderID);
        virtual int64_t trashFolderID();

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        virtual mailcore::IndexSet * foldersNeedCopyMessages();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
        int64_t mTrashFolderID;
        mailcore::IndexSet * mFoldersNeedCopyMessages;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBPurgeSentDraftOperation__) */
