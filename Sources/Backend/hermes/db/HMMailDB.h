// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __hermes__HMMailDB__
#define __hermes__HMMailDB__

#include <MailCore/MailCore.h>
#include <sqlite3.h>
#include "HMMailDBTypes.h"

#ifdef __cplusplus

namespace mailcore {
};

// TODO:
// performance issue when uidvalidity occurs.

namespace hermes {
    class MailDBChanges;
    class MailDBLocalMessagesChanges;
    class SearchIndex;
    class SQLiteKVDB;
    class SQLiteSearchIndex;

    class MailDB : public mailcore::Object {
    public:
        MailDB();
        virtual ~MailDB();
        
        static mailcore::Array * notificationHeaders();
        static mailcore::Array * headersToFetch();

        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();
        
        virtual void open();
        virtual void close();
        
        virtual int64_t addFolder(mailcore::String * folderPath);
        virtual void validateFolder(mailcore::String * folderPath, uint32_t uidValidity, MailDBChanges * changes);
        virtual void removeFolder(mailcore::String * folderPath, MailDBChanges * changes);

        // Returns map folderPath -> folderID
        virtual mailcore::HashMap * folders();
        
        virtual int64_t addIMAPMessage(int64_t folderID, mailcore::IMAPMessage * msg, bool notificationEnabled,
                                       int64_t draftsFolderID, MailDBChanges * changes);
        virtual void removeMessage(int64_t messageRowID, MailDBChanges * changes);
        virtual void removeMessageUid(int64_t folderID, uint32_t uid, MailDBChanges * changes);
        virtual void changeMessageWithUID(int64_t folderID, uint32_t uid, mailcore::MessageFlag flags, mailcore::MessageFlag mask,
                                          int64_t draftsFolderID,
                                          MailDBChanges * changes, int64_t * pRowID, int64_t * pPeopleViewID);
        virtual void changeMessageLabelsWithUID(int64_t messageRowID, int64_t peopleViewID, mailcore::Array * labels, MailDBChanges * changes);

        virtual void markMessageAsRead(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes);
        virtual void markMessageAsUnread(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes);
        virtual void markMessageAsFlagged(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes);
        virtual void markMessageAsUnflagged(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes);
        virtual void markMessageAsDeleted(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes);
        
        virtual void markPeopleViewAsRead(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID, MailDBChanges * changes);
        virtual void markPeopleViewAsUnread(int64_t peopleViewID, int64_t folderID,
                                            int64_t inboxFolderID, int64_t sentFolderID, int64_t draftsFolderID,
                                            MailDBChanges * changes);
        virtual void markPeopleViewAsFlagged(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID,
                                             MailDBChanges * changes);
        virtual void markPeopleViewAsUnflagged(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID,
                                               MailDBChanges * changes);
        virtual void markPeopleViewAsDeleted(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID,
                                             MailDBChanges * changes);

        virtual void copyMessageToFolder(int64_t messageRowID, int64_t otherFolderID, mailcore::IndexSet * foldersIDs,
                                         int64_t draftsFolderID, MailDBChanges * changes);
        virtual void copyPeopleViewToFolder(int64_t peopleViewID, int64_t otherFolderID, mailcore::HashMap * foldersScores, mailcore::IndexSet * foldersIDs,
                                            int64_t draftsFolderID, MailDBChanges * changes);
        virtual void moveMessageToFolder(int64_t messageRowID, int64_t otherFolderID, mailcore::IndexSet * foldersIDs,
                                         int64_t draftsFolderID, MailDBChanges * changes);
        virtual void movePeopleViewToFolder(int64_t peopleViewID, int64_t otherFolderID, mailcore::HashMap * foldersScores, mailcore::IndexSet * foldersIDs,
                                            int64_t draftsFolderID, MailDBChanges * changes);
        virtual void purgeMessageToFolder(int64_t messageRowID, int64_t trashFolderID, mailcore::IndexSet * foldersIDs,
                                          int64_t draftsFolderID, MailDBChanges * changes);
        virtual void purgePeopleViewToFolder(int64_t peopleViewID, int64_t folderID,
                                             int64_t trashFolderID, mailcore::IndexSet * foldersIDs,
                                             int64_t draftsFolderID, MailDBChanges * changes);
        virtual void removeCopyMessage(int64_t rowID);
        virtual void clearMovingForMessage(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes);

