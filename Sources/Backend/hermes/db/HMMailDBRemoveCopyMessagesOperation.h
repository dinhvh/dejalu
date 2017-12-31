// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBRemoveCopyMessagesOperation__
#define __dejalu__HMMailDBRemoveCopyMessagesOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBRemoveCopyMessagesOperation : public MailDBOperation {
    public:
        MailDBRemoveCopyMessagesOperation();
        virtual ~MailDBRemoveCopyMessagesOperation();

        virtual void setRowsIDs(mailcore::IndexSet * rowsIDs);
        virtual mailcore::IndexSet * rowsIDs();

        virtual void setMessagesRowIDs(mailcore::IndexSet * messagesRowIDs);
        virtual mailcore::IndexSet * messagesRowIDs();

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        virtual void setClearMoving(bool clearMoving);
        virtual bool clearMoving();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::IndexSet * mRowsIDs;
        mailcore::IndexSet * mMessagesRowsIDs;
        bool mClearMoving;
        int64_t mDraftsFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBRemoveCopyMessagesOperation__) */
