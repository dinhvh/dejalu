// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBChangeConversationsFlags__
#define __dejalu__HMMailDBChangeConversationsFlags__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"
#include "HMMailDBTypes.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChangePeopleConversationsFlagsOperation : public MailDBOperation {
    public:
        MailDBChangePeopleConversationsFlagsOperation();
        virtual ~MailDBChangePeopleConversationsFlagsOperation();
        
        virtual mailcore::Array * conversationsIDs();
        virtual void setConversationsIDs(mailcore::Array * conversationsIDs);
        
        virtual MailDBChangeFlagsType changeFlagsType();
        virtual void setChangeFlagsType(MailDBChangeFlagsType type);

#if 0
        virtual bool isTweakLabelsEnabled();
        virtual void setTweakLabelsEnabled(bool enabled);
#endif

        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual int64_t trashFolderID();
        virtual void setTrashFolderID(int64_t trashFolderID);

        virtual int64_t inboxFolderID();
        virtual void setInboxFolderID(int64_t inboxFolderID);

        virtual int64_t sentFolderID();
        virtual void setSentFolderID(int64_t sentFolderID);

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        virtual mailcore::String * folderPath();
        virtual void setFolderPath(mailcore::String * folderPath);

        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::Array * mConversationsIDs;
        MailDBChangeFlagsType mChangeFlagsType;
        int64_t mFolderID;
        //bool mTweakLabelsEnabled;
        mailcore::String * mFolderPath;
        int64_t mTrashFolderID;
        int64_t mInboxFolderID;
        int64_t mSentFolderID;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBChangeConversationsFlags__) */
