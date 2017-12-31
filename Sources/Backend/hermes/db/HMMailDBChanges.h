// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBChanges__
#define __dejalu__HMMailDBChanges__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class MailDBChanges : public mailcore::Object {
    public:
        MailDBChanges();
        virtual ~MailDBChanges();
        
        virtual void addPeopleViewID(int64_t peopleViewID, int64_t date);
        virtual void modifyPeopleViewID(int64_t peopleViewID, int64_t date);
        virtual void removePeopleViewID(int64_t peopleViewID);
        
        virtual void addFolderForConversation(int64_t peopleViewID, int64_t folderID);
        virtual void removeFolderFromConversation(int64_t peopleViewID, int64_t folderID);

        virtual void addMessagePart(int64_t messageRowID, mailcore::String * partID);

        virtual void setFolderNeedsPushFlags(int64_t folderID);
        virtual void setFolderUnseen(int64_t folderID);
        
        virtual void removeMessageIDFromSendQueue(mailcore::String * messageID);

        virtual mailcore::Array * addedPeopleViewIDs();
        virtual mailcore::Array * modifiedPeopleViewIDs();
        virtual mailcore::Array * removedPeopleViewIDs();
        virtual mailcore::Array * addedConversationsForFolder(int64_t folderID);
        virtual mailcore::Array * removedConversationsForFolder(int64_t folderID);
        virtual mailcore::IndexSet * foldersNeedPushFlags();
        virtual time_t dateForPeopleViewID(int64_t peopleViewID);
        virtual mailcore::Array * addedMessageParts();
        virtual mailcore::IndexSet * unseenFolders();

        virtual void changeCountForFolderID(int64_t folderID, int unreadCount, int starredCount, int totalCount);
        virtual mailcore::Array * changedFoldersIDs();
        virtual void addChangedFoldersIDs(mailcore::HashMap * info);

        virtual int unreadCountForFolderID(int64_t folderID);
        virtual int starredCountForFolderID(int64_t folderID);
        virtual int countForFolderID(int64_t folderID);

        virtual void notifyMessage(int64_t folderID, int64_t rowid);
        virtual mailcore::Array * notifiedMessages();

        virtual void changePeopleViewCount(int64_t peopleViewID);
        virtual mailcore::IndexSet * changedCountPeopleViewIDs();

        virtual mailcore::Set * messageIDsToRemoveFromSendQueue();

    public: // override
        virtual mailcore::String * description();
        
    private:
        mailcore::Set * mAddedPeopleViewIDs;
        mailcore::Set * mModifiedPeopleViewIDs;
        mailcore::Set * mRemovedPeopleViewIDs;
        mailcore::HashMap * mConversationsDates;
        mailcore::HashMap * mFoldersAddedConversations;
        mailcore::HashMap * mFoldersRemovedConversations;
        mailcore::HashMap * mExistedBefore;
        mailcore::HashMap * mDidntExistBefore;
        mailcore::IndexSet * mFoldersNeedsPushFlags;
        mailcore::Array * mAddedParts;
        mailcore::IndexSet * mUnseenFolders;
        mailcore::HashMap * mFolderCountChanges;
        mailcore::Array * mNotifiedMessages;
        mailcore::IndexSet * mPeopleViewCountChanged;
        mailcore::Set * mMessageIDsToRemoveFromSendQueue;
    };

}

#endif

#endif /* defined(__dejalu__MailDBChanges__) */
