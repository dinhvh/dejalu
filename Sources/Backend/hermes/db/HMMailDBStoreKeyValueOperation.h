// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBStoreKeyValueOperation__
#define __dejalu__HMMailDBStoreKeyValueOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBStoreKeyValueOperation : public MailDBOperation {
    public:
        MailDBStoreKeyValueOperation();
        virtual ~MailDBStoreKeyValueOperation();
        
        virtual mailcore::String * key();
        virtual void setKey(mailcore::String * key);
        virtual mailcore::Data * value();
        virtual void setValue(mailcore::Data * value);
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::String * mKey;
        mailcore::Data * mValue;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBStoreKeyValueOperation__) */
