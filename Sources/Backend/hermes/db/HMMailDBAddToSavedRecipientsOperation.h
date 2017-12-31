// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBAddToSavedRecipientsOperation_hpp
#define HMMailDBAddToSavedRecipientsOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBAddToSavedRecipientsOperation : public MailDBOperation {
    public:
        MailDBAddToSavedRecipientsOperation();
        virtual ~MailDBAddToSavedRecipientsOperation();

        virtual void setRowID(int64_t rowID);
        virtual int64_t rowID();

        virtual void setAddresses(mailcore::Array * addresses);
        virtual mailcore::Array * addresses();

        virtual mailcore::Array * allSavedAddresses();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::Array * mAddresses;
        int64_t mRowID;
        mailcore::Array * mAllSavedAddresses;
    };
    
}

#endif

#endif /* MailDBAddToSavedRecipientsOperation_hpp */
