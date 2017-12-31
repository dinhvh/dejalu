// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBPeopleConversationInfoOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBPeopleConversationInfoOperation::MailDBPeopleConversationInfoOperation()
{
    mConversationID = -1;
    mInboxFolderID = -1;
    mEmailSet = NULL;
    mFoldersScores = NULL;
    mConversationInfo = NULL;
    mFoldersToExcludeFromUnread = NULL;
}

MailDBPeopleConversationInfoOperation::~MailDBPeopleConversationInfoOperation()
{
    MC_SAFE_RELEASE(mFoldersToExcludeFromUnread);
    MC_SAFE_RELEASE(mFoldersScores);
    MC_SAFE_RELEASE(mEmailSet);
    MC_SAFE_RELEASE(mConversationInfo);
}

int64_t MailDBPeopleConversationInfoOperation::conversationID()
{
    return mConversationID;
}

void MailDBPeopleConversationInfoOperation::setConversationID(int64_t conversationID)
{
    mConversationID = conversationID;
}

int64_t MailDBPeopleConversationInfoOperation::inboxFolderID()
{
    return mInboxFolderID;
}

void MailDBPeopleConversationInfoOperation::setInboxFolderID(int64_t inboxFolderID)
{
    mInboxFolderID = inboxFolderID;
}

mailcore::HashMap * MailDBPeopleConversationInfoOperation::foldersScores()
{
    return mFoldersScores;
}

void MailDBPeopleConversationInfoOperation::setFoldersScores(HashMap * foldersScores)
{
    MC_SAFE_REPLACE_RETAIN(HashMap, mFoldersScores, foldersScores);
}

mailcore::Set * MailDBPeopleConversationInfoOperation::emailSet()
{
    return mEmailSet;
}

void MailDBPeopleConversationInfoOperation::setEmailSet(mailcore::Set * emailSet)
{
    MC_SAFE_REPLACE_RETAIN(mailcore::Set, mEmailSet, emailSet);
}

mailcore::Set * MailDBPeopleConversationInfoOperation::foldersToExcludeFromUnread()
{
    return mFoldersToExcludeFromUnread;
}

void MailDBPeopleConversationInfoOperation::setFoldersToExcludeFromUnread(mailcore::Set * foldersToExcludeFromUnread)
{
    MC_SAFE_REPLACE_RETAIN(mailcore::Set, mFoldersToExcludeFromUnread, foldersToExcludeFromUnread);
}

HashMap * MailDBPeopleConversationInfoOperation::conversationInfo()
{
    return mConversationInfo;
}

void MailDBPeopleConversationInfoOperation::main()
{
    syncDB()->beginTransaction();
    mConversationInfo = syncDB()->peopleConversationInfo(mConversationID, mFoldersScores, mInboxFolderID, mEmailSet, mFoldersToExcludeFromUnread, changes());
    mConversationInfo->retain();
    syncDB()->commitTransaction(changes());
}
