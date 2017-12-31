// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchNextAttachmentSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBNextUIDToFetchOperation.h"
#include "HMMailDBRetrievePartOperation.h"
#include "HMMailDBUIDToFetchOperation.h"
#include "HMMailDBMessageRenderOperation.h"
#include "HMActivityItem.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchNextAttachmentSyncStep::IMAPFetchNextAttachmentSyncStep()
{
    mUid = 0;
    mEncoding = EncodingOther;
    mMessageRowID = -1;
    mPartID = NULL;
    mRetrievePartOp = NULL;
    mFetched = false;
    mUidOp = NULL;
    mActivity = new ActivityItem();
    mFetchOp = NULL;
    mContent = NULL;
    mStoreOp = NULL;
    mUrgent = false;
}

IMAPFetchNextAttachmentSyncStep::~IMAPFetchNextAttachmentSyncStep()
{
    MC_SAFE_RELEASE(mStoreOp);
    MC_SAFE_RELEASE(mContent);
    MC_SAFE_RELEASE(mFetchOp);
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mRetrievePartOp);
    MC_SAFE_RELEASE(mUidOp);
    MC_SAFE_RELEASE(mPartID);
}
int64_t IMAPFetchNextAttachmentSyncStep::messageRowID()
{
    return mMessageRowID;
}

void IMAPFetchNextAttachmentSyncStep::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

mailcore::String * IMAPFetchNextAttachmentSyncStep::partID()
{
    return mPartID;
}

void IMAPFetchNextAttachmentSyncStep::setPartID(mailcore::String * partID)
{
    MC_SAFE_REPLACE_COPY(String, mPartID, partID);
}

bool IMAPFetchNextAttachmentSyncStep::isUrgent()
{
    return mUrgent;
}

void IMAPFetchNextAttachmentSyncStep::setUrgent(bool urgent)
{
    mUrgent = urgent;
}

void IMAPFetchNextAttachmentSyncStep::start()
{
    fetchUidInfo();
}

void IMAPFetchNextAttachmentSyncStep::retrievePartData()
{
    retain();
    mRetrievePartOp = storage()->dataForPartOperation(mMessageRowID, mPartID);
    mRetrievePartOp->setCallback(this);
    mRetrievePartOp->retain();
    mRetrievePartOp->start();
}

void IMAPFetchNextAttachmentSyncStep::retrievePartDataDone()
{
    if (mRetrievePartOp->content() == NULL) {
        fetchUidInfo();
    }
    else {
        notifyDelegateDone();
        return;
    }

    release();
}

void IMAPFetchNextAttachmentSyncStep::fetchUidInfo()
{
    retain();
    mUidOp = storage()->uidEncodingToFetchOperation(mMessageRowID, mPartID);
    mUidOp->setCallback(this);
    mUidOp->retain();
    mUidOp->start();
}

void IMAPFetchNextAttachmentSyncStep::fetchUidInfoDone()
{
    mUid = mUidOp->uid();
    mEncoding = mUidOp->encoding();
    MC_SAFE_RELEASE(mUidOp);

    fetchPart();
    release();
}

void IMAPFetchNextAttachmentSyncStep::fetchPart()
{
    setNetwork(true);
    String * progressString = String::stringWithUTF8Format("fetch part %lu %s", (unsigned long) mUid, MCUTF8(mPartID));
    mActivity->setProgressString(progressString);
    mActivity->registerActivity();
    retain();
    mFetchOp = session()->fetchMessageAttachmentByUIDOperation(folderPath(), mUid, mPartID, mEncoding, mUrgent);
    mFetchOp->setCallback(this);
    mFetchOp->retain();
    mFetchOp->start();
}

void IMAPFetchNextAttachmentSyncStep::fetchPartDone()
{
    mActivity->unregisterActivity();
    setError((hermes::ErrorCode) mFetchOp->error());
    if (error() != ErrorNone) {
        MC_SAFE_RELEASE(mFetchOp);
        MC_SAFE_RELEASE(mContent);

        notifyDelegateDone();
        release();
        return;
    }
    MC_SAFE_REPLACE_RETAIN(Data, mContent, mFetchOp->data());
    MC_SAFE_RELEASE(mFetchOp);

    storePart();
    release();
}

void IMAPFetchNextAttachmentSyncStep::storePart()
{
    retain();
    mStoreOp = storage()->storeDataForPartOperation(mMessageRowID, mPartID, mContent);
    mStoreOp->setCallback(this);
    mStoreOp->retain();
    mStoreOp->start();
}

void IMAPFetchNextAttachmentSyncStep::storePartDone()
{
    MC_SAFE_RELEASE(mStoreOp);
    MC_SAFE_RELEASE(mContent);

    mFetched = true;
    notifyDelegateDone();

    release();
}

bool IMAPFetchNextAttachmentSyncStep::fetched()
{
    return mFetched;
}

void IMAPFetchNextAttachmentSyncStep::operationFinished(Operation * op)
{
    if (op == mStoreOp) {
        storePartDone();
    }
    else if (op == mFetchOp) {
        fetchPartDone();
    }
    else if (op == mRetrievePartOp) {
        retrievePartDataDone();
    }
    else if (op == mUidOp) {
        fetchUidInfoDone();
    }
}

void IMAPFetchNextAttachmentSyncStep::cancel()
{
    if (mRetrievePartOp != NULL) {
        mRetrievePartOp->cancel();
        MC_SAFE_RELEASE(mRetrievePartOp);
        release();
    }
    if (mUidOp != NULL) {
        mUidOp->cancel();
        MC_SAFE_RELEASE(mUidOp);
        release();
    }
    if (mFetchOp != NULL) {
        mActivity->unregisterActivity();
        mFetchOp->cancel();
        MC_SAFE_RELEASE(mFetchOp);
        release();
    }
    if (mStoreOp != NULL) {
        mStoreOp->cancel();
        MC_SAFE_RELEASE(mStoreOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}