        virtual mailcore::Array * messagesUidsToPurge(int64_t folderID);
        virtual mailcore::Array * messagesUidsToMove(int64_t folderID);
        virtual mailcore::Array * messagesUidsToCopy(int64_t folderID);

        // Adds a message that needs to be synced to IMAP.
        // needsToBeSentToServer is true if we need to append it to a folder on the server.
        // typically, needsToBeSentToServer is false when adding a message to the sent folder on Gmail
        // (or when a draft is still being edited).
        // needsToBeSentToServer is true when adding it to drafts.
        //
        // When needsToBeSentToServer is false, after a sync that happened 15 minutes after it has been added,
        // the message will be removed.
        virtual int64_t addPendingMessageWithData(int64_t folderID, mailcore::Data * data,
                                                  bool needsToBeSentToServer,
                                                  bool hasBeenPushed,
                                                  mailcore::String * parsedMessageID,
                                                  int64_t draftsFolderID,
                                                  MailDBChanges * changes);
        virtual void setLocalMessagePushed(int64_t messageRowID);
        virtual void removeExpiredLocalMessage(int64_t folderID, MailDBChanges * changes);
        virtual mailcore::HashMap * nextMessageToPush(int64_t folderID, bool draftBehaviorEnabled);

        virtual mailcore::Array * peopleConversations(bool isStarred = false);
        virtual mailcore::Array * peopleConversationsForFolder(int64_t folderID, bool isUnread = false);
        virtual mailcore::IndexSet * uids(int64_t folderID);
        virtual mailcore::IndexSet * peopleViewIDsForKeywords(mailcore::Array * keywords);
        virtual mailcore::Array * peopleConversationsForKeywords(mailcore::Array * keywords);
        
        // emailSet are the emails of the account.
        virtual mailcore::HashMap * peopleConversationInfo(int64_t peopleConversationID,
                                                           mailcore::HashMap * foldersScores,
                                                           int64_t inboxFolderID,
                                                           mailcore::Set * emailSet,
                                                           mailcore::Set * folderIDToExcludeFromUnread,
                                                           MailDBChanges * changes);
        virtual mailcore::Array * messagesForPeopleConversation(int64_t peopleConversationID,
                                                                mailcore::HashMap * foldersScores);
        //virtual mailcore::Array * messagesUidsForPeopleConversation(int64_t peopleConversationID);

        virtual mailcore::IndexSet * messagesForFolderID(int64_t folderID, int64_t minimumRowID);
        
        virtual void storeValueForKey(mailcore::String * key, mailcore::Data * value);
        virtual mailcore::Data * retrieveValueForKey(mailcore::String * key);
        void removeValueForKey(mailcore::String * key);

        virtual mailcore::Data * retrieveDataForLocalPartWithUniqueID(int64_t messageRowID, mailcore::String * uniqueID);
        virtual mailcore::Data * retrieveDataForPart(int64_t messageRowID, mailcore::String * partID);
        virtual void storeDataForPart(int64_t messageRowID,
                                      mailcore::String * partID, mailcore::Data * data,
                                      MailDBChanges * changes);
        virtual void parseMessageAndStoreParts(int64_t messageRowID,
                                               mailcore::Data * data,
                                               MailDBChanges * changes);

        virtual mailcore::String * renderMessageSummary(int64_t messageRowID,
                                                        mailcore::Array * requiredParts,
                                                        bool * p_hasMessagePart,
                                                        bool * p_shouldFetchFullMessage);
        virtual mailcore::HashMap * messageInfo(int64_t messageRowID,
                                                mailcore::Array * requiredParts,
                                                mailcore::Set * emailSet,
                                                bool renderImageEnabled);

        virtual void nextUidToFetch(int64_t folderID, uint32_t maxUid, uint32_t * pUid, int64_t * pMessageRowID);
        virtual void uidToFetch(int64_t messageRowID, uint32_t * pUid);
        virtual mailcore::Encoding encodingForPart(int64_t messageRowID, mailcore::String * partID);
        virtual void markAsFetched(int64_t pMessageRowID, MailDBChanges * changes);
        
        virtual MailDBLocalMessagesChanges * localMessagesChanges(int64_t folderID);
        virtual void removeLocalMessagesChanges(mailcore::IndexSet * rowsIDs);

        virtual void removeSentDraftWithMessageID(int64_t folderID, mailcore::String * messageID);
        virtual mailcore::IndexSet * sentDraftsToRemoveWithMessageID(int64_t folderID);
        virtual void removeSentDraftRemove(int64_t folderID);

        void storeLabelsForMessage(int64_t messageRowID, mailcore::Array * labels);
        mailcore::Array * labelsForMessage(int64_t messageRowID);

        virtual mailcore::AbstractMessage * messageForRowIDNoAssert(int64_t messageRowID);
        virtual mailcore::AbstractMessage * messageForRowID(int64_t messageRowID);

        virtual mailcore::MessageParser * storedParsedMessage(int64_t messageRowID);

        virtual int64_t peopleViewIDForMessageID(mailcore::String * messageID);

        virtual void removeLabelsForConversation(int64_t conversationRowID, int64_t folderID, int64_t trashFolderID, mailcore::String * folderName, MailDBChanges * changes);
        virtual void addLabelsForConversation(int64_t conversationRowID, int64_t folderID, int64_t trashFolderID, mailcore::String * folderName, MailDBChanges * changes);

        virtual void storeLastSeenUIDForFolder(int64_t folderID);
        virtual bool isFolderUnseen(int64_t folderID);

        virtual void storeDefaultNamespace(mailcore::IMAPNamespace * ns);
        virtual mailcore::IMAPNamespace * defaultNamespace();

        virtual mailcore::HashMap * foldersCounts();

        virtual mailcore::Array * recipientsForMessages(mailcore::IndexSet * messageRowID);
        virtual mailcore::Array * addToSavedRecipients(mailcore::Array * addresses, int64_t rowID);
        virtual mailcore::Array * savedRecipients();
        virtual int64_t lastUidForSavedRecipients();

        virtual mailcore::String * filenameForRowID(int64_t messageRowID);

        virtual bool checkFolderSeen(int64_t folderID);

        virtual bool isFirstSyncDone(int64_t folderID);
        virtual void markFirstSyncDone(int64_t folderID);

        virtual void beginTransaction();
        virtual void commitTransaction(MailDBChanges * changes);

    public: // private for SQLiteKVDB
        virtual void kv_setObjectForKey(mailcore::String * key, mailcore::Data * data);
        virtual mailcore::Data * kv_objectForKey(mailcore::String * key);
        virtual void kv_removeObjectForKey(mailcore::String * key);

    public: // private for SQLiteIndexSearch
        virtual void index_setStringForID(int64_t identifier, mailcore::String * text);
        virtual void index_setStringsForID(int64_t identifier, mailcore::Array * tokens);
        virtual void index_setTransformedStringForID(int64_t identifier, mailcore::String * text);
        virtual void index_removeID(int64_t identifier);
        virtual mailcore::IndexSet * index_search(mailcore::String * searchString);

    private:
        mailcore::String * mPath;
        sqlite3 * mSqlite;
        SQLiteKVDB * mKVDB;
        SQLiteSearchIndex * mIndex;

        mailcore::HashMap * mStatementsCache;
        bool mCreatedRawMessageFolder;

        time_t mDebugLastLogDate;

        mailcore::HashMap * mSerializedMessageCache;
        
