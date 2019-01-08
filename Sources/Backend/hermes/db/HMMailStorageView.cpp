// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailStorageView.h"

#include <libetpan/libetpan.h>

#include "HMMailStorage.h"
#include "HMMailDBPeopleConversationsOperation.h"
#include "HMMailDBChanges.h"
#include "HMMailStorageViewObserver.h"
#include "HMMailDBPeopleConversationInfoOperation.h"
#include "HMMailDBConversationMessagesOperation.h"
#include "HMUtils.h"
#include "DJLLog.h"

using namespace hermes;
using namespace mailcore;

#define LOG(...) DJLLogWithID("storage", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("storage", __VA_ARGS__)

MailStorageView::MailStorageView()
{
    mFolderID = -1;
    mStorage = NULL;
    mConversations = NULL;
    mConversationsToLoad = new Array();
    mLoadedConversations = new Array();
    mObservers = carray_new(4);
    mOpenedCount = 0;
    mConversationsOperation = NULL;
    mEmailSet = new Set();
    mInfoOp = NULL;
    mInfos = new HashMap();
    mNotifications = new Set();
    mDirtyConversations = new Set();
    mUpdatedConversations = new Set();
    mInboxFolderID = -1;
    mAllMailFolderID = -1;
    mArchiveFolderID = -1;
    mDraftsFolderID = -1;
    mTrashFolderID = -1;
    mSentFolderID = -1;
    mSpamFolderID = -1;
    mKeywords = NULL;
    mNeedsReloadConversations = false;
    mLoadingConversations = false;
    mUpdateSearchResultScheduled = false;
    mStartTime = 0;
//    mToday2am = 0;
    mStandardFolders = NULL;
}

MailStorageView::~MailStorageView()
{
    MC_SAFE_RELEASE(mStandardFolders);
    MC_SAFE_RELEASE(mKeywords);
    MC_SAFE_RELEASE(mUpdatedConversations);
    MC_SAFE_RELEASE(mDirtyConversations);
    MC_SAFE_RELEASE(mNotifications);
    MC_SAFE_RELEASE(mInfos);
    MC_SAFE_RELEASE(mInfoOp);
    MC_SAFE_RELEASE(mEmailSet);
    MC_SAFE_RELEASE(mConversationsOperation);
    carray_free(mObservers);
    MC_SAFE_RELEASE(mLoadedConversations);
    MC_SAFE_RELEASE(mConversationsToLoad);
    MC_SAFE_RELEASE(mConversations);
    MC_SAFE_RELEASE(mStorage);
}

#if 0
Object * MailStorageView::retain()
{
    Object::retain();
    LOG_ERROR_STACK("*** %p retain mailstorageview %i\n", this, retainCount());
    return this;
}

void MailStorageView::release()
{
    LOG_ERROR_STACK("*** %p release mailstorageview %i\n", this, retainCount() - 1);
    if (retainCount() == 1) {
        LOG_ERROR_STACK("*** %p dealloc mailstorageview\n", this);
    }
    Object::release();
}
#endif

Set * MailStorageView::emailSet()
{
    return mEmailSet;
}

void MailStorageView::setEmailSet(Set * emailSet)
{
    MCAssert(emailSet != NULL);
    MC_SAFE_REPLACE_RETAIN(Set, mEmailSet, emailSet);
}

void MailStorageView::open()
{
    mOpenedCount ++;
    if (mOpenedCount == 1) {
        fetchConversations();
    }
}

void MailStorageView::close()
{
    mOpenedCount --;
    if (mOpenedCount == 0) {
        cancel();
    }
}

void MailStorageView::cancel()
{
    cancelLoadNextInfo();
    cancelFetchConversations();
}

unsigned int MailStorageView::openedCount()
{
    return mOpenedCount;
}

int64_t MailStorageView::folderID()
{
    return mFolderID;
}

void MailStorageView::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

Array * MailStorageView::keywords()
{
    return mKeywords;
}

void MailStorageView::setKeywords(Array * keywords)
{
    MC_SAFE_REPLACE_RETAIN(Array, mKeywords, keywords);
}

MailStorage * MailStorageView::storage()
{
    return mStorage;
}

void MailStorageView::setStorage(MailStorage * storage)
{
    MC_SAFE_REPLACE_RETAIN(MailStorage, mStorage, storage);
}

int64_t MailStorageView::inboxFolderID()
{
    return mInboxFolderID;
}

void MailStorageView::setInboxFolderID(int64_t folderID)
{
    mInboxFolderID = folderID;
}

int64_t MailStorageView::allMailFolderID()
{
    return mAllMailFolderID;
}

void MailStorageView::setAllMailFolderID(int64_t folderID)
{
    mAllMailFolderID = folderID;
}

int64_t MailStorageView::archiveFolderID()
{
    return mArchiveFolderID;
}

void MailStorageView::setArchiveFolderID(int64_t folderID)
{
    mArchiveFolderID = folderID;
}

int64_t MailStorageView::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailStorageView::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

int64_t MailStorageView::trashFolderID()
{
    return mTrashFolderID;
}

int64_t MailStorageView::spamFolderID()
{
    return mSpamFolderID;
}

void MailStorageView::setSpamFolderID(int64_t folderID)
{
    mSpamFolderID = folderID;
}

void MailStorageView::setTrashFolderID(int64_t folderID)
{
    mTrashFolderID = folderID;
}

int64_t MailStorageView::sentFolderID()
{
    return mSentFolderID;
}

void MailStorageView::setSentFolderID(int64_t folderID)
{
    mSentFolderID = folderID;
}

mailcore::HashMap * MailStorageView::standardFolders()
{
    return mStandardFolders;
}

void MailStorageView::setStandardFolders(mailcore::HashMap * standardFolders)
{
    MC_SAFE_REPLACE_RETAIN(HashMap, mStandardFolders, standardFolders);
}

time_t MailStorageView::ageLimit()
{
    return mAgeLimit;
}

void MailStorageView::setAgeLimit(time_t ageLimit)
{
    mAgeLimit = ageLimit;
}

void MailStorageView::addObserver(MailStorageViewObserver * observer)
{
    LOGSTACK("add observer %p", observer);
    carray_add(mObservers, observer, NULL);
}

void MailStorageView::removeObserver(MailStorageViewObserver * observer)
{
    LOGSTACK("remove observer %p", observer);
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            LOG("found observer to remove");
            carray_delete(mObservers, i);
            break;
        }
    }
}

unsigned int MailStorageView::conversationsCount()
{
    return mLoadedConversations->count();
}

HashMap * MailStorageView::conversationsInfoAtIndex(unsigned int idx)
{
    if (idx >= mLoadedConversations->count()) {
        LOG("requesting index %i (%i conversations)", idx, mLoadedConversations->count());
        LOG("going to crash");
        MCAssert(0);
    }
    HashMap * info = (HashMap *) mLoadedConversations->objectAtIndex(idx);
    Value * vConvID = (Value *) info->objectForKey(MCSTR("id"));
    return (HashMap *) mInfos->objectForKey(vConvID);
}

HashMap * MailStorageView::conversationsInfoForConversationID(int64_t conversationID)
{
    return (HashMap *) mInfos->objectForKey(Value::valueWithLongLongValue(conversationID));
}

// operation callback

void MailStorageView::operationFinished(Operation * op)
{
    if (op == mConversationsOperation) {
        LOG("op finished fetch conversations %p %i\n", this, this->retainCount());
        fetchConversationsDone();
    }
    else if (op == mInfoOp) {
        loadInfoFinished();
    }
}

// fetch conversations

void MailStorageView::fetchConversations()
{
    if ((mKeywords == NULL) && (mFolderID == -1)) {
        return;
    }

    mStartTime = hermes::currentTime();
//    struct tm timeinfo;
//    time_t currentTime = time(NULL);
//    gmtime_r(&currentTime, &timeinfo);
//    timeinfo.tm_hour = 2;
//    timeinfo.tm_min = 0;
//    timeinfo.tm_sec = 0;
//    mToday2am = mktime(&timeinfo);
    mLoadingConversations = true;
    retain();
    if (mKeywords != NULL) {
        mConversationsOperation = mStorage->peopleConversationsForKeywords(mKeywords);
    }
    else {
        mConversationsOperation = mStorage->peopleConversationsOperation(mFolderID);
    }
    mConversationsOperation->retain();
    mConversationsOperation->setCallback(this);
    mConversationsOperation->start();
}

