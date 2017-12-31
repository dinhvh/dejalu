// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBSetLocalMessagesPushedOperation__
#define __dejalu__HMMailDBSetLocalMessagesPushedOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBSetLocalMessagesPushedOperation : public MailDBOperation {
    public:
        MailDBSetLocalMessagesPushedOperation();
        virtual ~MailDBSetLocalMessagesPushedOperation();

        virtual mailcore::IndexSet * messagesRowsIDs();
        virtual void setMessagesRowsIDs(mailcore::IndexSet * messagesRowsIDs);

        // Implements Operation.
        virtual void main();

    private:
        mailcore::IndexSet * mMessagesRowsIDs;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBSetLocalMessagesPushedOperation__) */
