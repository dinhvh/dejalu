// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchNextSummarySyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBNextUIDToFetchOperation.h"
#include "HMMailDBUIDToFetchOperation.h"
#include "HMMailDBMessageRenderOperation.h"
#include "HMActivityItem.h"
#include "HMIMAPSyncTypesUtils.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchNextSummarySyncStep::IMAPFetchNextSummarySyncStep()
{
    mNextUidOp = NULL;
    mUidOp = NULL;
    mUid = 0;
    mMessageRowID = -1;
    mRenderOp = NULL;
    mRequiredParts = NULL;
    mBodyIndex = 0;
    mFetchOp = NULL;
    mContent = NULL;
    mStoreOp = NULL;
    mMarkAsFetchedOp = NULL;
    mFetched = false;
    mMaxUid = 0;
    mActivity = new ActivityItem();
    mUrgent = false;
    mHasMessagePart = false;
    mFetchFullOp = NULL;
    mStoreMessagePartsOp = NULL;
    mShouldFetchFullMessage = false;
}

IMAPFetchNextSummarySyncStep::~IMAPFetchNextSummarySyncStep()
{
    MC_SAFE_RELEASE(mStoreMessagePartsOp);
    MC_SAFE_RELEASE(mFetchFullOp);
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mNextUidOp);
    MC_SAFE_RELEASE(mUidOp);
    MC_SAFE_RELEASE(mRenderOp);
    MC_SAFE_RELEASE(mRequiredParts);
    MC_SAFE_RELEASE(mFetchOp);
    MC_SAFE_RELEASE(mContent);
    MC_SAFE_RELEASE(mStoreOp);
    MC_SAFE_RELEASE(mMarkAsFetchedOp);
}

uint32_t IMAPFetchNextSummarySyncStep::maxUid()
{
    return mMaxUid;
}

void IMAPFetchNextSummarySyncStep::setMaxUid(uint32_t maxUid)
{
    mMaxUid = maxUid;
}

uint32_t IMAPFetchNextSummarySyncStep::uid()
{
    return mUid;
}

int64_t IMAPFetchNextSummarySyncStep::messageRowID()
{
    return mMessageRowID;
}

void IMAPFetchNextSummarySyncStep::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

bool IMAPFetchNextSummarySyncStep::isUrgent()
{
    return mUrgent;
}

void IMAPFetchNextSummarySyncStep::setUrgent(bool urgent)
{
    mUrgent = urgent;
}

void IMAPFetchNextSummarySyncStep::start()
{
    if (mMessageRowID != -1) {
        fetchUidInfo();
    }
    else {
        nextUidToFetch();
    }
}

void IMAPFetchNextSummarySyncStep::fetchUidInfo()
{
    retain();
#if 1
    mUidOp = storage()->uidToFetchOperation(mMessageRowID);
    mUidOp->setCallback(this);
    mUidOp->retain();
    mUidOp->start();
#else // force error fetch summary
    performMethodAfterDelay((Object::Method) &IMAPFetchNextSummarySyncStep::debugCallbackError, NULL, 1);
#endif
}

void IMAPFetchNextSummarySyncStep::debugCallbackError()
{
    setError(ErrorFetch);
    notifyDelegateDone();
    release();
}

void IMAPFetchNextSummarySyncStep::fetchUidInfoDone()
{
    mUid = mUidOp->uid();
    MC_SAFE_RELEASE(mUidOp);
    
    if (mUid == 0) {
        // It's a message copy in progress.
        notifyDelegateDone();
    }
    else {
        tryRenderMessage();
    }
    release();
}

void IMAPFetchNextSummarySyncStep::nextUidToFetch()
{
    retain();
    mNextUidOp = storage()->nextUidToFetchOperation(folderID(), mMaxUid);
    mNextUidOp->setCallback(this);
    mNextUidOp->retain();
    mNextUidOp->start();
}