void MailStorageView::fetchConversationsDone()
{
    MC_SAFE_REPLACE_RETAIN(Array, mConversations, mConversationsOperation->conversations());
    MC_SAFE_RELEASE(mConversationsOperation);
    mLoadingConversations = false;
    
    if (mNeedsReloadConversations) {
        fetchConversations();
        release();
        return;
    }

    if (mOpenedCount > 0) {
        startLoadingInfos();
    }
    
    release();
}

void MailStorageView::cancelFetchConversations()
{
    if (mConversationsOperation != NULL) {
        mConversationsOperation->cancel();
        MC_SAFE_RELEASE(mConversationsOperation);
        release();
    }
}

// fetch conv info

void MailStorageView::startLoadingInfos()
{
    if (mLoadingInfo) {
        cancelLoadNextInfo();
    }
    
    mLoadIndex = 0;
    mConversationsToLoad->removeAllObjects();
    //fprintf(stderr, "existing %s\n", MCUTF8(mInfos->allKeys()));
    //fprintf(stderr, "dirty: %s\n", MCUTF8(mDirtyConversations));
    mc_foreacharray(HashMap, info, mConversations) {
        Value * vConvID = (Value *) info->objectForKey(MCSTR("id"));
        if ((mInfos->objectForKey(vConvID) == NULL) || mDirtyConversations->containsObject(vConvID)) {
            if (!mNotifications->containsObject(vConvID)) {
                mConversationsToLoad->addObject(vConvID);
            }
        }
    }

    loadNextInfo();
}

void MailStorageView::cancelLoadNextInfo()
{
    if (mInfoOp != NULL) {
        mInfoOp->cancel();
        MC_SAFE_RELEASE(mInfoOp);
        release();
    }
}

HashMap * MailStorageView::foldersScores()
{
    HashMap * foldersScores = HashMap::hashMap();
    foldersScores->setObjectForKey(Value::valueWithLongLongValue(mFolderID),
                                   Value::valueWithIntValue(2));
    if ((mFolderID == mTrashFolderID) || (mFolderID == mSpamFolderID)) {
        foldersScores->setObjectForKey(Value::valueWithLongLongValue(-1),
                                       Value::valueWithIntValue(-1));
    }
    else {
        if (mAllMailFolderID != -1) {
            foldersScores->setObjectForKey(Value::valueWithLongLongValue(mAllMailFolderID),
                                           Value::valueWithIntValue(1));
        }
        if (mArchiveFolderID != -1) {
            foldersScores->setObjectForKey(Value::valueWithLongLongValue(mArchiveFolderID),
                                           Value::valueWithIntValue(1));
        }
        if ((mTrashFolderID != -1) && (mFolderID != mTrashFolderID)) {
            foldersScores->setObjectForKey(Value::valueWithLongLongValue(mTrashFolderID),
                                           Value::valueWithIntValue(-1));
        }
        if ((mSpamFolderID != -1) && (mFolderID != mSpamFolderID)) {
            foldersScores->setObjectForKey(Value::valueWithLongLongValue(mSpamFolderID),
                                           Value::valueWithIntValue(-1));
        }
        if ((mDraftsFolderID != -1) && (mFolderID != mDraftsFolderID)) {
            foldersScores->setObjectForKey(Value::valueWithLongLongValue(mDraftsFolderID),
                                           Value::valueWithIntValue(-1));
        }
    }
    return foldersScores;
}

mailcore::Set * MailStorageView::foldersToExcludeFromUnread()
{
    Set * result = Set::set();
    if (mFolderID == mInboxFolderID) {
        if (mAllMailFolderID != -1) {
            result->addObject(Value::valueWithLongLongValue(mAllMailFolderID));
        }
        if (mArchiveFolderID != -1) {
            result->addObject(Value::valueWithLongLongValue(mArchiveFolderID));
        }
        if (mDraftsFolderID != -1) {
            result->addObject(Value::valueWithLongLongValue(mDraftsFolderID));
        }
        if (mSentFolderID != -1) {
            result->addObject(Value::valueWithLongLongValue(mSentFolderID));
        }
    }
    return result;
}

