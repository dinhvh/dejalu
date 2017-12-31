// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBUidsToCopyOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBUidsToCopyOperation::MailDBUidsToCopyOperation()
{
    mFolderID = -1;
    mDeleteOriginal = 0;
    mMessagesInfos = NULL;
}

MailDBUidsToCopyOperation::~MailDBUidsToCopyOperation()
{
    MC_SAFE_RELEASE(mMessagesInfos);
}

void MailDBUidsToCopyOperation::setFolderID(int64_t aFolderID)
{
    mFolderID = aFolderID;
}

int64_t MailDBUidsToCopyOperation::folderID()
{
    return mFolderID;
}

void MailDBUidsToCopyOperation::setDeleteOriginal(int value)
{
    mDeleteOriginal = value;
}

int MailDBUidsToCopyOperation::deleteOriginal()
{
    return mDeleteOriginal;
}

mailcore::Array * MailDBUidsToCopyOperation::messagesInfos()
{
    return mMessagesInfos;
}

void MailDBUidsToCopyOperation::main()
{
    syncDB()->beginTransaction();
    switch (mDeleteOriginal) {
        case 0:
            mMessagesInfos = syncDB()->messagesUidsToCopy(mFolderID);
            break;
        case 1:
            mMessagesInfos = syncDB()->messagesUidsToMove(mFolderID);
            break;
        case 2:
            mMessagesInfos = syncDB()->messagesUidsToPurge(mFolderID);
            break;
    }
    MC_SAFE_RETAIN(mMessagesInfos);
    syncDB()->commitTransaction(changes());
}

