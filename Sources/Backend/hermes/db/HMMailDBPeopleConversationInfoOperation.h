// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__MailDBPeopleConversationInfoOperation__
#define __dejalu__MailDBPeopleConversationInfoOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBPeopleConversationInfoOperation : public MailDBOperation {
    public:
        MailDBPeopleConversationInfoOperation();
        virtual ~MailDBPeopleConversationInfoOperation();
        
        virtual int64_t conversationID();
        virtual void setConversationID(int64_t conversationID);
        
        virtual int64_t inboxFolderID();
        virtual void setInboxFolderID(int64_t inboxFolderID);

        virtual mailcore::Set * emailSet();
        virtual void setEmailSet(mailcore::Set * emailSet);
        
        virtual mailcore::HashMap * foldersScores();
        virtual void setFoldersScores(mailcore::HashMap * foldersScores);
        
        virtual mailcore::Set * foldersToExcludeFromUnread();
        virtual void setFoldersToExcludeFromUnread(mailcore::Set * foldersToExcludeFromUnread);

        virtual mailcore::HashMap * conversationInfo();
        
        // Implements Operation.
        virtual void main();

    private:
        int64_t mConversationID;
        int64_t mInboxFolderID;
        mailcore::Set * mEmailSet;
        mailcore::HashMap * mFoldersScores;
        mailcore::HashMap * mConversationInfo;
        mailcore::Set * mFoldersToExcludeFromUnread;
    };
    
}

#endif

#endif /* defined(__dejalu__MailDBPeopleConversationInfoOperation__) */
