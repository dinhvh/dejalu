// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMAsyncMailDB__
#define __dejalu__HMAsyncMailDB__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    class MailDB;
    class MailDBOperation;
    class MailDBAddMessagesOperation;
    class MailDBPeopleConversationsOperation;
    class MailDBPeopleConversationInfoOperation;
    class MailDBConversationMessagesOperation;
    class MailDBUidsOperation;
    class MailDBRetrieveKeyValueOperation;
    class MailDBOpenOperation;
    class MailDBRetrievePartOperation;
    class MailDBMessageRenderOperation;
    class MailDBNextUIDToFetchOperation;
    class MailDBMessageInfoOperation;
    class MailDBUIDToFetchOperation;
    class MailDBMessagesLocalChangesOperation;
    class MailDBAddLocalMessagesOperation;
    class MailDBNextMessageToPushOperation;
    class MailDBUidsToCopyOperation;
    class MailDBFolderUnseenOperation;
    class MailDBPeopleViewIDOperation;
    class MailDBMessagesOperation;
    class MailDBMessagesRecipientsOperation;
    class MailDBRecipientsOperation;
    class MailDBAddToSavedRecipientsOperation;
    class MailDBCheckFolderSeenOperation;
    
    class AsyncMailDB : public mailcore::Object {
    public:
        AsyncMailDB();
        virtual ~AsyncMailDB();
        
        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();
        
        virtual MailDBOpenOperation * openOperation();
        virtual MailDBOperation * closeOperation();

        virtual MailDBOperation * addFoldersOperation(mailcore::Array * foldersPathsToAdd,
                                                      mailcore::Array * foldersPathsToRemove,
                                                      mailcore::IMAPNamespace * ns);
        virtual MailDBOperation * validateFolderOperation(mailcore::String * folderPath, uint32_t uidValidity);
        virtual MailDBOperation * storeValueForKeyOperation(mailcore::String * key, mailcore::Data * value);
        virtual MailDBRetrieveKeyValueOperation * retrieveValueForKey(mailcore::String * key);
        
        virtual MailDBAddMessagesOperation * addMessagesOperation(int64_t folderID,
                                                                  mailcore::Array * msgs,
                                                                  int64_t draftsFolderID);
        virtual MailDBOperation * removeMessagesOperation(mailcore::Array * messagesRowIDs);
        virtual MailDBOperation * removeMessagesUidsOperation(int64_t folderID, mailcore::IndexSet * messagesUids);
        virtual MailDBOperation * changeMessagesOperation(int64_t folderID, mailcore::Array * msgs, int64_t draftsFolderID);
        
        virtual MailDBPeopleConversationsOperation * starredPeopleConversationsOperation();
        virtual MailDBPeopleConversationsOperation * peopleConversationsOperation(int64_t folderID);
        virtual MailDBPeopleConversationsOperation * unreadPeopleConversationsOperation(int64_t folderID);
        virtual MailDBPeopleConversationsOperation * peopleConversationsForKeywords(mailcore::Array * keywords);
        virtual MailDBPeopleConversationInfoOperation * peopleConversationInfoOperation(int64_t peopleConversationID, mailcore::HashMap * foldersScores,
                                                                                        int64_t inboxFolderID, mailcore::Set * emailSet,
                                                                                        mailcore::Set * foldersToExcludeFromUnread);

        virtual MailDBConversationMessagesOperation * messagesForPeopleConversationOperation(int64_t peopleConversationID,
                                                                                             mailcore::HashMap * foldersScores);
        virtual MailDBMessageInfoOperation * messageInfoOperation(int64_t messageRowID,
                                                                  mailcore::Set * emailSet,
                                                                  bool renderImageEnabled);
        
        virtual MailDBUidsOperation * uidsOperation(int64_t folderID);
        
        virtual MailDBRetrievePartOperation * dataForPartOperation(int64_t messageRowID,
                                                                   mailcore::String * partID);
        virtual MailDBRetrievePartOperation * dataForPartByUniqueIDOperation(int64_t messageRowID,
                                                                             mailcore::String * uniqueID);
        virtual MailDBRetrievePartOperation * dataForLocalPartOperation(int64_t messageRowID,
                                                                        mailcore::String * uniqueID);
        virtual MailDBOperation * storeDataForPartOperation(int64_t messageRowID,
                                                            mailcore::String * partID,
                                                            mailcore::Data * data);

        virtual MailDBOperation * storeDataForMessageDataOperation(int64_t messageRowID, mailcore::Data * data);

        virtual MailDBMessageRenderOperation * messageRenderSummaryOperation(int64_t messageRowID);
        
        virtual MailDBNextUIDToFetchOperation * nextUidToFetchOperation(int64_t folderID, uint32_t maxUid);
        virtual MailDBUIDToFetchOperation * uidToFetchOperation(int64_t messageRowID);
        virtual MailDBUIDToFetchOperation * uidEncodingToFetchOperation(int64_t messageRowID, mailcore::String * partID);
        virtual MailDBOperation * markAsFetchedOperation(int64_t messageRowID);
        
        virtual MailDBOperation * archivePeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                      int64_t inboxFolderID, int64_t draftsFolderID);
        virtual MailDBOperation * purgeFromTrashPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                             int64_t trashFolderID, int64_t draftsFolderID);
        virtual MailDBOperation * starPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID);
        virtual MailDBOperation * unstarPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID);
        virtual MailDBOperation * markAsReadPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID);
        virtual MailDBOperation * markAsUnreadPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t inboxFolderID,
                                                                           int64_t sentFolderID, int64_t draftsFolderID);
        virtual MailDBOperation * addLabelToPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label, int64_t folderID, int64_t trashFolderID);
        virtual MailDBOperation * removeLabelFromPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                              mailcore::String * label, int64_t folderID,
                                                                              int64_t trashFolderID);
        virtual MailDBOperation * removeConversationFromFolderOperation(mailcore::Array * conversationIDs, int64_t folderID,
                                                                        int64_t draftsFolderID);

        virtual MailDBOperation * markAsReadMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID);
        virtual MailDBOperation * markAsDeletedMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID);
        virtual MailDBOperation * markAsDeletedPeopleConversationsFromFolderOperation(mailcore::Array * conversationIDs,
                                                                                      int64_t folderID, mailcore::String * folderPath,
                                                                                      int64_t trashFolderID, int64_t draftsFolderID);

        virtual MailDBMessagesLocalChangesOperation * messagesLocalChangesOperation(int64_t folderID);
        virtual MailDBOperation * removeMessagesLocalChangesOperation(mailcore::IndexSet * messagesRowIDs);
        
        virtual MailDBAddLocalMessagesOperation * addPendingMessageWithDataOperation(int64_t folderID, mailcore::Data * data,
                                                                                     bool needsToBeSentToServer,
                                                                                     bool hasBeenPushed,
                                                                                     int64_t draftsFolderID);
        virtual MailDBOperation * setLocalMessagePushedOperation(int64_t messageRowID);
        virtual MailDBOperation * removeExpiredLocalMessageOperation(int64_t folderID);
        virtual MailDBNextMessageToPushOperation * nextMessageToPush(int64_t folderID, bool draftBehaviorEnabled);

        virtual MailDBOperation * copyPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                   mailcore::HashMap * foldersScores, int64_t draftsFolderID);
        virtual MailDBOperation * movePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                   mailcore::HashMap * foldersScores, int64_t draftsFolderID);
        virtual MailDBOperation * purgePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID,
                                                                    int64_t trashFolderID);
        virtual MailDBOperation * purgeMessagesOperation(mailcore::Array * messagesRowIDs,
                                                         int64_t trashFolderID, int64_t draftsFolderID);

        virtual MailDBUidsToCopyOperation * messagesUidsToPurgeOperation(int64_t folderID);
        virtual MailDBUidsToCopyOperation * messagesUidsToMoveOperation(int64_t folderID);
        virtual MailDBUidsToCopyOperation * messagesUidsToCopyOperation(int64_t folderID);

        virtual MailDBOperation * removeCopyMessagesOperation(mailcore::IndexSet * rowsIDs, mailcore::IndexSet * messagesRowIDs,
                                                              bool clearMoving, int64_t draftsFolderID);
        virtual MailDBOperation * removeSentDraftMessageWithMessageIDOperation(int64_t folderID, mailcore::String * messageID);
        virtual MailDBOperation * purgeSentDraftMessageOperation(int64_t folderID, int64_t trashFolderID, int64_t draftsFolderID);

        virtual MailDBOperation * storeLastSeenUIDOperation(int64_t folderID);
        virtual MailDBFolderUnseenOperation * isFolderUnseenOperation(int64_t folderID);

        virtual MailDBPeopleViewIDOperation * peopleViewIDOperation(mailcore::String * msgid);

        virtual MailDBMessagesOperation * messagesForFolderOperation(int64_t folderID);
        virtual MailDBMessagesRecipientsOperation * recipientsForMessagesRowsIDsOperation(mailcore::IndexSet * messagesRowsIDs, int maxCount);
        virtual MailDBAddToSavedRecipientsOperation * addToSavedRecipientsOperation(mailcore::Array * addresses, int64_t lastRowID);

        virtual MailDBCheckFolderSeenOperation * checkFolderSeenOperation(int64_t folderID);
        virtual MailDBOperation * markFirstSyncDoneOperation(int64_t folderID);

    private:
        MailDB * mSyncDB;
        mailcore::OperationQueue * mQueue;
    };
}

#endif

#endif /* defined(__dejalu__HMAsyncMailDB__) */
