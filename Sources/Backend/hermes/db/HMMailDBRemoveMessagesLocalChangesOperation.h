// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBRemoveMessagesLocalChangesOperation__
#define __dejalu__HMMailDBRemoveMessagesLocalChangesOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailDBRemoveMessagesLocalChangesOperation : public MailDBOperation {
    public:
        MailDBRemoveMessagesLocalChangesOperation();
        virtual ~MailDBRemoveMessagesLocalChangesOperation();
        
        virtual mailcore::IndexSet * rowsIDs();
        virtual void setRowsIDs(mailcore::IndexSet * rowsIDs);
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::IndexSet * mRowsIDs;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBRemoveMessagesLocalChangesOperation__) */
