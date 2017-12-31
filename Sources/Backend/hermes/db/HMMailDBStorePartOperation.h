// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBStorePartOperation__
#define __dejalu__HMMailDBStorePartOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBStorePartOperation : public MailDBOperation {
    public:
        MailDBStorePartOperation();
        virtual ~MailDBStorePartOperation();
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);
        virtual mailcore::String * partID();
        virtual void setPartID(mailcore::String * partID);
        virtual mailcore::Data * content();
        virtual void setContent(mailcore::Data * content);
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
        mailcore::String * mPartID;
        mailcore::Data * mContent;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBStorePartOperation__) */
