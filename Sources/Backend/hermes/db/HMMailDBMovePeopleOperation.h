// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMovePeopleOperation__
#define __dejalu__HMMailDBMovePeopleOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBMovePeopleOperation : public MailDBOperation {
    public:
        MailDBMovePeopleOperation();
        virtual ~MailDBMovePeopleOperation();

        virtual void setConversationsIDs(mailcore::Array * conversationsIDs);
        virtual mailcore::Array * conversationsIDs();

        virtual void setOtherFolderID(int64_t otherFolderID);
        virtual int64_t otherFolderID();

        mailcore::HashMap * foldersScores();
        void setFoldersScores(mailcore::HashMap * foldersScores);
        
        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        virtual mailcore::IndexSet * foldersNeedCopyMessages();
        
        // Implements Operation.
        virtual void main();

    private:
        mailcore::IndexSet * mFoldersNeedCopyMessages;
        int64_t mOtherFolderID;
        mailcore::Array * mConversationsIDs;
        mailcore::HashMap * mFoldersScores;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBMovePeopleOperation__) */
