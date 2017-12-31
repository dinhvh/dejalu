// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBNextUIDToFetchOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBNextUIDToFetchOperation::MailDBNextUIDToFetchOperation()
{
    mMessageRowID = -1;
    mUid = 0;
    mFolderID = -1;
    mMaxUid = 0;
}

MailDBNextUIDToFetchOperation::~MailDBNextUIDToFetchOperation()
{
}

void MailDBNextUIDToFetchOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBNextUIDToFetchOperation::folderID()
{
    return mFolderID;
}

void MailDBNextUIDToFetchOperation::setMaxUid(uint32_t maxUid)
{
    mMaxUid = maxUid;
}

uint32_t MailDBNextUIDToFetchOperation::maxUid()
{
    return mMaxUid;
}

int64_t MailDBNextUIDToFetchOperation::messageRowID()
{
    return mMessageRowID;
}

uint32_t MailDBNextUIDToFetchOperation::uid()
{
    return mUid;
}

void MailDBNextUIDToFetchOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->nextUidToFetch(mFolderID, mMaxUid, &mUid, &mMessageRowID);
    syncDB()->commitTransaction(changes());
}
