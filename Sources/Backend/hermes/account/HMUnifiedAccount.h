// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMUnifiedAccount_hpp
#define HMUnifiedAccount_hpp

#include <MailCore/MailCore.h>
#include <libetpan/libetpan.h>

#include "HMAccountObserver.h"

#ifdef __cplusplus

namespace hermes {

    class Account;
    class IMAPAttachmentDownloader;
    class UnifiedAccountObserver;
    class UnifiedMailStorageView;

    class UnifiedAccount : public mailcore::Object, public AccountObserver {
    public:
        UnifiedAccount();
        virtual ~UnifiedAccount();

        virtual void setAccounts(mailcore::Array * /* Account */ account);
        virtual mailcore::Array * accounts();

        virtual void addObserver(UnifiedAccountObserver * observer);
        virtual void removeObserver(UnifiedAccountObserver * observer);

        virtual mailcore::String * shortDisplayName();

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

        virtual void setSearchKeywords(mailcore::Array * keywords);
        virtual mailcore::Array * searchKeywords();
        virtual bool isSearching();

        virtual void disableSync();
        virtual void enableSync();

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

        // storage view
        virtual UnifiedMailStorageView * openViewForSearchKeywords(mailcore::Array * keywords);
        virtual void closeViewForSearch(UnifiedMailStorageView * view);
        virtual void openViewForFolder(int64_t folderID);
        virtual UnifiedMailStorageView * viewForFolder(int64_t folderID);
        virtual void closeView(UnifiedMailStorageView * view);
        virtual void closeViewForFolder(int64_t folderID);

    public: // Account observer
        virtual void accountGotFolders(Account * account);
        virtual void accountFoldersUpdated(Account * account);
        virtual void accountFetchSummaryDone(Account * account, hermes::ErrorCode error, int64_t messageRowID);
        virtual void accountFetchPartDone(Account * account, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID);
        virtual void accountStateUpdated(Account * account);

        virtual void accountLocalMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer);
        virtual void accountPushMessageDone(Account * account, hermes::ErrorCode error, int64_t messageRowID);
        virtual void accountMessageSaved(Account * account, int64_t folderID, mailcore::String * messageID);

        virtual void accountSyncDone(Account * account, hermes::ErrorCode error, mailcore::String * folderPath);
        virtual void accountConnected(Account * account);

    private:
        mailcore::Array * mAccounts;
        carray * mObservers;
        mailcore::HashMap * mPathToFolderID;
        mailcore::Array * mFolderIDToPath;
        unsigned int mPendingGotFolders;
        mailcore::HashMap * mPendingOpenViewsCount;
        mailcore::HashMap * mStorageViews;
        mailcore::HashMap * mFolderIDOpenCount;
        mailcore::HashMap * mOpenedPathCount;
        mailcore::HashMap * mPendingOpenFolderPath;

        Account * singleAccount();
        int64_t folderIDForAccount(hermes::Account * account, int64_t folderID);
        void openPendingFolders(Account * account);
        void setViews(UnifiedMailStorageView * unifiedStorageView, int64_t folderID);
    };
    
}

#endif

#endif /* HMUnifiedAccount_hpp */