        mailcore::HashMap * computeAttachment(mailcore::AbstractMessage * msg);
        int64_t sqliteAddMessage(uint32_t uid, mailcore::String * msgid, uint64_t folderID, time_t date,
                                 mailcore::MessageFlag flags, mailcore::String * filename,
                                 int attachments_count,
                                 mailcore::String * attachment_filename,
                                 bool notificationEnabled,
                                 MailDBChanges * changes);
        int64_t sqliteAddConversation();
        void sqliteRemoveConversation(int64_t conversationRowID);
        void sqliteChangeConversationIDForMessageWithRowID(int64_t messageRowID,
                                                           int64_t conversationRowID);
        void sqliteChangeConversationIDForMessagesWithConversationID(int64_t oldConversationRowID,
                                                                     int64_t conversationRowID);
        void sqliteChangeConversationRecipientMD5(int64_t conversationRowID, mailcore::String * md5);
        void sqliteChangePeopleViewIDForMessagesWithConversationID(int64_t conversationRowID,
                                                                   int64_t peopleViewID,
                                                                   MailDBChanges * changes,
                                                                   int64_t peopleViewDate,
                                                                   bool peopleHasAttachment,
                                                                   int64_t draftsFolderID);
        void sqliteChangePeopleViewIDForMessage(int64_t messageRowID,
                                                int64_t folderID,
                                                int64_t peopleViewID,
                                                int64_t date,
                                                bool hasAttachment,
                                                MailDBChanges * changes,
                                                int64_t peopleViewDate,
                                                bool peopleHasAttachment,
                                                int64_t draftsFolderID);
        int64_t sqlitePeopleViewIDForConversationIDWithRecipientMD5(int64_t conversationID, mailcore::String * recipientMD5,
                                                                    time_t date, bool hasAttachment,
                                                                    bool createIfNeeded,
                                                                    MailDBChanges * changes, int64_t * pPeopleViewDate,
                                                                    bool * pPeopleHasAttachment);
        bool sqliteCheckRemovePeopleViewID(int64_t peopleViewID, MailDBChanges * changes);
        bool sqliteCheckRemoveConversationID(int64_t conversationID);
        void sqliteAddFolderForPeopleViewID(int64_t peopleViewID, int64_t folderID, MailDBChanges * changes);
        void sqliteRemoveFolderForPeopleViewID(int64_t peopleViewID, int64_t folderID, MailDBChanges * changes);
        
        void sqliteBeginTransaction();
        void sqliteCommitTransaction();
        
        void internalRemoveMessage(int64_t messageRowID, MailDBChanges * changes, bool removeEntry);
        void internalRemoveMessageUid(int64_t folderID, uint32_t uid, MailDBChanges * changes, bool removeEntry);
        void internalCommonRemoveMessage(int64_t messageRowID, int64_t folderID, uint32_t uid,
                                         int64_t peopleViewRowID, int64_t conversationRowID,
                                         MailDBChanges * changes, bool removeEntry, mailcore::String * basename);
        int64_t addMessage(int64_t folderID,
                           uint32_t msgUid, mailcore::AbstractMessage * msg,
                           mailcore::MessageFlag flags, mailcore::String * filename,
                           bool notificationEnabled,
                           int64_t draftsFolderID,
                           MailDBChanges * changes);
        void internalAddMessage(int64_t folderID, int64_t messageRowID,
                                mailcore::AbstractMessage * msg, mailcore::MessageFlag flags,
                                int64_t draftsFolderID,
                                MailDBChanges * changes);
        mailcore::String * folderPathForFolderID(int64_t folderID);
        int64_t rowIDForMessage(int64_t folderID, uint32_t uid);

        void mutateMessageFlag(int64_t messageRowID, mailcore::MessageFlag mask, bool remove, int64_t draftsFolderID, MailDBChanges * changes, bool mutateOther = true);
        void mutateMessageLabel(int64_t messageRowID, mailcore::String * label, bool remove, MailDBChanges * changes, bool mutateOther = true);
        void mutateMessageFlagAndLabel(int64_t messageRowID, mailcore::MessageFlag mask, mailcore::String * label, bool remove,
                                       int64_t draftsFolderID, MailDBChanges * changes, bool mutateOther = true);

        /*
        void changeMessageWithRowID(int64_t rowID,
                                    mailcore::MessageFlag flags,
                                    mailcore::MessageFlag mask,
                                    MailDBChanges * changes);
         */
        bool changeMessageLabel(int64_t messageRowID, int64_t peopleViewID, mailcore::String * label, bool remove, MailDBChanges * changes);
        bool changeMessageCommon(int64_t folderID,
                                 int64_t rowID,
                                 int64_t peopleViewID,
                                 mailcore::MessageFlag currentFlags,
                                 mailcore::MessageFlag flags,
                                 mailcore::MessageFlag mask,
                                 bool currentMoving,
                                 bool moving,
                                 bool adding,
                                 int64_t draftsFolderID,
                                 MailDBChanges * changes);
        bool changeMessageToMoving(int64_t folderID,
                                   int64_t rowID,
                                   mailcore::MessageFlag flags,
                                   bool currentMoving,
                                   bool moving,
                                   int64_t draftsFolderID,
                                   MailDBChanges * changes);

