// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPPushFlagsStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBMessagesLocalChangesOperation.h"
#include "HMMailDBLocalMessagesChanges.h"
#include "DJLLog.h"
#include "HMActivityItem.h"
#include "HMUtils.h"

using namespace hermes;
using namespace mailcore;

#define LOG(...) DJLLogWithID("flags", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("flags", __VA_ARGS__)

enum {
    STATE_ADD_FLAGGED,
    STATE_REMOVE_FLAGGED,
    STATE_ADD_SEEN,
    STATE_REMOVE_SEEN,
    STATE_ADD_DELETED,
    STATE_REMOVE_DELETED,
    STATE_ADD_LABELS,
    STATE_REMOVE_LABELS,
    STATE_COUNT,
};

IMAPPushFlagsStep::IMAPPushFlagsStep()
{
    mLocalChangesOp = NULL;
    mStoreOp = NULL;
    mRemoveLocalChangesOp = NULL;
    mChanges = NULL;
    mState = -1;
    mActivity = new ActivityItem();
    mActivity->setProgressString(MCSTR("pushing flags"));
    mCurrentLabelsAddedIndex = 0;
    mCurrentLabelsRemovedIndex = 0;
    mAddedKeys = NULL;
    mRemovedKeys = NULL;
    mStoreLabelsOp = NULL;
    mNeedsExpunge = false;
    mExpungeOp = NULL;
}

IMAPPushFlagsStep::~IMAPPushFlagsStep()
{
    MC_SAFE_RELEASE(mExpungeOp);
    MC_SAFE_RELEASE(mAddedKeys);
    MC_SAFE_RELEASE(mRemovedKeys);
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mLocalChangesOp);
    MC_SAFE_RELEASE(mStoreOp);
    MC_SAFE_RELEASE(mStoreLabelsOp);
    MC_SAFE_RELEASE(mRemoveLocalChangesOp);
    MC_SAFE_RELEASE(mChanges);
}

void IMAPPushFlagsStep::start()
{
    storage()->startPushFlagsToServer(folderID());
    retain();
    mLocalChangesOp = storage()->messagesLocalChangesOperation(folderID());
    mLocalChangesOp->retain();
    mLocalChangesOp->setCallback(this);
    mLocalChangesOp->start();
}

void IMAPPushFlagsStep::localChangesFetched()
{
    MC_SAFE_REPLACE_RETAIN(MailDBLocalMessagesChanges, mChanges, mLocalChangesOp->localChanges());
    MC_SAFE_RELEASE(mLocalChangesOp);

    MC_SAFE_REPLACE_RETAIN(Array, mAddedKeys, mChanges->labelsAdditions()->allKeys());
    MC_SAFE_REPLACE_RETAIN(Array, mRemovedKeys, mChanges->labelsRemoval()->allKeys());

    startPushFlags();
    
    release();
}

void IMAPPushFlagsStep::startPushFlags()
{
    mState = STATE_ADD_FLAGGED;
    pushFlags();
}

void IMAPPushFlagsStep::pushLabels()
{
    bool nextState = false;
    switch (mState) {
        case STATE_ADD_LABELS:
            if (mCurrentLabelsAddedIndex >= mAddedKeys->count()) {
                nextState = true;
            }
            break;
        case STATE_REMOVE_LABELS:
            if (mCurrentLabelsRemovedIndex >= mRemovedKeys->count()) {
                nextState = true;
            }
            break;
    }

    if (nextState) {
        mState ++;
        if (mState == STATE_COUNT) {
            expunge();
        }
        else {
            pushFlags();
        }
        return;
    }

    IndexSet * uids = NULL;
    IMAPStoreFlagsRequestKind kind = IMAPStoreFlagsRequestKindAdd;

    String * label = NULL;

    switch (mState) {
        case STATE_ADD_LABELS:
            label = (String *) mAddedKeys->objectAtIndex(mCurrentLabelsAddedIndex);
            uids = (IndexSet *) mChanges->labelsAdditions()->objectForKey(label);
            kind = IMAPStoreFlagsRequestKindAdd;

            break;
        case STATE_REMOVE_LABELS:
            label = (String *) mRemovedKeys->objectAtIndex(mCurrentLabelsRemovedIndex);
            uids = (IndexSet *) mChanges->labelsRemoval()->objectForKey(label);
            kind = IMAPStoreFlagsRequestKindRemove;

            break;
        default:
            MCAssert(0);
            break;
    }

    retain();

    if (uids->count() == 0) {
        pushLabelsDone();
        return;
    }

    mActivity->registerActivity();
    LOG("store labels %i %s %s", kind, label->UTF8Characters(), MCUTF8DESC(uids));
    setNetwork(true);
    mStoreLabelsOp = session()->storeLabelsByUIDOperation(folderPath(), uids, kind, Array::arrayWithObject(label));
    mStoreLabelsOp->retain();
    mStoreLabelsOp->setCallback(this);
    mStoreLabelsOp->start();
}