void MailStorageView::loadNextInfo()
{
    if (mLoadIndex >= mConversationsToLoad->count()) {
        loadingInfosFinished();
        return;
    }
    
    retain();
    Value * vConvID = (Value *) mConversationsToLoad->objectAtIndex(mLoadIndex);
    
    mLoadingInfo = true;
    mInfoOp = mStorage->peopleConversationInfoOperation(vConvID->longLongValue(),
                                                        foldersScores(),
                                                        mInboxFolderID,
                                                        mEmailSet,
                                                        foldersToExcludeFromUnread());
    mInfoOp->retain();
    mInfoOp->setCallback(this);
    mInfoOp->start();
}

#if 0
static int compareLabels(void * a, void * b, void * context)
{
    String * strA = (String *) a;
    String * strB = (String *) b;
    return strA->lowercaseString()->compare(strB->lowercaseString());
}
#endif

void MailStorageView::loadInfoFinished()
{
    HashMap * info = mInfoOp->conversationInfo();
    //Value * vIsNotification = (Value *) info->objectForKey(MCSTR("notification"));
    Value * vConvID = Value::valueWithLongLongValue(mInfoOp->conversationID());
//    if (vConvID->longLongValue() == 10) {
//        fprintf(stderr, "updated %s\n", MCUTF8(info));
//    }

#if 0 // don't merge folders
    Set * labelsSet = Set::setWithArray((Array *) info->objectForKey(MCSTR("labels")));
    mc_foreacharray(Value, vFolderID, (Array *) info->objectForKey(MCSTR("folders"))) {
        String * label = (String *) mStandardFolders->objectForKey(vFolderID);
        if (label != NULL) {
            labelsSet->addObject(label);
        }
        else {
            label = mStorage->pathForFolderID(vFolderID->longLongValue());
            if (label != NULL) {
                labelsSet->addObject(label);
            }
        }
    }
    Array * labels = labelsSet->allObjects()->sortedArray(compareLabels, NULL);
    info->setObjectForKey(MCSTR("labels"), labels);
#endif
    info->removeObjectForKey(MCSTR("folders"));

    if (mFolderID == mTrashFolderID) {
        info->setObjectForKey(MCSTR("trash"), Value::valueWithBoolValue(true));
    }

#if 0
    if (!vIsNotification->boolValue()) {
        if (mInfos->objectForKey(vConvID) != NULL) {
            mUpdatedConversations->addObject(vConvID);
        }
        mInfos->setObjectForKey(vConvID, info);
    }
    else {
        mNotifications->addObject(vConvID);
    }
#else
    bool skip = false;

#if 0
    if (!((Value *) info->objectForKey(MCSTR("hasattachment")))->boolValue()) {
        skip = true;
    }
#endif
#if 0
    time_t convTimestamp = (time_t) ((Value *) info->objectForKey(MCSTR("timestamp")))->longLongValue();
    if (convTimestamp < mToday2am) {
        skip = true;
    }
#endif
    if (mAgeLimit != 0) {
        if (info->objectForKey(MCSTR("timestamp")) != NULL) {
            time_t convTimestamp = (time_t) ((Value *) info->objectForKey(MCSTR("timestamp")))->longLongValue();
            if (mStartTime - convTimestamp > mAgeLimit) {
                skip = true;
            }
        }
    }

    if (!skip) {
        // The number of messages can be zero if a message has been found in trash.
        // In this case, we skip the conversation.
        if (((Array *) info->objectForKey(MCSTR("messages")))->count() > 0) {
            if (mInfos->objectForKey(vConvID) != NULL) {
                mUpdatedConversations->addObject(vConvID);
            }
            mInfos->setObjectForKey(vConvID, info);
        }
    }
#endif
    mDirtyConversations->removeObject(vConvID);
    MC_SAFE_RELEASE(mInfoOp);
    mLoadingInfo = false;
    
    if (mOpenedCount > 0) {
        mLoadIndex ++;

        //fprintf(stderr, "loaded info %i - %lli\n", mLoadIndex, vConvID->longLongValue());
        if (mLoadIndex < mConversationsToLoad->count()) {
            double currentTime = hermes::currentTime();
            if (currentTime - mStartTime > 0.5) {
                loadedConversationsUpdated();
                mStartTime = currentTime;
            }
#if 0
            if (mLoadIndex % 50 == 0) {
                loadedConversationsUpdated();
            }
#endif
        }
        
        loadNextInfo();
    }
    release();
}

void MailStorageView::loadingInfosFinished()
{
    //fprintf(stderr, "loaded info finished\n");
    loadedConversationsUpdated();
}

static int compareConversation(void * a, void * b, void * context)
{
    HashMap * conversationA = (HashMap *) a;
    HashMap * conversationB = (HashMap *) b;
#if 0
    Value * vUnreadA = (Value *) conversationA->objectForKey(MCSTR("unread"));
    Value * vUnreadB = (Value *) conversationB->objectForKey(MCSTR("unread"));
    if (vUnreadA->boolValue() != vUnreadB->boolValue()) {
        if (vUnreadA->boolValue()) {
            return -1;
        }
        else {
            return 1;
        }
    }
#endif
    Value * vDateA = (Value *) conversationA->objectForKey(MCSTR("date"));
    Value * vDateB = (Value *) conversationB->objectForKey(MCSTR("date"));
    int64_t delta = vDateB->longLongValue() - vDateA->longLongValue();
    //fprintf(stderr, "dateA: %lli, dateB: %lli -> %lli\n", vDateA->longLongValue(), vDateB->longLongValue(), delta);
    if (delta < 0LL) {
        return -1;
    }
    else if (delta > 0LL) {
        return 1;
    }
    else {
        Value * vIDA = (Value *) conversationA->objectForKey(MCSTR("id"));
        Value * vIDB = (Value *) conversationB->objectForKey(MCSTR("id"));
        int64_t idDelta = vIDB->longLongValue() - vIDA->longLongValue();
        if (idDelta < 0LL) {
            return 1;
        }
        else if (idDelta > 0LL) {
            return -1;
        }
        else {
            return 0;
        }
    }
}

void MailStorageView::notifyChangesToObserver(Array * deleted, Array * moved, Array * added,
                                              Array * modified, Array * modifiedIDs)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        MailStorageViewObserver * observer = (MailStorageViewObserver *) carray_get(mObservers, i);
        LOG("notify %i/%i %p", i, carray_count(mObservers), observer);
        observer->mailStorageViewChanged(this, deleted, moved, added, modified, modifiedIDs);
    }
}

void MailStorageView::notifyModifiedDeletedConversationsToObserver(mailcore::Array * modified, mailcore::Array * deleted)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        MailStorageViewObserver * observer = (MailStorageViewObserver *) carray_get(mObservers, i);
        observer->mailStorageViewModifiedDeletedConversations(this, modified, deleted);
    }
}

