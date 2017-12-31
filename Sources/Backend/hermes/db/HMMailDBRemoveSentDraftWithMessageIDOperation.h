// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBRemoveDraftWithMessageID__
#define __dejalu__HMMailDBRemoveDraftWithMessageID__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBRemoveSentDraftWithMessageIDOperation : public MailDBOperation {
    public:
        MailDBRemoveSentDraftWithMessageIDOperation();
        virtual ~MailDBRemoveSentDraftWithMessageIDOperation();

        virtual void setFolderID(int64_t folderID);
        virtual int64_t folderID();

        virtual void setMessageID(mailcore::String * messageID);
        virtual mailcore::String * messageID();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::String * mMessageID;
        int64_t mFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBRemoveDraftWithMessageID__) */
