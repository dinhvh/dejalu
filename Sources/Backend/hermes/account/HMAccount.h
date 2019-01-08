// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMAccount__
#define __dejalu__HMAccount__

#include <MailCore/MailCore.h>
#include <libetpan/libetpan.h>

#include "HMIMAPAccountSynchronizerDelegate.h"
#include "HMMessageQueueSenderDelegate.h"

#ifdef __cplusplus

namespace hermes {
    
    class IMAPAccountInfo;
    class SMTPAccountInfo;
    class IMAPAttachmentDownloader;
    class AccountObserver;
    class MailDBMessageInfoOperation;
    class MessageQueueSender;
    class MailDBConversationMessagesOperation;
    class MailDBRetrievePartOperation;
    class MailDBMessagesOperation;
    class MailStorageView;
    class AccountInfo;

    class Account : public mailcore::Object,
    public IMAPAccountSynchronizerDelegate,
    public MessageQueueSenderDelegate {

    public:
        Account();
        virtual ~Account();

        virtual Object * retain();
        virtual void release();
        
        virtual void setLogEnabled(bool enabled);
        virtual void setQuickSyncEnabled(bool enabled);

        virtual void addObserver(AccountObserver * observer);
        virtual void removeObserver(AccountObserver * observer);

        virtual void setAccountInfo(AccountInfo * info);
        virtual AccountInfo * accountInfo();

        virtual mailcore::String * shortDisplayName();

        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();

        virtual void load();
        virtual void save();

        virtual int64_t folderIDForPath(mailcore::String * path);
        virtual mailcore::String * pathForFolderID(int64_t folderID);
        virtual int unreadCountForFolderID(int64_t folderID);
        virtual int starredCountForFolderID(int64_t folderID);
        virtual int countForFolderID(int64_t folderID);

        virtual mailcore::String * inboxFolderPath();
        virtual mailcore::String * allMailFolderPath();
        virtual mailcore::String * archiveFolderPath();
        virtual mailcore::String * sentFolderPath();
        virtual mailcore::String * trashFolderPath();
        virtual mailcore::String * draftsFolderPath();
        virtual mailcore::String * importantFolderPath();
        virtual mailcore::String * spamFolderPath();
        virtual mailcore::String * starredFolderPath();
        virtual mailcore::Array * folders();
        virtual mailcore::Array * componentsForFolderPath(mailcore::String * path);

        virtual mailcore::Set * emailSet();

        virtual mailcore::Array * addresses();

        virtual void open();
        virtual void close();

        virtual void setSearchKeywords(mailcore::Array * keywords);
        virtual mailcore::Array * searchKeywords();
        virtual bool isSearching();

        // Doesn't need the result.
        virtual void fetchMessageSummary(int64_t folderID, int64_t messageRowID, bool urgent);
        virtual bool canFetchMessageSummary(int64_t messageRowID);

        virtual void fetchMessageSource(int64_t folderID, int64_t messageRowID);

        virtual void fetchMessagePart(int64_t folderID, int64_t messageRowID, mailcore::String * partID, bool urgent);

        virtual void disableSync();
        virtual void enableSync();

        virtual void archivePeopleConversations(mailcore::Array * conversationIDs, mailcore::HashMap * foldersScores);
        virtual void deletePeopleConversations(mailcore::Array * conversationIDs, mailcore::HashMap * foldersScores);
        virtual void purgeFromTrashPeopleConversations(mailcore::Array * conversationIDs);
        virtual void starPeopleConversations(mailcore::Array * conversationIDs);
        virtual void unstarPeopleConversations(mailcore::Array * conversationIDs);
        virtual void markAsReadPeopleConversations(mailcore::Array * conversationIDs);
        virtual void markAsUnreadPeopleConversations(mailcore::Array * conversationIDs);
        virtual void markAsReadMessages(mailcore::Array * messageRowIDs);
        virtual void removeConversationFromFolder(mailcore::Array * conversationIDs, mailcore::String * folderPath);

        virtual void saveMessageToDraft(mailcore::String * messageID, mailcore::Data * messageData, bool pushNow);
        //virtual void saveMessageToSent(mailcore::String * messageID, mailcore::Data * messageData);
        virtual void saveMessageToFolder(mailcore::String * messageID, mailcore::Data * messageData, mailcore::String * folderPath);
        virtual void removeDraftForSentMessage(mailcore::String * draftMessageID);
        virtual bool isSavingDraft(mailcore::String * draftMessageID);

        virtual void copyPeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, mailcore::HashMap * foldersScores);
        virtual void movePeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, mailcore::HashMap * foldersScores);
        virtual void purgePeopleConversations(mailcore::Array * conversationIDs);
        virtual void purgeMessage(int64_t messageRowID);

        virtual void addLabelToConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, bool isTrash);
        virtual void removeLabelFromConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, bool isTrash);

        virtual void fetchConversationIDForMessageID(mailcore::String * messageID);
        
        virtual void createFolder(mailcore::String * folderPath);
        virtual void renameFolder(mailcore::String * initialFolderPath, mailcore::String * destinationFolderPath);
        virtual void deleteFolder(mailcore::String * folderPath);

        virtual bool shouldShowProgressForFolder(int64_t folderID);
        virtual bool canLoadMoreForFolder(int64_t folderID);
        virtual void refreshFolder(int64_t folderID);
        virtual unsigned int headersProgressValueForFolder(int64_t folderID);
        virtual unsigned int headersProgressMaxForFolder(int64_t folderID);
        virtual bool loadMoreForFolder(int64_t folderID);
        virtual void resetMessagesToLoadForFolder(int64_t folderID);
        virtual bool messagesToLoadCanBeResetForFolder(int64_t folderID);

        virtual void setWaitingLoadMoreForFolder(int64_t folderID, bool waitingLoadMore);
        virtual bool isWaitingLoadMoreForFolder(int64_t folderID);

        virtual void markFolderAsSeen(int64_t folderID);
        virtual bool isFolderUnseen(int64_t folderID);

        virtual IMAPAttachmentDownloader * attachmentDownloader();

        // for debug activity report.
        virtual bool isSyncingFolder(mailcore::String * folderPath);
        virtual mailcore::String * urgentTaskDescriptionForFolder(mailcore::String * folderPath);
        virtual mailcore::String * syncStateDescriptionForFolder(mailcore::String * folderPath);

        // storage view
        virtual MailStorageView * openViewForSearchKeywords(mailcore::Array * keywords);
        virtual void closeViewForSearch(MailStorageView * view);
        virtual void openViewForFolder(int64_t folderID, time_t ageLimit);
        virtual MailStorageView * viewForFolder(int64_t folderID);
        virtual void closeViewForFolder(int64_t folderID);

        virtual MailStorageView * viewForCounters();
        virtual void closeViewForCounters(MailStorageView * view);

        // storage operations
        virtual MailDBMessageInfoOperation * messageInfoOperation(int64_t messageRowID,
                                                                  bool renderImageEnabled = true);
        virtual MailDBConversationMessagesOperation * messagesForPeopleConversationOperation(int64_t peopleConversationID,
                                                                                             mailcore::HashMap * foldersScores);
        virtual MailDBRetrievePartOperation * dataForPartOperation(int64_t messageRowID,
                                                                   mailcore::String * partID);
        virtual MailDBRetrievePartOperation * dataForLocalPartOperation(int64_t messageRowID,
                                                                        mailcore::String * uniqueID);
        virtual MailDBRetrievePartOperation * dataForPartByUniqueIDOperation(int64_t messageRowID,
                                                                             mailcore::String * uniqueID);

        // send queue
        virtual void sendMessage(mailcore::String * draftMessageID, mailcore::Data * messageData);

        virtual bool isSending();
        virtual unsigned int currentMessageIndex();
        virtual unsigned int totalMessagesCount();
        virtual unsigned int currentMessageProgress();
        virtual unsigned int currentMessageProgressMax();
        virtual mailcore::String * currentMessageSubject();

        virtual void setDeliveryEnabled(bool enabled);

    public:
        virtual mailcore::String * description();

    public: // private for IMAPAttachmentDownloader
        virtual void registerPartDownloader(IMAPAttachmentDownloader * downloader);
        virtual void unregisterPartDownloader(IMAPAttachmentDownloader * downloader);

    public: // IMAPAccountSynchronizer delegate
        virtual mailcore::Array * accountSynchronizerFavoriteFolders(IMAPAccountSynchronizer * account);
        virtual void accountSynchronizerOpened(IMAPAccountSynchronizer * account);
        virtual void accountSynchronizerClosed(IMAPAccountSynchronizer * account);
        virtual void accountSynchronizerGotFolders(IMAPAccountSynchronizer * account);
        virtual void accountSynchronizerConnected(IMAPAccountSynchronizer * account);
        virtual void accountSynchronizerFetchSummaryDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID);
        virtual void accountSynchronizerFetchPartDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID);
        virtual void accountSynchronizerMessageSourceFetched(IMAPAccountSynchronizer * account, hermes::ErrorCode error,
                                                             int64_t folderID, int64_t messageRowID,
                                                             mailcore::Data * messageData);
        virtual void accountSynchronizerStateUpdated(IMAPAccountSynchronizer * account);

        virtual void accountSynchronizerLocalMessageSaved(IMAPAccountSynchronizer * account, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer);
        virtual void accountSynchronizerPushMessageDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID);
        virtual void accountSynchronizerMessageSaved(IMAPAccountSynchronizer * account, int64_t folderID, mailcore::String * messageID);

        virtual void accountSynchronizerSyncDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, mailcore::String * folderPath);

        virtual void accountSynchronizerNotifyAuthenticationError(IMAPAccountSynchronizer * account, hermes::ErrorCode error);
        virtual void accountSynchronizerNotifyConnectionError(IMAPAccountSynchronizer * account, hermes::ErrorCode error);
        virtual void accountSynchronizerNotifyFatalError(IMAPAccountSynchronizer * account, hermes::ErrorCode error);
        virtual void accountSynchronizerNotifyCopyError(IMAPAccountSynchronizer * account, hermes::ErrorCode error);
        virtual void accountSynchronizerNotifyAppendError(IMAPAccountSynchronizer * account, hermes::ErrorCode error);

        virtual void accountSynchronizerAccountInfoChanged(IMAPAccountSynchronizer * account);

        virtual void accountSynchronizerFoldersChanged(IMAPAccountSynchronizer * account, hermes::ErrorCode error);
        virtual void accountSynchronizerFoldersUpdated(IMAPAccountSynchronizer * account);
        virtual void accountSynchronizerFolderUnseenChanged(IMAPAccountSynchronizer * account, mailcore::String * folderPath);
        virtual void accountSynchronizerNotifyUnreadEmail(IMAPAccountSynchronizer * account, mailcore::String * folderPath);
        virtual void accountSynchronizerHasConversationIDForMessageID(IMAPAccountSynchronizer * account, mailcore::String * messageID, int64_t conversationID);
        virtual void accountSynchronizerHasNewContacts(IMAPAccountSynchronizer * account);

        virtual void accountSynchronizerRemoveMessageIDsFromSendQueue(mailcore::Set * messageIDs);

    public: // MessageQueueSender
        virtual void messageQueueSenderSendDone(MessageQueueSender * sender);
        virtual void messageQueueSenderSendingStateChanged(MessageQueueSender * sender);
        virtual void messageQueueSenderSent(MessageQueueSender * sender, mailcore::MessageParser * parsedMessage);
        virtual void messageQueueSenderAccountInfoChanged(MessageQueueSender * sender);
        virtual void messageQueueSenderProgress(MessageQueueSender * sender);

        virtual void messageQueueSenderNotifyAuthenticationError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage);
        virtual void messageQueueSenderNotifyConnectionError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage);
        virtual void messageQueueSenderNotifyFatalError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage);
        // There's an error with that specific message.
        virtual void messageQueueSenderNotifySendError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage);

    private:
        IMAPAccountSynchronizer * mSync;
        MessageQueueSender * mSendQueue;
        carray * mObservers;
        AccountInfo * mAccountInfo;

        mailcore::Set * currentEmailSet();
        mailcore::String * uncheckedShortDisplayName();
        mailcore::HashMap * standardFolders();

        // make sure it will sync.
        void openFolderPath(mailcore::String * path);
        void closeFolderPath(mailcore::String * path);
    };
    
}

#endif

#endif /* defined(__dejalu__HMAccount__) */
