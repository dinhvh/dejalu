// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBCopyPeopleOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBCopyPeopleOperation::MailDBCopyPeopleOperation()
{
    mFoldersNeedCopyMessages = new IndexSet();
    mOtherFolderID = -1;
    mConversationsIDs = NULL;
    mFoldersScores = NULL;
    mDraftsFolderID = -1;
}

MailDBCopyPeopleOperation::~MailDBCopyPeopleOperation()
{
    MC_SAFE_RELEASE(mFoldersScores);
    MC_SAFE_RELEASE(mFoldersNeedCopyMessages);
    MC_SAFE_RELEASE(mConversationsIDs);
}

void MailDBCopyPeopleOperation::setConversationsIDs(mailcore::Array * conversationsIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mConversationsIDs, conversationsIDs);
}

mailcore::Array * MailDBCopyPeopleOperation::conversationsIDs()
{
    return mConversationsIDs;
}

IndexSet * MailDBCopyPeopleOperation::foldersNeedCopyMessages()
{
    return mFoldersNeedCopyMessages;
}

void MailDBCopyPeopleOperation::setOtherFolderID(int64_t otherFolderID)
{
    mOtherFolderID = otherFolderID;
}

int64_t MailDBCopyPeopleOperation::otherFolderID()
{
    return mOtherFolderID;
}

int64_t MailDBCopyPeopleOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBCopyPeopleOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

mailcore::HashMap * MailDBCopyPeopleOperation::foldersScores()
{
    return mFoldersScores;
}

void MailDBCopyPeopleOperation::setFoldersScores(mailcore::HashMap * foldersScores)
{
    MC_SAFE_REPLACE_RETAIN(HashMap, mFoldersScores, foldersScores);
}

void MailDBCopyPeopleOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreacharray(Value, vConvID, mConversationsIDs) {
        syncDB()->copyPeopleViewToFolder(vConvID->longLongValue(), mOtherFolderID, mFoldersScores, mFoldersNeedCopyMessages,
                                         mDraftsFolderID, changes());
    }
    syncDB()->commitTransaction(changes());
}
