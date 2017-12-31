// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRemoveExpiredLocalMessagesOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBRemoveExpiredLocalMessagesOperation::MailDBRemoveExpiredLocalMessagesOperation()
{
    mFolderID = -1;
}

MailDBRemoveExpiredLocalMessagesOperation::~MailDBRemoveExpiredLocalMessagesOperation()
{
}

void MailDBRemoveExpiredLocalMessagesOperation::setFolderID(int64_t aFolderID)
{
    mFolderID = aFolderID;
}

int64_t MailDBRemoveExpiredLocalMessagesOperation::folderID()
{
    return mFolderID;
}

void MailDBRemoveExpiredLocalMessagesOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->removeExpiredLocalMessage(mFolderID, changes());
    syncDB()->commitTransaction(changes());
}

