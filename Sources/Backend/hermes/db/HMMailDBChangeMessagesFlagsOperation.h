// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBChangeFlagsOperation__
#define __dejalu__HMMailDBChangeFlagsOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"
#include "HMMailDBTypes.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChangeMessagesFlagsOperation : public MailDBOperation {
    public:
        MailDBChangeMessagesFlagsOperation();
        virtual ~MailDBChangeMessagesFlagsOperation();
        
        virtual mailcore::Array * messagesRowIDs();
        virtual void setMessagesRowIDs(mailcore::Array * messagesRowIDs);
        
        virtual MailDBChangeFlagsType changeFlagsType();
        virtual void setChangeFlagsType(MailDBChangeFlagsType type);
        
        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::Array * mMessagesRowIDs;
        MailDBChangeFlagsType mChangeFlagsType;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBChangeFlagsOperation__) */
