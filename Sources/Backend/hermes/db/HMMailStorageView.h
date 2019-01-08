// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__MailStorageView__
#define __dejalu__MailStorageView__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    
    class MailStorage;
    class MailStorageViewObserver;
    class MailDBPeopleConversationsOperation;
    class MailDBChanges;
    class MailDBPeopleConversationInfoOperation;
    class MailDBConversationMessagesOperation;
    
    class MailStorageView : public mailcore::Object, public mailcore::OperationCallback {
    public:
        MailStorageView();
        virtual ~MailStorageView();
        
        virtual void open();
        virtual void close();
        virtual unsigned int openedCount();

        virtual void cancel();
        
        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);
        
        virtual MailStorage * storage();
        virtual void setStorage(MailStorage * storage);
        
        virtual mailcore::Array * keywords();
        virtual void setKeywords(mailcore::Array * keywords);
        
        virtual int64_t inboxFolderID();
        virtual void setInboxFolderID(int64_t folderID);

        virtual int64_t allMailFolderID();
        virtual void setAllMailFolderID(int64_t folderID);
        
        virtual int64_t archiveFolderID();
        virtual void setArchiveFolderID(int64_t folderID);

        virtual int64_t draftsFolderID();
        virtual void setDraftsFolderID(int64_t folderID);

        virtual int64_t trashFolderID();
        virtual void setTrashFolderID(int64_t folderID);

        virtual int64_t spamFolderID();
        virtual void setSpamFolderID(int64_t folderID);

        virtual int64_t sentFolderID();
        virtual void setSentFolderID(int64_t folderID);

        virtual mailcore::HashMap * standardFolders();
        virtual void setStandardFolders(mailcore::HashMap * standardFoldersIDs);
        
        virtual mailcore::Set * emailSet();
        virtual void setEmailSet(mailcore::Set * emailSet);

        virtual time_t ageLimit();
        virtual void setAgeLimit(time_t ageLimit);

        virtual void addObserver(MailStorageViewObserver * delegate);
        virtual void removeObserver(MailStorageViewObserver * delegate);
        
        virtual unsigned int conversationsCount();
        virtual mailcore::HashMap * conversationsInfoAtIndex(unsigned int idx);
        virtual mailcore::HashMap * conversationsInfoForConversationID(int64_t conversationID);
        
        virtual MailDBConversationMessagesOperation * messagesForPeopleConversationOperation(int64_t conversationID);

        virtual bool isLoading();

        virtual mailcore::HashMap * foldersScores();

    public: // private for MailStorage
        // notify changes.
        virtual void notifyChanges(MailDBChanges * changes);
        
    public: // Implementation of OperationCallback.
        virtual void operationFinished(mailcore::Operation * op);
        
    private:
        mailcore::Set * mEmailSet;
        int64_t mFolderID;
        mailcore::Array * mKeywords;
        MailStorage * mStorage; // weak
        carray * mObservers;
        unsigned int mOpenedCount;
        bool mLoadingConversations;
        bool mNeedsReloadConversations;
        MailDBPeopleConversationsOperation * mConversationsOperation;
        mailcore::Array * mConversations;
        
        mailcore::Array * mLoadedConversations;
        mailcore::Set * mUpdatedConversations;
        
        mailcore::Set * mDirtyConversations;
        mailcore::Array * mConversationsToLoad;
        unsigned int mLoadIndex;
        bool mLoadingInfo;
        mailcore::Set * mNotifications;
        mailcore::HashMap * mInfos;
        MailDBPeopleConversationInfoOperation * mInfoOp;
        
        int64_t mInboxFolderID;
        int64_t mAllMailFolderID;
        int64_t mDraftsFolderID;
        int64_t mTrashFolderID;
        int64_t mSentFolderID;
        int64_t mSpamFolderID;
        int64_t mArchiveFolderID;

        bool mUpdateSearchResultScheduled;
        double mStartTime;
//        time_t mToday2am;
        time_t mAgeLimit;

        mailcore::HashMap * mStandardFolders;

        void fetchConversations();
        void fetchConversationsDone();
        void cancelFetchConversations();
        void notifyChangesToObserver(mailcore::Array * deleted, mailcore::Array * moved, mailcore::Array * added,
                                     mailcore::Array * modified, mailcore::Array * modifiedIDs);
        void notifyModifiedDeletedConversationsToObserver(mailcore::Array * modified, mailcore::Array * deleted);
        void notifyChangesForFolderCount(mailcore::Array * foldersIDs);
        void notifyMessages(mailcore::Array * notifiedMessages);
        void startLoadingInfos();
        void loadingInfosFinished();
        void loadNextInfo();
        void loadInfo(int64_t conversationID, unsigned int indexToLoad);
        void loadInfoFinished();
        void cancelLoadNextInfo();
        
        void loadedConversationsUpdated();
        mailcore::Set * foldersToExcludeFromUnread();

        void notifyChangesForFolder(MailDBChanges * changes);
        void notifyChangesForSearch(MailDBChanges * changes);
        void notifyStoredParts(mailcore::Array * /* MailDBMessagePartInfo */ messageParts);
        void updateSearchResultAfterDelay(void * context);
    };
    
}

#endif

#endif /* defined(__dejalu__MailStorageView__) */
