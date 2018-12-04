// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPFolderSynchronizer.h"

#include "HMIMAPFolderSynchronizerDelegate.h"
#include "HMIMAPFetchFolderStateSyncStep.h"
#include "HMMailStorage.h"
#include "HMIMAPFetchMessageListSyncStep.h"
#include "HMIMAPFetchHeadersSyncStep.h"
#include "HMIMAPFetchFlagsSyncStep.h"
#include "HMIMAPFetchNextSummarySyncStep.h"
#include "HMIMAPFetchNextAttachmentSyncStep.h"
#include "HMIMAPUncacheOldMessagesSyncStep.h"
#include "HMIMAPRemoveExpiredLocalMessageSyncStep.h"
#include "HMIMAPPushFlagsStep.h"
#include "HMIMAPPushMessagesStep.h"
#include "HMIMAPCopyMessagesStep.h"
#include "HMIMAPFetchNextSourceSyncStep.h"
#include "HMMailDBFolderUnseenOperation.h"
#include "DJLLog.h"
#include "HMActivityItem.h"
#include "HMUtils.h"

using namespace hermes;
using namespace mailcore;

#define DEFAULT_MESSAGES_TO_FETCH 2000
#define DEFAULT_REFRESH_DELAY (10 * 60)

#define LOG(...) DJLLogWithID("sync", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("sync", __VA_ARGS__)
#define LOG_IDLE(...) DJLLogWithID("idle", __VA_ARGS__)
#define LOG_SEARCH(...) DJLLogWithID("search", __VA_ARGS__)
#define LOG_CLEANUP(...)

enum IMAPFolderSynchronizerState {
    IMAPFolderSynchronizerStateNeedMessageCount,
    IMAPFolderSynchronizerStateNeedSyncList,
    IMAPFolderSynchronizerStateNeedSyncHeaders,
    IMAPFolderSynchronizerStateNeedUncacheOldMessages,
    IMAPFolderSynchronizerStateNeedPushMessages,
    IMAPFolderSynchronizerStateNeedSyncFlags,
    IMAPFolderSynchronizerStateNeedSyncContent,
    IMAPFolderSynchronizerStateNeedRemoveExpiredLocalMessages,
    IMAPFolderSynchronizerStateNeedIdle,
    IMAPFolderSynchronizerStateDone,
};

enum IMAPFolderSearchState {
    IMAPFolderSearchStateNone,
    IMAPFolderSearchStateNeedUids,
    IMAPFolderSearchStateNeedFetchHeaders,
    IMAPFolderSearchStateNeedFetchContent,
    IMAPFolderSearchStateDone,
};

IMAPFolderSynchronizer::IMAPFolderSynchronizer()
{
    mFolderPath = NULL;
    mDelegate = NULL;
    mSession = NULL;
    mState = IMAPFolderSynchronizerStateNeedMessageCount;
    mMessagesToFetch = DEFAULT_MESSAGES_TO_FETCH;
    mStorage = NULL;
    mMessageCount = 0;
    mUidNext = 0;
    mUids = NULL;
    mCachedUids = NULL;
    mUidsToFetch = NULL;
    mMaxUid = 0;
    mIdleInterrupted = false;
    mDisableIdleCount = 0;
    mSummaryToFetchMessageRowIDs = new Array();
    mSummaryToFetchMessageRowIDsUrgent = new Array();
    mFetchSummaryUrgent = false;
    mPartToFetchHashMap = new Array();
    mPartToFetchHashMapUrgent = new Array();
    mSourceToFetch = new Array();
    mFetchPartUrgent = false;

    mFetchFolderStateSyncStep = NULL;
    mFetchMessageListSyncStep = NULL;
    mFetchHeaderSyncStep = NULL;
    mFetchFlagsSyncStep = NULL;
    mFetchSummarySyncStep = NULL;
    mPushMessagesStep = NULL;
    mUncacheOldMessagesSyncStep = NULL;
    mIdleOperation = NULL;
    mIdleActivity = NULL;
    mUrgentFetchSummarySyncStep = NULL;
    mUrgentFetchAttachmentSyncStep = NULL;
    mPushFlagsStep = NULL;
    mCopyMessagesStep = NULL;
    mSearchKeywords = NULL;
    mSearchOp = NULL;
    mSearchActivity = NULL;
    mSearchResultUids = NULL;
    mSearchState = IMAPFolderSearchStateNone;
    mSearchFetchHeaderSyncStep = NULL;
    mSearchFetchSummarySyncStep = NULL;
    mRemoveExpiredLocalMessageSyncStep = NULL;
    mSearchStoredRowsIDs = NULL;
    mHasMoreMessages = false;
    mCanLoadMore = false;
    mNeedRefresh = false;
    mLoadingFirstHeaders = false;
    
    mHeadersProgressValue = 0;
    mHeadersProgressMax = 0;
    mWaitingLoadMore = false;

    mDraftBehaviorEnabled = false;
    mNextDeleteOriginal = 0;
    mError = hermes::ErrorNone;
    mNetwork = false;
    mRefreshDelay = DEFAULT_REFRESH_DELAY;
    mIsUnseen = false;
    mUnseenValueInitialized = false;
    mUrgentFetchSourceStep = NULL;

    mSyncType = IMAPSyncTypeOther;
}

IMAPFolderSynchronizer::~IMAPFolderSynchronizer()
{
    LOG_CLEANUP("IMAPFolderSynchronizer %p %s dealloced", this, MCUTF8(mFolderPath));
    MC_SAFE_RELEASE(mUrgentFetchSourceStep);
    MC_SAFE_RELEASE(mSearchStoredRowsIDs);
    MC_SAFE_RELEASE(mRemoveExpiredLocalMessageSyncStep);
    MC_SAFE_RELEASE(mSearchFetchSummarySyncStep);
    MC_SAFE_RELEASE(mSearchFetchHeaderSyncStep);
    MC_SAFE_RELEASE(mSearchResultUids);
    MC_SAFE_RELEASE(mSearchKeywords);
    MC_SAFE_RELEASE(mFolderPath);
    MC_SAFE_RELEASE(mSession);
    MC_SAFE_RELEASE(mStorage);
    MC_SAFE_RELEASE(mUids);
    MC_SAFE_RELEASE(mCachedUids);
    MC_SAFE_RELEASE(mUidsToFetch);
    MC_SAFE_RELEASE(mSourceToFetch);
    MC_SAFE_RELEASE(mPartToFetchHashMapUrgent);
    MC_SAFE_RELEASE(mPartToFetchHashMap);
    MC_SAFE_RELEASE(mSummaryToFetchMessageRowIDsUrgent);
    MC_SAFE_RELEASE(mSummaryToFetchMessageRowIDs);
    MC_SAFE_RELEASE(mFetchFolderStateSyncStep);
    MC_SAFE_RELEASE(mFetchMessageListSyncStep);
    MC_SAFE_RELEASE(mFetchHeaderSyncStep);
    MC_SAFE_RELEASE(mFetchFlagsSyncStep);
    MC_SAFE_RELEASE(mPushMessagesStep);
    MC_SAFE_RELEASE(mFetchSummarySyncStep);
    MC_SAFE_RELEASE(mUncacheOldMessagesSyncStep);
    MC_SAFE_RELEASE(mIdleOperation);
    MC_SAFE_RELEASE(mUrgentFetchAttachmentSyncStep);
    MC_SAFE_RELEASE(mUrgentFetchSummarySyncStep);
    MC_SAFE_RELEASE(mPushFlagsStep);
    MC_SAFE_RELEASE(mIdleActivity);
    MC_SAFE_RELEASE(mSearchActivity);
    MC_SAFE_RELEASE(mSearchOp);
    MC_SAFE_RELEASE(mCopyMessagesStep);
}

Object * IMAPFolderSynchronizer::retain()
{
    LOG_CLEANUP("foldersync %p %s retain %i", this, MCUTF8(mFolderPath), retainCount() + 1);
    Object::retain();

    return this;
}

void IMAPFolderSynchronizer::release()
{
    LOG_CLEANUP("foldersync %p %s release %i", this, MCUTF8(mFolderPath), retainCount() - 1);
    Object::release();
}

void IMAPFolderSynchronizer::setSession(mailcore::IMAPAsyncSession * session)
{
    MC_SAFE_REPLACE_RETAIN(IMAPAsyncSession, mSession, session);
}

mailcore::IMAPAsyncSession * IMAPFolderSynchronizer::session()
{
    return mSession;
}

void IMAPFolderSynchronizer::setFolderPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mFolderPath, path);
}

String * IMAPFolderSynchronizer::folderPath()
{
    return mFolderPath;
}

void IMAPFolderSynchronizer::setSyncType(IMAPSyncType syncType)
{
    mSyncType = syncType;
}

IMAPSyncType IMAPFolderSynchronizer::syncType()
{
    return mSyncType;
}

void IMAPFolderSynchronizer::setDraftBehaviorEnabled(bool enabled)
{
    mDraftBehaviorEnabled = enabled;
}

bool IMAPFolderSynchronizer::isDraftBehaviorEnabled()
{
    return mDraftBehaviorEnabled;
}

void IMAPFolderSynchronizer::setRefreshDelay(double refreshDelay)
{
    mRefreshDelay = refreshDelay;
}

double IMAPFolderSynchronizer::refreshDelay()
{
    return mRefreshDelay;
}

void IMAPFolderSynchronizer::setMessagesToFetch(unsigned int messageToFetch)
{
    mMessagesToFetch = messageToFetch;
}

unsigned int IMAPFolderSynchronizer::messagesToFetch()
{
    return mMessagesToFetch;
}

void IMAPFolderSynchronizer::setDelegate(IMAPFolderSynchronizerDelegate * delegate)
{
    mDelegate = delegate;
}

IMAPFolderSynchronizerDelegate * IMAPFolderSynchronizer::delegate()
{
    return mDelegate;
}

int64_t IMAPFolderSynchronizer::folderID()
{
    return mStorage->folderIDForPath(mFolderPath);
}

#pragma mark -
#pragma mark sync state

void IMAPFolderSynchronizer::syncNext()
{
    mError = hermes::ErrorNone;

    if (!mUnseenValueInitialized) {
        mUnseenValueInitialized = true;
        mUnseenOp = mStorage->isFolderUnseenOperation(folderID());
        mUnseenOp->setCallback(this);
        mUnseenOp->retain();
        mUnseenOp->start();
    }

    if (mFolderPath->isEqual(MCSTR("INBOX"))) {
        //fprintf(stderr, "sync next %s\n", MCUTF8(mFolderPath));
    }
    if (syncUrgent()) {
        //fprintf(stderr, "got sync urgent %s\n", MCUTF8(mFolderPath));
        mDelegate->folderSynchronizerStateUpdated(this);
        return;
    }
    
    if (mNeedRefresh) {
        mState = IMAPFolderSynchronizerStateNeedMessageCount;
        mNeedRefresh = false;
        mNetwork = false;
        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }

    if (mFolderPath->isEqual(MCSTR("INBOX"))) {
        LOG_ERROR("sync important %s %i", MCUTF8(mFolderPath), mState);
    }
    switch (mState) {
        case IMAPFolderSynchronizerStateNeedMessageCount:
            mLoadingFirstHeaders = true;
            fetchFolderState();
            break;
        case IMAPFolderSynchronizerStateNeedSyncList:
            fetchMessageList();
            break;
        case IMAPFolderSynchronizerStateNeedSyncHeaders:
            fetchNextHeaders();
            break;
        case IMAPFolderSynchronizerStateNeedUncacheOldMessages:
            uncacheOldMessages();
            break;
        case IMAPFolderSynchronizerStateNeedPushMessages:
            pushMessages();
            break;
        case IMAPFolderSynchronizerStateNeedSyncFlags:
            fetchNextFlags();
            break;
        case IMAPFolderSynchronizerStateNeedSyncContent:
            fetchNextSummary();
            break;
        case IMAPFolderSynchronizerStateNeedRemoveExpiredLocalMessages:
            removeExpiredLocalMessages();
            break;
        case IMAPFolderSynchronizerStateNeedIdle:
            idle();
            break;
        case IMAPFolderSynchronizerStateDone:
            break;
    }
    mDelegate->folderSynchronizerStateUpdated(this);
}

void IMAPFolderSynchronizer::unseenOpDone()
{
    setFolderUnseen(mUnseenOp->isUnseen());
    MC_SAFE_RELEASE(mUnseenOp);
}

bool IMAPFolderSynchronizer::hasUrgentTask()
{
    if (mSummaryToFetchMessageRowIDs->count() > 0) {
        return true;
    }
    if (mPartToFetchHashMap->count() > 0) {
        return true;
    }
    if (mSummaryToFetchMessageRowIDsUrgent->count() > 0) {
        return true;
    }
    if (mPartToFetchHashMapUrgent->count() > 0) {
        return true;
    }
    if (mSourceToFetch->count() > 0) {
        return true;
    }

    if ((mSearchKeywords != NULL) && (mSearchState != IMAPFolderSearchStateNone) && (mSearchState != IMAPFolderSearchStateDone)) {
        return true;
    }
    
    if (mStorage->pushFlagsToServerNeeded(mStorage->folderIDForPath(mFolderPath))) {
        return true;
    }
    if (mStorage->copyMessagesNeeded(mStorage->folderIDForPath(mFolderPath))) {
        return true;
    }

    if (mNeedRefresh) {
        return true;
    }
    
    return false;
}

bool IMAPFolderSynchronizer::syncUrgent()
{
    int64_t folderID = mStorage->folderIDForPath(mFolderPath);
    if (mStorage->pushFlagsToServerNeeded(folderID)) {
        pushFlags();
        return true;
    }
    if (mStorage->copyMessagesNeeded(mStorage->folderIDForPath(mFolderPath))) {
        copyMessages();
        return true;
    }
    if (mNeedRefresh) {
        return false;
    }
    if (isWaitingLoadMore()) {
        return false;
    }
    if (mSourceToFetch->count() > 0) {
        urgentFetchNextSource();
        return true;
    }
    if (mSummaryToFetchMessageRowIDs->count() > 0) {
        //fprintf(stderr, "fetch summary\n");
        urgentFetchNextSummary();
        return true;
    }
    if (mSummaryToFetchMessageRowIDsUrgent->count() > 0) {
        //fprintf(stderr, "fetch summary\n");
        urgentFetchNextSummary();
        return true;
    }
    if (mPartToFetchHashMap->count() > 0) {
        urgentFetchNextPart();
        return true;
    }
    if (mPartToFetchHashMapUrgent->count() > 0) {
        urgentFetchNextPart();
        return true;
    }
    if ((mSearchKeywords != NULL) && (mSearchState != IMAPFolderSearchStateNone) && (mSearchState != IMAPFolderSearchStateDone)) {
        //fprintf(stderr, "perform search\n");
        performSearch();
        return true;
    }
    return false;
}

bool IMAPFolderSynchronizer::isSyncDone()
{
    if (hasUrgentTask())
        return false;

    if (mState == IMAPFolderSynchronizerStateDone)
        return true;

    return false;
}

#pragma mark -
#pragma mark sync step delegate

void IMAPFolderSynchronizer::syncStepStart(IMAPFolderSyncStep * syncStep)
{
    syncStep->setSession(mSession);
    syncStep->setFolderPath(mFolderPath);
    syncStep->setStorage(mStorage);
    syncStep->setSyncType(mSyncType);
    syncStep->setDelegate(this);
    syncStep->start();
}

void IMAPFolderSynchronizer::folderSyncStepDone(IMAPFolderSyncStep * syncStep)
{
    mError = hermes::ErrorNone;
    mNetwork = syncStep->isNetwork();
    hermes::ErrorCode error = syncStep->error();
    if (isAuthenticationError(error) || isConnectionError(error) || isFatalError(error)) {
        mError = error;
    }

    if (syncStep == mFetchFolderStateSyncStep) {
        fetchFolderStateSyncStepDone();
    }
    else if (syncStep == mFetchMessageListSyncStep) {
        if ((error == ErrorFetch) || (error == ErrorNonExistantFolder)) {
            mError = error;
        }
        fetchMessageListSyncStepDone();
    }
    else if (syncStep == mFetchHeaderSyncStep) {
        fetchHeadersSyncStepDone();
    }
    else if (syncStep == mFetchFlagsSyncStep) {
        fetchNextFlagsDone();
    }
    else if (syncStep == mFetchSummarySyncStep) {
        fetchNextSummaryDone();
    }
    else if (syncStep == mUncacheOldMessagesSyncStep) {
        uncacheOldMessagesDone();
    }
    else if (syncStep == mUrgentFetchSummarySyncStep) {
        urgentFetchNextSummaryDone();
    }
    else if (syncStep == mUrgentFetchAttachmentSyncStep) {
        urgentFetchNextPartDone();
    }
    else if (syncStep == mPushFlagsStep) {
        pushFlagsDone();
    }
    else if (syncStep == mPushMessagesStep) {
        if (error == ErrorAppend) {
            mError = error;
        }
        pushMessagesDone();
    }
    else if (syncStep == mSearchFetchHeaderSyncStep) {
        searchFetchHeadersDone();
    }
    else if (syncStep == mSearchFetchSummarySyncStep) {
        searchFetchContentDone();
    }
    else if (syncStep == mRemoveExpiredLocalMessageSyncStep) {
        removeExpiredLocalMessagesDone();
    }
    else if (syncStep == mCopyMessagesStep) {
        if (error == ErrorCopy) {
            mError = error;
        }
        copyMessagesLoopNextDone();
    }
    else if (syncStep == mUrgentFetchSourceStep) {
        if (error == ErrorFetch) {
            mError = error;
        }
        urgentFetchNextSourceDone();
    }
}

void IMAPFolderSynchronizer::folderSyncStateUpdated(IMAPFolderSyncStep * syncStep)
{
    if (syncStep == mFetchHeaderSyncStep) {
        fetchHeadersSyncStateUpdated();
    }
}

#pragma mark operation delegate

void IMAPFolderSynchronizer::operationFinished(mailcore::Operation * op)
{
    hermes::ErrorCode error = hermes::ErrorNone;
    if (op == mIdleOperation) {
        error = (hermes::ErrorCode) mIdleOperation->error();
    }
    else if (op == mSearchOp) {
        error = (hermes::ErrorCode) mSearchOp->error();
    }

    mError = hermes::ErrorNone;
    mNetwork = true;
    if (isAuthenticationError(error) || isConnectionError(error) || isFatalError(error)) {
        mError = (hermes::ErrorCode) error;
    }

    if (op == mIdleOperation) {
        idleDone();
    }
    else if (op == mSearchOp) {
        searchUidsDone();
    }
    else if (op == mUnseenOp) {
        unseenOpDone();
    }
}

#pragma mark -
#pragma mark folder state

void IMAPFolderSynchronizer::fetchFolderState()
{
    LOG("fetch folder state");
    retain();
    mFetchFolderStateSyncStep = new IMAPFetchFolderStateSyncStep();
    syncStepStart(mFetchFolderStateSyncStep);
}

void IMAPFolderSynchronizer::fetchFolderStateSyncStepDone()
{
    LOG("fetch folder state done");
    mMessageCount = mFetchFolderStateSyncStep->count();
    mUidNext = mFetchFolderStateSyncStep->uidNext();
    MC_SAFE_RELEASE(mFetchFolderStateSyncStep);

    if (mError != hermes::ErrorNone) {
        if (mLoadingFirstHeaders) {
            delegate()->folderSynchronizerSyncDone(this);
        }
        mLoadingFirstHeaders = false;
        handleError();
        release();
        return;
    }

    mState = IMAPFolderSynchronizerStateNeedSyncList;

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark message list

void IMAPFolderSynchronizer::fetchMessageList()
{
    LOG("fetch msg list");
    retain();
    mFetchMessageListSyncStep = new IMAPFetchMessageListSyncStep();
    mFetchMessageListSyncStep->setMessagesCount(mMessageCount);
    mFetchMessageListSyncStep->setMaxFetchCount(mMessagesToFetch);
    syncStepStart(mFetchMessageListSyncStep);
}

void IMAPFolderSynchronizer::fetchMessageListSyncStepDone()
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mUids, mFetchMessageListSyncStep->uids());
    MC_SAFE_REPLACE_RETAIN(IndexSet, mCachedUids, mFetchMessageListSyncStep->cachedUids());
    
    MC_SAFE_RELEASE(mUidsToFetch);
    MC_SAFE_RELEASE(mFetchMessageListSyncStep);

    if (mError != hermes::ErrorNone) {
        if (mLoadingFirstHeaders) {
            delegate()->folderSynchronizerSyncDone(this);
        }
        mLoadingFirstHeaders = false;
        handleError();
        release();
        return;
    }

    if (mUids->count() == 0) {
        setFolderUnseen(false);
    }

    mUidsToFetch = (IndexSet *) mUids->copy();
    //fprintf(stderr, "uid to fetch: %s\n", MCUTF8DESC(mUidsToFetch));
    mUidsToFetch->removeIndexSet(mCachedUids);
    
    //fprintf(stderr, "cached uids: %s\n", MCUTF8DESC(mCachedUids));
    //fprintf(stderr, "uid to fetch: %s\n", MCUTF8DESC(mUidsToFetch));
    //fprintf(stderr, "msg list: %s\n", MCUTF8DESC(mUids));

    mState = IMAPFolderSynchronizerStateNeedSyncHeaders;
    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark fetch headers

void IMAPFolderSynchronizer::fetchNextHeaders()
{
    if (mUidsToFetch->count() == 0) {
        mState = IMAPFolderSynchronizerStateNeedUncacheOldMessages;
        MC_SAFE_RELEASE(mUidsToFetch);
        mUidsToFetch = (IndexSet *) mCachedUids->copy();
        
        mCanLoadMore = true;

        if (mLoadingFirstHeaders) {
            cancelDelayedPerformMethod((Object::Method) &IMAPFolderSynchronizer::refreshAfterDelay, NULL);
            performMethodAfterDelay((Object::Method) &IMAPFolderSynchronizer::refreshAfterDelay, NULL, mRefreshDelay);
        }

        if (mLoadingFirstHeaders) {
            delegate()->folderSynchronizerSyncDone(this);
        }
        mLoadingFirstHeaders = false;

        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }
    
    //fprintf(stderr, "to fetch: %s\n", MCUTF8DESC(mUidsToFetch));
    
    retain();
    mFetchHeaderSyncStep = new IMAPFetchHeadersSyncStep();
    mFetchHeaderSyncStep->setDraftsFolderID(mStorage->folderIDForPath(delegate()->folderSynchronizerDraftsFolder(this)));
    mFetchHeaderSyncStep->setUids(mUidsToFetch);
    syncStepStart(mFetchHeaderSyncStep);
}

void IMAPFolderSynchronizer::fetchHeadersSyncStepDone()
{
    if (mFetchHeaderSyncStep->isUnseen()) {
        setFolderUnseen(true);
    }

    bool hasFetchedMessages = false;
    if ((mFetchHeaderSyncStep->fetchedUids() != NULL) && (mFetchHeaderSyncStep->fetchedUids()->count() > 0)) {
        hasFetchedMessages = true;
    }

    MC_SAFE_REPLACE_RETAIN(IndexSet, mUidsToFetch, mFetchHeaderSyncStep->remainingUids());
    //fprintf(stderr, "fetched: %s\n", MCUTF8DESC(mFetchHeaderSyncStep->fetchedUids()));
    MC_SAFE_RELEASE(mFetchHeaderSyncStep);
    
    if (mError != hermes::ErrorNone) {
        if (mLoadingFirstHeaders) {
            delegate()->folderSynchronizerSyncDone(this);
        }
        mLoadingFirstHeaders = false;
        handleError();
        release();
        return;
    }

    if (mError == hermes::ErrorNone) {
        cancelDelayedPerformMethod((Object::Method) &IMAPFolderSynchronizer::refreshAfterDelay, NULL);
        performMethodAfterDelay((Object::Method) &IMAPFolderSynchronizer::refreshAfterDelay, NULL, mRefreshDelay);
    }

    if (hasFetchedMessages) {
        delegate()->folderSynchronizerFetchedHeaders(this);
    }

    if (mLoadingFirstHeaders) {
        delegate()->folderSynchronizerSyncDone(this);
    }
    mLoadingFirstHeaders = false;
    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

void IMAPFolderSynchronizer::refreshAfterDelay()
{
    refresh();
}

void IMAPFolderSynchronizer::fetchHeadersSyncStateUpdated()
{
    mHeadersProgressMax = mFetchHeaderSyncStep->headersProgressMax();
    mHeadersProgressValue = mFetchHeaderSyncStep->headersProgressValue();
    mDelegate->folderSynchronizerStateUpdated(this);
}

#pragma mark uncache messages

void IMAPFolderSynchronizer::uncacheOldMessages()
{
    LOG_ERROR("%s %s uncache", MCUTF8(mSession->username()), MCUTF8(mFolderPath));
    if (mSearchKeywords != NULL) {
        mState = IMAPFolderSynchronizerStateNeedPushMessages;
        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }
    
    IndexSet * uids = (IndexSet *) mCachedUids->copy();
    uids->removeIndexSet(mUids);
    
    retain();
    mUncacheOldMessagesSyncStep = new IMAPUncacheOldMessagesSyncStep();
    mUncacheOldMessagesSyncStep->setTrashFolderPath(delegate()->folderSynchronizerTrashFolder(this));
    mUncacheOldMessagesSyncStep->setDraftsFolderPath(delegate()->folderSynchronizerDraftsFolder(this));
    mUncacheOldMessagesSyncStep->setMessagesToUncache(uids);
    syncStepStart(mUncacheOldMessagesSyncStep);

    uids->release();
}

void IMAPFolderSynchronizer::uncacheOldMessagesDone()
{
    LOG_ERROR("%s %s uncache done", MCUTF8(mSession->username()), MCUTF8(mFolderPath));
    mState = IMAPFolderSynchronizerStateNeedPushMessages;
    
    MC_SAFE_RELEASE(mUncacheOldMessagesSyncStep);
    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark push messages

void IMAPFolderSynchronizer::pushMessages()
{
    if (!mStorage->pushMessagesToServerNeeded(mStorage->folderIDForPath(mFolderPath))) {
        mState = IMAPFolderSynchronizerStateNeedSyncFlags;
        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }

    retain();
    mPushMessagesStep = new IMAPPushMessagesStep();
    mPushMessagesStep->setDraftBehaviorEnabled(isDraftBehaviorEnabled());
    mPushMessagesStep->setTrashFolderPath(delegate()->folderSynchronizerTrashFolder(this));
    syncStepStart(mPushMessagesStep);
}

void IMAPFolderSynchronizer::pushMessagesDone()
{
    if (!mPushMessagesStep->isDone()) {
        mStorage->setNeedsPushMessagesToServer(mStorage->folderIDForPath(mFolderPath));
        mState = IMAPFolderSynchronizerStateNeedMessageCount;
    }
    delegate()->folderSynchronizerSyncPushMessageDone(this, mError, mPushMessagesStep->messageRowID());
    MC_SAFE_RELEASE(mPushMessagesStep);

    if (mError == hermes::ErrorAppend) {
        handleRecoverableError();
        release();
        return;
    }
    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);

    release();
}

#pragma mark fetch flags

void IMAPFolderSynchronizer::fetchNextFlags()
{
    if ((mUidsToFetch == NULL) || (mUidsToFetch->count() == 0)) {
        mState = IMAPFolderSynchronizerStateNeedSyncContent;
        MC_SAFE_RELEASE(mUidsToFetch);
        
        mMaxUid = 0;
        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }
    
    //fprintf(stderr, "to fetch flags: %s\n", MCUTF8DESC(mUidsToFetch));
    
    retain();
    mFetchFlagsSyncStep = new IMAPFetchFlagsSyncStep();
    mFetchFlagsSyncStep->setUids(mUidsToFetch);
    syncStepStart(mFetchFlagsSyncStep);
}

void IMAPFolderSynchronizer::fetchNextFlagsDone()
{
    if (mFetchFlagsSyncStep->isSeen()) {
        setFolderUnseen(false);
    }

    MC_SAFE_REPLACE_RETAIN(IndexSet, mUidsToFetch, mFetchFlagsSyncStep->remainingUids());
    //fprintf(stderr, "fetched flags: %s\n", MCUTF8DESC(mFetchFlagsSyncStep->fetchedUids()));
    MC_SAFE_RELEASE(mFetchFlagsSyncStep);
    
    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark fetch summary

void IMAPFolderSynchronizer::fetchNextSummary()
{
    retain();
    mFetchSummarySyncStep = new IMAPFetchNextSummarySyncStep();
    mFetchSummarySyncStep->setMaxUid(mMaxUid);
    syncStepStart(mFetchSummarySyncStep);
}

void IMAPFolderSynchronizer::fetchNextSummaryDone()
{
    //fprintf(stderr, "fetched summary\n");

    if (mFetchSummarySyncStep->uid() != 0) {
        mDelegate->folderSynchronizerSyncFetchSummaryDone(this, mFetchSummarySyncStep->error(), mFetchSummarySyncStep->messageRowID());
        mMaxUid = mFetchSummarySyncStep->uid() - 1;
    }
    else {
        mState = IMAPFolderSynchronizerStateNeedRemoveExpiredLocalMessages;
    }
    MC_SAFE_RELEASE(mFetchSummarySyncStep);

    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark expired messages

void IMAPFolderSynchronizer::removeExpiredLocalMessages()
{
    retain();
    mRemoveExpiredLocalMessageSyncStep = new IMAPRemoveExpiredLocalMessageSyncStep();
    syncStepStart(mRemoveExpiredLocalMessageSyncStep);
}

void IMAPFolderSynchronizer::removeExpiredLocalMessagesDone()
{
    if (mFolderPath->isEqual(MCSTR("INBOX"))) {
        if (isIdleDisabled()) {
            mState = IMAPFolderSynchronizerStateDone;
        }
        else {
            mState = IMAPFolderSynchronizerStateNeedIdle;
        }
    }
    else {
        mState = IMAPFolderSynchronizerStateDone;
    }
    MC_SAFE_RELEASE(mRemoveExpiredLocalMessageSyncStep);

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark idle

void IMAPFolderSynchronizer::idle()
{
    retain();
    
    mIdleInterrupted = false;

    uint32_t lastUid = 1;
    
    if (mUids->count() > 0) {
        Range range = mUids->allRanges()[mUids->rangesCount() - 1];
        lastUid = (uint32_t) RangeRightBound(range);
    }
    
    mIdleActivity = new ActivityItem();
    mIdleActivity->setProgressString(MCSTR("Idle"));
    mIdleActivity->registerActivity();
    
    LOG_IDLE("** IDLING %u\n", lastUid);
    mIdleOperation = mSession->idleOperation(mFolderPath, lastUid);
    mIdleOperation->retain();
    mIdleOperation->setCallback(this);
    mIdleOperation->start();
}

void IMAPFolderSynchronizer::idleDone()
{
    LOG_IDLE("** IDLING done\n");
    if (mIdleOperation->error() == mailcore::ErrorNone) {
        if (mIdleInterrupted) {
            if (isIdleDisabled()) {
                mState = IMAPFolderSynchronizerStateDone;
            }
            else {
                mState = IMAPFolderSynchronizerStateNeedIdle;
            }
        }
        else {
            mState = IMAPFolderSynchronizerStateNeedMessageCount;
        }
    }
    else if (mError != hermes::ErrorNone) {
        mIdleActivity->unregisterActivity();
        MC_SAFE_RELEASE(mIdleActivity);
        MC_SAFE_RELEASE(mIdleOperation);

        handleError();
        release();
        return;
    }

    mIdleActivity->unregisterActivity();
    MC_SAFE_RELEASE(mIdleActivity);
    MC_SAFE_RELEASE(mIdleOperation);
    
    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

void IMAPFolderSynchronizer::interruptIdle()
{
    if (mIdleOperation == NULL) {
        LOG_IDLE("** interrupt IDLE but no IDLE operation in progress\n");
        return;
    }
    LOG_IDLE("** interrupt IDLE\n");
    mIdleInterrupted = true;
    mIdleOperation->interruptIdle();
}

bool IMAPFolderSynchronizer::isIdling()
{
    return (mIdleOperation != NULL);
}

bool IMAPFolderSynchronizer::isIdleDisabled()
{
    return mDisableIdleCount > 0 || !mSession->isIdleEnabled();
}

void IMAPFolderSynchronizer::disableIdle()
{
    mDisableIdleCount ++;
    if (isIdling()) {
        interruptIdle();
    }
}

void IMAPFolderSynchronizer::enableIdle()
{
    mDisableIdleCount --;
    if (mDisableIdleCount == 0) {
        if (mState == IMAPFolderSynchronizerStateDone ) {
            mState = IMAPFolderSynchronizerStateNeedIdle;
            mDelegate->folderSynchronizerSyncShouldSync(this);
        }
    }
}

void IMAPFolderSynchronizer::setStorage(MailStorage * storage)
{
    MC_SAFE_REPLACE_RETAIN(MailStorage, mStorage, storage);
}

MailStorage * IMAPFolderSynchronizer::storage()
{
    return mStorage;
}

#pragma mark urgent fetch summary

void IMAPFolderSynchronizer::fetchMessageSummary(int64_t messageRowID, bool urgent)
{
    MCAssert(messageRowID != -1);
    Value * vMessageRowID = Value::valueWithLongLongValue(messageRowID);
    if (mSummaryToFetchMessageRowIDs->containsObject(vMessageRowID)) {
        return;
    }
    if (mSummaryToFetchMessageRowIDsUrgent->containsObject(vMessageRowID)) {
        return;
    }
    if (urgent) {
        mSummaryToFetchMessageRowIDsUrgent->addObject(vMessageRowID);
    }
    else {
        mSummaryToFetchMessageRowIDs->addObject(vMessageRowID);
    }
    mDelegate->folderSynchronizerSyncShouldSync(this);
}

void IMAPFolderSynchronizer::urgentFetchNextSummary()
{
    mFetchSummaryUrgent = (mSummaryToFetchMessageRowIDsUrgent->count() > 0);
    Value * vMessageRowID;
    if (mFetchSummaryUrgent) {
        vMessageRowID = (Value *) mSummaryToFetchMessageRowIDsUrgent->objectAtIndex(0);
    }
    else {
        vMessageRowID = (Value *) mSummaryToFetchMessageRowIDs->objectAtIndex(0);
    }
    
    //fprintf(stderr, "fetch urgent: %lli\n", vMessageRowID->longLongValue());
    retain();
    mUrgentFetchSummarySyncStep = new IMAPFetchNextSummarySyncStep();
    mUrgentFetchSummarySyncStep->setMessageRowID(vMessageRowID->longLongValue());
    //mUrgentFetchSummarySyncStep->setUrgent(mFetchSummaryUrgent);
    syncStepStart(mUrgentFetchSummarySyncStep);
}

void IMAPFolderSynchronizer::urgentFetchNextSummaryDone()
{
    mDelegate->folderSynchronizerSyncFetchSummaryDone(this, mUrgentFetchSummarySyncStep->error(), mUrgentFetchSummarySyncStep->messageRowID());

    MC_SAFE_RELEASE(mUrgentFetchSummarySyncStep);
    
    if (mFetchSummaryUrgent) {
        mSummaryToFetchMessageRowIDsUrgent->removeObjectAtIndex(0);
    }
    else {
        mSummaryToFetchMessageRowIDs->removeObjectAtIndex(0);
    }
    
    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

void IMAPFolderSynchronizer::urgentFetchNextSource()
{
    retain();
    Value * vRowID = (Value *) mSourceToFetch->objectAtIndex(0);
    mUrgentFetchSourceStep = new IMAPFetchNextSourceSyncStep();
    mUrgentFetchSourceStep->setMessageRowID(vRowID->longLongValue());
    syncStepStart(mUrgentFetchSourceStep);
}

void IMAPFolderSynchronizer::urgentFetchNextSourceDone()
{
    Value * vRowID = (Value *) mSourceToFetch->objectAtIndex(0);
    mDelegate->folderSynchronizerMessageSourceFetched(this, mUrgentFetchSourceStep->error(), vRowID->longLongValue(),
                                                       mUrgentFetchSourceStep->messageData());

    MC_SAFE_RELEASE(mUrgentFetchSourceStep);
    mSourceToFetch->removeObjectAtIndex(0);

    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark urgent fetch part

void IMAPFolderSynchronizer::fetchMessageSource(int64_t messageRowID)
{
    if (mSourceToFetch->containsObject(Value::valueWithLongLongValue(messageRowID))) {
        return;
    }
    mSourceToFetch->addObject(Value::valueWithLongLongValue(messageRowID));
    mDelegate->folderSynchronizerSyncShouldSync(this);
}

void IMAPFolderSynchronizer::fetchMessagePart(int64_t messageRowID, mailcore::String * partID, bool urgent)
{
    bool found = false;
    {
        mc_foreacharray(HashMap, currentItem, mPartToFetchHashMap) {
            Value * vRowID = (Value *) currentItem->objectForKey(MCSTR("rowid"));
            String * currentPartID = (String *) currentItem->objectForKey(MCSTR("partid"));
            if ((vRowID->longLongValue() == messageRowID) && currentPartID->isEqual(partID)) {
                found = true;
                break;
            }
        }
    }
    {
        mc_foreacharray(HashMap, currentItem, mPartToFetchHashMapUrgent) {
            Value * vRowID = (Value *) currentItem->objectForKey(MCSTR("rowid"));
            String * currentPartID = (String *) currentItem->objectForKey(MCSTR("partid"));
            if ((vRowID->longLongValue() == messageRowID) && currentPartID->isEqual(partID)) {
                found = true;
                break;
            }
        }
    }
    if (found) {
        return;
    }
    HashMap * item = new HashMap();
    item->setObjectForKey(MCSTR("rowid"), Value::valueWithLongLongValue(messageRowID));
    item->setObjectForKey(MCSTR("partid"), partID);
    if (urgent) {
        mPartToFetchHashMapUrgent->addObject(item);
    }
    else {
        mPartToFetchHashMap->addObject(item);
    }
    MC_SAFE_RELEASE(item);

    mDelegate->folderSynchronizerSyncShouldSync(this);
}

void IMAPFolderSynchronizer::urgentFetchNextPart()
{
    mFetchPartUrgent = (mPartToFetchHashMapUrgent->count() > 0);
    HashMap * item;
    if (mFetchPartUrgent) {
        item = (HashMap *) mPartToFetchHashMapUrgent->objectAtIndex(0);
    }
    else {
        item = (HashMap *) mPartToFetchHashMap->objectAtIndex(0);
    }
    Value * vMessageRowID = (Value *) item->objectForKey(MCSTR("rowid"));
    String * partID = (String *) item->objectForKey(MCSTR("partid"));

    //fprintf(stderr, "fetch urgent: %lli\n", vMessageRowID->longLongValue());
    retain();
    mUrgentFetchAttachmentSyncStep = new IMAPFetchNextAttachmentSyncStep();
    mUrgentFetchAttachmentSyncStep->setMessageRowID(vMessageRowID->longLongValue());
    mUrgentFetchAttachmentSyncStep->setPartID(partID);
    //mUrgentFetchAttachmentSyncStep->setUrgent(mFetchPartUrgent);
    syncStepStart(mUrgentFetchAttachmentSyncStep);
}

void IMAPFolderSynchronizer::urgentFetchNextPartDone()
{
    mDelegate->folderSynchronizerSyncFetchPartDone(this, mUrgentFetchAttachmentSyncStep->error(), mUrgentFetchAttachmentSyncStep->messageRowID(), mUrgentFetchAttachmentSyncStep->partID());

    MC_SAFE_RELEASE(mUrgentFetchAttachmentSyncStep);

    if (mFetchPartUrgent) {
        mPartToFetchHashMapUrgent->removeObjectAtIndex(0);
    }
    else {
        mPartToFetchHashMap->removeObjectAtIndex(0);
    }

    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark push flags

void IMAPFolderSynchronizer::pushFlags()
{
    retain();
    mPushFlagsStep = new IMAPPushFlagsStep();
    syncStepStart(mPushFlagsStep);
}

void IMAPFolderSynchronizer::pushFlagsDone()
{
    MC_SAFE_RELEASE(mPushFlagsStep);

    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }
    
    mDelegate->folderSynchronizerSyncStepDone(this);
    
    release();
}

#pragma mark copy messages

// copy, delete and purge
void IMAPFolderSynchronizer::copyMessages()
{
    mNextDeleteOriginal = 0;
    copyMessagesLoopNext();
}

void IMAPFolderSynchronizer::copyMessagesLoopNext()
{
    if (mNextDeleteOriginal == 3) {
        copyMessagesDone();
        return;
    }

    retain();
    mCopyMessagesStep = new IMAPCopyMessagesStep();
    mCopyMessagesStep->setDeleteOriginal(mNextDeleteOriginal);
    syncStepStart(mCopyMessagesStep);
}

void IMAPFolderSynchronizer::copyMessagesLoopNextDone()
{
    MC_SAFE_RELEASE(mCopyMessagesStep);

    if (mError == hermes::ErrorCopy) {
        storage()->setNeedsCopyMessages(folderID());
        handleRecoverableError();
        release();
        return;
    }
    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mNextDeleteOriginal ++;
    copyMessagesLoopNext();

    release();
}

void IMAPFolderSynchronizer::copyMessagesDone()
{
    mDelegate->folderSynchronizerSyncStepDone(this);
}

#pragma mark -
#pragma mark search

void IMAPFolderSynchronizer::setSearchKeywords(mailcore::Array * keywords)
{
    MC_SAFE_REPLACE_RETAIN(Array, mSearchKeywords, keywords);
    if (mSearchKeywords == NULL) {
        mSearchState = IMAPFolderSearchStateNone;
        cancelSearch();
        return;
    }
    mSearchState = IMAPFolderSearchStateNeedUids;
    mDelegate->folderSynchronizerSyncShouldSync(this);
}

mailcore::Array * IMAPFolderSynchronizer::searchKeywords()
{
    return mSearchKeywords;
}

void IMAPFolderSynchronizer::cancelSearch()
{
    bool inProgress = false;

    if (mSearchActivity != NULL) {
        mSearchActivity->unregisterActivity();
        MC_SAFE_RELEASE(mSearchActivity);
    }
    if (mSearchOp != NULL) {
        inProgress = true;
        mSearchOp->cancel();
        MC_SAFE_RELEASE(mSearchOp);
    }
    if (mSearchFetchHeaderSyncStep != NULL) {
        inProgress = true;
        mSearchFetchHeaderSyncStep->cancel();
        MC_SAFE_RELEASE(mSearchFetchHeaderSyncStep);
    }
    if (mSearchFetchSummarySyncStep != NULL) {
        inProgress = true;
        mSearchFetchSummarySyncStep->cancel();
        MC_SAFE_RELEASE(mSearchFetchSummarySyncStep);
    }

    MC_SAFE_RELEASE(mSearchStoredRowsIDs);
    MC_SAFE_RELEASE(mSearchResultUids);

    if (inProgress) {
        mDelegate->folderSynchronizerSyncStepDone(this);
        release();
    }
}

bool IMAPFolderSynchronizer::isSearching()
{
    return (mSearchState != IMAPFolderSearchStateNone) && (mSearchState != IMAPFolderSearchStateDone);
}

void IMAPFolderSynchronizer::performSearch()
{
    switch (mSearchState) {
        case IMAPFolderSearchStateNeedUids:
            searchUids();
            break;
        case IMAPFolderSearchStateNeedFetchHeaders:
            searchFetchHeaders();
            break;
        case IMAPFolderSearchStateNeedFetchContent:
            searchFetchContent();
            break;
    }
}

void IMAPFolderSynchronizer::searchUids()
{
    IMAPSearchExpression * expr = NULL;
    mc_foreacharray(String, keyword, mSearchKeywords) {
        IMAPSearchExpression * keywordExpr = IMAPSearchExpression::searchContent(keyword);
        if (expr == NULL) {
            expr = keywordExpr;
        }
        else {
            expr = IMAPSearchExpression::searchAnd(expr, keywordExpr);
        }
    }
    retain();
    mSearchActivity = new ActivityItem();
    mSearchActivity->setProgressString(MCSTR("searching"));
    mSearchActivity->registerActivity();
    mSearchOp = mSession->searchOperation(mFolderPath, expr);
    mSearchOp->setCallback(this);
    mSearchOp->retain();
    mSearchOp->start();
}

void IMAPFolderSynchronizer::searchUidsDone()
{
    mSearchActivity->unregisterActivity();
    MC_SAFE_RELEASE(mSearchActivity);
    MC_SAFE_REPLACE_RETAIN(IndexSet, mSearchResultUids, mSearchOp->uids());
    MC_SAFE_RELEASE(mSearchOp);
    
    LOG_SEARCH("found %s", MCUTF8DESC(mSearchResultUids));

    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mSearchState = IMAPFolderSearchStateNeedFetchHeaders;
    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

void IMAPFolderSynchronizer::searchFetchHeaders()
{
    if ((mSearchResultUids == NULL) || (mSearchResultUids->count() == 0)) {
        mSearchState = IMAPFolderSearchStateDone;
        MC_SAFE_RELEASE(mSearchResultUids);
        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }
    
    retain();
    mSearchFetchHeaderSyncStep = new IMAPFetchHeadersSyncStep();
    mSearchFetchHeaderSyncStep->setDraftsFolderID(mStorage->folderIDForPath(delegate()->folderSynchronizerDraftsFolder(this)));
    mSearchFetchHeaderSyncStep->setUids(mSearchResultUids);
    syncStepStart(mSearchFetchHeaderSyncStep);
}

void IMAPFolderSynchronizer::searchFetchHeadersDone()
{
    LOG_SEARCH("fetched headers %s", MCUTF8DESC(mSearchFetchHeaderSyncStep->fetchedUids()));
    //fprintf(stderr, "fetched headers %s\n", MCUTF8DESC(mSearchFetchHeaderSyncStep->fetchedUids()));
    MC_SAFE_REPLACE_RETAIN(IndexSet, mSearchStoredRowsIDs, mSearchFetchHeaderSyncStep->rowsIDs());
    MC_SAFE_REPLACE_RETAIN(IndexSet, mSearchResultUids, mSearchFetchHeaderSyncStep->remainingUids());
    MC_SAFE_RELEASE(mSearchFetchHeaderSyncStep);
    
    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mSearchState = IMAPFolderSearchStateNeedFetchContent;
    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

void IMAPFolderSynchronizer::searchFetchContent()
{
    if (mSearchStoredRowsIDs == NULL || mSearchStoredRowsIDs->rangesCount() == 0) {
        MC_SAFE_RELEASE(mSearchFetchHeaderSyncStep);
        mSearchState = IMAPFolderSearchStateNeedFetchHeaders;
        mDelegate->folderSynchronizerSyncStepDone(this);
        return;
    }
    
    int64_t rowID = mSearchStoredRowsIDs->allRanges()[0].location;
    
    //fprintf(stderr, "fetch %lli", rowID);
    LOG_SEARCH("fetch %s %lli", MCUTF8(mFolderPath), rowID);
    
    retain();
    mSearchFetchSummarySyncStep = new IMAPFetchNextSummarySyncStep();
    mSearchFetchSummarySyncStep->setMessageRowID(rowID);
    syncStepStart(mSearchFetchSummarySyncStep);
}

void IMAPFolderSynchronizer::searchFetchContentDone()
{
    mDelegate->folderSynchronizerSyncFetchSummaryDone(this, mSearchFetchSummarySyncStep->error(), mSearchFetchSummarySyncStep->messageRowID());

    mSearchStoredRowsIDs->removeIndex(mSearchFetchSummarySyncStep->messageRowID());
    MC_SAFE_RELEASE(mSearchFetchSummarySyncStep);

    if (mError != hermes::ErrorNone) {
        handleError();
        release();
        return;
    }

    mDelegate->folderSynchronizerSyncStepDone(this);
    release();
}

#pragma mark -
#pragma mark progress

bool IMAPFolderSynchronizer::shouldShowProgress()
{
    return (mNeedRefresh || mLoadingFirstHeaders) && (mSession != NULL);
}

unsigned int IMAPFolderSynchronizer::headersProgressValue()
{
    return mHeadersProgressValue;
}

unsigned int IMAPFolderSynchronizer::headersProgressMax()
{
    return mHeadersProgressMax;
}

#pragma mark -
#pragma mark list state

void IMAPFolderSynchronizer::reset()
{
    mNeedRefresh = true;
    mHeadersProgressMax = 0;
    mHeadersProgressValue = 0;
}

void IMAPFolderSynchronizer::refresh()
{
    reset();
    mDelegate->folderSynchronizerSyncShouldSync(this);
}

bool IMAPFolderSynchronizer::canLoadMore()
{
    if (mMessagesToFetch == 0) {
        return false;
    }
    //LOG("can load more %s %i %i\n", MCUTF8(mFolderPath), mCanLoadMore, mHasMoreMessages);
    return mCanLoadMore && mHasMoreMessages;
}

bool IMAPFolderSynchronizer::loadMore()
{
    if (mNeedRefresh) {
        return false;
    }
    
    switch (mState) {
        case IMAPFolderSynchronizerStateNeedMessageCount:
        case IMAPFolderSynchronizerStateNeedSyncList:
        case IMAPFolderSynchronizerStateNeedSyncHeaders:
            return false;
    }
    
    mMessagesToFetch += DEFAULT_MESSAGES_TO_FETCH;
    refresh();
    return true;
}

void IMAPFolderSynchronizer::resetMessagesToLoad()
{
    mMessagesToFetch = DEFAULT_MESSAGES_TO_FETCH;
    refresh();
}

bool IMAPFolderSynchronizer::messagesToLoadCanBeReset()
{
    if (mMessagesToFetch == 0) {
        return false;
    }
    return mMessagesToFetch > DEFAULT_MESSAGES_TO_FETCH;
}

void IMAPFolderSynchronizer::setWaitingLoadMore(bool needsLoadMore)
{
    mWaitingLoadMore = needsLoadMore;
}

bool IMAPFolderSynchronizer::isWaitingLoadMore()
{
    return mWaitingLoadMore;
}

String * IMAPFolderSynchronizer::urgentTaskDescription()
{
    if (mSummaryToFetchMessageRowIDs->count() > 0) {
        return String::stringWithUTF8Format("has summary to fetch: %s", MCUTF8(mSummaryToFetchMessageRowIDs));
    }
    if (mPartToFetchHashMap->count() > 0) {
        return String::stringWithUTF8Format("has part to fetch: %s", MCUTF8(mPartToFetchHashMap));
    }
    
    if ((mSearchKeywords != NULL) && (mSearchState != IMAPFolderSearchStateNone) && (mSearchState != IMAPFolderSearchStateDone)) {
        const char * searchState = NULL;
        switch (mSearchState) {
            case IMAPFolderSearchStateNone:
                searchState = "none";
                break;
            case IMAPFolderSearchStateNeedUids:
                searchState = "needs-uid";
                break;
            case IMAPFolderSearchStateNeedFetchHeaders:
                searchState = "need-fetch-headers";
                break;
            case IMAPFolderSearchStateNeedFetchContent:
                searchState = "need-fetch-content";
                break;
            case IMAPFolderSearchStateDone:
                searchState = "done";
                break;
        }
        return String::stringWithUTF8Format("has search: %s %s", MCUTF8(mSearchKeywords), searchState);
    }
    
    if (mStorage->pushFlagsToServerNeeded(folderID())) {
        return MCSTR("has flags to push");
    }
    
    if (mNeedRefresh) {
        return MCSTR("needs refresh");
    }
    
    return NULL;
}

String * IMAPFolderSynchronizer::syncStateDescription()
{
    switch (mState) {
        case IMAPFolderSynchronizerStateNeedMessageCount:
            return MCSTR("need msg count");
        case IMAPFolderSynchronizerStateNeedSyncList:
            return MCSTR("need sync list");
        case IMAPFolderSynchronizerStateNeedSyncHeaders:
            return MCSTR("need sync header");
        case IMAPFolderSynchronizerStateNeedUncacheOldMessages:
            return MCSTR("need uncache old msgs");
        case IMAPFolderSynchronizerStateNeedRemoveExpiredLocalMessages:
            return MCSTR("remove expired messages");
        case IMAPFolderSynchronizerStateNeedSyncFlags:
            return MCSTR("need sync flags");
        case IMAPFolderSynchronizerStateNeedSyncContent:
            return MCSTR("need sync content");
        case IMAPFolderSynchronizerStateNeedIdle:
            return MCSTR("need idle");
        case IMAPFolderSynchronizerStateDone:
            return MCSTR("done");
    }
    return NULL;
}

hermes::ErrorCode IMAPFolderSynchronizer::lastError()
{
    return mError;
}

bool IMAPFolderSynchronizer::lastOperationIsNetwork()
{
    return mNetwork;
}

#pragma mark -
#pragma mark close & error

void IMAPFolderSynchronizer::closeConnection()
{
    mState = IMAPFolderSynchronizerStateNeedMessageCount;
    if (mFetchFolderStateSyncStep != NULL) {
        mFetchFolderStateSyncStep->cancel();
        MC_SAFE_RELEASE(mFetchFolderStateSyncStep);
        release();
    }
    if (mFetchMessageListSyncStep != NULL) {
        mFetchMessageListSyncStep->cancel();
        MC_SAFE_RELEASE(mFetchMessageListSyncStep);
        release();
    }
    if (mFetchHeaderSyncStep != NULL) {
        mFetchHeaderSyncStep->cancel();
        MC_SAFE_RELEASE(mFetchHeaderSyncStep);
        release();
    }
    if (mFetchFlagsSyncStep != NULL) {
        mFetchFlagsSyncStep->cancel();
        MC_SAFE_RELEASE(mFetchFlagsSyncStep);
        release();
    }
    if (mFetchSummarySyncStep != NULL) {
        mFetchSummarySyncStep->cancel();
        MC_SAFE_RELEASE(mFetchSummarySyncStep);
        release();
    }
    if (mPushFlagsStep != NULL) {
        mPushFlagsStep->cancel();
        MC_SAFE_RELEASE(mPushFlagsStep);
        release();
    }
    if (mPushMessagesStep != NULL) {
        mPushMessagesStep->cancel();
        MC_SAFE_RELEASE(mPushMessagesStep);
        release();
    }
    if (mUncacheOldMessagesSyncStep != NULL) {
        mUncacheOldMessagesSyncStep->cancel();
        MC_SAFE_RELEASE(mUncacheOldMessagesSyncStep);
        release();
    }
    if (mUrgentFetchSummarySyncStep != NULL) {
        mUrgentFetchSummarySyncStep->cancel();
        MC_SAFE_RELEASE(mUrgentFetchSummarySyncStep);
        release();
    }
    if (mUrgentFetchAttachmentSyncStep != NULL) {
        mUrgentFetchAttachmentSyncStep->cancel();
        MC_SAFE_RELEASE(mUrgentFetchAttachmentSyncStep);
        release();
    }
    if (mIdleOperation != NULL) {
        mIdleActivity->unregisterActivity();
        MC_SAFE_RELEASE(mIdleActivity);
        mIdleOperation->cancel();
        MC_SAFE_RELEASE(mIdleOperation);
        release();
    }
    if (mSearchOp != NULL) {
        mSearchActivity->unregisterActivity();
        MC_SAFE_RELEASE(mSearchActivity);
        mSearchOp->cancel();
        MC_SAFE_RELEASE(mSearchOp);
        release();
    }
    if (mSearchFetchHeaderSyncStep != NULL) {
        mSearchFetchHeaderSyncStep->cancel();
        MC_SAFE_RELEASE(mSearchFetchHeaderSyncStep);
        release();
    }
    if (mSearchFetchSummarySyncStep != NULL) {
        mSearchFetchSummarySyncStep->cancel();
        MC_SAFE_RELEASE(mSearchFetchSummarySyncStep);
        release();
    }
    if (mRemoveExpiredLocalMessageSyncStep != NULL) {
        mRemoveExpiredLocalMessageSyncStep->cancel();
        MC_SAFE_RELEASE(mRemoveExpiredLocalMessageSyncStep);
        release();
    }
    if (mCopyMessagesStep != NULL) {
        mCopyMessagesStep->cancel();
        MC_SAFE_RELEASE(mCopyMessagesStep);
        release();
    }
    if (mUrgentFetchSourceStep != NULL) {
        mUrgentFetchSourceStep->cancel();
        MC_SAFE_RELEASE(mUrgentFetchSourceStep);
        release();
    }
    mMessageCount = 0;
    mUidNext = 0;
    MC_SAFE_RELEASE(mUids);
    MC_SAFE_RELEASE(mCachedUids);
    MC_SAFE_RELEASE(mUidsToFetch);
    mMaxUid = 0;
    mSummaryToFetchMessageRowIDs->removeAllObjects();
    mPartToFetchHashMap->removeAllObjects();
    mIdleInterrupted = false;
    mDisableIdleCount = 0;
    MC_SAFE_RELEASE(mSession);
    cancelDelayedPerformMethod((Object::Method) &IMAPFolderSynchronizer::refreshAfterDelay, NULL);
}

void IMAPFolderSynchronizer::handleError()
{
    mState = IMAPFolderSynchronizerStateDone;
    mDelegate->folderSynchronizerSyncStepDone(this);
}

void IMAPFolderSynchronizer::handleRecoverableError()
{
    mDelegate->folderSynchronizerSyncStepDone(this);
}

void IMAPFolderSynchronizer::failPendingRequests(hermes::ErrorCode error)
{
    {
        mc_foreacharray(Value, vMessageRowID, mSummaryToFetchMessageRowIDs) {
            delegate()->folderSynchronizerSyncFetchSummaryDone(this, error, vMessageRowID->longLongValue());
        }
    }
    {
        mc_foreacharray(Value, vMessageRowID, mSummaryToFetchMessageRowIDsUrgent) {
            delegate()->folderSynchronizerSyncFetchSummaryDone(this, error, vMessageRowID->longLongValue());
        }
    }
    {
        mc_foreacharray(HashMap, item, mPartToFetchHashMap) {
            Value * vRowID = (Value *) item->objectForKey(MCSTR("rowid"));
            String * currentPartID = (String *) item->objectForKey(MCSTR("partid"));
            delegate()->folderSynchronizerSyncFetchPartDone(this, error, vRowID->longLongValue(), currentPartID);
        }
    }
    {
        mc_foreacharray(HashMap, item, mPartToFetchHashMapUrgent) {
            Value * vRowID = (Value *) item->objectForKey(MCSTR("rowid"));
            String * currentPartID = (String *) item->objectForKey(MCSTR("partid"));
            delegate()->folderSynchronizerSyncFetchPartDone(this, error, vRowID->longLongValue(), currentPartID);
        }
    }
}

void IMAPFolderSynchronizer::markFolderAsSeen()
{
    setFolderUnseen(false);
    mailcore::Operation * op = storage()->storeLastSeenUIDOperation(storage()->folderIDForPath(folderPath()));
    op->start();
}

bool IMAPFolderSynchronizer::isFolderUnseen()
{
    return mIsUnseen;
}

void IMAPFolderSynchronizer::setFolderUnseen(bool isUnseen)
{
    if (isUnseen) {
        delegate()->folderSynchronizerNotifyUnreadEmail(this);
    }

    if (mIsUnseen == isUnseen) {
        return;
    }
    mIsUnseen = isUnseen;
    delegate()->folderSynchronizerUnseenChanged(this);
}
