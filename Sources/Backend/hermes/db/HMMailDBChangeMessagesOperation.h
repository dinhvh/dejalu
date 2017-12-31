// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBChangeMessagesOperation__
#define __dejalu__HMMailDBChangeMessagesOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChanges;
    
    class MailDBChangeMessagesOperation : public MailDBOperation {
    public:
        MailDBChangeMessagesOperation();
        virtual ~MailDBChangeMessagesOperation();
        
        virtual mailcore::Array * messages();
        virtual void setMessages(mailcore::Array * msgs);
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::Array * mMessages;
        int64_t mFolderID;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBChangeMessagesOperation__) */
