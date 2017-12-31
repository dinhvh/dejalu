// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPUncacheOldMessagesSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBUidsOperation.h"

using namespace hermes;
using namespace mailcore;

IMAPUncacheOldMessagesSyncStep::IMAPUncacheOldMessagesSyncStep()
{
    mUncacheOp = NULL;
    mMessagesToUncache = NULL;
    mPurgeDraftsOp = NULL;
    mTrashFolderPath = NULL;
    mDraftsFolderPath = NULL;
}

IMAPUncacheOldMessagesSyncStep::~IMAPUncacheOldMessagesSyncStep()
{
    MC_SAFE_RELEASE(mUncacheOp);
    MC_SAFE_RELEASE(mMessagesToUncache);
    MC_SAFE_RELEASE(mPurgeDraftsOp);
    MC_SAFE_RELEASE(mTrashFolderPath);
    MC_SAFE_RELEASE(mDraftsFolderPath);
}

mailcore::IndexSet * IMAPUncacheOldMessagesSyncStep::messagesToUncache()
{
    return mMessagesToUncache;
}

void IMAPUncacheOldMessagesSyncStep::setMessagesToUncache(mailcore::IndexSet * uids)
{
    MC_SAFE_REPLACE_COPY(mailcore::IndexSet, mMessagesToUncache, uids);
}

mailcore::String * IMAPUncacheOldMessagesSyncStep::trashFolderPath()
{
    return mTrashFolderPath;
}

void IMAPUncacheOldMessagesSyncStep::setTrashFolderPath(mailcore::String * trashFolderPath)
{
    MC_SAFE_REPLACE_COPY(String, mTrashFolderPath, trashFolderPath);
}

mailcore::String * IMAPUncacheOldMessagesSyncStep::draftsFolderPath()
{
    return mDraftsFolderPath;
}

void IMAPUncacheOldMessagesSyncStep::setDraftsFolderPath(mailcore::String * draftsFolderPath)
{
    MC_SAFE_REPLACE_COPY(String, mDraftsFolderPath, draftsFolderPath);
}

void IMAPUncacheOldMessagesSyncStep::start()
{
    markFirstSyncDone();
}

void IMAPUncacheOldMessagesSyncStep::markFirstSyncDone()
{
    retain();
    mMarkFirstSyncDoneOp = storage()->markFirstSyncDoneOperation(storage()->folderIDForPath(folderPath()));
    mMarkFirstSyncDoneOp->retain();
    mMarkFirstSyncDoneOp->setCallback(this);
    mMarkFirstSyncDoneOp->start();
}

void IMAPUncacheOldMessagesSyncStep::markFirstSyncDoneFinished()
{
    MC_SAFE_RELEASE(mMarkFirstSyncDoneOp);

    uncacheUids();
    release();
}

void IMAPUncacheOldMessagesSyncStep::uncacheUids()
{
    retain();
    mUncacheOp = storage()->removeMessagesUidsOperation(storage()->folderIDForPath(folderPath()), mMessagesToUncache);
    mUncacheOp->retain();
    mUncacheOp->setCallback(this);
    mUncacheOp->start();
}

void IMAPUncacheOldMessagesSyncStep::uncacheUidsDone()
{
    MC_SAFE_RELEASE(mUncacheOp);

    purgeDrafts();
    release();
}

void IMAPUncacheOldMessagesSyncStep::purgeDrafts()
{
    if (mTrashFolderPath == NULL) {
        notifyDelegateDone();
        return;
    }

    retain();
    mPurgeDraftsOp = storage()->purgeSentDraftMessageOperation(storage()->folderIDForPath(folderPath()),
                                                               storage()->folderIDForPath(mTrashFolderPath),
                                                               storage()->folderIDForPath(mDraftsFolderPath));
    mPurgeDraftsOp->retain();
    mPurgeDraftsOp->setCallback(this);
    mPurgeDraftsOp->start();
}

void IMAPUncacheOldMessagesSyncStep::purgeDraftsDone()
{
    MC_SAFE_RELEASE(mPurgeDraftsOp);

    notifyDelegateDone();
    release();
}

void IMAPUncacheOldMessagesSyncStep::operationFinished(Operation * op)
{
    if (op == mUncacheOp) {
        uncacheUidsDone();
    }
    else if (op == mPurgeDraftsOp) {
        purgeDraftsDone();
    }
    else if (op == mMarkFirstSyncDoneOp) {
        markFirstSyncDoneFinished();
    }
}

void IMAPUncacheOldMessagesSyncStep::cancel()
{
    if (mMarkFirstSyncDoneOp != NULL) {
        mMarkFirstSyncDoneOp->cancel();
        MC_SAFE_RELEASE(mMarkFirstSyncDoneOp);
        release();
    }
    if (mUncacheOp != NULL) {
        mUncacheOp->cancel();
        MC_SAFE_RELEASE(mUncacheOp);
        release();
    }
    if (mPurgeDraftsOp != NULL) {
        mPurgeDraftsOp->cancel();
        MC_SAFE_RELEASE(mPurgeDraftsOp);
        release();
    }
    IMAPFolderSyncStep::cancel();
}
