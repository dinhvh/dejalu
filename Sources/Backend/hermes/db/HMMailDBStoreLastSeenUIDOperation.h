// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBStoreLastSeenUIDOperation_hpp
#define HMMailDBStoreLastSeenUIDOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBStoreLastSeenUIDOperation : public MailDBOperation {
    public:
        MailDBStoreLastSeenUIDOperation();
        virtual ~MailDBStoreLastSeenUIDOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
    };
    
}

#endif

#endif /* HMMailDBStoreLastSeenUIDOperation_hpp */
