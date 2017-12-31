// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBOpenOperation.h"

#include "HMMailDB.h"
#include "HMMailDBChanges.h"
#include "HMSerialization.h"

using namespace hermes;
using namespace mailcore;

MailDBOpenOperation::MailDBOpenOperation()
{
    mFolders = NULL;
    mMainFolders = NULL;
    mDefaultNamespace = NULL;
}

MailDBOpenOperation::~MailDBOpenOperation()
{
    MC_SAFE_RELEASE(mDefaultNamespace);
    MC_SAFE_RELEASE(mMainFolders);
    MC_SAFE_RELEASE(mFolders);
}

void MailDBOpenOperation::main()
{
    syncDB()->open();
    syncDB()->beginTransaction();
    MC_SAFE_REPLACE_RETAIN(HashMap, mFolders, syncDB()->folders());
    MC_SAFE_REPLACE_RETAIN(IMAPNamespace, mDefaultNamespace, syncDB()->defaultNamespace());
    HashMap * foldersCounts = syncDB()->foldersCounts();
    changes()->addChangedFoldersIDs(foldersCounts);
    Data * data = syncDB()->retrieveValueForKey(MCSTR("mainfolders"));
    if (data != NULL) {
        mMainFolders = (HashMap *) hermes::objectWithFastSerializedData(data);
        MC_SAFE_RETAIN(mMainFolders);
    }
    syncDB()->commitTransaction(changes());
}

HashMap * MailDBOpenOperation::folders()
{
    return mFolders;
}

HashMap * MailDBOpenOperation::mainFolders()
{
    return mMainFolders;
}

mailcore::IMAPNamespace * MailDBOpenOperation::defaultNamespace()
{
    return mDefaultNamespace;
}
