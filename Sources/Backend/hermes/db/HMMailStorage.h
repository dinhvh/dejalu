// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailStorage__
#define __dejalu__HMMailStorage__

#include <MailCore/MailCore.h>
#include <libetpan/libetpan.h>

#ifdef __cplusplus

namespace hermes {
    
    class AsyncMailDB;
    class MailStorageView;
    //class MailDBAddFolderOperation;
    class MailDBAddMessagesOperation;
    class MailDBPeopleConversationInfoOperation;
    class MailDBConversationMessagesOperation;
    class MailDBPeopleConversationsOperation;
    class MailDBUidsOperation;
    class MailStorageObserver;
    class MailDBOperation;
    class MailDBRetrieveKeyValueOperation;
    class MailDBOpenOperation;
    class MailDBMessageRenderOperation;
    class MailDBNextUIDToFetchOperation;
    class MailDBUIDToFetchOperation;
    class MailDBRetrievePartOperation;
    class MailDBMessageInfoOperation;
    class MailDBMessagesLocalChangesOperation;
    class MailDBAddLocalMessagesOperation;
    class MailDBNextMessageToPushOperation;
    class MailDBUidsToCopyOperation;
    class MailDBFolderUnseenOperation;
    class MailDBPeopleViewIDOperation;
    class MailDBMessagesOperation;
    class MailDBRecipientsOperation;
    class MailDBMessagesRecipientsOperation;
    class MailDBAddToSavedRecipientsOperation;
    class MailDBCheckFolderSeenOperation;

    class MailStorage : public mailcore::Object {
    public:
        MailStorage();
        virtual ~MailStorage();
        
        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();
        
        virtual int64_t folderIDForPath(mailcore::String * path);
        virtual mailcore::String * pathForFolderID(int64_t folderID);
        virtual int unreadCountForFolderID(int64_t folderID);
        virtual int starredCountForFolderID(int64_t folderID);
        virtual int countForFolderID(int64_t folderID);
        virtual mailcore::Array * folders();
//        virtual mailcore::IMAPNamespace * defaultNamespace();
        virtual mailcore::Array * componentsForFolderPath(mailcore::String * path);

        virtual void openViewForFolder(int64_t folderID, mailcore::HashMap * standardFolders, mailcore::Set * emailSet, time_t ageLimit);
        virtual MailStorageView * viewForFolder(int64_t folderID);
        virtual void closeViewForFolder(int64_t folderID);
        virtual MailStorageView * openViewForSearchKeywords(mailcore::Array * keywords, mailcore::HashMap * standardFolders, mailcore::Set * emailSet);
        virtual void closeViewForSearch(MailStorageView * view);
        
        virtual MailStorageView * viewForCounters();
        virtual void closeViewForCounters(MailStorageView * view);

        //////////////////
        // Display
        
        virtual MailDBPeopleConversationsOperation * starredPeopleConversationsOperation();
        virtual MailDBPeopleConversationsOperation * peopleConversationsOperation(int64_t folderID);
        virtual MailDBPeopleConversationsOperation * unreadPeopleConversationsOperation(int64_t folderID);
        virtual MailDBPeopleConversationsOperation * peopleConversationsForKeywords(mailcore::Array * keywords);
        virtual MailDBPeopleConversationInfoOperation * peopleConversationInfoOperation(int64_t peopleConversationID, mailcore::HashMap * foldersScores,
                                                                                        int64_t inboxFolderID, mailcore::Set * emailSet,
                                                                                        mailcore::Set * foldersToExcludeFromUnread);
        virtual MailDBMessageInfoOperation * messageInfoOperation(int64_t messageRowID,
                                                                  mailcore::Set * emailSet,
                                                                  bool renderImageEnabled = true);
        virtual MailDBConversationMessagesOperation * messagesForPeopleConversationOperation(int64_t peopleConversationID,
                                                                                             mailcore::HashMap * foldersScores);
        //virtual MailDBConversationMessagesOperation * messagesUidsForPeopleConversationOperation(int64_t peopleConversationID);
        virtual MailDBMessagesOperation * messagesForFolderOperation(int64_t folderID);
        virtual MailDBMessagesRecipientsOperation * recipientsForMessagesRowsIDsOperation(mailcore::IndexSet * messagesRowsIDs, int maxCount);
        virtual MailDBAddToSavedRecipientsOperation * addToSavedRecipientsOperation(mailcore::Array * addresses, int64_t lastRowID);
//        virtual MailDBRecipientsOperation * recipientsOperation();

        //////////////////
        // User actions
        
        virtual MailDBOpenOperation * openOperation();
        virtual mailcore::Operation * closeOperation();
        
        virtual MailDBOperation * archivePeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                      int64_t folderID, int64_t draftsFolderID);
        virtual MailDBOperation * purgeFromTrashPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                             int64_t trashFolderID, int64_t draftsFolderID);
        virtual MailDBOperation * starPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID);
        virtual MailDBOperation * unstarPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID);
        virtual MailDBOperation * markAsReadPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID);
        virtual MailDBOperation * markAsUnreadPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t inboxFolderID, int64_t sentFolderID, int64_t draftsFolderID);
        virtual MailDBOperation * addLabelToPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label, int64_t folderID, int64_t trashFolderID);
        virtual MailDBOperation * removeLabelFromPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label, int64_t folderID, int64_t trashFolderID);
        virtual MailDBOperation * removeConversationFromFolderOperation(mailcore::Array * conversationIDs,
                                                                        int64_t folderID, int64_t draftsFolderID);

        virtual MailDBOperation * markAsReadMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID);

        virtual MailDBOperation * markAsDeletedMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID);

        virtual MailDBOperation * markAsDeletedPeopleConversationsFromFolderOperation(mailcore::Array * conversationIDs,
                                                                                      int64_t folderID, mailcore::String * folderPath,
                                                                                      int64_t trashFolderID, int64_t draftsFolderID);

        virtual MailDBMessagesLocalChangesOperation * messagesLocalChangesOperation(int64_t folderID);
        virtual MailDBOperation * removeMessagesLocalChangesOperation(mailcore::IndexSet * messagesRowIDs);
        
        virtual void addLabelToConversation(int64_t conversation, mailcore::Array * labels);
        virtual void removeLabelFromConversation(int64_t conversation, mailcore::Array * labels);
        
        virtual bool pushFlagsToServerNeeded(int64_t folderID);
        virtual void startPushFlagsToServer(int64_t folderID);
        virtual void finishedPushFlagsToServer(int64_t folderID);
        virtual void cancelledPushFlagsToServer(int64_t folderID);
        virtual void setNeedsPushFlagsToServer(int64_t folderID);

        virtual bool pushMessagesToServerNeeded(int64_t folderID);
        virtual void startPushMessagesToServer(int64_t folderID);
        virtual void finishedPushMessagesToServer(int64_t folderID);
        virtual void cancelledPushMessagesToServer(int64_t folderID);
        virtual void setNeedsPushMessagesToServer(int64_t folderID);

        virtual bool copyMessagesNeeded(int64_t folderID);
        virtual void startCopyMessages(int64_t folderID);
        virtual void finishedCopyMessages(int64_t folderID);
        virtual void cancelledCopyMessages(int64_t folderID);
        virtual void setNeedsCopyMessages(int64_t folderID);

        //////////////////
        // for Sync
        // For the following methods, the result operation should not be set a callback.
        // When the operation is finished, the observer callback will be called.
        
        virtual mailcore::Operation * addFoldersOperation(mailcore::Array * foldersPathsToAdd,
                                                          mailcore::Array * foldersPathsToRemove,
                                                          mailcore::IMAPNamespace * ns);
        virtual mailcore::Operation * validateFolderOperation(mailcore::String * folderPath, uint32_t uidValidity);
        //virtual mailcore::Operation * removeFoldersOperation(mailcore::Array * paths);
        virtual mailcore::Operation * storeValueForKeyOperation(mailcore::String * key, mailcore::Data * value);
        virtual MailDBRetrieveKeyValueOperation * retrieveValueForKey(mailcore::String * key);
        
        //virtual mailcore::Operation * addFolderOperation(mailcore::String * folderPath);
        //virtual mailcore::Operation * removeFolderOperation(int64_t folderID);
        
        virtual MailDBAddMessagesOperation * addMessagesOperation(int64_t folderID, mailcore::Array * /* IMAPMessage */ msgs, int64_t draftsFolderID);
        virtual mailcore::Operation * removeMessagesOperation(int64_t folderID, mailcore::Array * /* uint32_t */ msgsUids);
        virtual mailcore::Operation * removeMessagesUidsOperation(int64_t folderID, mailcore::IndexSet * messagesUids);
        // labels and flags
        virtual mailcore::Operation * changeMessagesOperation(int64_t folderID, mailcore::Array * /* IMAPMessage */ msgs, int64_t draftsFolderID);
        
        virtual MailDBUidsOperation * uidsOperation(int64_t folderID);
        
        virtual MailDBRetrievePartOperation * dataForPartOperation(int64_t messageRowID,
                                                                   mailcore::String * partID);
        virtual MailDBRetrievePartOperation * dataForPartByUniqueIDOperation(int64_t messageRowID,
                                                                             mailcore::String * uniqueID);
        virtual mailcore::Operation * storeDataForPartOperation(int64_t messageRowID,
                                                                mailcore::String * partID,
                                                                mailcore::Data * data);
        virtual MailDBRetrievePartOperation * dataForLocalPartOperation(int64_t messageRowID,
                                                                        mailcore::String * uniqueID);
        virtual mailcore::Operation * storeDataForMessageDataOperation(int64_t messageRowID, mailcore::Data * data);
        virtual MailDBMessageRenderOperation * messageRenderSummaryOperation(int64_t messageRowID);
        
        virtual MailDBNextUIDToFetchOperation * nextUidToFetchOperation(int64_t folderID, uint32_t maxUid);
        virtual MailDBUIDToFetchOperation * uidToFetchOperation(int64_t messageRowID);
        virtual MailDBUIDToFetchOperation * uidEncodingToFetchOperation(int64_t messageRowID, mailcore::String * partID);
        virtual mailcore::Operation * markAsFetchedOperation(int64_t messageRowID);

        virtual MailDBAddLocalMessagesOperation * addPendingMessageWithDataOperation(int64_t folderID, mailcore::Data * data,
                                                                                     bool needsToBeSentToServer,
                                                                                     bool hasBeenPushed,
                                                                                     int64_t draftsFolderID);
        virtual mailcore::Operation * setLocalMessagePushedOperation(int64_t messageRowID);
        virtual mailcore::Operation * removeExpiredLocalMessageOperation(int64_t folderID);
        virtual MailDBNextMessageToPushOperation * nextMessageToPush(int64_t folderID, bool draftBehaviorEnabled);

        virtual mailcore::Operation * copyPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                       mailcore::HashMap * foldersScores, int64_t draftsFolderID);
        virtual mailcore::Operation * movePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                       mailcore::HashMap * foldersScores, int64_t draftsFolderID);
        virtual mailcore::Operation * purgePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID,
                                                                        int64_t trashFolderID);
        virtual mailcore::Operation * purgeMessagesOperation(mailcore::Array * messagesRowIDs, int64_t trashFolderID,
                                                             int64_t draftsFolderID);

        virtual MailDBUidsToCopyOperation * messagesUidsToPurgeOperation(int64_t folderID);
        virtual MailDBUidsToCopyOperation * messagesUidsToMoveOperation(int64_t folderID);
        virtual MailDBUidsToCopyOperation * messagesUidsToCopyOperation(int64_t folderID);
        
        virtual mailcore::Operation * removeCopyMessagesOperation(mailcore::IndexSet * rowsIDs, mailcore::IndexSet * messagesRowIDs,
                                                                  bool clearMoving, int64_t draftsFolderID);

        virtual mailcore::Operation * removeSentDraftMessageWithMessageIDOperation(int64_t folderID, mailcore::String * messageID);
        virtual mailcore::Operation * purgeSentDraftMessageOperation(int64_t folderID, int64_t trashFolderID, int64_t draftsFolderID);

        virtual mailcore::Operation * storeLastSeenUIDOperation(int64_t folderID);
        virtual MailDBFolderUnseenOperation * isFolderUnseenOperation(int64_t folderID);

        virtual MailDBPeopleViewIDOperation * peopleViewIDOperation(mailcore::String * msgid);

        virtual MailDBCheckFolderSeenOperation * checkFolderSeenOperation(int64_t folderID);
        virtual mailcore::Operation * markFirstSyncDoneOperation(int64_t folderID);

    public: // private for MailDBOperation.
        virtual void notifyStorageOperationFinished(MailDBOperation * op);
        virtual void cancelViews();
        virtual void setTerminated();
        virtual bool isTerminated();

    private:
        mailcore::HashMap * mFoldersIDsToPath;
        mailcore::HashMap * mFoldersPathsToIDs;
        mailcore::HashMap * mFoldersCounts;
        mailcore::IMAPNamespace * mDefaultNamespace;
        mailcore::HashMap * mViews;
        mailcore::Array * mSearchViews;
        AsyncMailDB * mDb;
        carray * mStorageViews;
        mailcore::HashMap * mFoldersNeedsPushFlags;
        mailcore::HashMap * mFoldersNeedsPushMessage;
        mailcore::HashMap * mFoldersNeedsCopyMessage;
        mailcore::Array * mSortedFolders;
        bool mTerminated;

        void addStorageView(MailStorageView * view);
        void removeStorageView(MailStorageView * view);

        bool isTaskPending(mailcore::HashMap * taskMap, int64_t folderID);
        void startTask(mailcore::HashMap * taskMap, int64_t folderID);
        void finishedTask(mailcore::HashMap * taskMap, int64_t folderID);
        void cancelledTask(mailcore::HashMap * taskMap, int64_t folderID);
        void setTaskPending(mailcore::HashMap * taskMap, int64_t folderID);
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailStorage__) */
