// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPRemoveExpiredLocalMessageSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"

using namespace mailcore;
using namespace hermes;

IMAPRemoveExpiredLocalMessageSyncStep::IMAPRemoveExpiredLocalMessageSyncStep()
{
    mRemoveExpiredLocalMessageOp = NULL;
}

IMAPRemoveExpiredLocalMessageSyncStep::~IMAPRemoveExpiredLocalMessageSyncStep()
{
    MC_SAFE_RELEASE(mRemoveExpiredLocalMessageOp);
}

void IMAPRemoveExpiredLocalMessageSyncStep::start()
{
    removeExpiredLocalMessage();
}

void IMAPRemoveExpiredLocalMessageSyncStep::cancel()
{
    if (mRemoveExpiredLocalMessageOp != NULL) {
        mRemoveExpiredLocalMessageOp->cancel();
        MC_SAFE_RELEASE(mRemoveExpiredLocalMessageOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}

void IMAPRemoveExpiredLocalMessageSyncStep::operationFinished(mailcore::Operation * op)
{
    removeExpiredLocalMessageDone();
}

void IMAPRemoveExpiredLocalMessageSyncStep::removeExpiredLocalMessage()
{
    retain();
    mRemoveExpiredLocalMessageOp = storage()->removeExpiredLocalMessageOperation(storage()->folderIDForPath(folderPath()));
    mRemoveExpiredLocalMessageOp->retain();
    mRemoveExpiredLocalMessageOp->setCallback(this);
    mRemoveExpiredLocalMessageOp->start();
}

void IMAPRemoveExpiredLocalMessageSyncStep::removeExpiredLocalMessageDone()
{
    MC_SAFE_RELEASE(mRemoveExpiredLocalMessageOp);
    notifyDelegateDone();
    release();
}
