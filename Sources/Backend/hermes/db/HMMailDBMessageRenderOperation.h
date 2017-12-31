// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMessageRenderOperation__
#define __dejalu__HMMailDBMessageRenderOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"
#include "HMMailDBTypes.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBMessageRenderOperation : public MailDBOperation {
    public:
        MailDBMessageRenderOperation();
        virtual ~MailDBMessageRenderOperation();
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);
        
        virtual MailDBMessageRenderType renderType();
        virtual void setRenderType(MailDBMessageRenderType type);
        
        virtual mailcore::String * result();
        virtual mailcore::Array * requiredParts();
        virtual bool shouldFetchFullMessage();
        virtual bool hasMessagePart();

        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
        MailDBMessageRenderType mRenderType;
        mailcore::Array * mRequiredParts;
        mailcore::String * mResult;
        bool mHasMessagePart;
        bool mShouldFetchFullMessage;
    };
    
};

#endif

#endif /* defined(__dejalu__HMMailDBMessageRenderOperation__) */
