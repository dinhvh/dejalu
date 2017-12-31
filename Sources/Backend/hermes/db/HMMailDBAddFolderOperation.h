// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBAddFolderOperation__
#define __dejalu__HMMailDBAddFolderOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBAddFolderOperation : public MailDBOperation {
    public:
        MailDBAddFolderOperation();
        virtual ~MailDBAddFolderOperation();
        
        virtual mailcore::String * path();
        virtual void setPath(mailcore::String * path);
        
        virtual int64_t folderID();
        
        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::String * mPath;
        int64_t mFolderID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBAddFolderOperation__) */
