// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBMarkFirstSyncDoneOperation_hpp
#define HMMailDBMarkFirstSyncDoneOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBMarkFirstSyncDoneOperation : public MailDBOperation {
    public:
        MailDBMarkFirstSyncDoneOperation();
        virtual ~MailDBMarkFirstSyncDoneOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
    };
    
}

#endif

#endif /* HMMailDBMarkFirstSyncDoneOperation_hpp */