void IMAPPushFlagsStep::pushLabelsDone()
{
    mActivity->unregisterActivity();
    if (mStoreLabelsOp != NULL) {
        setError((hermes::ErrorCode) mStoreLabelsOp->error());
    }
    if (error() != ErrorNone) {
        if (isConnectionError(error()) || isFatalError(error()) || isAuthenticationError(error())) {
            MC_SAFE_RELEASE(mStoreLabelsOp);
            notifyDelegateDone();
            release();
            return;
        }
        // ignore error.
        setError(ErrorNone);
    }
    MC_SAFE_RELEASE(mStoreLabelsOp);

    switch (mState) {
        case STATE_ADD_LABELS:
            mCurrentLabelsAddedIndex ++;
            break;
        case STATE_REMOVE_LABELS:
            mCurrentLabelsRemovedIndex ++;
            break;
    }

    pushFlags();

    release();
}

void IMAPPushFlagsStep::pushFlags()
{
    if ((mState == STATE_ADD_LABELS) || (mState == STATE_REMOVE_LABELS)) {
        pushLabels();
        return;
    }

    IndexSet * uids = NULL;
    IMAPStoreFlagsRequestKind kind = IMAPStoreFlagsRequestKindAdd;
    MessageFlag flag = (MessageFlag) 0;

    switch (mState) {
        case STATE_ADD_DELETED:
            uids = mChanges->messagesWithAddedDeletedFlag();
            flag = MessageFlagDeleted;
            if (uids->count() > 0) {
                mNeedsExpunge = true;
            }
            break;
        case STATE_REMOVE_DELETED:
            uids = mChanges->messagesWithRemovedDeletedFlag();
            kind = IMAPStoreFlagsRequestKindRemove;
            flag = MessageFlagDeleted;
            break;
        case STATE_ADD_FLAGGED:
            uids = mChanges->messagesWithAddedFlaggedFlag();
            flag = MessageFlagFlagged;
            break;
        case STATE_REMOVE_FLAGGED:
            uids = mChanges->messagesWithRemovedFlaggedFlag();
            kind = IMAPStoreFlagsRequestKindRemove;
            flag = MessageFlagFlagged;
            break;
        case STATE_ADD_SEEN:
            uids = mChanges->messagesWithAddedSeenFlag();
            flag = MessageFlagSeen;
            break;
        case STATE_REMOVE_SEEN:
            uids = mChanges->messagesWithRemovedSeenFlag();
            kind = IMAPStoreFlagsRequestKindRemove;
            flag = MessageFlagSeen;
            break;
        default:
            MCAssert(0);
            break;
    }
    
    retain();
    
    if (uids->count() == 0) {
        pushFlagsDone();
        return;
    }
    
    mActivity->registerActivity();
    LOG("store flags %s %i %i %s", MCUTF8(folderPath()), kind, flag, MCUTF8DESC(uids));
    //fprintf(stderr, "store flags %s %i %i %s\n", MCUTF8(folderPath()), kind, flag, MCUTF8DESC(uids));
    setNetwork(true);
    mStoreOp = session()->storeFlagsByUIDOperation(folderPath(), uids, kind, flag);
    mStoreOp->retain();
    mStoreOp->setCallback(this);
    mStoreOp->start();
}

