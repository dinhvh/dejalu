// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchMessageListSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBUidsOperation.h"
#include "HMActivityItem.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchMessageListSyncStep::IMAPFetchMessageListSyncStep()
{
    mFetchOp = NULL;
    mUids = NULL;
    mCachedUids = NULL;
    mCachedUidsOp = NULL;
    mMessagesCount = 0;
    mMaxFetchCount = 200;
    mActivity = new ActivityItem();
    mActivity->setProgressString(MCSTR("get message list"));
}

IMAPFetchMessageListSyncStep::~IMAPFetchMessageListSyncStep()
{
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mFetchOp);
    MC_SAFE_RELEASE(mCachedUids);
    MC_SAFE_RELEASE(mUids);
    MC_SAFE_RELEASE(mCachedUidsOp);
}

void IMAPFetchMessageListSyncStep::setMessagesCount(unsigned int messagesCount)
{
    mMessagesCount = messagesCount;
}

unsigned int IMAPFetchMessageListSyncStep::messagesCount()
{
    return mMessagesCount;
}

void IMAPFetchMessageListSyncStep::setMaxFetchCount(unsigned int maxFetchCount)
{
    mMaxFetchCount = maxFetchCount;
}

unsigned int IMAPFetchMessageListSyncStep::maxFetchCount()
{
    return mMaxFetchCount;
}

IndexSet * IMAPFetchMessageListSyncStep::uids()
{
    return mUids;
}

mailcore::IndexSet * IMAPFetchMessageListSyncStep::cachedUids()
{
    return mCachedUids;
}

void IMAPFetchMessageListSyncStep::start()
{
    fetchRemoteUids();
}

void IMAPFetchMessageListSyncStep::fetchRemoteUids()
{
    if (mMessagesCount == 0) {
        mUids = new IndexSet();
        fetchCachedUids();
        return;
    }

    IndexSet * numbers = NULL;
    if ((mMaxFetchCount != 0) && (mMessagesCount > mMaxFetchCount)) {
        numbers = IndexSet::indexSetWithRange(RangeMake(mMessagesCount - mMaxFetchCount + 1, mMaxFetchCount - 1));
    }
    else {
        numbers = IndexSet::indexSetWithRange(RangeMake(1, mMessagesCount - 1));
    }
    setNetwork(true);
    mActivity->registerActivity();
    retain();
    mFetchOp = session()->fetchMessagesByNumberOperation(folderPath(), IMAPMessagesRequestKindUid, numbers);
    mFetchOp->retain();
    mFetchOp->setCallback(this);
    mFetchOp->start();
}

void IMAPFetchMessageListSyncStep::fetchedRemoteUids()
{
    mActivity->unregisterActivity();
    setError((hermes::ErrorCode) mFetchOp->error());
    if (error() != ErrorNone) {
        MC_SAFE_RELEASE(mFetchOp);
        notifyDelegateDone();
        release();
        return;
    }
    
    mUids = new IndexSet();
    mc_foreacharray(IMAPMessage, msg, mFetchOp->messages()) {
        mUids->addIndex(msg->uid());
    }
    MC_SAFE_RELEASE(mFetchOp);
    
    fetchCachedUids();
    release();
}

void IMAPFetchMessageListSyncStep::fetchCachedUids()
{
    retain();
    mCachedUidsOp = storage()->uidsOperation(folderID());
    mCachedUidsOp->retain();
    mCachedUidsOp->setCallback(this);
    mCachedUidsOp->start();
}

void IMAPFetchMessageListSyncStep::fetchedCachedUids()
{
    mCachedUids = mCachedUidsOp->uids();
    mCachedUids->retain();
    MC_SAFE_RELEASE(mCachedUidsOp);
    
    notifyDelegateDone();
    release();
}

void IMAPFetchMessageListSyncStep::operationFinished(Operation * op)
{
    if (op == mFetchOp) {
        fetchedRemoteUids();
    }
    else {
        fetchedCachedUids();
    }
}

void IMAPFetchMessageListSyncStep::cancel()
{
    if (mFetchOp != NULL) {
        mActivity->unregisterActivity();
        mFetchOp->cancel();
        MC_SAFE_RELEASE(mFetchOp);
        release();
    }
    if (mCachedUidsOp != NULL) {
        mCachedUidsOp->cancel();
        MC_SAFE_RELEASE(mCachedUidsOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}
