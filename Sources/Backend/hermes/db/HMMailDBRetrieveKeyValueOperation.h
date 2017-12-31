// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBRetrieveKeyValueOperation__
#define __dejalu__HMMailDBRetrieveKeyValueOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBRetrieveKeyValueOperation : public MailDBOperation {
    public:
        MailDBRetrieveKeyValueOperation();
        virtual ~MailDBRetrieveKeyValueOperation();
        
        virtual mailcore::String * key();
        virtual void setKey(mailcore::String * key);
        
        virtual mailcore::Data * value();
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::String * mKey;
        mailcore::Data * mValue;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBRetrieveKeyValueOperation__) */
