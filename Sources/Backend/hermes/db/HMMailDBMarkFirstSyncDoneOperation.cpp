// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMarkFirstSyncDoneOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBMarkFirstSyncDoneOperation::MailDBMarkFirstSyncDoneOperation()
{
    mFolderID = -1;
}

MailDBMarkFirstSyncDoneOperation::~MailDBMarkFirstSyncDoneOperation()
{
}

void MailDBMarkFirstSyncDoneOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBMarkFirstSyncDoneOperation::folderID()
{
    return mFolderID;
}

void MailDBMarkFirstSyncDoneOperation::main()
{
    syncDB()->markFirstSyncDone(mFolderID);
}
