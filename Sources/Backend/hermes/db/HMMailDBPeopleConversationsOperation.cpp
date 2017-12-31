// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBPeopleConversationsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBPeopleConversationsOperation::MailDBPeopleConversationsOperation()
{
    mConversations = NULL;
    mFolderID = -1;
    mUnreadOnly = false;
    mStarredOnly = false;
    mKeywords = NULL;
}

MailDBPeopleConversationsOperation::~MailDBPeopleConversationsOperation()
{
    MC_SAFE_RELEASE(mKeywords);
    MC_SAFE_RELEASE(mConversations);
}

mailcore::Array * MailDBPeopleConversationsOperation::keywords()
{
    return mKeywords;
}

void MailDBPeopleConversationsOperation::setKeywords(mailcore::Array * keywords)
{
    MC_SAFE_REPLACE_COPY(Array, mKeywords, keywords);
}

bool MailDBPeopleConversationsOperation::unreadOnly()
{
    return mUnreadOnly;
}

void MailDBPeopleConversationsOperation::setUnreadOnly(bool value)
{
    mUnreadOnly = value;
}

bool MailDBPeopleConversationsOperation::starredOnly()
{
    return mStarredOnly;
}

void MailDBPeopleConversationsOperation::setStarredOnly(bool value)
{
    mStarredOnly = value;
}

int64_t MailDBPeopleConversationsOperation::folderID()
{
    return mFolderID;
}

void MailDBPeopleConversationsOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

Array * MailDBPeopleConversationsOperation::conversations()
{
    return mConversations;
}

void MailDBPeopleConversationsOperation::main()
{
    syncDB()->beginTransaction();
    if (mKeywords != NULL) {
        mConversations = syncDB()->peopleConversationsForKeywords(mKeywords);
    }
    else if (mFolderID == -1) {
        mConversations = syncDB()->peopleConversations(mStarredOnly);
    }
    else {
        mConversations = syncDB()->peopleConversationsForFolder(mFolderID, mUnreadOnly);
    }
    mConversations->retain();
    syncDB()->commitTransaction(changes());
}
