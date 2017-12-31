// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMarkAsFetchedOperation__
#define __dejalu__HMMailDBMarkAsFetchedOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChanges;
    
    class MailDBMarkAsFetchedOperation : public MailDBOperation {
    public:
        MailDBMarkAsFetchedOperation();
        virtual ~MailDBMarkAsFetchedOperation();
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBMarkAsFetchedOperation__) */
