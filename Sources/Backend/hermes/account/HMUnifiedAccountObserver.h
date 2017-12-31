// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMUnifiedAccountObserver_h
#define HMUnifiedAccountObserver_h

#ifdef __cplusplus

#include "HMConstants.h"

namespace hermes {

    class UnifiedAccount;

    class UnifiedAccountObserver {

    public:
        virtual void accountGotFolders(UnifiedAccount * account, unsigned int accountIndex) {}
        virtual void accountFoldersUpdated(UnifiedAccount * account, unsigned int accountIndex) {}
        virtual void accountFetchSummaryDone(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error, int64_t messageRowID) {}
        virtual void accountFetchPartDone(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID) {} // not used
        virtual void accountStateUpdated(UnifiedAccount * account, unsigned int accountIndex) {}

        virtual void accountLocalMessageSaved(UnifiedAccount * account, unsigned int accountIndex, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer) {} // not used
        virtual void accountPushMessageDone(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error, int64_t messageRowID) {} // not used
        virtual void accountMessageSaved(UnifiedAccount * account, unsigned int accountIndex, int64_t folderID, mailcore::String * messageID) {}

        virtual void accountSyncDone(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error, mailcore::String * folderPath) {}

        virtual void accountFoldersChanged(UnifiedAccount * account, unsigned int accountIndex, hermes::ErrorCode error) {}

    };
}

#endif

#endif /* HMUnifiedAccountObserver_h */
