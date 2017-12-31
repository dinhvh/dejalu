// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchFlagsSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBAddMessagesOperation.h"
#include "HMActivityItem.h"
#include "HMMailDBCheckFolderSeenOperation.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchFlagsSyncStep::IMAPFetchFlagsSyncStep()
{
    mFetchOp = NULL;
    mStorageOp = NULL;
    mUids = NULL;
    mRemainingUids = NULL;
    mFetchedUids = NULL;
    mMaxCount = 50;
    mActivity = new ActivityItem();
    mActivity->setProgressString(MCSTR("fetch flags"));
    mActivity->setHasProgress(true);
    mCheckFolderSeenOp = NULL;
    mSeen = false;
    mDraftsFolderID = -1;
}

IMAPFetchFlagsSyncStep::~IMAPFetchFlagsSyncStep()
{
    MC_SAFE_RELEASE(mCheckFolderSeenOp);
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mFetchedUids);
    MC_SAFE_RELEASE(mFetchOp);
    MC_SAFE_RELEASE(mUids);
    MC_SAFE_RELEASE(mRemainingUids);
    MC_SAFE_RELEASE(mFetchedUids);
}

void IMAPFetchFlagsSyncStep::setUids(IndexSet * uids)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mUids, uids);
}

IndexSet * IMAPFetchFlagsSyncStep::uids()
{
    return mUids;
}

IndexSet * IMAPFetchFlagsSyncStep::remainingUids()
{
    return mRemainingUids;
}

IndexSet * IMAPFetchFlagsSyncStep::fetchedUids()
{
    return mFetchedUids;
}

bool IMAPFetchFlagsSyncStep::isSeen()
{
    return mSeen;
}

void IMAPFetchFlagsSyncStep::setMaxCount(unsigned int maxCount)
{
    mMaxCount = maxCount;
}

unsigned int IMAPFetchFlagsSyncStep::maxCount()
{
    return mMaxCount;
}

int64_t IMAPFetchFlagsSyncStep::draftsFolderID()
{
    return mDraftsFolderID;
}

void IMAPFetchFlagsSyncStep::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

void IMAPFetchFlagsSyncStep::start()
{
    IndexSet * uidsToFetch = new IndexSet();
    unsigned int remaining = mMaxCount;
    for(int i = (int) mUids->rangesCount() - 1 ; i >= 0 ; i --) {
        Range range = mUids->allRanges()[i];
        if (range.length + 1 <= remaining) {
            uidsToFetch->addRange(range);
            remaining -= range.length + 1;
        }
        else {
            uidsToFetch->addRange(RangeMake(range.location + range.length - (mMaxCount - 1), remaining - 1));
            remaining = 0;
        }
        if (remaining == 0)
            break;
    }
    mRemainingUids = (IndexSet *) mUids->copy();
    mRemainingUids->removeIndexSet(uidsToFetch);
    
    mActivity->registerActivity();
    mActivity->setProgressValue(mUids->count());
    IMAPMessagesRequestKind kind;
    if (syncType() == IMAPSyncTypeGmail) {
        kind = (IMAPMessagesRequestKind) (IMAPMessagesRequestKindUid | IMAPMessagesRequestKindFlags | IMAPMessagesRequestKindGmailLabels);
    }
    else {
        kind = (IMAPMessagesRequestKind) (IMAPMessagesRequestKindUid | IMAPMessagesRequestKindFlags);
    }
    setNetwork(true);
    retain();
    mFetchOp = session()->fetchMessagesByUIDOperation(folderPath(), kind, uidsToFetch);
    mFetchOp->setCallback(this);
    mFetchOp->retain();
    mFetchOp->start();

    MC_SAFE_RELEASE(uidsToFetch);
}

void IMAPFetchFlagsSyncStep::fetched()
{
    mActivity->unregisterActivity();
    setError((hermes::ErrorCode) mFetchOp->error());
    if (error() != ErrorNone) {
        MC_SAFE_RELEASE(mFetchOp);
        notifyDelegateDone();
        release();
        return;
    }
    
    mFetchedUids = new IndexSet();
    mc_foreacharray(IMAPMessage, msg, mFetchOp->messages()) {
        mFetchedUids->addIndex(msg->uid());
    }
    
    retain();
    mStorageOp = storage()->changeMessagesOperation(folderID(), mFetchOp->messages(), mDraftsFolderID);
    mStorageOp->retain();
    mStorageOp->setCallback(this);
    mStorageOp->start();
    
    MC_SAFE_RELEASE(mFetchOp);
    release();
}

void IMAPFetchFlagsSyncStep::stored()
{
    MC_SAFE_RELEASE(mStorageOp);
    
    if (mRemainingUids->count() == 0) {
        checkFolderSeen();
        release();
        return;
    }

    notifyDelegateDone();
    release();
}

void IMAPFetchFlagsSyncStep::checkFolderSeen()
{
    retain();
    mCheckFolderSeenOp = storage()->checkFolderSeenOperation(folderID());
    mCheckFolderSeenOp->retain();
    mCheckFolderSeenOp->setCallback(this);
    mCheckFolderSeenOp->start();
}

void IMAPFetchFlagsSyncStep::checkFolderSeenDone()
{
    if (mCheckFolderSeenOp->isFolderSeen()) {
        mSeen = true;
    }

    MC_SAFE_RELEASE(mCheckFolderSeenOp);

    notifyDelegateDone();
    release();
}

void IMAPFetchFlagsSyncStep::operationFinished(Operation * op)
{
    if (op == mFetchOp) {
        fetched();
    }
    else if (op == mStorageOp) {
        stored();
    }
    else if (op == mCheckFolderSeenOp) {
        checkFolderSeenDone();
    }
}

void IMAPFetchFlagsSyncStep::cancel()
{
    if (mFetchOp != NULL) {
        mActivity->unregisterActivity();
        mFetchOp->cancel();
        MC_SAFE_RELEASE(mFetchOp);
        release();
    }
    if (mStorageOp != NULL) {
        mStorageOp->cancel();
        MC_SAFE_RELEASE(mStorageOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}
