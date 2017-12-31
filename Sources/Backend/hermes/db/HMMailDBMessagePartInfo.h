// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMessagePartInfo__
#define __dejalu__HMMailDBMessagePartInfo__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class MailDBMessagePartInfo : public mailcore::Object {
    public:
        MailDBMessagePartInfo();
        virtual ~MailDBMessagePartInfo();

        virtual int64_t messageRowID();
        virtual void setMessageRowID(int64_t messageRowID);

        virtual mailcore::String * partID();
        virtual void setPartID(mailcore::String * partID);

    private:
        int64_t mMessageRowID;
        mailcore::String * mPartID;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBMessagePartInfo__) */