void MailStorageView::loadedConversationsUpdated()
{
    Array * indexDeletions = new Array();
    Array * indexAdditions = new Array();
    Array * indexMoves = new Array();
    Array * indexModified = new Array();
    
    Array * lastConversationsIDs = new Array();
    {
        mc_foreacharray(HashMap, info, mLoadedConversations) {
            lastConversationsIDs->addObject(info->objectForKey(MCSTR("id")));
        }
    }
    
    Array * updatedConversationsIDs = new Array();
    mLoadedConversations->removeAllObjects();
    {
        mc_foreacharray(HashMap, info, mConversations) {
            Value * vConvID = (Value *) info->objectForKey(MCSTR("id"));
            HashMap * convInfo = (HashMap *) mInfos->objectForKey(vConvID);
            if (convInfo != NULL) {
                mLoadedConversations->addObject(convInfo);
                updatedConversationsIDs->addObject(vConvID);
            }
        }
    }
    
    Set * lastConversationsIDsSet = new Set();
    lastConversationsIDsSet->addObjectsFromArray(lastConversationsIDs);
    Set * updatedConversationsIDsSet = new Set();
    updatedConversationsIDsSet->addObjectsFromArray(updatedConversationsIDs);
    
    LOG("previous convs: %s", MCUTF8DESC(lastConversationsIDs));
    LOG("next convs: %s", MCUTF8DESC(updatedConversationsIDs));
    
    Set * deletionsSet = new Set();
    {
        mc_foreacharray(Value, vConvID, lastConversationsIDs) {
            if (!updatedConversationsIDsSet->containsObject(vConvID)) {
                deletionsSet->addObject(vConvID);
            }
        }
    }
    Set * additionsSet = new Set();
    {
        mc_foreacharray(Value, vConvID, updatedConversationsIDs) {
            if (!lastConversationsIDsSet->containsObject(vConvID)) {
                additionsSet->addObject(vConvID);
            }
        }
    }
    
    // Deletions
    
    HashMap * beforeMovePositions = new HashMap();
    {
        for(int idx = (int) lastConversationsIDs->count() - 1 ; idx >= 0 ; idx --) {
            Value * vConvID = (Value *) lastConversationsIDs->objectAtIndex(idx);
            if (deletionsSet->containsObject(vConvID)) {
                indexDeletions->addObject(Value::valueWithIntValue(idx));
            }
        }
    }
    
    // Moves
    Array * filteredUpdatedConversationsIDs = new Array();
    {
        mc_foreacharrayIndex(idx, Value, vConvID, updatedConversationsIDs) {
            if (lastConversationsIDsSet->containsObject(vConvID)) {
                filteredUpdatedConversationsIDs->addObject(vConvID);
            }
        }
    }
    
    Array * currentConvIDs = new Array();
    {
        mc_foreacharray(Value, vConvID, lastConversationsIDs) {
            if (!deletionsSet->containsObject(vConvID)) {
                currentConvIDs->addObject(vConvID);
            }
        }
    }
    {
        mc_foreacharrayIndex(idx, Value, vConvID, currentConvIDs) {
            beforeMovePositions->setObjectForKey(vConvID, Value::valueWithIntValue(idx));
        }
    }
    if (filteredUpdatedConversationsIDs->count() != currentConvIDs->count()) {
        LOG("last convs: %s", MCUTF8DESC(lastConversationsIDs));
        LOG("updated convs: %s", MCUTF8DESC(updatedConversationsIDs));
        LOG("filtered updated conv: %s", MCUTF8DESC(filteredUpdatedConversationsIDs));
        LOG("current conv: %s", MCUTF8DESC(currentConvIDs));
    }
    MCAssert(filteredUpdatedConversationsIDs->count() == currentConvIDs->count());
    {
        //fprintf(stderr, "%s\n", MCUTF8DESC(currentConvIDs));
        mc_foreacharrayIndex(idx, Value, vConvID, filteredUpdatedConversationsIDs) {
            Value * vOldIndex = (Value *) beforeMovePositions->objectForKey(vConvID);
            if (vOldIndex->intValue() == idx) {
                continue;
            }
            //fprintf(stderr, "%s\n", MCUTF8DESC(beforeMovePositions));
            Array * swapInfo = Array::array();
            swapInfo->addObject(vOldIndex);
            swapInfo->addObject(Value::valueWithIntValue(idx));
            indexMoves->addObject(swapInfo);
            //fprintf(stderr, "%s\n", MCUTF8DESC(swapInfo));
            
            if (idx + 1 != vOldIndex->intValue()) {
                swapInfo = Array::array();
                swapInfo->addObject(Value::valueWithIntValue(idx + 1));
                swapInfo->addObject(vOldIndex);
                indexMoves->addObject(swapInfo);
                //fprintf(stderr, "%s\n", MCUTF8DESC(swapInfo));
            }
            
            Value * v1 = (Value *) currentConvIDs->objectAtIndex(vOldIndex->intValue());
            v1->retain();
            Value * v2 = (Value *) currentConvIDs->objectAtIndex(idx);
            v2->retain();
            currentConvIDs->replaceObject(idx, v1);
            currentConvIDs->replaceObject(vOldIndex->intValue(), v2);
            v2->release();
            v1->release();
            
            //fprintf(stderr, "%s\n", MCUTF8DESC(currentConvIDs));
            
            beforeMovePositions->setObjectForKey(v2, vOldIndex);
            beforeMovePositions->setObjectForKey(v1, Value::valueWithIntValue(idx));
        }
    }
    
    MC_SAFE_RELEASE(currentConvIDs);
    MC_SAFE_RELEASE(filteredUpdatedConversationsIDs);
    
    // Additions
    
    mc_foreacharrayIndex(idx, Value, vConvID, updatedConversationsIDs) {
        if (!lastConversationsIDsSet->containsObject(vConvID)) {
            indexAdditions->addObject(Value::valueWithIntValue(idx));
        }
    }
    
    {
        mc_foreacharrayIndex(idx, Value, vConvID, lastConversationsIDs) {
            if (mUpdatedConversations->containsObject(vConvID)) {
                indexModified->addObject(Value::valueWithIntValue(idx));
            }
        }
    }
    Array * modifiedConversationsIDs = (Array *) mUpdatedConversations->allObjects();
    mUpdatedConversations->removeAllObjects();
    
    LOG("notify conv:");
    LOG("deletions: %s",  MCUTF8DESC(indexDeletions));
    LOG("moves: %s",  MCUTF8DESC(indexMoves));
    LOG("added: %s",  MCUTF8DESC(indexAdditions));
    LOG("modified: %s",  MCUTF8DESC(indexModified));
    
    if (indexDeletions->count() + indexMoves->count() + indexAdditions->count() + indexModified->count() != 0) {
        notifyChangesToObserver(indexDeletions, indexMoves, indexAdditions, indexModified, modifiedConversationsIDs);
    }

    MC_SAFE_RELEASE(beforeMovePositions);
    
    MC_SAFE_RELEASE(additionsSet);
    MC_SAFE_RELEASE(deletionsSet);
    
    MC_SAFE_RELEASE(updatedConversationsIDsSet);
    MC_SAFE_RELEASE(lastConversationsIDsSet);
    
    MC_SAFE_RELEASE(updatedConversationsIDs);
    MC_SAFE_RELEASE(lastConversationsIDs);

    MC_SAFE_RELEASE(indexDeletions);
    MC_SAFE_RELEASE(indexAdditions);
    MC_SAFE_RELEASE(indexMoves);
    MC_SAFE_RELEASE(indexModified);
}

