// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFetchHeadersSyncStep.h"

#include "HMIMAPFolderSyncStepDelegate.h"
#include "HMMailStorage.h"
#include "HMMailDBAddMessagesOperation.h"
#include "HMActivityItem.h"
#include "HMMailDB.h"
#include "HMMailDBChanges.h"
#include "DJLLog.h"
#include "HMIMAPSyncTypesUtils.h"

using namespace hermes;
using namespace mailcore;

IMAPFetchHeadersSyncStep::IMAPFetchHeadersSyncStep()
{
    mFetchOp = NULL;
    mStorageOp = NULL;
    mUids = NULL;
    mRemainingUids = NULL;
    mFetchedUids = NULL;
    mMaxCount = 50;
    mRowsIDs = NULL;
    mHeadersProgressMax = 0;
    mHeadersProgressValue = 0;
    mActivity = new ActivityItem();
    mActivity->setProgressString(MCSTR("fetch headers"));
    mActivity->setHasProgress(true);
    mUnseen = false;
    mDraftsFolderID = -1;
}

IMAPFetchHeadersSyncStep::~IMAPFetchHeadersSyncStep()
{
    MC_SAFE_RELEASE(mActivity);
    MC_SAFE_RELEASE(mRowsIDs);
    MC_SAFE_RELEASE(mFetchedUids);
    MC_SAFE_RELEASE(mStorageOp);
    MC_SAFE_RELEASE(mFetchOp);
    MC_SAFE_RELEASE(mUids);
    MC_SAFE_RELEASE(mRemainingUids);
}

void IMAPFetchHeadersSyncStep::setUids(IndexSet * uids)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mUids, uids);
}

IndexSet * IMAPFetchHeadersSyncStep::uids()
{
    return mUids;
}

IndexSet * IMAPFetchHeadersSyncStep::remainingUids()
{
    return mRemainingUids;
}

IndexSet * IMAPFetchHeadersSyncStep::fetchedUids()
{
    return mFetchedUids;
}

IndexSet * IMAPFetchHeadersSyncStep::rowsIDs()
{
    return mRowsIDs;
}

void IMAPFetchHeadersSyncStep::setMaxCount(unsigned int maxCount)
{
    mMaxCount = maxCount;
}

unsigned int IMAPFetchHeadersSyncStep::maxCount()
{
    return mMaxCount;
}

void IMAPFetchHeadersSyncStep::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

int64_t IMAPFetchHeadersSyncStep::draftsFolderID()
{
    return mDraftsFolderID;
}

void IMAPFetchHeadersSyncStep::start()
{
    mActivity->registerActivity();
    mActivity->setProgressValue(mUids->count());
    
    IndexSet * uidsToFetch = new IndexSet();
    unsigned int remaining = mMaxCount;
    if (remaining == 0) {
        remaining = mUids->count();
    }
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
    mHeadersProgressMax = uidsToFetch->count();
    mHeadersProgressValue = 0;
    
    delegate()->folderSyncStateUpdated(this);
    
    mRemainingUids = (IndexSet *) mUids->copy();
    mRemainingUids->removeIndexSet(uidsToFetch);

    IMAPMessagesRequestKind kind = (IMAPMessagesRequestKind) 0;
    if (syncType() == IMAPSyncTypeGmail) {
        kind = (IMAPMessagesRequestKind) (IMAPMessagesRequestKindUid | IMAPMessagesRequestKindHeaders |
                                          IMAPMessagesRequestKindFlags | IMAPMessagesRequestKindGmailLabels | IMAPMessagesRequestKindHeaderSubject |
                                          IMAPMessagesRequestKindInternalDate | IMAPMessagesRequestKindStructure);
    }
    else if (hermes::supportsBodystructure(syncType())) {
        kind = (IMAPMessagesRequestKind) (IMAPMessagesRequestKindUid | IMAPMessagesRequestKindHeaders |
                                          IMAPMessagesRequestKindFlags |
                                          IMAPMessagesRequestKindInternalDate | IMAPMessagesRequestKindStructure);
    }
    else {
        kind = (IMAPMessagesRequestKind) (IMAPMessagesRequestKindUid | IMAPMessagesRequestKindFullHeaders |
                                          IMAPMessagesRequestKindFlags |
                                          IMAPMessagesRequestKindInternalDate);
    }
    //MCAssert((kind & IMAPMessagesRequestKindStructure) != 0);
    LOG_ERROR("fetch uid: %s", MCUTF8(uidsToFetch));
    LOG_ERROR("remaining uid: %s", MCUTF8(mRemainingUids));
    retain();
    setNetwork(true);
    mFetchOp = session()->fetchMessagesByUIDOperation(folderPath(), kind, uidsToFetch);
    Array * extraHeaders = new Array();
    extraHeaders->addObjectsFromArray(MailDB::headersToFetch());
    mFetchOp->setExtraHeaders(extraHeaders);
    MC_SAFE_RELEASE(extraHeaders);;
    mFetchOp->setCallback(this);
    mFetchOp->setImapCallback(this);
    mFetchOp->retain();
    mFetchOp->start();

    MC_SAFE_RELEASE(uidsToFetch);
}

void IMAPFetchHeadersSyncStep::fetched()
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
    mStorageOp = storage()->addMessagesOperation(folderID(), mFetchOp->messages(), mDraftsFolderID);
    mStorageOp->retain();
    mStorageOp->setCallback(this);
    mStorageOp->start();
    
    MC_SAFE_RELEASE(mFetchOp);
    release();
}

void IMAPFetchHeadersSyncStep::stored()
{
    if (mStorageOp->changes()->unseenFolders()->containsIndex(folderID())) {
        mUnseen = true;
    }

    MC_SAFE_REPLACE_RETAIN(IndexSet, mRowsIDs, mStorageOp->messagesRowsIDs());
    MC_SAFE_RELEASE(mStorageOp);
    
    notifyDelegateDone();
    release();
}

void IMAPFetchHeadersSyncStep::operationFinished(Operation * op)
{
    if (op == mFetchOp) {
        fetched();
    }
    else if (op == mStorageOp) {
        stored();
    }
}

void IMAPFetchHeadersSyncStep::itemProgress(IMAPOperation * session, unsigned int current, unsigned int maximum)
{
    mHeadersProgressValue = current;
    delegate()->folderSyncStateUpdated(this);
}

void IMAPFetchHeadersSyncStep::cancel()
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

unsigned int IMAPFetchHeadersSyncStep::headersProgressMax()
{
    return mHeadersProgressMax;
}

unsigned int IMAPFetchHeadersSyncStep::headersProgressValue()
{
    return mHeadersProgressValue;
}

bool IMAPFetchHeadersSyncStep::isUnseen()
{
    return mUnseen;
}
