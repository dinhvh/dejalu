// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBAddLocalMessagesOperation__
#define __dejalu__HMMailDBAddLocalMessagesOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBAddLocalMessagesOperation : public MailDBOperation {
    public:
        MailDBAddLocalMessagesOperation();
        virtual ~MailDBAddLocalMessagesOperation();

        virtual mailcore::Array * messagesData();
        virtual void setMessagesData(mailcore::Array * /* Data */ msgsData);

        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);

        virtual void setNeedsToBeSentToServer(bool enabled);
        virtual bool needsToBeSentToServer();

        virtual void setHasBeenPushed(bool enabled);
        virtual bool hasBeenPushed();

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);
        
        virtual mailcore::Array * messagesRowsIDs();
        mailcore::Array * messageIDs();;

        // Implements Operation.
        virtual void main();

    private:
        mailcore::Array * mMessagesRowsIDs;
        mailcore::Array * mMessageIDs;
        mailcore::Array * mMessagesData;
        int64_t mFolderID;
        bool mNeedsToBeSentToServer;
        bool mHasBeenPushed;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBAddLocalMessageOperation__) */
