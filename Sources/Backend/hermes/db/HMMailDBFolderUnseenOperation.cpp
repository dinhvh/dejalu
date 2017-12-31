// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBFolderUnseenOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBFolderUnseenOperation::MailDBFolderUnseenOperation()
{
    mFolderID = -1;
}

MailDBFolderUnseenOperation::~MailDBFolderUnseenOperation()
{
}

void MailDBFolderUnseenOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBFolderUnseenOperation::folderID()
{
    return mFolderID;
}

bool MailDBFolderUnseenOperation::isUnseen()
{
    return mUnseen;
}

void MailDBFolderUnseenOperation::main()
{
    mUnseen = syncDB()->isFolderUnseen(mFolderID);
}
