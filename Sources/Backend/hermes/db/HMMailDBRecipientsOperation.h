// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBRecipientsOperation_hpp
#define HMMailDBRecipientsOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBRecipientsOperation : public MailDBOperation {
    public:
        MailDBRecipientsOperation();
        virtual ~MailDBRecipientsOperation();

        // result
        virtual mailcore::Array * addresses();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::Array * mAddresses;
    };
    
}

#endif

#endif /* HMMailDBRecipientsOperation_hpp */
