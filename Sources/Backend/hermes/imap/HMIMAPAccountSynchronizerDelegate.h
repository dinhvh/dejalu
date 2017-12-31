// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMIMAPAccountSynchronizerDelegate_h
#define dejalu_HMIMAPAccountSynchronizerDelegate_h

#include <MailCore/MailCore.h>

#include "HMConstants.h"

#ifdef __cplusplus

namespace hermes {

    class IMAPAccountSynchronizer;
    
    class IMAPAccountSynchronizerDelegate {
        
    public:
        virtual void accountSynchronizerOpened(IMAPAccountSynchronizer * account) {}
        virtual void accountSynchronizerClosed(IMAPAccountSynchronizer * account) {}
        virtual void accountSynchronizerGotFolders(IMAPAccountSynchronizer * account) {}
        virtual void accountSynchronizerFoldersUpdated(IMAPAccountSynchronizer * account) {}
        virtual void accountSynchronizerConnected(IMAPAccountSynchronizer * account) {}
        virtual void accountSynchronizerFetchSummaryDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID) {}
        virtual void accountSynchronizerFetchPartDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID) {}
        virtual void accountSynchronizerStateUpdated(IMAPAccountSynchronizer * account) {}

        virtual void accountSynchronizerLocalMessageSaved(IMAPAccountSynchronizer * account, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer) {}
        virtual void accountSynchronizerPushMessageDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID) {}
        virtual void accountSynchronizerMessageSaved(IMAPAccountSynchronizer * account, int64_t folderID, mailcore::String * messageID) {}

        virtual void accountSynchronizerSyncDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, mailcore::String * folderPath) {}
        
        virtual void accountSynchronizerNotifyAuthenticationError(IMAPAccountSynchronizer * account, hermes::ErrorCode error) {}
        virtual void accountSynchronizerNotifyConnectionError(IMAPAccountSynchronizer * account, hermes::ErrorCode error) {}
        virtual void accountSynchronizerNotifyFatalError(IMAPAccountSynchronizer * account, hermes::ErrorCode error) {}
        virtual void accountSynchronizerNotifyCopyError(IMAPAccountSynchronizer * account, hermes::ErrorCode error) {}
        virtual void accountSynchronizerNotifyAppendError(IMAPAccountSynchronizer * account, hermes::ErrorCode error) {}

        virtual void accountSynchronizerAccountInfoChanged(IMAPAccountSynchronizer * account) {}

        virtual void accountSynchronizerFoldersChanged(IMAPAccountSynchronizer * account, hermes::ErrorCode error) {}
        virtual void accountSynchronizerFolderUnseenChanged(IMAPAccountSynchronizer * account, mailcore::String * folderPath) {}
        virtual void accountSynchronizerNotifyUnreadEmail(IMAPAccountSynchronizer * account, mailcore::String * folderPath) {}

        virtual void accountSynchronizerHasConversationIDForMessageID(IMAPAccountSynchronizer * account, mailcore::String * messageID, int64_t conversationID) {}
        virtual void accountSynchronizerMessageSourceFetched(IMAPAccountSynchronizer * account, hermes::ErrorCode error,
                                                             int64_t folderID, int64_t messageRowID,
                                                             mailcore::Data * messageData) {}
        virtual void accountSynchronizerHasNewContacts(IMAPAccountSynchronizer * account) {}

        virtual mailcore::Array * accountSynchronizerFavoriteFolders(IMAPAccountSynchronizer * account) { return NULL; }

        virtual void accountSynchronizerRemoveMessageIDsFromSendQueue(mailcore::Set * messageIDs) {}
    };
}

#endif

#endif
