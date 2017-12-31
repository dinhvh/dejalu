// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBPurgeMessageOperation__
#define __dejalu__HMMailDBPurgeMessageOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBPurgeMessageOperation : public MailDBOperation {
    public:
        MailDBPurgeMessageOperation();
        virtual ~MailDBPurgeMessageOperation();

        virtual void setMessagesRowIDs(mailcore::Array * messagesRowIDs);
        virtual mailcore::Array * messagesRowIDs();

        virtual void setConversationsIDs(mailcore::Array * conversationsIDs);
        virtual mailcore::Array * conversationsIDs();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        virtual mailcore::IndexSet * foldersNeedCopyMessages();
        
        virtual void setTrashFolderID(int64_t trashFolderID);
        virtual int64_t trashFolderID();

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        // Implements Operation.
        virtual void main();

    private:
        mailcore::IndexSet * mFoldersNeedCopyMessages;
        int64_t mTrashFolderID;
        int64_t mFolderID;
        int64_t mDraftsFolderID;
        mailcore::Array * mMessagesRowIDs;
        mailcore::Array * mConversationsIDs;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBPurgeMessageOperation__) */