void IMAPFetchNextSummarySyncStep::nextUidToFetchDone()
{
    mUid = mNextUidOp->uid();
    mMessageRowID = mNextUidOp->messageRowID();
    if (mMessageRowID == -1) {
        MC_SAFE_RELEASE(mNextUidOp);
        notifyDelegateDone();
        release();
        return;
    }
    
    MC_SAFE_RELEASE(mNextUidOp);
    //fprintf(stderr, "fetching %i %i\n", (int) mUid, (int) mMessageRowID);
    
    tryRenderMessage();
    release();
}

void IMAPFetchNextSummarySyncStep::tryRenderMessage()
{
    retain();
    mRenderOp = storage()->messageRenderSummaryOperation(mMessageRowID);
    mRenderOp->setCallback(this);
    mRenderOp->retain();
    mRenderOp->start();
}

void IMAPFetchNextSummarySyncStep::tryRenderMessageDone()
{
    mShouldFetchFullMessage = mRenderOp->shouldFetchFullMessage();
    mHasMessagePart = mRenderOp->hasMessagePart();
    MC_SAFE_REPLACE_RETAIN(Array, mRequiredParts, mRenderOp->requiredParts());
    MC_SAFE_RELEASE(mRenderOp);
    
    if ((mRequiredParts->count() == 0) && !mShouldFetchFullMessage) {
        markAsFetched();
    }
    else {
        fetchBodies();
    }
    release();
}

bool IMAPFetchNextSummarySyncStep::shouldFetchFullMessage()
{
    bool fetchFullBody = false;
    if ((syncType() == IMAPSyncTypeGmail) && mHasMessagePart) {
        fetchFullBody = true;
    }
    if (mShouldFetchFullMessage) {
        fetchFullBody = true;
    }
    return fetchFullBody;
}

void IMAPFetchNextSummarySyncStep::fetchBodies()
{
    if (shouldFetchFullMessage()) {
        // workaround in case Gmail won't be able to fetch subparts of a message/rfc822 part.
        fetchFullMessage();
        return;
    }

    mBodyIndex = 0;
    fetchNextBody();
}

void IMAPFetchNextSummarySyncStep::fetchNextBody()
{
    if (mBodyIndex >= mRequiredParts->count()) {
        tryRenderMessage();
        return;
    }

    setNetwork(true);
    String * progressString = String::stringWithUTF8Format("fetch message %lu", (unsigned long) mUid);
    mActivity->setProgressString(progressString);
    mActivity->registerActivity();
    retain();
    IMAPPart * part = (IMAPPart *) mRequiredParts->objectAtIndex(mBodyIndex);
    mFetchOp = session()->fetchMessageAttachmentByUIDOperation(folderPath(), mUid, part->partID(), part->encoding(), mUrgent);
    mFetchOp->setCallback(this);
    mFetchOp->retain();
    mFetchOp->start();
}

void IMAPFetchNextSummarySyncStep::fetchNextBodyDone()
{
    mActivity->unregisterActivity();
    setError((hermes::ErrorCode) mFetchOp->error());
    if (error() != ErrorNone) {
        MC_SAFE_RELEASE(mFetchOp);
        MC_SAFE_RELEASE(mRequiredParts);
        MC_SAFE_RELEASE(mContent);
        
        notifyDelegateDone();
        release();
        return;
    }
    mContent = mFetchOp->data();
    mContent->retain();
    MC_SAFE_RELEASE(mFetchOp);
    
    storeNextBody();
    release();
}

void IMAPFetchNextSummarySyncStep::storeNextBody()
{
    retain();
    IMAPPart * part = (IMAPPart *) mRequiredParts->objectAtIndex(mBodyIndex);
    mStoreOp = storage()->storeDataForPartOperation(mMessageRowID, part->partID(), mContent);
    mStoreOp->setCallback(this);
    mStoreOp->retain();
    mStoreOp->start();
}

