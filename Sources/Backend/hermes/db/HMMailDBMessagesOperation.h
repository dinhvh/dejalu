// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBMessagesOperation_hpp
#define HMMailDBMessagesOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBMessagesOperation : public MailDBOperation {
    public:
        MailDBMessagesOperation();
        virtual ~MailDBMessagesOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        // result
        virtual mailcore::IndexSet * messagesRowsIDs();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
        mailcore::IndexSet * mMessagesRowsIDs;
    };

}

#endif

#endif /* HMMailDBMessagesOperation_hpp */
