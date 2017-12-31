// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRemoveMessagesOperation.h"

#include "HMMailDB.h"
#include "HMMailDBChanges.h"

using namespace hermes;
using namespace mailcore;

MailDBRemoveMessagesOperation::MailDBRemoveMessagesOperation()
{
    mFolderID = -1;
    mMessagesUids = NULL;
    mMessagesRowIDs = NULL;
}

MailDBRemoveMessagesOperation::~MailDBRemoveMessagesOperation()
{
    MC_SAFE_RELEASE(mMessagesUids);
    MC_SAFE_RELEASE(mMessagesRowIDs);
}

Array * MailDBRemoveMessagesOperation::messagesRowIDs()
{
    return mMessagesRowIDs;
}

void MailDBRemoveMessagesOperation::setMessagesRowIDs(Array * rowIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mMessagesRowIDs, rowIDs);
}

IndexSet * MailDBRemoveMessagesOperation::messagesUids()
{
    return mMessagesUids;
}

void MailDBRemoveMessagesOperation::setMessagesUids(IndexSet * uids)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mMessagesUids, uids);
}

int64_t MailDBRemoveMessagesOperation::folderID()
{
    return mFolderID;
}

void MailDBRemoveMessagesOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

void MailDBRemoveMessagesOperation::main()
{
    syncDB()->beginTransaction();
    if (mMessagesRowIDs != NULL) {
        mc_foreacharray(Value, vRowID, mMessagesRowIDs) {
            syncDB()->removeMessage(vRowID->longLongValue(), changes());
        }
    }
    if (mMessagesUids != NULL) {
        mc_foreachindexset(uid, mMessagesUids) {
            syncDB()->removeMessageUid(mFolderID, (uint32_t) uid, changes());
        }
    }
    MCLog("%i removed messages, changes: %s", mMessagesUids->count(), MCUTF8DESC(changes()));
    syncDB()->commitTransaction(changes());
}