void IMAPFetchNextSummarySyncStep::storeNextBodyDone()
{
    MC_SAFE_RELEASE(mStoreOp);
    MC_SAFE_RELEASE(mContent);
    
    mBodyIndex ++;
    fetchNextBody();
    
    release();
}

void IMAPFetchNextSummarySyncStep::fetchFullMessage()
{
    MC_SAFE_RELEASE(mRequiredParts);

    setNetwork(true);
    String * progressString = String::stringWithUTF8Format("fetch message %lu", (unsigned long) mUid);
    mActivity->setProgressString(progressString);
    mActivity->registerActivity();
    retain();
    mFetchFullOp = session()->fetchMessageByUIDOperation(folderPath(), mUid, mUrgent);
    mFetchFullOp->setCallback(this);
    mFetchFullOp->retain();
    mFetchFullOp->start();
}

void IMAPFetchNextSummarySyncStep::fetchFullMessageDone()
{
    mActivity->unregisterActivity();
    setError((hermes::ErrorCode) mFetchFullOp->error());
    if (error() != ErrorNone) {
        MC_SAFE_RELEASE(mFetchFullOp);
        MC_SAFE_RELEASE(mContent);

        notifyDelegateDone();
        release();
        return;
    }
    mContent = mFetchFullOp->data();
    mContent->retain();
    MC_SAFE_RELEASE(mFetchFullOp);

    storeMessageParts();
    release();
}

void IMAPFetchNextSummarySyncStep::storeMessageParts()
{
    retain();
    mStoreMessagePartsOp = storage()->storeDataForMessageDataOperation(mMessageRowID, mContent);
    mStoreMessagePartsOp->setCallback(this);
    mStoreMessagePartsOp->retain();
    mStoreMessagePartsOp->start();
}

void IMAPFetchNextSummarySyncStep::storeMessagePartsDone()
{
    MC_SAFE_RELEASE(mStoreMessagePartsOp);
    MC_SAFE_RELEASE(mContent);

    markAsFetched();

    release();
}

void IMAPFetchNextSummarySyncStep::markAsFetched()
{
    retain();
    mMarkAsFetchedOp = storage()->markAsFetchedOperation(mMessageRowID);
    mMarkAsFetchedOp->setCallback(this);
    mMarkAsFetchedOp->retain();
    mMarkAsFetchedOp->start();
}

void IMAPFetchNextSummarySyncStep::markAsFetchedDone()
{
    MC_SAFE_RELEASE(mMarkAsFetchedOp);
    MC_SAFE_RELEASE(mRequiredParts);
    
    mFetched = true;
    
    notifyDelegateDone();
    release();
}

bool IMAPFetchNextSummarySyncStep::fetched()
{
    return mFetched;
}

void IMAPFetchNextSummarySyncStep::operationFinished(Operation * op)
{
    if (op == mNextUidOp) {
        nextUidToFetchDone();
    }
    else if (op == mUidOp) {
        fetchUidInfoDone();
    }
    else if (op == mRenderOp) {
        tryRenderMessageDone();
    }
    else if (op == mFetchOp) {
        fetchNextBodyDone();
    }
    else if (op == mStoreOp) {
        storeNextBodyDone();
    }
    else if (op == mMarkAsFetchedOp) {
        markAsFetchedDone();
    }
    else if (op == mFetchFullOp) {
        fetchFullMessageDone();
    }
    else if (op == mStoreMessagePartsOp) {
        storeMessagePartsDone();
    }
}

void IMAPFetchNextSummarySyncStep::cancel()
{
    if (mNextUidOp != NULL) {
        mNextUidOp->cancel();
        MC_SAFE_RELEASE(mNextUidOp);
        release();
    }
    if (mRenderOp != NULL) {
        mRenderOp->cancel();
        MC_SAFE_RELEASE(mRenderOp);
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
    if (mMarkAsFetchedOp != NULL) {
        mMarkAsFetchedOp->cancel();
        MC_SAFE_RELEASE(mMarkAsFetchedOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}
