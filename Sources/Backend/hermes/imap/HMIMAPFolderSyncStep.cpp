// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFolderSyncStep.h"

#include "HMMailStorage.h"
#include "HMIMAPFolderSyncStepDelegate.h"

using namespace hermes;
using namespace mailcore;

IMAPFolderSyncStep::IMAPFolderSyncStep()
{
    mSession = NULL;
    mFolderPath = NULL;
    mStorage = NULL;
    mDelegate = NULL;
    mError = ErrorNone;
    mNetwork = false;
    mSyncType = IMAPSyncTypeOther;
}

IMAPFolderSyncStep::~IMAPFolderSyncStep()
{
    MC_SAFE_RELEASE(mStorage);
    MC_SAFE_RELEASE(mFolderPath);
    MC_SAFE_RELEASE(mSession);
}

void IMAPFolderSyncStep::setSession(mailcore::IMAPAsyncSession * session)
{
    MC_SAFE_REPLACE_RETAIN(IMAPAsyncSession, mSession, session);
}

mailcore::IMAPAsyncSession * IMAPFolderSyncStep::session()
{
    return mSession;
}

void IMAPFolderSyncStep::setStorage(MailStorage * storage)
{
    MC_SAFE_REPLACE_RETAIN(MailStorage, mStorage, storage);
}

MailStorage * IMAPFolderSyncStep::storage()
{
    return mStorage;
}

void IMAPFolderSyncStep::setFolderPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mFolderPath, path);
}

String * IMAPFolderSyncStep::folderPath()
{
    return mFolderPath;
}

void IMAPFolderSyncStep::setDelegate(IMAPFolderSyncStepDelegate * delegate)
{
    mDelegate = delegate;
}

IMAPFolderSyncStepDelegate * IMAPFolderSyncStep::delegate()
{
    return mDelegate;
}

void IMAPFolderSyncStep::setError(hermes::ErrorCode error)
{
    mError = error;
}

hermes::ErrorCode IMAPFolderSyncStep::error()
{
    return mError;
}

void IMAPFolderSyncStep::setNetwork(bool network)
{
    mNetwork = network;
}

bool IMAPFolderSyncStep::isNetwork()
{
    return mNetwork;
}

void IMAPFolderSyncStep::setSyncType(IMAPSyncType syncType)
{
    mSyncType = syncType;
}

IMAPSyncType IMAPFolderSyncStep::syncType()
{
    return mSyncType;
}

int64_t IMAPFolderSyncStep::folderID()
{
    return storage()->folderIDForPath(folderPath());
}

void IMAPFolderSyncStep::start()
{
    MCAssert(0);
}

void IMAPFolderSyncStep::cancel()
{
    setDelegate(NULL);
}

void IMAPFolderSyncStep::notifyDelegateDone()
{
    if (mDelegate != NULL) {
        mDelegate->folderSyncStepDone(this);
    }
}
