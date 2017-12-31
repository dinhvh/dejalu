// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMessagesLocalChangesOperation__
#define __dejalu__HMMailDBMessagesLocalChangesOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBLocalMessagesChanges;
    
    class MailDBMessagesLocalChangesOperation : public MailDBOperation {
    public:
        MailDBMessagesLocalChangesOperation();
        virtual ~MailDBMessagesLocalChangesOperation();
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual MailDBLocalMessagesChanges * localChanges();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mFolderID;
        MailDBLocalMessagesChanges * mLocalChanges;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBMessagesLocalChangesOperation__) */
