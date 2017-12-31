// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFolderSyncStep__
#define __dejalu__HMIMAPFolderSyncStep__

#include <MailCore/MailCore.h>

#include "HMConstants.h"
#include "HMIMAPSyncTypes.h"

#ifdef __cplusplus

namespace hermes {
    
    class MailStorage;
    class IMAPFolderSyncStepDelegate;
    
    class IMAPFolderSyncStep : public mailcore::Object {
        
    public:
        IMAPFolderSyncStep();
        virtual ~IMAPFolderSyncStep();
        
        virtual void setSession(mailcore::IMAPAsyncSession * session);
        virtual mailcore::IMAPAsyncSession * session();
        
        virtual void setStorage(MailStorage * storage);
        virtual MailStorage * storage();
        
        virtual void setFolderPath(mailcore::String * path);
        virtual mailcore::String * folderPath();

        virtual void setSyncType(IMAPSyncType syncType);
        virtual IMAPSyncType syncType();

        virtual void setDelegate(IMAPFolderSyncStepDelegate * delegate);
        virtual IMAPFolderSyncStepDelegate * delegate();
        
        virtual void setError(hermes::ErrorCode error);
        virtual hermes::ErrorCode error();

        virtual void setNetwork(bool network);
        virtual bool isNetwork();

        virtual int64_t folderID();

        virtual void start();
        virtual void cancel();
        
        virtual void notifyDelegateDone();
        
    private:
        mailcore::IMAPAsyncSession * mSession;
        mailcore::String * mFolderPath;
        MailStorage * mStorage;
        IMAPFolderSyncStepDelegate * mDelegate;
        hermes::ErrorCode mError;
        bool mNetwork;
        IMAPSyncType mSyncType;
    };
    
}

#endif

#endif /* defined(__dejalu__HMIMAPFolderSyncStep__) */
