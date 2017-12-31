// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMIMAPFolderSynchronizerDelegate_h
#define dejalu_HMIMAPFolderSynchronizerDelegate_h

#include <MailCore/MailCore.h>

#include "HMConstants.h"

#ifdef __cplusplus

namespace hermes {
    
    class IMAPFolderSynchronizer;
    
    class IMAPFolderSynchronizerDelegate {
        
    public:
        virtual void folderSynchronizerSyncDone(IMAPFolderSynchronizer * synchronizer) {}

        virtual mailcore::String * folderSynchronizerTrashFolder(IMAPFolderSynchronizer * synchronizer) { return NULL; }
        virtual mailcore::String * folderSynchronizerDraftsFolder(IMAPFolderSynchronizer * synchronizer) { return NULL; }
        virtual bool folderSynchronizerSyncAccountIsSearching(IMAPFolderSynchronizer * synchronizer) { return false; }
        virtual void folderSynchronizerSyncStepDone(IMAPFolderSynchronizer * synchronizer) {}
        virtual void folderSynchronizerSyncShouldSync(IMAPFolderSynchronizer * synchronizer) {}
        virtual void folderSynchronizerSyncFetchSummaryDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID) {}
        virtual void folderSynchronizerSyncFetchPartDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID) {}
        virtual void folderSynchronizerStateUpdated(IMAPFolderSynchronizer * synchronizer) {}
        virtual void folderSynchronizerSyncPushMessageDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID) {}
        virtual void folderSynchronizerUnseenChanged(IMAPFolderSynchronizer * synchronizer) {}
        virtual void folderSynchronizerNotifyUnreadEmail(IMAPFolderSynchronizer * synchronizer) {}
        virtual void folderSynchronizerMessageSourceFetched(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error,
                                                            int64_t messageRowID,
                                                            mailcore::Data * messageData) {}
        virtual void folderSynchronizerFetchedHeaders(IMAPFolderSynchronizer * synchronizer) {}
    };
    
}

#endif

#endif
