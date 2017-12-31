// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMessagesOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBMessagesOperation::MailDBMessagesOperation()
{
    mFolderID = -1;
    mMessagesRowsIDs = NULL;
}

MailDBMessagesOperation::~MailDBMessagesOperation()
{
    MC_SAFE_RELEASE(mMessagesRowsIDs);
}

void MailDBMessagesOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBMessagesOperation::folderID()
{
    return mFolderID;
}

// result
IndexSet * MailDBMessagesOperation::messagesRowsIDs()
{
    return mMessagesRowsIDs;
}

// Implements Operation.
void MailDBMessagesOperation::main()
{
    int64_t rowID = syncDB()->lastUidForSavedRecipients();
    mMessagesRowsIDs = syncDB()->messagesForFolderID(mFolderID, rowID + 1);
    mMessagesRowsIDs->retain();
}
