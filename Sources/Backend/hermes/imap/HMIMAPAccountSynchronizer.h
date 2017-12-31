// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPAccountSynchronizer__
#define __dejalu__HMIMAPAccountSynchronizer__

#include <MailCore/MailCore.h>
#include <libetpan/libetpan.h>
#include "HMIMAPFolderSynchronizerDelegate.h"
#include "HMConstants.h"
#include "HMReachabilityObserver.h"
#include "HMIMAPSyncTypes.h"

#ifdef __cplusplus

namespace hermes {
    
    class IMAPAccountSynchronizerDelegate;
    class MailStorage;
    class MailDBOperation;
    class MailDBAddLocalMessagesOperation;
    class MailDBPeopleViewIDOperation;
    class IMAPFolderSynchronizer;
    class MailDBOpenOperation;
    class ActivityItem;
    class IMAPAccountInfo;
    class ReachabilityObserver;
    class Reachability;
    class IMAPAttachmentDownloader;
    class MailDBMessagesOperation;
    class MailDBMessagesRecipientsOperation;
    class MailDBAddToSavedRecipientsOperation;
    
    class IMAPAccountSynchronizer : public mailcore::Object,
    public IMAPFolderSynchronizerDelegate,
    public mailcore::OperationCallback,
    public mailcore::ConnectionLogger,
    public ReachabilityObserver {
        
    public:
        IMAPAccountSynchronizer();
        virtual ~IMAPAccountSynchronizer();

        virtual Object * retain();
        virtual void release();

        virtual void setLogEnabled(bool enabled);

        virtual void setAccountInfo(IMAPAccountInfo * info);
        virtual IMAPAccountInfo * accountInfo();

        virtual void setDelegate(IMAPAccountSynchronizerDelegate * delegate);
        virtual IMAPAccountSynchronizerDelegate * delegate();
        
        virtual void setPath(mailcore::String * path);
        virtual mailcore::String * path();
        
        virtual MailStorage * storage();
        virtual mailcore::IMAPAsyncSession * session();
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

        // addresses to complete
        virtual mailcore::Array * addresses();

        virtual void open();
        virtual void close();

        // make sure it will sync.
        virtual void openFolderPath(mailcore::String * path);
        virtual void closeFolderPath(mailcore::String * path);

        virtual void setSearchKeywords(mailcore::Array * keywords);
        virtual mailcore::Array * searchKeywords();
        virtual bool isSearching();

        // Doesn't need the result.
        virtual void fetchMessageSummary(int64_t folderID, int64_t messageRowID, bool urgent);
        virtual bool canFetchMessageSummary(int64_t messageRowID);
        
        virtual void fetchMessagePart(int64_t folderID, int64_t messageRowID, mailcore::String * partID, bool urgent);
        virtual void fetchMessageSource(int64_t folderID, int64_t messageRowID);

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
        virtual void saveMessageToSent(mailcore::String * messageID, mailcore::Data * messageData);
        virtual void saveMessageToFolder(mailcore::String * messageID, mailcore::Data * messageData, mailcore::String * folderPath);
        virtual void removeDraftForSentMessage(mailcore::String * draftMessageID);
        virtual bool isSavingDraft(mailcore::String * draftMessageID);

        virtual void copyPeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, mailcore::HashMap * foldersScores);
        virtual void movePeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, mailcore::HashMap * foldersScores);
        virtual void purgePeopleConversations(mailcore::Array * conversationIDs);
        virtual void purgeMessage(int64_t messageRowID);

        virtual void fetchConversationIDForMessageID(mailcore::String * messageID);

        virtual void addLabelToConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, int64_t folderID);
        virtual void removeLabelFromConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, int64_t folderID);

        virtual void markFolderAsSeen(int64_t folderID);
        virtual bool isFolderUnseen(int64_t folderID);
        
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

        virtual void registerPartDownloader(IMAPAttachmentDownloader * downloader);
        virtual void unregisterPartDownloader(IMAPAttachmentDownloader * downloader);

        // for debug activity report.
        virtual bool isSyncingFolder(mailcore::String * folderPath);
        virtual mailcore::String * urgentTaskDescriptionForFolder(mailcore::String * folderPath);
        virtual mailcore::String * syncStateDescriptionForFolder(mailcore::String * folderPath);
        
    public: // Implements IMAPFolderSynchronizer delegate
        virtual void folderSynchronizerSyncStepDone(IMAPFolderSynchronizer * synchronizer);
        virtual void folderSynchronizerSyncShouldSync(IMAPFolderSynchronizer * synchronizer);
        //virtual void folderSynchronizerSyncFetchSummaryFailed(IMAPFolderSynchronizer * synchronizer, int64_t messageRowID);
        virtual void folderSynchronizerSyncFetchSummaryDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID);
        virtual void folderSynchronizerStateUpdated(IMAPFolderSynchronizer * synchronizer);
        //virtual void folderSynchronizerSyncFetchPartFailed(IMAPFolderSynchronizer * synchronizer, int64_t messageRowID, mailcore::String * partID);
        virtual void folderSynchronizerSyncFetchPartDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID);
        virtual void folderSynchronizerMessageSourceFetched(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error,
                                                            int64_t messageRowID,
                                                            mailcore::Data * messageData);
        virtual mailcore::String * folderSynchronizerTrashFolder(IMAPFolderSynchronizer * synchronizer);
        virtual mailcore::String * folderSynchronizerDraftsFolder(IMAPFolderSynchronizer * synchronizer);
        virtual void folderSynchronizerSyncDone(IMAPFolderSynchronizer * synchronizer);
        virtual void folderSynchronizerSyncPushMessageDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID);
        virtual void folderSynchronizerUnseenChanged(IMAPFolderSynchronizer * synchronizer);
        virtual void folderSynchronizerNotifyUnreadEmail(IMAPFolderSynchronizer * synchronizer);
        virtual void folderSynchronizerFetchedHeaders(IMAPFolderSynchronizer * synchronizer);

    public: //Implements OperationCallback
        void operationFinished(mailcore::Operation * op);
        
    public: // ConnectionLogger
        virtual void log(void * sender, mailcore::ConnectionLogType logType, mailcore::Data * buffer);

    public: // ReachabilityObserver
        virtual void reachabilityChanged(Reachability * reachability);

    private:
        mailcore::String * mInboxFolderPath;
        mailcore::String * mDraftsFolderPath;
        mailcore::String * mImportantFolderPath;
        mailcore::String * mAllMailFolderPath;
        mailcore::String * mStarredFolderPath;
        mailcore::String * mSentFolderPath;
        mailcore::String * mTrashFolderPath;
        mailcore::String * mSpamFolderPath;
        mailcore::String * mArchiveFolderPath;
        mailcore::Set * mSyncingFolders;
        mailcore::Set * mOpenFoldersPaths;
        mailcore::HashMap * mOpenCountFoldersPaths;
        mailcore::HashMap * mFoldersSynchronizers;

        IMAPAccountInfo * mAccountInfo;
        
        IMAPAccountSynchronizerDelegate * mDelegate;
        
        mailcore::String * mPath;
        
        MailStorage * mStorage;
        mailcore::IMAPAsyncSession * mSession;
        
        MailDBOpenOperation * mOpenOperation;
        mailcore::Operation * mCloseOperation;
        ActivityItem * mFetchFoldersActivity;
        mailcore::IMAPFetchFoldersOperation * mFetchFoldersOp;
        mailcore::Operation * mStoreFoldersOp;
        mailcore::Operation * mStoreMainFoldersOp;

        pthread_mutex_t mProtocolLogFileLock;
        chash * mProtocolLogFiles;
        
        unsigned int mDisableSyncCount;
        
        mailcore::IndexSet * mMessageFetchFailedSet;
        mailcore::Array * mPendingFlagsOperations;
        mailcore::Array * mPendingSaveMessageOperations;
        mailcore::Array * mPendingCopyOperations;
        mailcore::Array * mPendingMoveOperations;
        mailcore::Array * mPendingPurgeOperations;
        mailcore::Array * mRemoveDraftForSendOperations;
        mailcore::Array * mPendingLabelOperations;
        mailcore::Array * mPendingFolderOperations;
        mailcore::Array * mFetchConversationIDOperations;
        bool mFolderOperationNotification;
        bool mDisabledIdleSinceFolderOperation;

        mailcore::Array * mSearchKeywords;

        mailcore::IndexSet * mFoldersThatNeedsPushMessages;

        int mSetupSessionCallback;

        hermes::ErrorCode mError;
        int mConnectionErrorCount;
        int mAuthenticationErrorCount;

        int mConnectionRetryState;

        mailcore::AccountValidator * mValidator;
        bool mGotFolders;

        mailcore::Array * mAttachmentDownloaders;

        mailcore::HashMap * mMessageSavingInfo;
        bool mSettingUpSession;
        bool mOpenedDatabase;

        int mRetrieveAuth2TokenTries;

        bool mFoldersFetched;
        bool mFetchingFolders;

        bool mCollectingAddresses;
        bool mScheduledAddressCollection;
        bool mPendingAddressCollection;
        MailDBMessagesOperation * mMessagesOp;
        double mAddressCollectionStartTime;
        mailcore::IndexSet * mCollectAddressesMessagesRowIDs;
        int64_t mCollectAddressesMessagesLastRowID;
        mailcore::Array * mFetchedRecipients;
        MailDBMessagesRecipientsOperation * mFetchRecipientOp;
        MailDBAddToSavedRecipientsOperation * mSaveRecipientsOp;
        // recipients in memory
        mailcore::Array * mRecipients;
        bool mClosed;
        bool mLogEnabled;

        IMAPSyncType mSyncType;
        bool mCreatedMissingFolders;
        int mCreateMissingFolderIndex;
        mailcore::Array * mMissingFolderToCreate;
        mailcore::IMAPOperation * mMissingFolderCreateOp;
        ActivityItem * mCreateMissingFoldersActivity;

        bool canSyncFolder(mailcore::String * folderPath);
        void trySyncUrgent(mailcore::String * folderPath);
        void trySync(mailcore::String * folderPath);
        
        mailcore::HashMap * mainFolders();
        void applyMainFolders(mailcore::HashMap * folders);
        
        void openFinished();
        void closeFinished();
        void fetchFolders();
        void fetchFoldersFinished();
        void storeFolders(mailcore::Array * folders, mailcore::IMAPNamespace * ns);
        void storeFoldersFinished();
        void storeMainFolders();
        void storeMainFoldersFinished();
        void setFoldersSynchronizers();
        void refreshFoldersAfterDelay();
        void setupFolders(bool hasMainFolders);

        void startSync();
        void syncNext();
        bool hasUrgentTask();
        
        void setupSession();
        void unsetupSession();
        void retrieveOAuth2Token();
        void closeConnection();
        bool isSyncDisabled();

        void flagsOperationFinished(MailDBOperation * op);
        void saveMessageOperationFinished(MailDBAddLocalMessagesOperation * op);
        void copyPeopleConversationsOperationFinished(mailcore::Operation * op);
        void movePeopleConversationsOperationFinished(mailcore::Operation * op);
        void purgeOperationFinished(mailcore::Operation * op);
        void removeDraftForSentMessageOperationFinished(mailcore::Operation * op);
        void labelOperationFinished(mailcore::Operation * op);
        void fetchConversationIDForMessageIDFinished(MailDBPeopleViewIDOperation * op);

        void setFolderSearchKeywords(mailcore::String * path, mailcore::Array * keywords);
        static void oauth2GetTokenCallback(hermes::ErrorCode code, mailcore::String * oauth2Token, void * data);
        void setupSessionDone(hermes::ErrorCode code, mailcore::String * oauth2Token);
        void setupSessionWithPassword();

        void connectSetupSessionDone(hermes::ErrorCode code);
        void openSetupSessionDone(hermes::ErrorCode code);

        void handleError();
        void handleOAuth2Error(hermes::ErrorCode error);
        void fatalError(hermes::ErrorCode error);
        void authenticationError(hermes::ErrorCode error);
        void connectionError(hermes::ErrorCode error);
        void copyError(hermes::ErrorCode error);
        void appendError(hermes::ErrorCode error);

        void autodetect();
        void autodetectDone();
        
        void disconnect();
        void connect();
        void notifyChangedNetwork();
        void failPendingRequests(hermes::ErrorCode error);
        void notifyAttachmentDownloaders(hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID);

        void saveMessageToFolderCommon(mailcore::String * messageID,
                                       mailcore::Data * messageData,
                                       mailcore::String * folderPath,
                                       bool needsToBeSentToServer,
                                       bool hasBeenPushed);
        void syncDone(hermes::ErrorCode error, mailcore::String * path);
        void checkSaveFinished(mailcore::String * messageID, int64_t folderID);
        bool isFolderSearching(mailcore::String * path);
        void folderOperationFinished(mailcore::Operation * op);
        void notifyFolderOperation(hermes::ErrorCode error);
        void disableIdle();
        void enableIdle();

        void startCollectingAddresses();
        void fetchSentMessages();
        void fetchSentMessagesDone();
        void fetchNextRecipients();
        void fetchNextRecipientsDone();
        void saveFetchedRecipients();
        void saveFetchedRecipientsDone();
        void finishedCollectingAddresses();
        void scheduleCollectAddresses();
        void tryReconnectAfterDelay();
        void tryReconnectNow();
        void cancelTryReconnectNow();

        void createMainFoldersIfNeeded();
        void completeWithStandardFolders(mailcore::HashMap * folders);
        void createMainFolders();
        void createNextMainFolder();
        void createNextMainFolderDone();
        void createMainFoldersDone();
        void refetchFolders();
    };
}

#endif

#endif /* defined(__dejalu__HMIMAPAccountSynchronizer__) */
