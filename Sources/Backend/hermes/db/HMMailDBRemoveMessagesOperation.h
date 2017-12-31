// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBRemoveMessageOperation__
#define __dejalu__HMMailDBRemoveMessageOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChanges;
    
    class MailDBRemoveMessagesOperation : public MailDBOperation {
    public:
        MailDBRemoveMessagesOperation();
        virtual ~MailDBRemoveMessagesOperation();
        
        virtual mailcore::Array * messagesRowIDs();
        virtual void setMessagesRowIDs(mailcore::Array * rowIDs);
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual mailcore::IndexSet * messagesUids();
        virtual void setMessagesUids(mailcore::IndexSet * uids);
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::Array * mMessagesRowIDs;
        int64_t mFolderID;
        mailcore::IndexSet * mMessagesUids;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBRemoveMessageOperation__) */
