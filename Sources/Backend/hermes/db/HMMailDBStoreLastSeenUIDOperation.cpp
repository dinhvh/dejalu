// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBStoreLastSeenUIDOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBStoreLastSeenUIDOperation::MailDBStoreLastSeenUIDOperation()
{
    mFolderID = -1;
}

MailDBStoreLastSeenUIDOperation::~MailDBStoreLastSeenUIDOperation()
{
}

void MailDBStoreLastSeenUIDOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBStoreLastSeenUIDOperation::folderID()
{
    return mFolderID;
}

void MailDBStoreLastSeenUIDOperation::main()
{
    syncDB()->storeLastSeenUIDForFolder( mFolderID);
}