void MailStorageView::notifyChanges(MailDBChanges * changes)
{
    notifyStoredParts(changes->addedMessageParts());
    if (mKeywords != NULL) {
        notifyChangesForSearch(changes);
    }
    else if (mFolderID != -1) {
        notifyChangesForFolder(changes);
    }
    if (changes->changedFoldersIDs()->count() > 0) {
        notifyChangesForFolderCount(changes->changedFoldersIDs());
    }
    if (changes->notifiedMessages()->count() > 0) {
        notifyMessages(changes->notifiedMessages());
    }
}

void MailStorageView::notifyChangesForFolderCount(mailcore::Array * foldersIDs)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        MailStorageViewObserver * observer = (MailStorageViewObserver *) carray_get(mObservers, i);
        observer->mailStorageFoldersCountsChanged(this, foldersIDs);
    }
}

void MailStorageView::notifyMessages(mailcore::Array * notifiedMessages)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        MailStorageViewObserver * observer = (MailStorageViewObserver *) carray_get(mObservers, i);
        observer->mailStorageNotifyMessages(this, notifiedMessages);
    }
}

void MailStorageView::notifyChangesForSearch(MailDBChanges * changes)
{
    Array * added = changes->addedPeopleViewIDs();
    Array * removed = changes->removedPeopleViewIDs();
    Array * modified = changes->modifiedPeopleViewIDs();
    
    if ((added->count() == 0) && (removed->count() == 0) && (modified->count() == 0)) {
        return;
    }

    notifyModifiedDeletedConversationsToObserver(modified, removed);

    LOG("db changes for search:");
    LOG("%s", MCUTF8DESC(changes));
    LOG("added: %s", MCUTF8DESC(added));
    LOG("removed: %s", MCUTF8DESC(removed));
    LOG("modified: %s", MCUTF8DESC(modified));
    //virtual mailcore::IndexSet * peopleViewIDsForKeywords(mailcore::Array * keywords);

    //fprintf(stderr, "search update %i %i %i\n", added->count(), removed->count(), modified->count());
    //notifyChangesToObserver(Array::array(), Array::array(), Array::array(), modified);
    mDirtyConversations->addObjectsFromArray(modified);
    startLoadingInfos();
    
    if (mUpdateSearchResultScheduled) {
        return;
    }
    
    mUpdateSearchResultScheduled = true;
    cancelDelayedPerformMethod((Object::Method) &MailStorageView::updateSearchResultAfterDelay, NULL);
    performMethodAfterDelay((Object::Method) &MailStorageView::updateSearchResultAfterDelay, NULL, 5.0);
}

