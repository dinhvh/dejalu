// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMRemoveExpiredLocalMessageOperation__
#define __dejalu__HMRemoveExpiredLocalMessageOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBRemoveExpiredLocalMessagesOperation : public MailDBOperation {
    public:
        MailDBRemoveExpiredLocalMessagesOperation();
        virtual ~MailDBRemoveExpiredLocalMessagesOperation();

        virtual void setFolderID(int64_t aFolderID);
        virtual int64_t folderID();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMRemoveExpiredLocalMessageOperation__) */
