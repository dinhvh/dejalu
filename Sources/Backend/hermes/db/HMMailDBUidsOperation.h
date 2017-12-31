// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBUidsOperation__
#define __dejalu__HMMailDBUidsOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBUidsOperation : public MailDBOperation {
    public:
        MailDBUidsOperation();
        virtual ~MailDBUidsOperation();
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual mailcore::IndexSet * uids();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mFolderID;
        mailcore::IndexSet * mUids;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBUidsOperation__) */
