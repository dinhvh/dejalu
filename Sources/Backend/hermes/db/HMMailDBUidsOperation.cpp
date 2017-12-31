// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBUidsOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBUidsOperation::MailDBUidsOperation()
{
    mUids = NULL;
    mFolderID = -1;
}

MailDBUidsOperation::~MailDBUidsOperation()
{
    MC_SAFE_RELEASE(mUids);
}

int64_t MailDBUidsOperation::folderID()
{
    return mFolderID;
}

void MailDBUidsOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

mailcore::IndexSet * MailDBUidsOperation::uids()
{
    return mUids;
}

void MailDBUidsOperation::main()
{
    syncDB()->beginTransaction();
    mUids = syncDB()->uids(mFolderID);
    MC_SAFE_RETAIN(mUids);
    syncDB()->commitTransaction(changes());
}

