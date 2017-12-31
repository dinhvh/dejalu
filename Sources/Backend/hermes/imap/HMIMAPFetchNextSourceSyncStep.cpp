// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchNextSourceSyncStep.h"

#include "HMMailDBUIDToFetchOperation.h"
#include "HMMailStorage.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchNextSourceSyncStep::IMAPFetchNextSourceSyncStep()
{
    mUidOp = NULL;
    mFetchOp = NULL;
    mMessageRowID = -1;
    mMessageData = NULL;
}

IMAPFetchNextSourceSyncStep::~IMAPFetchNextSourceSyncStep()
{
    MC_SAFE_RELEASE(mMessageData);
    MC_SAFE_RELEASE(mUidOp);
    MC_SAFE_RELEASE(mFetchOp);
}

void IMAPFetchNextSourceSyncStep::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

int64_t IMAPFetchNextSourceSyncStep::messageRowID()
{
    return mMessageRowID;
}

mailcore::Data * IMAPFetchNextSourceSyncStep::messageData()
{
    return mMessageData;
}

void IMAPFetchNextSourceSyncStep::start()
{
    retain();
    mUidOp = storage()->uidToFetchOperation(mMessageRowID);
    mUidOp->setCallback(this);
    MC_SAFE_RETAIN(mUidOp);
    mUidOp->start();
}

void IMAPFetchNextSourceSyncStep::uidFetched()
{
    if (mUidOp->uid() == -1) {
        setError(hermes::ErrorMessageNotFound);
        MC_SAFE_RELEASE(mUidOp);
        notifyDelegateDone();
        release();
        return;
    }
    if ((mUidOp->uid() == 0) && (mUidOp->filename() != NULL)) {
        Data * data = Data::dataWithContentsOfFile(mUidOp->filename());
        MC_SAFE_REPLACE_RETAIN(Data, mMessageData, data);
        notifyDelegateDone();
        release();
        return;
    }

    mFetchOp = session()->fetchMessageByUIDOperation(folderPath(), mUidOp->uid());
    mFetchOp->setCallback(this);
    MC_SAFE_RETAIN(mFetchOp);
    mFetchOp->start();
    MC_SAFE_RELEASE(mUidOp);
}

void IMAPFetchNextSourceSyncStep::sourceFetched()
{
    if (mFetchOp->error() != mailcore::ErrorNone) {
        setError((hermes::ErrorCode) mFetchOp->error());
        MC_SAFE_RELEASE(mFetchOp);
        notifyDelegateDone();
        release();
        return;
    }
    mMessageData = mFetchOp->data();
    MC_SAFE_RETAIN(mMessageData);
    MC_SAFE_RELEASE(mFetchOp);
    notifyDelegateDone();
    release();
}

void IMAPFetchNextSourceSyncStep::cancel()
{
    if (mUidOp != NULL) {
        mUidOp->cancel();
        MC_SAFE_RELEASE(mUidOp);
        release();
    }
    else if (mFetchOp != NULL) {
        mFetchOp->cancel();
        MC_SAFE_RELEASE(mFetchOp);
        release();
    }
}

void IMAPFetchNextSourceSyncStep::operationFinished(mailcore::Operation * op)
{
    if (op == mUidOp) {
        uidFetched();
    }
    else if (op == mFetchOp) {
        sourceFetched();
    }
}
