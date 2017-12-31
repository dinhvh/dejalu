// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchFolderStateSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMActivityItem.h"
#include "HMMailStorage.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchFolderStateSyncStep::IMAPFetchFolderStateSyncStep()
{
    mFolderInfoOp = NULL;
    mValidateFolderOp = NULL;
    mCount = 0;
    mUidNext = 0;
    mUidValidity = 0;
    mActivity = new ActivityItem();
    mActivity->setProgressString(MCSTR("get folder info"));
}

IMAPFetchFolderStateSyncStep::~IMAPFetchFolderStateSyncStep()
{
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mFolderInfoOp);
    MC_SAFE_RELEASE(mValidateFolderOp);
}

void IMAPFetchFolderStateSyncStep::start()
{
    folderInfo();
}

void IMAPFetchFolderStateSyncStep::folderInfo()
{
    mActivity->registerActivity();
    
    retain();
    setNetwork(true);
    mFolderInfoOp = session()->folderInfoOperation(folderPath());
    mFolderInfoOp->retain();
    mFolderInfoOp->setCallback(this);
    mFolderInfoOp->start();
}

void IMAPFetchFolderStateSyncStep::folderInfoDone()
{
    mActivity->unregisterActivity();
    setError((hermes::ErrorCode) mFolderInfoOp->error());
    if (error() == hermes::ErrorNone) {
        mCount = mFolderInfoOp->info()->messageCount();
        mUidNext = mFolderInfoOp->info()->uidNext();
        mUidValidity = mFolderInfoOp->info()->uidValidity();
        //fprintf(stderr, "uid validity: %llu\n", (unsigned long long) mFolderInfoOp->info()->uidValidity());
    }
    //fprintf(stderr, "folder has %i messages\n", mCount);
    MC_SAFE_RELEASE(mFolderInfoOp);

    if (error() == hermes::ErrorNone) {
        validateFolder();
    }
    else {
        notifyDelegateDone();
    }
    release();
}

void IMAPFetchFolderStateSyncStep::validateFolder()
{
    retain();
    mValidateFolderOp = storage()->validateFolderOperation(folderPath(), mUidValidity);
    mValidateFolderOp->retain();
    mValidateFolderOp->setCallback(this);
    mValidateFolderOp->start();
}

void IMAPFetchFolderStateSyncStep::validateFolderDone()
{
    MC_SAFE_RELEASE(mValidateFolderOp);
    notifyDelegateDone();
    release();
}

void IMAPFetchFolderStateSyncStep::operationFinished(Operation * op)
{
    if (op == mFolderInfoOp) {
        folderInfoDone();
    }
    else if (op == mValidateFolderOp) {
        validateFolderDone();
    }
}

unsigned int IMAPFetchFolderStateSyncStep::count()
{
    return mCount;
}

uint32_t IMAPFetchFolderStateSyncStep::uidNext()
{
    return mUidNext;
}

void IMAPFetchFolderStateSyncStep::cancel()
{
    if (mFolderInfoOp != NULL) {
        mActivity->unregisterActivity();
        mFolderInfoOp->cancel();
        MC_SAFE_RELEASE(mFolderInfoOp);
        release();
    }
    if (mValidateFolderOp != NULL) {
        mValidateFolderOp->cancel();
        MC_SAFE_RELEASE(mValidateFolderOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}
