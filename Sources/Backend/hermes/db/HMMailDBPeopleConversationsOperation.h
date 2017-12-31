// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBPeopleConversationsOperation__
#define __dejalu__HMMailDBPeopleConversationsOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBPeopleConversationsOperation : public MailDBOperation {
    public:
        MailDBPeopleConversationsOperation();
        virtual ~MailDBPeopleConversationsOperation();
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual bool unreadOnly();
        virtual void setUnreadOnly(bool value);
        
        virtual bool starredOnly();
        virtual void setStarredOnly(bool value);
        
        virtual mailcore::Array * keywords();
        virtual void setKeywords(mailcore::Array * keywords);
        
        virtual mailcore::Array * conversations();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mFolderID;
        bool mUnreadOnly;
        bool mStarredOnly;
        mailcore::Array * mKeywords;
        mailcore::Array * mConversations;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBPeopleConversationsOperation__) */
