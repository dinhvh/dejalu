// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBCheckFolderSeenOperation_hpp
#define HMMailDBCheckFolderSeenOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBCheckFolderSeenOperation : public MailDBOperation {
    public:
        MailDBCheckFolderSeenOperation();
        virtual ~MailDBCheckFolderSeenOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        // Implements Operation.
        virtual void main();

        // result
        virtual bool isFolderSeen();

    private:
        bool mFolderSeen;
        int64_t mFolderID;
    };
    
}

#endif

#endif /* HMMailDBCheckFolderSeenOperation_hpp */
