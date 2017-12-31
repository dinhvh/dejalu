// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBPurgeSentDraftOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBPurgeSentDraftOperation::MailDBPurgeSentDraftOperation()
{
    mFolderID = -1;
    mTrashFolderID = -1;
    mFoldersNeedCopyMessages = new IndexSet();
    mDraftsFolderID = -1;
}

MailDBPurgeSentDraftOperation::~MailDBPurgeSentDraftOperation()
{
    MC_SAFE_RELEASE(mFoldersNeedCopyMessages);
}

void MailDBPurgeSentDraftOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBPurgeSentDraftOperation::folderID()
{
    return mFolderID;
}

void MailDBPurgeSentDraftOperation::setTrashFolderID(int64_t trashFolderID)
{
    mTrashFolderID = trashFolderID;
}

int64_t MailDBPurgeSentDraftOperation::trashFolderID()
{
    return mTrashFolderID;
}

int64_t MailDBPurgeSentDraftOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBPurgeSentDraftOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

mailcore::IndexSet * MailDBPurgeSentDraftOperation::foldersNeedCopyMessages()
{
    return mFoldersNeedCopyMessages;
}

void MailDBPurgeSentDraftOperation::main()
{
    syncDB()->beginTransaction();
    IndexSet * messagesRowIDs = syncDB()->sentDraftsToRemoveWithMessageID(mFolderID);
    mc_foreachindexset(messageRowID, messagesRowIDs) {
        syncDB()->purgeMessageToFolder(messageRowID, mTrashFolderID, mFoldersNeedCopyMessages, mDraftsFolderID, changes());
    }
    syncDB()->removeSentDraftRemove(mFolderID);
    syncDB()->commitTransaction(changes());
}

