// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBMessagesRecipientsOperation_hpp
#define HMMailDBMessagesRecipientsOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBMessagesRecipientsOperation : public MailDBOperation {
    public:
        MailDBMessagesRecipientsOperation();
        virtual ~MailDBMessagesRecipientsOperation();

        virtual void setMessagesRowsIDs(mailcore::IndexSet * messagesRowsIDs);
        virtual mailcore::IndexSet * messagesRowsIDs();

        virtual void setMaxCount(int maxCount);
        virtual int maxCount();

        // result
        virtual mailcore::Array * recipients();
        virtual mailcore::IndexSet * remainingMessagesRowsIDs();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::IndexSet * mMessagesRowsIDs;
        int mMaxCount;
        mailcore::IndexSet * mRemainingMessagesRowsIDs;
        mailcore::Array * mRecipients;
    };
    
}

#endif

#endif /* MailDBMessagesRecipientsOperation_hpp */
