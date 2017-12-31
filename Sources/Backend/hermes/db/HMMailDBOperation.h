// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBOperation__
#define __dejalu__HMMailDBOperation__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    class MailDB;
    class MailStorage;
    class MailDBChanges;
    
    class MailDBOperation : public mailcore::Operation {
    public:
        MailDBOperation();
        virtual ~MailDBOperation();
        
        virtual void setSyncDB(MailDB * syncDB);
        virtual MailDB * syncDB();
        
        virtual void setStorage(MailStorage * storage);
        virtual MailStorage * storage();
        
        virtual void setOperationQueue(mailcore::OperationQueue * queue);
        virtual mailcore::OperationQueue * operationQueue();
        
        virtual MailDBChanges * changes();
        
        virtual void start();
        
    public: // override
        virtual void afterMain();
        
    private:
        MailDB * mSyncDB;
        MailStorage * mStorage;
        mailcore::OperationQueue * mQueue;
        MailDBChanges * mChanges;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBOperation__) */
