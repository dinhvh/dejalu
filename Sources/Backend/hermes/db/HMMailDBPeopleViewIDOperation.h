// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBPeopleViewIDOperation_hpp
#define HMMailDBPeopleViewIDOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBPeopleViewIDOperation : public MailDBOperation {
    public:
        MailDBPeopleViewIDOperation();
        virtual ~MailDBPeopleViewIDOperation();

        virtual void setMessageID(mailcore::String * messageID);
        virtual mailcore::String * messageID();

        // result
        virtual int64_t peopleViewID();

        // Implements Operation.
        virtual void main();

    private:
        mailcore::String * mMessageID;
        int64_t mPeopleViewID;
    };
    
}

#endif

#endif /* HMMailDBPeopleViewIDOperation_hpp */
