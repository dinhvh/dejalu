// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBNextUIDToFetchOperation__
#define __dejalu__HMMailDBNextUIDToFetchOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBNextUIDToFetchOperation : public MailDBOperation {
    public:
        MailDBNextUIDToFetchOperation();
        virtual ~MailDBNextUIDToFetchOperation();
        
        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();
        
        virtual void setMaxUid(uint32_t maxUid);
        virtual uint32_t maxUid();
        
        virtual int64_t messageRowID();
        virtual uint32_t uid();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
        uint32_t mUid;
        int64_t mFolderID;
        uint32_t mMaxUid;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBNextUIDToFetchOperation__) */
