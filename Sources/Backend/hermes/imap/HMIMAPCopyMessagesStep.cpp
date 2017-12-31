// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPCopyMessagesStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBUidsToCopyOperation.h"
#include "HMUtils.h"

using namespace hermes;
using namespace mailcore;

IMAPCopyMessagesStep::IMAPCopyMessagesStep()
{
    mDeleteOriginal = 0;
    mMessagesPerFolders = NULL;
    mFolders = NULL;
    mFolderIndex = 0;
    mUidsOp = NULL;
    mUidMapping = NULL;
    mCopyOp = NULL;
    mFlagOp = NULL;
    mUidSet = NULL;
    mRemoveCopyMessagesOp = NULL;
    mExpungeOp = NULL;
    mDraftsFolderID = -1;
}

IMAPCopyMessagesStep::~IMAPCopyMessagesStep()
{
    MC_SAFE_RELEASE(mExpungeOp);
    MC_SAFE_RELEASE(mRemoveCopyMessagesOp);
    MC_SAFE_RELEASE(mUidSet);
    MC_SAFE_RELEASE(mFlagOp);
    MC_SAFE_RELEASE(mCopyOp);
    MC_SAFE_RELEASE(mUidMapping);
    MC_SAFE_RELEASE(mUidsOp);
    MC_SAFE_RELEASE(mFolders);
    MC_SAFE_RELEASE(mMessagesPerFolders);
}

void IMAPCopyMessagesStep::setDeleteOriginal(int deleteOriginal)
{
    mDeleteOriginal = deleteOriginal;
}

int IMAPCopyMessagesStep::deleteOriginal()
{
    return mDeleteOriginal;
}

int64_t IMAPCopyMessagesStep::draftsFolderID()
{
    return mDraftsFolderID;
}

void IMAPCopyMessagesStep::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

void IMAPCopyMessagesStep::start()
{
    storage()->startCopyMessages(folderID());
    fetchUidsMessagesToCopy();
}

void IMAPCopyMessagesStep::cancel()
{
    storage()->cancelledCopyMessages(folderID());

    if (mUidsOp != NULL) {
        mUidsOp->cancel();
        MC_SAFE_RELEASE(mUidsOp);
    }
    if (mCopyOp != NULL) {
        mCopyOp->cancel();
        MC_SAFE_RELEASE(mCopyOp);
    }
    if (mFlagOp != NULL) {
        mFlagOp->cancel();
        MC_SAFE_RELEASE(mFlagOp);
    }
    if (mRemoveCopyMessagesOp != NULL) {
        mRemoveCopyMessagesOp->cancel();
        MC_SAFE_RELEASE(mRemoveCopyMessagesOp);
    }
    if (mExpungeOp != NULL) {
        mExpungeOp->cancel();
        MC_SAFE_RELEASE(mExpungeOp);
    }
}

void IMAPCopyMessagesStep::fetchUidsMessagesToCopy()
{
    retain();
    switch (mDeleteOriginal) {
        case 0:
            mUidsOp = storage()->messagesUidsToCopyOperation(folderID());
            break;
        case 1:
            mUidsOp = storage()->messagesUidsToMoveOperation(folderID());
            break;
        case 2:
             mUidsOp = storage()->messagesUidsToPurgeOperation(folderID());
            break;
    }
    mUidsOp->setCallback(this);
    mUidsOp->retain();
    mUidsOp->start();
}

void IMAPCopyMessagesStep::fetchUidsMessagesToCopyDone()
{
    mMessagesPerFolders = new HashMap();
    Array * messages = mUidsOp->messagesInfos();
    mc_foreacharray(HashMap, item, messages) {
        Value * vFolderID = (Value *) item->objectForKey(MCSTR("dest"));
        Array * array = (Array *) mMessagesPerFolders->objectForKey(vFolderID);
        if (array == NULL) {
            array = Array::array();
            mMessagesPerFolders->setObjectForKey(vFolderID, array);
        }
        array->addObject(item);
    }

    copyMessages();

    MC_SAFE_RELEASE(mUidsOp);
    release();
}

void IMAPCopyMessagesStep::copyMessages()
{
    mFolders = mMessagesPerFolders->allKeys();
    MC_SAFE_RETAIN(mFolders);
    mFolderIndex = 0;
    copyMessagesFromNextFolder();
}

void IMAPCopyMessagesStep::copyMessagesFromNextFolder()
{
    if (mFolderIndex >= mFolders->count()) {
        copyMessagesDone();
        return;
    }

    retain();

    Value * vFolderID = (Value *) mFolders->objectAtIndex(mFolderIndex);
    Array * messages = (Array *) mMessagesPerFolders->objectForKey(vFolderID);
    IndexSet * uidSet = IndexSet::indexSet();
    mc_foreacharray(HashMap, item, messages) {
        Value * vUid = (Value *) item->objectForKey(MCSTR("uid"));
        uint32_t uid = (uint32_t) vUid->longLongValue();
        uidSet->addIndex(uid);
    }
    MC_SAFE_REPLACE_RETAIN(IndexSet, mUidSet, uidSet);

    if ((mDeleteOriginal == 2) && (syncType() != IMAPSyncTypeGmail)) {
        markAsDeleted();
        release();
    }
    else {
        mCopyOp = session()->copyMessagesOperation(folderPath(), mUidSet, storage()->pathForFolderID(vFolderID->longLongValue()));
        mCopyOp->retain();
        mCopyOp->setCallback(this);
        mCopyOp->start();
    }
}

void IMAPCopyMessagesStep::copyMessagesFromNextFolderDone()
{
    setError((hermes::ErrorCode) mCopyOp->error());
    if (error() != ErrorNone) {
        if (error() == ErrorCopy) {
            MC_SAFE_RELEASE(mCopyOp);
            removeAction();
            release();
            return;
        }
        MC_SAFE_RELEASE(mCopyOp);

        notifyDelegateDone();
        release();
        return;
    }

    MC_SAFE_REPLACE_RETAIN(HashMap, mUidMapping, mCopyOp->uidMapping());
    MC_SAFE_RELEASE(mCopyOp);

    switch (mDeleteOriginal) {
        case 0:
            removeAction();
            break;
        case 1:
            markAsDeleted();
            break;
        case 2:
            markCopyAsDeleted();
            break;
    }

    release();
}

void IMAPCopyMessagesStep::markAsDeleted()
{
    // TODO: should be improved by storing flags in the DB instead of sending the IMAP command directly.
    retain();
    mFlagOp = session()->storeFlagsByUIDOperation(folderPath(), mUidSet, IMAPStoreFlagsRequestKindAdd, MessageFlagDeleted);
    mFlagOp->retain();
    mFlagOp->setCallback(this);
    mFlagOp->start();
}

void IMAPCopyMessagesStep::markAsDeletedDone()
{
    setError((hermes::ErrorCode) mFlagOp->error());
    if (error() != ErrorNone) {
        if (isConnectionError(error()) || isFatalError(error()) || isAuthenticationError(error())) {
            MC_SAFE_RELEASE(mFlagOp);

            notifyDelegateDone();
            release();
            return;
        }
        // ignore error.
        setError(ErrorNone);
    }

    MC_SAFE_RELEASE(mFlagOp);
    runExpunge(storage()->folderIDForPath(folderPath()));
    release();
}

void IMAPCopyMessagesStep::markCopyAsDeleted()
{
    if ((mUidMapping == NULL) || (mUidMapping->count() == 0)) {
        removeAction();
        return;
    }

    retain();
    IndexSet * uidSetCopy = IndexSet::indexSet();
    mc_foreacharray(Value, uidDest, mUidMapping->allValues()) {
        uidSetCopy->addIndex(uidDest->longLongValue());
    }
    Value * vFolderID = (Value *) mFolders->objectAtIndex(mFolderIndex);
    int64_t destFolderID = vFolderID->longLongValue();
    // TODO: should be improved by storing flags in the DB instead of sending the IMAP command directly.
    mFlagOp = session()->storeFlagsByUIDOperation(storage()->pathForFolderID(destFolderID), uidSetCopy, IMAPStoreFlagsRequestKindAdd, MessageFlagDeleted);
    mFlagOp->retain();
    mFlagOp->setCallback(this);
    mFlagOp->start();
}

void IMAPCopyMessagesStep::markCopyAsDeletedDone()
{
    setError((hermes::ErrorCode) mFlagOp->error());
    if (error() != ErrorNone) {
        if (isConnectionError(error()) || isFatalError(error()) || isAuthenticationError(error())) {
            MC_SAFE_RELEASE(mFlagOp);

            notifyDelegateDone();
            release();
            return;
        }
        // ignore error.
        setError(ErrorNone);
    }

    MC_SAFE_RELEASE(mFlagOp);

    Value * vFolderID = (Value *) mFolders->objectAtIndex(mFolderIndex);
    int64_t destFolderID = vFolderID->longLongValue();

    runExpunge(destFolderID);
    release();
}

void IMAPCopyMessagesStep::runExpunge(int64_t expungeFolderID)
{
    retain();
    mExpungeOp = session()->expungeOperation(storage()->pathForFolderID(expungeFolderID));
    mExpungeOp->retain();
    mExpungeOp->setCallback(this);
    mExpungeOp->start();
}

void IMAPCopyMessagesStep::runExpungeDone()
{
    setError((hermes::ErrorCode) mExpungeOp->error());
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
    removeAction();
    release();
}

void IMAPCopyMessagesStep::removeAction()
{
    Value * vFolderID = (Value *) mFolders->objectAtIndex(mFolderIndex);
    Array * messages = (Array *) mMessagesPerFolders->objectForKey(vFolderID);
    IndexSet * rowidSet = IndexSet::indexSet();
    IndexSet * messagesRowIDsSet = IndexSet::indexSet();
    mc_foreacharray(HashMap, item, messages) {
        Value * vUid = (Value *) item->objectForKey(MCSTR("rowid"));
        int64_t rowid = vUid->longLongValue();
        Value * vMessageRowID = (Value *) item->objectForKey(MCSTR("messagerowid"));
        int64_t messageRowID = vMessageRowID->longLongValue();
        rowidSet->addIndex(rowid);
        messagesRowIDsSet->addIndex(messageRowID);
    }

    retain();
    bool clearMoving = false;
    if ((error() == ErrorCopy) && (mDeleteOriginal != 0)) {
        clearMoving = true;
    }
    mRemoveCopyMessagesOp = storage()->removeCopyMessagesOperation(rowidSet, messagesRowIDsSet, clearMoving, mDraftsFolderID);
    mRemoveCopyMessagesOp->setCallback(this);
    mRemoveCopyMessagesOp->retain();
    mRemoveCopyMessagesOp->start();
}

void IMAPCopyMessagesStep::removeActionDone()
{
    MC_SAFE_RELEASE(mRemoveCopyMessagesOp);

    if (error() != ErrorNone) {
        // in case of copy error.
        notifyDelegateDone();
        release();
        return;
    }

    nextFolder();
    release();
}

void IMAPCopyMessagesStep::nextFolder()
{
    MC_SAFE_RELEASE(mUidSet);
    mFolderIndex ++;
    copyMessagesFromNextFolder();
}

void IMAPCopyMessagesStep::copyMessagesDone()
{
    MC_SAFE_RELEASE(mMessagesPerFolders);
    MC_SAFE_RELEASE(mFolders);

    notifyDelegateDone();
}

void IMAPCopyMessagesStep::operationFinished(mailcore::Operation * op)
{
    if (op == mUidsOp) {
        fetchUidsMessagesToCopyDone();
    }
    else if (op == mCopyOp) {
        copyMessagesFromNextFolderDone();
    }
    else if (op == mFlagOp) {
        MCAssert(mDeleteOriginal != 0);
        if (mDeleteOriginal == 1) {
            markAsDeletedDone();
        }
        else if (mDeleteOriginal == 2) {
            markCopyAsDeletedDone();
        }
    }
    else if (op == mRemoveCopyMessagesOp) {
        removeActionDone();
    }
    else if (op == mExpungeOp) {
        runExpungeDone();
    }
}

void IMAPCopyMessagesStep::notifyDelegateDone()
{
    storage()->finishedCopyMessages(folderID());
    IMAPFolderSyncStep::notifyDelegateDone();
}
