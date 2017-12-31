// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBCloseOperation__
#define __dejalu__HMMailDBCloseOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBCloseOperation : public MailDBOperation {
    public:
        MailDBCloseOperation();
        virtual ~MailDBCloseOperation();

        // override
        virtual void start();

        // Implements Operation.
        virtual void main();
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBCloseOperation__) */
