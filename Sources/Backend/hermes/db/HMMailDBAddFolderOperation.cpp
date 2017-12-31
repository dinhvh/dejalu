// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBAddFolderOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBAddFolderOperation::MailDBAddFolderOperation()
{
    mPath = NULL;
    mFolderID = -1;
}

MailDBAddFolderOperation::~MailDBAddFolderOperation()
{
    MC_SAFE_RELEASE(mPath);
}

String * MailDBAddFolderOperation::path()
{
    return mPath;
}

void MailDBAddFolderOperation::setPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mPath, path);
}

int64_t MailDBAddFolderOperation::folderID()
{
    return mFolderID;
}

void MailDBAddFolderOperation::main()
{
    syncDB()->beginTransaction();
    mFolderID = syncDB()->addFolder(mPath);
    syncDB()->commitTransaction(changes());
}
