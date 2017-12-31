// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBAddFoldersOperation__
#define __dejalu__HMMailDBAddFoldersOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBAddFoldersOperation : public MailDBOperation {
    public:
        MailDBAddFoldersOperation();
        virtual ~MailDBAddFoldersOperation();
        
        virtual mailcore::Array * pathsToAdd();
        virtual void setPathsToAdd(mailcore::Array * paths);
        virtual mailcore::Array * pathsToRemove();
        virtual void setPathsToRemove(mailcore::Array * paths);
        virtual mailcore::IMAPNamespace * defaultNamespace();
        virtual void setDefaultNamespace(mailcore::IMAPNamespace * defaultNamespace);

        virtual mailcore::Array * foldersToAddIDs();

        // Implements Operation.
        virtual void main();
        
    private:
        mailcore::Array * mPathsToAdd;
        mailcore::Array * mPathsToRemove;
        mailcore::Array * mPathsToValidate;
        mailcore::Array * mFoldersToAddIDs;
        mailcore::HashMap * mUidValidities;
        mailcore::IMAPNamespace * mDefaultNamespace;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBAddFoldersOperation__) */
