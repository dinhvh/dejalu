// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBChangePeopleConversationsFlagsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBChangePeopleConversationsFlagsOperation::MailDBChangePeopleConversationsFlagsOperation()
{
    mConversationsIDs = NULL;
    mChangeFlagsType = MailDBChangeFlagsTypeMarkRead;
    mFolderID = -1;
    //mTweakLabelsEnabled = false;
    mFolderPath = NULL;
    mTrashFolderID = -1;
    mInboxFolderID = -1;
    mSentFolderID = -1;
    mDraftsFolderID = -1;
}

MailDBChangePeopleConversationsFlagsOperation::~MailDBChangePeopleConversationsFlagsOperation()
{
    MC_SAFE_RELEASE(mFolderPath);
    MC_SAFE_RELEASE(mConversationsIDs);
}

Array * MailDBChangePeopleConversationsFlagsOperation::conversationsIDs()
{
    return mConversationsIDs;
}

void MailDBChangePeopleConversationsFlagsOperation::setConversationsIDs(Array * conversationsIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mConversationsIDs, conversationsIDs);
}

MailDBChangeFlagsType MailDBChangePeopleConversationsFlagsOperation::changeFlagsType()
{
    return mChangeFlagsType;
}

void MailDBChangePeopleConversationsFlagsOperation::setChangeFlagsType(MailDBChangeFlagsType type)
{
    mChangeFlagsType = type;
}

int64_t MailDBChangePeopleConversationsFlagsOperation::folderID()
{
    return mFolderID;
}

void MailDBChangePeopleConversationsFlagsOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBChangePeopleConversationsFlagsOperation::trashFolderID()
{
    return mTrashFolderID;
}

void MailDBChangePeopleConversationsFlagsOperation::setTrashFolderID(int64_t trashFolderID)
{
    mTrashFolderID = trashFolderID;
}

int64_t MailDBChangePeopleConversationsFlagsOperation::inboxFolderID()
{
    return mInboxFolderID;
}

void MailDBChangePeopleConversationsFlagsOperation::setInboxFolderID(int64_t inboxFolderID)
{
    mInboxFolderID = inboxFolderID;
}

int64_t MailDBChangePeopleConversationsFlagsOperation::sentFolderID()
{
    return mSentFolderID;
}

void MailDBChangePeopleConversationsFlagsOperation::setSentFolderID(int64_t sentFolderID)
{
    mSentFolderID = sentFolderID;
}

int64_t MailDBChangePeopleConversationsFlagsOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBChangePeopleConversationsFlagsOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

mailcore::String * MailDBChangePeopleConversationsFlagsOperation::folderPath()
{
    return mFolderPath;
}

void MailDBChangePeopleConversationsFlagsOperation::setFolderPath(mailcore::String * folderPath)
{
    MC_SAFE_REPLACE_COPY(String, mFolderPath, folderPath);
}

#if 0
bool MailDBChangePeopleConversationsFlagsOperation::isTweakLabelsEnabled()
{
    return mTweakLabelsEnabled;
}

void MailDBChangePeopleConversationsFlagsOperation::setTweakLabelsEnabled(bool enabled)
{
    mTweakLabelsEnabled = enabled;
}
#endif

void MailDBChangePeopleConversationsFlagsOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreacharray(Value, vRowid, mConversationsIDs) {
        switch (mChangeFlagsType) {
            case MailDBChangeFlagsTypeMarkRead:
                syncDB()->markPeopleViewAsRead(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkUnread:
                syncDB()->markPeopleViewAsUnread(vRowid->longLongValue(), mFolderID, mInboxFolderID, mSentFolderID, mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkFlagged:
                syncDB()->markPeopleViewAsFlagged(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkUnflagged:
                syncDB()->markPeopleViewAsUnflagged(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkDeleted:
                syncDB()->markPeopleViewAsDeleted(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkArchived:
                syncDB()->markPeopleViewAsRead(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                syncDB()->markPeopleViewAsDeleted(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeRemoveFromFolder:
                syncDB()->markPeopleViewAsDeleted(vRowid->longLongValue(), mFolderID, mDraftsFolderID, changes());
                break;
        }
    }
    syncDB()->commitTransaction(changes());
}

