// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBAddFoldersOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBAddFoldersOperation::MailDBAddFoldersOperation()
{
    mPathsToAdd = NULL;
    mPathsToRemove = NULL;
    mFoldersToAddIDs = NULL;
    mDefaultNamespace = NULL;
}

MailDBAddFoldersOperation::~MailDBAddFoldersOperation()
{
    MC_SAFE_RELEASE(mDefaultNamespace);
    MC_SAFE_RELEASE(mFoldersToAddIDs);
    MC_SAFE_RELEASE(mPathsToAdd);
    MC_SAFE_RELEASE(mPathsToRemove);
}

mailcore::Array * MailDBAddFoldersOperation::pathsToAdd()
{
    return mPathsToAdd;
}

void MailDBAddFoldersOperation::setPathsToAdd(mailcore::Array * paths)
{
    MC_SAFE_REPLACE_RETAIN(Array, mPathsToAdd, paths);
}

mailcore::Array * MailDBAddFoldersOperation::pathsToRemove()
{
    return mPathsToRemove;
}

void MailDBAddFoldersOperation::setPathsToRemove(mailcore::Array * paths)
{
    MC_SAFE_REPLACE_RETAIN(Array, mPathsToRemove, paths);
}

mailcore::Array * MailDBAddFoldersOperation::foldersToAddIDs()
{
    return mFoldersToAddIDs;
}

mailcore::IMAPNamespace * MailDBAddFoldersOperation::defaultNamespace()
{
    return mDefaultNamespace;
}

void MailDBAddFoldersOperation::setDefaultNamespace(mailcore::IMAPNamespace * defaultNamespace)
{
    MC_SAFE_REPLACE_RETAIN(IMAPNamespace, mDefaultNamespace, defaultNamespace);
}

void MailDBAddFoldersOperation::main()
{
    mFoldersToAddIDs = new Array();
    syncDB()->beginTransaction();
    {
        mc_foreacharray(String, path, mPathsToAdd) {
            int64_t folderID = syncDB()->addFolder(path);
            mFoldersToAddIDs->addObject(Value::valueWithLongLongValue(folderID));
        }
    }
    {
        mc_foreacharray(String, path, mPathsToRemove) {
            syncDB()->removeFolder(path, changes());
        }
    }
    if (mDefaultNamespace != NULL) {
        syncDB()->storeDefaultNamespace(mDefaultNamespace);
    }
    syncDB()->commitTransaction(changes());
}