        mailcore::Array * messagesRowIDsForPeopleViewID(int64_t peopleViewID, int64_t folderID);
        mailcore::Array * mainMessagesRowIDsForPeopleViewID(int64_t peopleViewID, int64_t inboxFolderID, int64_t sentFolderID);

        void indexSetMessageSummary(int64_t messageRowID, mailcore::AbstractMessage * msg, mailcore::String * summary);
        void indexAddMessageHeaders(int64_t messageRowID, mailcore::AbstractMessage * msg);
        void indexAddMessageAttachments(int64_t messageRowID, mailcore::AbstractMessage * msg);
        void indexRemoveMessage(int64_t messageRowID);
        mailcore::IndexSet * messagesRowsIDsForKeywords(mailcore::Array * keywords);
        
        int64_t searchMetaPeopleViewID(int64_t messageRowID);
        void searchMetaUpdate(int64_t messageRowID, int64_t peopleViewID);
        void removeSearchMetaForMessage(int64_t messageRowID);
        mailcore::String * localMessageFilenameWithBasename(mailcore::String * basename);
        mailcore::MessageParser * messageParserForRowID(int64_t messageRowID);
        void storeFilenameForMessageParser(int64_t messageRowID, mailcore::String * filename);
        mailcore::Data * dataForMessageParser(int64_t messageRowID);
        void removeMessageParserForRowID(int64_t messageRowID);

        void removeLabelsForMessage(int64_t messageRowID);

        void removeMatchingLocalMessage(int64_t folderID, mailcore::String * messageID, time_t date, MailDBChanges * changes);
        void removeMatchingPendingCopyMessage(int64_t folderID, mailcore::String * messageID, int64_t date, MailDBChanges * changes);

        mailcore::Array * rowsForMessageID(mailcore::String * msgid, int64_t peopleViewID);
        void sqliteExecuteStatement(const char * statement);
        int sqlitePrepare(const char * statement, sqlite3_stmt ** p_stmt);
        void sqliteReset(sqlite3_stmt * stmt);

        void copyMessageToFolderCommon(int64_t messageRowID, int64_t otherFolderID, int deleteOriginal, mailcore::IndexSet * foldersIDs,
                                       int64_t draftsFolderID, MailDBChanges * changes);
        int64_t originalMessageRowID(int64_t messageRowID);
        mailcore::Array * messagesUidsToCopyCommon(int64_t folderID, int deleteOriginal);
        mailcore::HashMap * addressToHashMap(mailcore::Address * address);
        mailcore::Array * addressesToHashMaps(mailcore::Array * /* HashMap */ addresses);

        mailcore::Array * messageForConversationNoTrash(int64_t peopleConversationID, int64_t folderID, int64_t trashFolderID);
        bool isMetaValid();
        void removeFile(mailcore::String * filename);
        void removeFileWithType(mailcore::String * filename, int type);
        void resetDB();
        bool storeLastUIDForFolder(int64_t folderID, int64_t uid);
        void removePartsForMessage(int64_t messageRowID);
        void recursiveStorePart(int64_t messageRowID,
                                mailcore::AbstractPart * part,
                                MailDBChanges * changes);
        void recursiveStoreSinglePart(int64_t messageRowID,
                                      mailcore::Attachment * part,
                                      MailDBChanges * changes);
        void recursiveStoreMessagePart(int64_t messageRowID,
                                       mailcore::MessagePart * part,
                                       MailDBChanges * changes);
        void recursiveStoreMultipart(int64_t messageRowID,
                                     mailcore::Multipart * part,
                                     MailDBChanges * changes);

        bool isMessageStoredInDatabase(int64_t messageRowID);
        void checkMessageIsStoredInDatabase(int64_t messageRowID);
        void computePeopleViewCounts(MailDBChanges * changes);
        bool isMessageWithoutBodystructure(mailcore::AbstractMessage * msg);
        void storeParsedMessage(int64_t messageRowID, mailcore::MessageParser * message);
        int64_t peopleViewIDForMessageRowID(int64_t messageRowID);
        bool peopleViewHasAttachment(int64_t peopleViewID);

    };
}

#endif

#endif /* defined(__hermes__HMMailDB__) */
