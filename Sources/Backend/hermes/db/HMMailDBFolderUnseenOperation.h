// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBFolderUnseenOperation_hpp
#define HMMailDBFolderUnseenOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBFolderUnseenOperation : public MailDBOperation {
    public:
        MailDBFolderUnseenOperation();
        virtual ~MailDBFolderUnseenOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        virtual bool isUnseen();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
        bool mUnseen;
    };
    
}

#endif

#endif /* HMMailDBFolderUnseenOperation_hpp */
