// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMAccountObserver_h
#define dejalu_HMAccountObserver_h

#ifdef __cplusplus

#include "HMConstants.h"

namespace hermes {
    
    class Account;
    
    class AccountObserver {
        
    public:
        virtual void accountOpened(Account * account) {} // not used
        virtual void accountClosed(Account * account) {}
        virtual void accountGotFolders(Account * account) {}
        virtual void accountFoldersUpdated(Account * account) {}
        virtual void accountConnected(Account * account) {}
        virtual void accountFetchSummaryDone(Account * account, hermes::ErrorCode error, int64_t messageRowID) {}
        virtual void accountFetchPartDone(Account * account, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID) {} // not used
        virtual void accountStateUpdated(Account * account) {}

        virtual void accountLocalMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer) {} // not used
        virtual void accountPushMessageDone(Account * account, hermes::ErrorCode error, int64_t messageRowID) {} // not used
        virtual void accountMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID) {}

        virtual void accountSyncDone(Account * account, hermes::ErrorCode error, mailcore::String * folderPath) {}

        virtual void accountNotifyAuthenticationError(Account * account, hermes::ErrorCode error) {}
        virtual void accountNotifyConnectionError(Account * account, hermes::ErrorCode error) {}
        virtual void accountNotifyFatalError(Account * account, hermes::ErrorCode error) {}
        virtual void accountNotifyCopyError(Account * account, hermes::ErrorCode error) {}
        virtual void accountNotifyAppendError(Account * account, hermes::ErrorCode error) {}

        virtual void accountIMAPInfoChanged(Account * account) {}

        virtual void accountFoldersChanged(Account * account, hermes::ErrorCode error) {}

        virtual void accountSendDone(Account * account) {}
        virtual void accountSendingStateChanged(Account * account) {}
        virtual void accountMessageSent(Account * account, mailcore::MessageParser * parsedMessage) {}
        virtual void accountSMTPInfoChanged(Account * account) {}
        virtual void accountSenderProgress(Account * account) {}

        virtual void accountSenderNotifyAuthenticationError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
        virtual void accountSenderNotifyConnectionError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
        virtual void accountSenderNotifyFatalError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}
        // There's an error with that specific message.
        virtual void accountSenderNotifySendError(Account * account, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage) {}

        virtual void accountFolderUnseenChanged(Account * account, mailcore::String * folderPath) {}
        virtual void accountNotifyUnreadEmail(Account * account, mailcore::String * folderPath) {}

        virtual void accountHasConversationIDForMessageID(Account * account, mailcore::String * messageID, int64_t conversationID) {}

        virtual void accountMessageSourceFetched(Account * account, hermes::ErrorCode error, int64_t folderID, int64_t messageRowID,
                                                 mailcore::Data * messageData) {}

        virtual void accountHasNewContacts(Account * account) {}
    };
}

#endif

#endif
