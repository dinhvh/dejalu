// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBCheckFolderSeenOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBCheckFolderSeenOperation::MailDBCheckFolderSeenOperation()
{
    mFolderID = -1;
    mFolderSeen = false;
}

MailDBCheckFolderSeenOperation::~MailDBCheckFolderSeenOperation()
{
}

void MailDBCheckFolderSeenOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBCheckFolderSeenOperation::folderID()
{
    return mFolderID;
}

void MailDBCheckFolderSeenOperation::main()
{
    syncDB()->beginTransaction();
    mFolderSeen = syncDB()->checkFolderSeen(mFolderID);
    syncDB()->commitTransaction(changes());
}

bool MailDBCheckFolderSeenOperation::isFolderSeen()
{
    return mFolderSeen;
}

