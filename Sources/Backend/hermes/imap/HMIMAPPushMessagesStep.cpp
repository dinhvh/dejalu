// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPPushMessagesStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBNextMessageToPushOperation.h"
#include "HMActivityItem.h"

#include "DJLLog.h"

using namespace hermes;
using namespace mailcore;

IMAPPushMessagesStep::IMAPPushMessagesStep()
{
    mMessageToPushOp = NULL;
    mAppendOp = NULL;
    mSetPushedOp = NULL;
    mDone = false;
    mMessageRowID = -1;
    mFilename = NULL;
    mDraftBehaviorEnabled = false;
    mDraftsMessagesRowIDsToDelete = NULL;
    mActivity = new ActivityItem();
    mActivity->setProgressString(MCSTR("pushing flags"));
    mTrashFolderPath = NULL;
    mDraftsFolderPath = NULL;
    mPurgeOp = NULL;
}

IMAPPushMessagesStep::~IMAPPushMessagesStep()
{
    MC_SAFE_RELEASE(mPurgeOp);
    MC_SAFE_RELEASE(mDraftsFolderPath);
    MC_SAFE_RELEASE(mTrashFolderPath);
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mDraftsMessagesRowIDsToDelete);
    MC_SAFE_RELEASE(mMessageToPushOp);
    MC_SAFE_RELEASE(mAppendOp);
    MC_SAFE_RELEASE(mSetPushedOp);
    MC_SAFE_RELEASE(mFilename);
}

void IMAPPushMessagesStep::setDraftBehaviorEnabled(bool enabled)
{
    mDraftBehaviorEnabled = enabled;
}

bool IMAPPushMessagesStep::isDraftBehaviorEnabled()
{
    return mDraftBehaviorEnabled;
}

void IMAPPushMessagesStep::setTrashFolderPath(mailcore::String * trashFolderPath)
{
    MC_SAFE_REPLACE_COPY(String, mTrashFolderPath, trashFolderPath);
}

mailcore::String * IMAPPushMessagesStep::trashFolderPath()
{
    return mTrashFolderPath;
}

void IMAPPushMessagesStep::setDraftsFolderPath(mailcore::String * draftsFolderPath)
{
    MC_SAFE_REPLACE_COPY(String, mDraftsFolderPath, draftsFolderPath);
}

mailcore::String * IMAPPushMessagesStep::draftsFolderPath()
{
    return mDraftsFolderPath;
}

int64_t IMAPPushMessagesStep::messageRowID()
{
    return mMessageRowID;
}

void IMAPPushMessagesStep::start()
{
    storage()->startPushMessagesToServer(folderID());
    fetchMessageToPush();
}

void IMAPPushMessagesStep::cancel()
{
    storage()->cancelledPushMessagesToServer(folderID());

    if (mMessageToPushOp != NULL) {
        mMessageToPushOp->cancel();
        MC_SAFE_RELEASE(mMessageToPushOp);
    }
    if (mAppendOp != NULL) {
        mAppendOp->cancel();
        MC_SAFE_RELEASE(mAppendOp);
    }
    if (mSetPushedOp != NULL) {
        mSetPushedOp->cancel();
        MC_SAFE_RELEASE(mSetPushedOp);
    }
    if (mPurgeOp != NULL) {
        mPurgeOp->cancel();
        MC_SAFE_RELEASE(mPurgeOp);
    }
    IMAPFolderSyncStep::cancel();
}

bool IMAPPushMessagesStep::isDone()
{
    return mDone;
}

void IMAPPushMessagesStep::operationFinished(mailcore::Operation * op)
{
    if (op == mMessageToPushOp) {
        fetchMessageToPushDone();
    }
    else if (op == mAppendOp) {
        pushMessageDone();
    }
    else if (op == mSetPushedOp) {
        markMessageAsPushedDone();
    }
    else if (op == mPurgeOp) {
        deleteDraftMessagesDone();
    }
}

void IMAPPushMessagesStep::fetchMessageToPush()
{
    retain();
    mMessageToPushOp = storage()->nextMessageToPush(folderID(), mDraftBehaviorEnabled);
    mMessageToPushOp->retain();
    mMessageToPushOp->setCallback(this);
    mMessageToPushOp->start();
}

void IMAPPushMessagesStep::fetchMessageToPushDone()
{
    mFilename = mMessageToPushOp->filename();
    MC_SAFE_RETAIN(mFilename);
    mMessageRowID = mMessageToPushOp->messageRowID();
    mDraftsMessagesRowIDsToDelete = mMessageToPushOp->draftsMessagesRowIDsToDelete();
    MC_SAFE_RETAIN(mDraftsMessagesRowIDsToDelete);
    MC_SAFE_RELEASE(mMessageToPushOp);

    if (mFilename == NULL) {
        mDone = true;
        notifyDelegateDone();
        release();
        return;
    }

    pushMessage();
    release();
}

void IMAPPushMessagesStep::pushMessage()
{
    Data * data = Data::dataWithContentsOfFile(mFilename);
    if (data == NULL) {
        LOG_ERROR("There was no file for %lli", mMessageRowID);
        markMessageAsPushed();
        return;
    }

    mActivity->registerActivity();

    retain();
    //fprintf(stderr, "filename %s\n", MCUTF8(mFilename));
    setNetwork(true);
    mAppendOp = session()->appendMessageOperation(folderPath(), data, MessageFlagSeen);
    mAppendOp->setCallback(this);
    mAppendOp->retain();
    mAppendOp->start();
}

void IMAPPushMessagesStep::pushMessageDone()
{
    mActivity->unregisterActivity();
    if (mAppendOp != NULL) {
        setError((hermes::ErrorCode) mAppendOp->error());
    }
    if (error() != ErrorNone) {
        if (error() == ErrorAppend) {
            MC_SAFE_RELEASE(mAppendOp);
            MC_SAFE_RELEASE(mDraftsMessagesRowIDsToDelete);
            markMessageAsPushed();
            release();
            return;
        }
        MC_SAFE_RELEASE(mAppendOp);
        notifyDelegateDone();
        release();
        return;
    }

    MC_SAFE_RELEASE(mAppendOp);

    markMessageAsPushed();
    release();
}

void IMAPPushMessagesStep::markMessageAsPushed()
{
    retain();
    mSetPushedOp = storage()->setLocalMessagePushedOperation(mMessageRowID);
    mSetPushedOp->retain();
    mSetPushedOp->setCallback(this);
    mSetPushedOp->start();
}

void IMAPPushMessagesStep::markMessageAsPushedDone()
{
    MC_SAFE_RELEASE(mSetPushedOp);

    if (mDraftsMessagesRowIDsToDelete == NULL) {
        // When push failed, it will finish here.
        notifyDelegateDone();
        release();
        return;
    }

    deleteDraftMessages();
    release();
}

void IMAPPushMessagesStep::deleteDraftMessages()
{
    if (!isDraftBehaviorEnabled() || (mDraftsMessagesRowIDsToDelete == NULL) || (mDraftsMessagesRowIDsToDelete->count() == 0) || (trashFolderPath() == NULL)) {
        notifyDelegateDone();
        return;
    }

    retain();

    Array * oldMessageRowsIDs = Array::array();
    mc_foreachindexset(messageRowID, mDraftsMessagesRowIDsToDelete) {
        oldMessageRowsIDs->addObject(Value::valueWithLongLongValue(messageRowID));
    }

    mPurgeOp = storage()->purgeMessagesOperation(oldMessageRowsIDs, storage()->folderIDForPath(trashFolderPath()),
                                                 storage()->folderIDForPath(draftsFolderPath()));
    mPurgeOp->retain();
    mPurgeOp->setCallback(this);
    mPurgeOp->start();
}

void IMAPPushMessagesStep::deleteDraftMessagesDone()
{
    MC_SAFE_RELEASE(mPurgeOp);
    notifyDelegateDone();
    release();
}

void IMAPPushMessagesStep::notifyDelegateDone()
{
    storage()->finishedPushMessagesToServer(folderID());
    IMAPFolderSyncStep::notifyDelegateDone();

}