void MailStorageView::notifyStoredParts(mailcore::Array * /* MailDBMessagePartInfo */ messageParts)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        MailStorageViewObserver * observer = (MailStorageViewObserver *) carray_get(mObservers, i);
        observer->mailStorageViewAddedMessageParts(this, messageParts);
    }
}

void MailStorageView::updateSearchResultAfterDelay(void * context)
{
    mUpdateSearchResultScheduled = false;
    if (mLoadingConversations) {
        mNeedsReloadConversations = true;
    }
    else {
        fetchConversations();
    }
}

void MailStorageView::notifyChangesForFolder(MailDBChanges * changes)
{
    Array * added = changes->addedConversationsForFolder(mFolderID);
    Array * removed = changes->removedConversationsForFolder(mFolderID);
    Array * modified = changes->modifiedPeopleViewIDs();
    
    if ((added == NULL) && (removed == NULL) && (modified->count() == 0)) {
        return;
    }
    
    notifyModifiedDeletedConversationsToObserver(modified, removed);
    
    LOG("db changes folder folder:");
    LOG("%s", MCUTF8DESC(changes));
    LOG("added: %s", MCUTF8DESC(added));
    LOG("removed: %s", MCUTF8DESC(removed));
    LOG("modified: %s", MCUTF8DESC(modified));
    
    mDirtyConversations->addObjectsFromArray(modified);
    
    Set * removedSet = new Set();
    removedSet->addObjectsFromArray(removed);
    Set * modifiedSet = new Set();
    modifiedSet->addObjectsFromArray(modified);
    
    Array * conversations = new Array();
    
    {
        mc_foreacharray(HashMap, info, mConversations) {
            Value * vConvID = (Value *) info->objectForKey(MCSTR("id"));
            if (modifiedSet->containsObject(vConvID)) {
                time_t date = changes->dateForPeopleViewID(vConvID->longLongValue());
                info->setObjectForKey(MCSTR("date"), Value::valueWithLongLongValue(date));
            }
            if (removedSet->containsObject(vConvID)) {
                continue;
            }
            conversations->addObject(info);
        }
    }
    
    LOG("conversations(1): %s", MCUTF8DESC(conversations));
    
    if (added != NULL) {
        mc_foreacharray(Value, vConvID, added) {
            HashMap * info = HashMap::hashMap();
            time_t date = changes->dateForPeopleViewID(vConvID->longLongValue());
            //bool unread = changes->unreadForPeopleViewID(vConvID->longLongValue());
            info->setObjectForKey(MCSTR("id"), vConvID);
            info->setObjectForKey(MCSTR("date"), Value::valueWithLongLongValue(date));
            //info->setObjectForKey(MCSTR("unread"), Value::valueWithBoolValue(unread));
            conversations->addObject(info);
        }
    }
    LOG("conversations(2): %s", MCUTF8DESC(conversations));
    
    conversations->sortArray(compareConversation, this);
    LOG("conversations(3): %s", MCUTF8DESC(conversations));
    //fprintf(stderr, "sorted: %s\n", MCUTF8DESC(conversations));
    
    MC_SAFE_REPLACE_RETAIN(Array, mConversations, conversations);
    
    MC_SAFE_RELEASE(modifiedSet);
    MC_SAFE_RELEASE(removedSet);
    MC_SAFE_RELEASE(conversations);
    
    loadedConversationsUpdated();
    
    startLoadingInfos();
}

MailDBConversationMessagesOperation * MailStorageView::messagesForPeopleConversationOperation(int64_t conversationID)
{
    return mStorage->messagesForPeopleConversationOperation(conversationID, foldersScores());
}

bool MailStorageView::isLoading()
{
    return mLoadingConversations || (mLoadIndex < mConversationsToLoad->count());
}
