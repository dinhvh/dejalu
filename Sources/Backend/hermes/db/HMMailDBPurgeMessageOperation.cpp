// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBPurgeMessageOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBPurgeMessageOperation::MailDBPurgeMessageOperation()
{
    mConversationsIDs = NULL;
    mMessagesRowIDs = NULL;
    mFolderID = -1;
    mTrashFolderID = -1;
    mDraftsFolderID = -1;
    mFoldersNeedCopyMessages = new IndexSet();
}

MailDBPurgeMessageOperation::~MailDBPurgeMessageOperation()
{
    MC_SAFE_RELEASE(mMessagesRowIDs);
    MC_SAFE_RELEASE(mConversationsIDs);
    MC_SAFE_RELEASE(mFoldersNeedCopyMessages);
}

void MailDBPurgeMessageOperation::setConversationsIDs(mailcore::Array * conversationsIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mConversationsIDs, conversationsIDs);
}

mailcore::Array * MailDBPurgeMessageOperation::conversationsIDs()
{
    return mConversationsIDs;
}

void MailDBPurgeMessageOperation::setMessagesRowIDs(mailcore::Array * messagesRowIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mMessagesRowIDs, messagesRowIDs);
}

mailcore::Array * MailDBPurgeMessageOperation::messagesRowIDs()
{
    return mMessagesRowIDs;
}

void MailDBPurgeMessageOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBPurgeMessageOperation::folderID()
{
    return mFolderID;
}

void MailDBPurgeMessageOperation::setTrashFolderID(int64_t trashFolderID)
{
    mTrashFolderID = trashFolderID;
}

int64_t MailDBPurgeMessageOperation::trashFolderID()
{
    return mTrashFolderID;
}

int64_t MailDBPurgeMessageOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBPurgeMessageOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

IndexSet * MailDBPurgeMessageOperation::foldersNeedCopyMessages()
{
    return mFoldersNeedCopyMessages;
}

void MailDBPurgeMessageOperation::main()
{
    syncDB()->beginTransaction();
    if (mConversationsIDs != NULL) {
        mc_foreacharray(Value, vConvID, mConversationsIDs) {
            syncDB()->purgePeopleViewToFolder(vConvID->longLongValue(), mFolderID,
                                              mTrashFolderID, mFoldersNeedCopyMessages,
                                              mDraftsFolderID, changes());
        }
    }
    else if (mMessagesRowIDs != NULL) {
        mc_foreacharray(Value, vRowID, mMessagesRowIDs) {
            syncDB()->purgeMessageToFolder(vRowID->longLongValue(), mTrashFolderID, mFoldersNeedCopyMessages,
                                           mDraftsFolderID, changes());
        }
    }
    syncDB()->commitTransaction(changes());
}