void IMAPPushFlagsStep::pushFlagsDone()
{
    mActivity->unregisterActivity();
    if (mStoreOp != NULL) {
        setError((hermes::ErrorCode) mStoreOp->error());
    }
    if (error() != ErrorNone) {
        if (isConnectionError(error()) || isFatalError(error()) || isAuthenticationError(error())) {
            MC_SAFE_RELEASE(mStoreOp);
            notifyDelegateDone();
            release();
            return;
        }
        // ignore error.
        setError(ErrorNone);
    }
    MC_SAFE_RELEASE(mStoreOp);
    
    mState ++;
    pushFlags();

    release();
}

void IMAPPushFlagsStep::expunge()
{
    if (!mNeedsExpunge) {
        removeLocalChanges();
        return;
    }

    retain();
    mActivity->registerActivity();
    setNetwork(true);
    mExpungeOp = session()->expungeOperation(folderPath());
    mExpungeOp->retain();
    mExpungeOp->setCallback(this);
    mExpungeOp->start();
}

void IMAPPushFlagsStep::expungeDone()
{
    mActivity->unregisterActivity();

    if (mExpungeOp != NULL) {
        setError((hermes::ErrorCode) mExpungeOp->error());
    }
    if (error() != ErrorNone) {
        if (isConnectionError(error()) || isFatalError(error()) || isAuthenticationError(error())) {
            MC_SAFE_RELEASE(mExpungeOp);
            notifyDelegateDone();
            release();
            return;
        }
        // ignore error.
        setError(ErrorNone);
    }
    MC_SAFE_RELEASE(mExpungeOp);

    removeLocalChanges();
    release();
}

void IMAPPushFlagsStep::removeLocalChanges()
{
    retain();

    mRemoveLocalChangesOp = storage()->removeMessagesLocalChangesOperation(mChanges->rowIDs());
    mRemoveLocalChangesOp->retain();
    mRemoveLocalChangesOp->setCallback(this);
    mRemoveLocalChangesOp->start();
}

void IMAPPushFlagsStep::removeLocalChangesDone()
{
    MC_SAFE_RELEASE(mRemoveLocalChangesOp);
    
    notifyDelegateDone();
    release();
}

void IMAPPushFlagsStep::cancel()
{
    storage()->cancelledPushFlagsToServer(folderID());

    if (mLocalChangesOp != NULL) {
        mLocalChangesOp->cancel();
        MC_SAFE_RELEASE(mLocalChangesOp);
        release();
    }
    if (mStoreOp != NULL) {
        mActivity->unregisterActivity();
        mStoreOp->cancel();
        MC_SAFE_RELEASE(mStoreOp);
        release();
    }
    if (mStoreLabelsOp != NULL) {
        mActivity->unregisterActivity();
        mStoreLabelsOp->cancel();
        MC_SAFE_RELEASE(mStoreLabelsOp);
        release();
    }
    if (mRemoveLocalChangesOp != NULL) {
        mRemoveLocalChangesOp->cancel();
        MC_SAFE_RELEASE(mRemoveLocalChangesOp);
        release();
    }
    if (mExpungeOp != NULL) {
        mActivity->unregisterActivity();
        mExpungeOp->cancel();
        MC_SAFE_RELEASE(mExpungeOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}

void IMAPPushFlagsStep::operationFinished(mailcore::Operation * op)
{
    if (op == mLocalChangesOp) {
        localChangesFetched();
    }
    else if (op == mStoreOp) {
        pushFlagsDone();
    }
    else if (op == mRemoveLocalChangesOp) {
        removeLocalChangesDone();
    }
    else if (op == mStoreLabelsOp) {
        pushLabelsDone();
    }
    else if (op == mExpungeOp) {
        expungeDone();
    }
}

void IMAPPushFlagsStep::notifyDelegateDone()
{
    storage()->finishedPushFlagsToServer(folderID());
    IMAPFolderSyncStep::notifyDelegateDone();
}
