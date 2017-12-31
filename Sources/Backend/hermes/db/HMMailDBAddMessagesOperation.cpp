// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBAddMessagesOperation.h"

#include "HMMailDB.h"
#include "HMMailDBChanges.h"
#include "DJLLog.h"
#include "HMMailStorage.h"

using namespace hermes;
using namespace mailcore;

MailDBAddMessagesOperation::MailDBAddMessagesOperation()
{
    mMessages = NULL;
    mFolderID = -1;
    mMessagesRowsIDs = NULL;
    mDraftsFolderID = -1;
}

MailDBAddMessagesOperation::~MailDBAddMessagesOperation()
{
    MC_SAFE_RELEASE(mMessagesRowsIDs);
    MC_SAFE_RELEASE(mMessages);
}

Array * MailDBAddMessagesOperation::messages()
{
    return mMessages;
}

void MailDBAddMessagesOperation::setMessages(Array * msgs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mMessages, msgs);
}

int64_t MailDBAddMessagesOperation::folderID()
{
    return mFolderID;
}

void MailDBAddMessagesOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBAddMessagesOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBAddMessagesOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

mailcore::IndexSet * MailDBAddMessagesOperation::messagesRowsIDs()
{
    return mMessagesRowsIDs;
}

void MailDBAddMessagesOperation::main()
{
    mMessagesRowsIDs = new IndexSet();
    syncDB()->beginTransaction();
    bool notificationEnabled = syncDB()->isFirstSyncDone(mFolderID);
    LOG_ERROR("%s: add %i messages", MCUTF8(storage()->path()), mMessages->count());
    for(int i = (int) mMessages->count() - 1 ; i >= 0 ; i --) {
        IMAPMessage * msg = (IMAPMessage *) mMessages->objectAtIndex(i);
        //LOG_ERROR("%s: add messages %i/%i", MCUTF8(storage()->path()), i, mMessages->count());
        int64_t rowid = syncDB()->addIMAPMessage(mFolderID, msg, notificationEnabled, mDraftsFolderID, changes());
        mMessagesRowsIDs->addIndex(rowid);
    }
    syncDB()->commitTransaction(changes());
    MCLog("%i added messages, changes: %s", mMessages->count(), MCUTF8DESC(changes()));
}
