// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMovePeopleOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBMovePeopleOperation::MailDBMovePeopleOperation()
{
    mFoldersNeedCopyMessages = new IndexSet();
    mOtherFolderID = -1;
    mConversationsIDs = NULL;
    mFoldersScores = NULL;
    mDraftsFolderID = -1;
}

MailDBMovePeopleOperation::~MailDBMovePeopleOperation()
{
    MC_SAFE_RELEASE(mFoldersScores);
    MC_SAFE_RELEASE(mFoldersNeedCopyMessages);
    MC_SAFE_RELEASE(mConversationsIDs);
}

void MailDBMovePeopleOperation::setConversationsIDs(mailcore::Array * conversationsIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mConversationsIDs, conversationsIDs);
}

mailcore::Array * MailDBMovePeopleOperation::conversationsIDs()
{
    return mConversationsIDs;
}

IndexSet * MailDBMovePeopleOperation::foldersNeedCopyMessages()
{
    return mFoldersNeedCopyMessages;
}

void MailDBMovePeopleOperation::setOtherFolderID(int64_t otherFolderID)
{
    mOtherFolderID = otherFolderID;
}

int64_t MailDBMovePeopleOperation::otherFolderID()
{
    return mOtherFolderID;
}

mailcore::HashMap * MailDBMovePeopleOperation::foldersScores()
{
    return mFoldersScores;
}

void MailDBMovePeopleOperation::setFoldersScores(mailcore::HashMap * foldersScores)
{
    MC_SAFE_REPLACE_RETAIN(HashMap, mFoldersScores, foldersScores);
}

int64_t MailDBMovePeopleOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBMovePeopleOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

void MailDBMovePeopleOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreacharray(Value, vConvID, mConversationsIDs) {
        syncDB()->movePeopleViewToFolder(vConvID->longLongValue(), mOtherFolderID, mFoldersScores, mFoldersNeedCopyMessages,
                                         mDraftsFolderID, changes());
    }
    syncDB()->commitTransaction(changes());
}
