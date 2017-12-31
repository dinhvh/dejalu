// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMessagesLocalChangesOperation.h"

#include "HMMailDBLocalMessagesChanges.h"
#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBMessagesLocalChangesOperation::MailDBMessagesLocalChangesOperation()
{
    mFolderID = -1;
    mLocalChanges = NULL;
}

MailDBMessagesLocalChangesOperation::~MailDBMessagesLocalChangesOperation()
{
    MC_SAFE_RELEASE(mLocalChanges);
}

int64_t MailDBMessagesLocalChangesOperation::folderID()
{
    return mFolderID;
}

void MailDBMessagesLocalChangesOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

MailDBLocalMessagesChanges * MailDBMessagesLocalChangesOperation::localChanges()
{
    return mLocalChanges;
}

void MailDBMessagesLocalChangesOperation::main()
{
    syncDB()->beginTransaction();
    mLocalChanges = syncDB()->localMessagesChanges(mFolderID);
    syncDB()->commitTransaction(changes());
    mLocalChanges->retain();
}
