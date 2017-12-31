// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMessageInfoOperation__
#define __dejalu__HMMailDBMessageInfoOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBMessageInfoOperation : public MailDBOperation {
    public:
        MailDBMessageInfoOperation();
        virtual ~MailDBMessageInfoOperation();
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);
        
        virtual mailcore::Set * emailSet();
        virtual void setEmailSet(mailcore::Set * emailSet);

        virtual bool renderImageEnabled();
        virtual void setRenderImageEnabled(bool enabled);

        virtual mailcore::HashMap * messageInfo();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
        mailcore::HashMap * mMessageInfo;
        mailcore::Set * mEmailSet;
        bool mRenderImageEnabled;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBMessageInfoOperation__) */
