// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__MailDBRetrievePartOperation__
#define __dejalu__MailDBRetrievePartOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBRetrievePartOperation : public MailDBOperation {
    public:
        MailDBRetrievePartOperation();
        virtual ~MailDBRetrievePartOperation();
        
        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);
        virtual mailcore::String * partID();
        virtual void setPartID(mailcore::String * key);
        virtual mailcore::String * uniqueID();
        virtual void setUniqueID(mailcore::String * uniqueID);
        virtual mailcore::String * filename();
        virtual void setFilename(mailcore::String * filename);

        virtual void setRetrieveFilenameEnabled(bool enabled);
        virtual bool retrieveFilenameEnabled();

        virtual mailcore::Data * content();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mMessageRowID;
        mailcore::String * mPartID;
        mailcore::String * mUniqueID;
        mailcore::Data * mContent;
        mailcore::String * mFilename;
        bool mRetrieveFilenameEnabled;
    };
    
}

#endif

#endif /* defined(__dejalu__MailDBRetrievePartOperation__) */
