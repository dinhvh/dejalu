// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMIMAPFolderSynchronizer__
#define __dejalu__HMIMAPFolderSynchronizer__

#include <MailCore/MailCore.h>

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMConstants.h"
#include "HMIMAPSyncTypes.h"

#ifdef __cplusplus

namespace hermes {
    
    class IMAPFolderSynchronizerDelegate;
    class IMAPFetchFolderStateSyncStep;
    class IMAPFetchMessageListSyncStep;
    class IMAPFetchHeadersSyncStep;
    class IMAPFetchFlagsSyncStep;
    class MailStorage;
    class IMAPFetchNextSummarySyncStep;
    class IMAPFetchNextAttachmentSyncStep;
    class IMAPUncacheOldMessagesSyncStep;
    class IMAPRemoveExpiredLocalMessageSyncStep;
    class IMAPPushFlagsStep;
    class IMAPPushMessagesStep;
    class IMAPCopyMessagesStep;
    class IMAPFetchNextSourceSyncStep;
    class ActivityItem;
    class MailDBFolderUnseenOperation;
    
    class IMAPFolderSynchronizer : public mailcore::Object,
    public IMAPFolderSyncStepDelegate, public mailcore::OperationCallback {
                                       
    public:
        IMAPFolderSynchronizer();
        virtual ~IMAPFolderSynchronizer();
        
        virtual Object * retain();
        virtual void release();

        virtual void setSession(mailcore::IMAPAsyncSession * session);
        virtual mailcore::IMAPAsyncSession * session();
        
        virtual void setFolderPath(mailcore::String * path);
        virtual mailcore::String * folderPath();
        
        virtual void setStorage(MailStorage * storage);
        virtual MailStorage * storage();

        virtual void setDraftBehaviorEnabled(bool enabled);
        virtual bool isDraftBehaviorEnabled();

        virtual void setSyncType(IMAPSyncType syncType);
        virtual IMAPSyncType syncType();

        virtual void setDelegate(IMAPFolderSynchronizerDelegate * delegate);
        virtual IMAPFolderSynchronizerDelegate * delegate();

        virtual void syncNext();
        
        virtual bool hasUrgentTask();
        virtual bool isSyncDone();
        
        virtual void interruptIdle();
        virtual bool isIdling();
        virtual void disableIdle();
        virtual void enableIdle();
        virtual bool isIdleDisabled();

        virtual bool isSearching();
        
        // Doesn't need the result.
        virtual void fetchMessageSummary(int64_t messageRowID, bool urgent);
        
        virtual void fetchMessagePart(int64_t messageRowID, mailcore::String * partID, bool urgent);
        virtual void fetchMessageSource(int64_t messageRowID);

        virtual void setSearchKeywords(mailcore::Array * keywords);
        virtual mailcore::Array * searchKeywords();

        virtual void setRefreshDelay(double refreshDelay);
        virtual double refreshDelay();
        
        virtual void closeConnection();
        
        virtual bool canLoadMore();
        virtual bool shouldShowProgress();
        virtual unsigned int headersProgressValue();
        virtual unsigned int headersProgressMax();

        virtual void failPendingRequests(hermes::ErrorCode error);
        virtual void reset();
        virtual void refresh();
        virtual bool loadMore();
        virtual void resetMessagesToLoad();
        virtual bool messagesToLoadCanBeReset();
        virtual hermes::ErrorCode lastError();
        virtual bool lastOperationIsNetwork();

        virtual void setWaitingLoadMore(bool waitingLoadMore);
        virtual bool isWaitingLoadMore();
        
        // for debug activity report.
        virtual mailcore::String * urgentTaskDescription();
        virtual mailcore::String * syncStateDescription();

        virtual void markFolderAsSeen();
        virtual bool isFolderUnseen();

    public: // IMAPFolderSyncStepDelegate
        virtual void folderSyncStateUpdated(IMAPFolderSyncStep * syncStep);
        virtual void folderSyncStepDone(IMAPFolderSyncStep * syncStep);
        
    public: // OperationCallback
        void operationFinished(mailcore::Operation * op);
        
    private:
        mailcore::String * mFolderPath;
        IMAPFolderSynchronizerDelegate * mDelegate;
        mailcore::IMAPAsyncSession * mSession;
        int mState;
        unsigned int mMessagesToFetch;
        IMAPFetchFolderStateSyncStep * mFetchFolderStateSyncStep;
        IMAPFetchMessageListSyncStep * mFetchMessageListSyncStep;
        IMAPFetchHeadersSyncStep * mFetchHeaderSyncStep;
        IMAPFetchFlagsSyncStep * mFetchFlagsSyncStep;
        MailStorage * mStorage;
        int mMessageCount;
        uint32_t mUidNext;
        mailcore::IndexSet * mUids;
        mailcore::IndexSet * mCachedUids;
        mailcore::IndexSet * mUidsToFetch;
        IMAPFetchNextSummarySyncStep * mFetchSummarySyncStep;
        uint32_t mMaxUid;
        IMAPUncacheOldMessagesSyncStep * mUncacheOldMessagesSyncStep;
        mailcore::Array * mSummaryToFetchMessageRowIDs;
        mailcore::Array * mSummaryToFetchMessageRowIDsUrgent;
        bool mFetchSummaryUrgent;
        mailcore::Array * mPartToFetchHashMap;
        mailcore::Array * mPartToFetchHashMapUrgent;
        bool mFetchPartUrgent;
        ActivityItem * mIdleActivity;
        mailcore::IMAPIdleOperation * mIdleOperation;
        bool mIdleInterrupted;
        int mDisableIdleCount;
        IMAPFetchNextSummarySyncStep * mUrgentFetchSummarySyncStep;
        IMAPPushMessagesStep * mPushMessagesStep;
        IMAPFetchNextAttachmentSyncStep * mUrgentFetchAttachmentSyncStep;
        IMAPPushFlagsStep * mPushFlagsStep;
        mailcore::Array * mSearchKeywords;
        int mSearchState;
        ActivityItem * mSearchActivity;
        mailcore::IMAPSearchOperation * mSearchOp;
        mailcore::IndexSet * mSearchResultUids;
        IMAPFetchHeadersSyncStep * mSearchFetchHeaderSyncStep;
        IMAPFetchNextSummarySyncStep * mSearchFetchSummarySyncStep;
        IMAPRemoveExpiredLocalMessageSyncStep * mRemoveExpiredLocalMessageSyncStep;
        mailcore::IndexSet * mSearchStoredRowsIDs;
        bool mHasMoreMessages;
        bool mCanLoadMore;
        bool mNeedRefresh;
        bool mLoadingFirstHeaders;
        unsigned int mHeadersProgressValue;
        unsigned int mHeadersProgressMax;
        bool mWaitingLoadMore;
        bool mDraftBehaviorEnabled;
        IMAPCopyMessagesStep * mCopyMessagesStep;
        int mNextDeleteOriginal;
        hermes::ErrorCode mError;
        bool mNetwork;
        double mRefreshDelay;
        bool mIsUnseen;
        bool mUnseenValueInitialized;
        MailDBFolderUnseenOperation * mUnseenOp;
        mailcore::Array * mSourceToFetch;
        IMAPFetchNextSourceSyncStep * mUrgentFetchSourceStep;
        IMAPSyncType mSyncType;

        int64_t folderID();
        void syncStepStart(IMAPFolderSyncStep * syncStep);
        void fetchFolderState();
        void fetchFolderStateSyncStepDone();
        void fetchMessageList();
        void fetchMessageListSyncStepDone();
        void fetchNextHeaders();
        void fetchHeadersSyncStepDone();
        void fetchHeadersSyncStateUpdated();
        void uncacheOldMessages();
        void uncacheOldMessagesDone();
        void fetchNextFlags();
        void fetchNextFlagsDone();
        void fetchNextSummary();
        void fetchNextSummaryDone();
        void pushMessages();
        void pushMessagesDone();
        void removeExpiredLocalMessages();
        void removeExpiredLocalMessagesDone();
        void urgentFetchNextPart();
        void urgentFetchNextPartDone();
        bool syncUrgent();
        void idle();
        void idleDone();
        void urgentFetchNextSummary();
        void urgentFetchNextSummaryDone();
        void pushFlags();
        void pushFlagsDone();
        void copyMessages();
        void copyMessagesDone();
        void copyMessagesLoopNext();
        void copyMessagesLoopNextDone();
        void cancelSearch();
        void performSearch();
        void searchUids();
        void searchUidsDone();
        void searchFetchHeaders();
        void searchFetchHeadersDone();
        void searchFetchContent();
        void searchFetchContentDone();
        void handleError();
        void handleRecoverableError();
        void refreshAfterDelay();
        void setFolderUnseen(bool isUnseen);
        void unseenOpDone();
        void urgentFetchNextSource();
        void urgentFetchNextSourceDone();
    };
}

#endif

#endif /* defined(__dejalu__HMIMAPFolderSynchronizer__) */
