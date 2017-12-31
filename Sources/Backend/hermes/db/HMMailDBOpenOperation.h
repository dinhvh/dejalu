// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBOpenOperation__
#define __dejalu__HMMailDBOpenOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBOpenOperation : public MailDBOperation {
    public:
        MailDBOpenOperation();
        virtual ~MailDBOpenOperation();
        
        virtual mailcore::HashMap * folders();
        virtual mailcore::HashMap * mainFolders();
        virtual mailcore::IMAPNamespace * defaultNamespace();

        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::HashMap * mFolders;
        mailcore::HashMap * mMainFolders;
        mailcore::IMAPNamespace * mDefaultNamespace;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBOpenOperation__) */
