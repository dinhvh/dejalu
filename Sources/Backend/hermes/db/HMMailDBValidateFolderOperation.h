// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBValidateFolderOperation_hpp
#define HMMailDBValidateFolderOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {

    class MailDBValidateFolderOperation : public MailDBOperation {
    public:
        MailDBValidateFolderOperation();
        virtual ~MailDBValidateFolderOperation();

        virtual void setFolderPath(mailcore::String * folderPath);
        virtual mailcore::String * folderPath();

        virtual void setUidValidity(uint32_t uidValidity);
        virtual uint32_t uidValidity();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::String * mFolderPath;
        uint32_t mUidValidity;
    };

}

#endif

#endif /* HMMailDBValidateFolderOperation_hpp */
