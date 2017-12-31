// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBValidateFolderOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBValidateFolderOperation::MailDBValidateFolderOperation()
{
    mFolderPath = NULL;
    mUidValidity = 0;
}

MailDBValidateFolderOperation::~MailDBValidateFolderOperation()
{
    MC_SAFE_RELEASE(mFolderPath);
}

void MailDBValidateFolderOperation::setFolderPath(mailcore::String * folderPath)
{
    MC_SAFE_REPLACE_COPY(String, mFolderPath, folderPath);
}

mailcore::String * MailDBValidateFolderOperation::folderPath()
{
    return mFolderPath;
}

void MailDBValidateFolderOperation::setUidValidity(uint32_t uidValidity)
{
    mUidValidity = uidValidity;
}

uint32_t MailDBValidateFolderOperation::uidValidity()
{
    return mUidValidity;
}

void MailDBValidateFolderOperation::main()
{
    syncDB()->validateFolder(mFolderPath, mUidValidity, changes());
}

