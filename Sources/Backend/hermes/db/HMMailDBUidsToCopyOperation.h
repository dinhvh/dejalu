// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBUidsToCopyOperation__
#define __dejalu__HMMailDBUidsToCopyOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBUidsToCopyOperation : public MailDBOperation {
    public:
        MailDBUidsToCopyOperation();
        virtual ~MailDBUidsToCopyOperation();

        virtual void setFolderID(int64_t aFolderID);
        virtual int64_t folderID();

        virtual void setDeleteOriginal(int value);
        virtual int deleteOriginal();

        virtual mailcore::Array * messagesInfos();

        // Implements Operation.
        virtual void main();

    private:
        int64_t mFolderID;
        int mDeleteOriginal;
        mailcore::Array * mMessagesInfos;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBUidsToCopyOperation__) */
