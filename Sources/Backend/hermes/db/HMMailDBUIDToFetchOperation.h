// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__MailDBUIDToFetchOperation__
#define __dejalu__MailDBUIDToFetchOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBUIDToFetchOperation : public MailDBOperation {
    public:
        MailDBUIDToFetchOperation();
        virtual ~MailDBUIDToFetchOperation();
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);

        virtual mailcore::String * partID();
        virtual void setPartID(mailcore::String * partID);

        virtual uint32_t uid();
        virtual mailcore::Encoding encoding();
        virtual mailcore::String * filename();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
        uint32_t mUid;
        mailcore::String * mPartID;
        mailcore::Encoding mEncoding;
        mailcore::String * mFilename;
    };
    
}

#endif

#endif /* defined(__dejalu__MailDBUIDToFetchOperation__) */
