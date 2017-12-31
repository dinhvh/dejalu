// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBAddMessageOperation__
#define __dejalu__HMMailDBAddMessageOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChanges;
    
    class MailDBAddMessagesOperation : public MailDBOperation {
    public:
        MailDBAddMessagesOperation();
        virtual ~MailDBAddMessagesOperation();
        
        virtual mailcore::Array * messages();
        virtual void setMessages(mailcore::Array * /* IMAPMessage */ msgs);
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);
        
        virtual mailcore::IndexSet * messagesRowsIDs();
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::Array * mMessages;
        int64_t mFolderID;
        mailcore::IndexSet * mMessagesRowsIDs;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBAddMessageOperation__) */
