// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBNextMessageToPushOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBNextMessageToPushOperation::MailDBNextMessageToPushOperation()
{
    mFolderID = -1;
    mFilename = NULL;
    mDraftBehaviorEnabled = false;
    mDraftsMessagesRowIDsToDelete = NULL;
}

MailDBNextMessageToPushOperation::~MailDBNextMessageToPushOperation()
{
    MC_SAFE_RELEASE(mFilename);
}

void MailDBNextMessageToPushOperation::setFolderID(int64_t aFolderID)
{
    mFolderID = aFolderID;
}

int64_t MailDBNextMessageToPushOperation::folderID()
{
    return mFolderID;
}

void MailDBNextMessageToPushOperation::setDraftBehaviorEnabled(bool enabled)
{
    mDraftBehaviorEnabled = enabled;
}

bool MailDBNextMessageToPushOperation::isDraftBehaviorEnabled()
{
    return mDraftBehaviorEnabled;
}

mailcore::String * MailDBNextMessageToPushOperation::filename()
{
    return mFilename;
}

int64_t MailDBNextMessageToPushOperation::messageRowID()
{
    return mMessageRowID;
}

mailcore::IndexSet * MailDBNextMessageToPushOperation::draftsMessagesRowIDsToDelete()
{
    return mDraftsMessagesRowIDsToDelete;
}

void MailDBNextMessageToPushOperation::main()
{
    syncDB()->beginTransaction();
    HashMap * result = syncDB()->nextMessageToPush(mFolderID, mDraftBehaviorEnabled);
    syncDB()->commitTransaction(changes());
    if (result == NULL) {
        return;
    }
    mFilename = (String *) result->objectForKey(MCSTR("filename"));
    mMessageRowID = ((Value *) result->objectForKey(MCSTR("rowid")))->longLongValue();
    mFilename->retain();
    mDraftsMessagesRowIDsToDelete = (IndexSet *) result->objectForKey(MCSTR("old"));
    MC_SAFE_RETAIN(mDraftsMessagesRowIDsToDelete);
}

