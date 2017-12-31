// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMUnifiedMailStorageView.h"

#include <libetpan/libetpan.h>

#include "HMMailStorageView.h"
#include "HMUnifiedMailStorageViewObserver.h"
#include "HMUtils.h"

using namespace hermes;
using namespace mailcore;

#define UPDATE_DELAY 0.1

namespace hermes {
    class UnifiedConversationID : public Object {
    public:
        unsigned int accountIndex;
        int64_t convID;

        virtual bool isEqual(Object * otherObject)
        {
            UnifiedConversationID * otherConvID = (UnifiedConversationID *) otherObject;
            return accountIndex == otherConvID->accountIndex && convID == otherConvID->convID;
        }

        virtual unsigned int hash()
        {
            unsigned int c = 5381;

            c = ((c << 5) + c) + accountIndex;
            c = ((c << 5) + c) + (convID >> 32);
            c = ((c << 5) + c) + (convID & 0xffffffff);

            return c;
        }

        virtual Object * copy()
        {
            UnifiedConversationID * result = new UnifiedConversationID;
            result->accountIndex = accountIndex;
            result->convID = convID;
            return result;
        }
    };
}

UnifiedMailStorageView::UnifiedMailStorageView()
{
    mViews = NULL;
    mConversations = new Array();
    mObservers = carray_new(4);
    mLastUpdateTimestamp = 0;
    mModifiedConversationsIDs = new Set();
    mScheduledUpdate = false;
}

UnifiedMailStorageView::~UnifiedMailStorageView()
{
    cancelDelayedPerformMethod((Object::Method) &UnifiedMailStorageView::updateNow, NULL);
    MC_SAFE_RELEASE(mModifiedConversationsIDs);
    mc_foreacharray(MailStorageView, view, mViews) {
        view->removeObserver(this);
    }
    carray_free(mObservers);
    MC_SAFE_RELEASE(mConversations);
    MC_SAFE_RELEASE(mViews);
}

void UnifiedMailStorageView::setStorageViews(mailcore::Array * /* MailStorageView */ views)
{
    bool hasConversations = false;

    {
        mc_foreacharray(MailStorageView, view, mViews) {
            view->removeObserver(this);
        }
    }
    MC_SAFE_REPLACE_RETAIN(Array, mViews, views);
    {
        mc_foreacharray(MailStorageView, view, mViews) {
            view->addObserver(this);
            if (view->conversationsCount() > 0) {
                hasConversations = true;
            }
        }
    }

    if (hasConversations) {
        mc_foreacharray(MailStorageView, view, mViews) {
            mailStorageViewChanged(view,
                                   NULL,
                                   NULL,
                                   NULL,
                                   NULL,
                                   Array::array());
        }
    }
}

mailcore::Array * UnifiedMailStorageView::storageViews()
{
    return mViews;
}

void UnifiedMailStorageView::addObserver(UnifiedMailStorageViewObserver * observer)
{
    carray_add(mObservers, observer, NULL);
}

void UnifiedMailStorageView::removeObserver(UnifiedMailStorageViewObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            break;
        }
    }
}

unsigned int UnifiedMailStorageView::conversationsCount()
{
    return mConversations->count();
}

mailcore::HashMap * UnifiedMailStorageView::conversationsInfoAtIndex(unsigned int idx)
{
    return (HashMap *) mConversations->objectAtIndex(idx);
}

mailcore::HashMap * UnifiedMailStorageView::conversationsInfoForConversationID(unsigned int accountIndex,
                                                                               int64_t conversationID)
{
    MailStorageView * view = (MailStorageView *) mViews->objectAtIndex(accountIndex);
    HashMap * info = view->conversationsInfoForConversationID(conversationID);
    info = (HashMap *) info->copy();
    info->setObjectForKey(MCSTR("account"), Value::valueWithUnsignedIntValue(accountIndex));
    info->autorelease();
    return info;
}

bool UnifiedMailStorageView::isLoading()
{
    bool loading = false;
    mc_foreacharray(MailStorageView, view, mViews) {
        if (view->isLoading()) {
            loading = true;
        }
    }
    return loading;
}

static int compareConversation(void * a, void * b, void * context)
{
    HashMap * conversationA = (HashMap *) a;
    HashMap * conversationB = (HashMap *) b;
    Value * vDateA = (Value *) conversationA->objectForKey(MCSTR("timestamp"));
    Value * vDateB = (Value *) conversationB->objectForKey(MCSTR("timestamp"));
    int64_t delta = vDateB->longLongValue() - vDateA->longLongValue();
    //fprintf(stderr, "dateA: %lli, dateB: %lli -> %lli\n", vDateA->longLongValue(), vDateB->longLongValue(), delta);
    if (delta < 0LL) {
        return -1;
    }
    else if (delta > 0LL) {
        return 1;
    }
    else {
        Value * vIdxA = (Value *) conversationA->objectForKey(MCSTR("account"));
        Value * vIdxB = (Value *) conversationA->objectForKey(MCSTR("account"));
        int deltaIdx = (int) vIdxB->unsignedIntValue() - (int) vIdxA->unsignedIntValue();
        if (deltaIdx < 0) {
            return -1;
        }
        else if (deltaIdx > 0) {
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
}

void UnifiedMailStorageView::mailStorageViewChanged(MailStorageView * view,
                                                    mailcore::Array * deleted,
                                                    mailcore::Array * moved,
                                                    mailcore::Array * added,
                                                    mailcore::Array * modified,
                                                    mailcore::Array * modifiedIDs)
{
    int currentIndex = -1;
    mc_foreacharrayIndex(accountIdx, MailStorageView, currentView, mViews) {
        if (currentView == view) {
            currentIndex = accountIdx;
        }
    }
    MCAssert(currentIndex != -1);
    double currentTime = hermes::currentTime();
    mc_foreacharray(Value, vConvID, modifiedIDs) {
        UnifiedConversationID * convID = new UnifiedConversationID();
        convID->convID = vConvID->longLongValue();
        convID->accountIndex = currentIndex;
        mModifiedConversationsIDs->addObject(convID);
        MC_SAFE_RELEASE(convID);
    }
    if (currentTime - mLastUpdateTimestamp < UPDATE_DELAY) {
        scheduleUpdate(currentTime);
    }
    else {
        updateNow();
    }
}

void UnifiedMailStorageView::scheduleUpdate(double currentTime)
{
    if (mScheduledUpdate) {
        return;
    }
    mScheduledUpdate = true;
    performMethodAfterDelay((Object::Method) &UnifiedMailStorageView::updateNow, NULL, mLastUpdateTimestamp + UPDATE_DELAY - currentTime);
}

void UnifiedMailStorageView::updateNow()
{
    mScheduledUpdate = false;
    cancelDelayedPerformMethod((Object::Method) &UnifiedMailStorageView::updateNow, NULL);
    mLastUpdateTimestamp = hermes::currentTime();

    Array * updatedConversations = new Array();
    mc_foreacharrayIndex(accountIdx, MailStorageView, currentView, mViews) {
        for(unsigned int i = 0 ; i < currentView->conversationsCount() ; i ++) {
            HashMap * info = currentView->conversationsInfoAtIndex(i);
            info = (HashMap *) info->copy()->autorelease();
            info->setObjectForKey(MCSTR("account"), Value::valueWithUnsignedIntValue(accountIdx));
            updatedConversations->addObject(info);
        }
    }

    updatedConversations->sortArray(compareConversation, this);

    // compute diff
    Array * indexDeletions = new Array();
    Array * indexAdditions = new Array();
    Array * indexMoves = new Array();
    Array * indexModified = new Array();

    Array * lastConversationsIDs = new Array();
    {
        mc_foreacharray(HashMap, info, mConversations) {
            Value * vConvID = (Value *) info->objectForKey(MCSTR("id"));
            Value * vAccountIdx = (Value *) info->objectForKey(MCSTR("account"));
            UnifiedConversationID * convID = new UnifiedConversationID();
            convID->convID = vConvID->longLongValue();
            convID->accountIndex = vAccountIdx->unsignedIntValue();
            lastConversationsIDs->addObject(convID);
            MC_SAFE_RELEASE(convID);
        }
    }

    Array * updatedConversationsIDs = new Array();
    {
        mc_foreacharray(HashMap, info, updatedConversations) {
            Value * vConvID = (Value *) info->objectForKey(MCSTR("id"));
            Value * vAccountIdx = (Value *) info->objectForKey(MCSTR("account"));
            UnifiedConversationID * convID = new UnifiedConversationID();
            convID->convID = vConvID->longLongValue();
            convID->accountIndex = vAccountIdx->unsignedIntValue();
            updatedConversationsIDs->addObject(convID);
            MC_SAFE_RELEASE(convID);
        }
    }

    Set * lastConversationsIDsSet = new Set();
    lastConversationsIDsSet->addObjectsFromArray(lastConversationsIDs);
    Set * updatedConversationsIDsSet = new Set();
    updatedConversationsIDsSet->addObjectsFromArray(updatedConversationsIDs);

    Set * deletionsSet = new Set();
    {
        mc_foreacharray(UnifiedConversationID, vConvID, lastConversationsIDs) {
            if (!updatedConversationsIDsSet->containsObject(vConvID)) {
                deletionsSet->addObject(vConvID);
            }
        }
    }
    Set * additionsSet = new Set();
    {
        mc_foreacharray(UnifiedConversationID, vConvID, updatedConversationsIDs) {
            if (!lastConversationsIDsSet->containsObject(vConvID)) {
                additionsSet->addObject(vConvID);
            }
        }
    }

    // Deletions

    HashMap * /* UnifiedConversationID -> Value(int) */ beforeMovePositions = new HashMap();
    {
        for(int idx = (int) lastConversationsIDs->count() - 1 ; idx >= 0 ; idx --) {
            UnifiedConversationID * vConvID = (UnifiedConversationID *) lastConversationsIDs->objectAtIndex(idx);
            if (deletionsSet->containsObject(vConvID)) {
                indexDeletions->addObject(Value::valueWithIntValue(idx));
            }
        }
    }

    // Moves
    Array * /* UnifiedConversationID */ filteredUpdatedConversationsIDs = new Array();
    {
        mc_foreacharrayIndex(idx, UnifiedConversationID, vConvID, updatedConversationsIDs) {
            if (lastConversationsIDsSet->containsObject(vConvID)) {
                filteredUpdatedConversationsIDs->addObject(vConvID);
            }
        }
    }

    Array * /* UnifiedConversationID */ currentConvIDs = new Array();
    {
        mc_foreacharray(UnifiedConversationID, vConvID, lastConversationsIDs) {
            if (!deletionsSet->containsObject(vConvID)) {
                currentConvIDs->addObject(vConvID);
            }
        }
    }
    {
        mc_foreacharrayIndex(idx, UnifiedConversationID, vConvID, currentConvIDs) {
            beforeMovePositions->setObjectForKey(vConvID, Value::valueWithIntValue(idx));
        }
    }
    MCAssert(filteredUpdatedConversationsIDs->count() == currentConvIDs->count());
    {
        mc_foreacharrayIndex(idx, UnifiedConversationID, vConvID, filteredUpdatedConversationsIDs) {
            Value * vOldIndex = (Value *) beforeMovePositions->objectForKey(vConvID);
            if (vOldIndex->intValue() == idx) {
                continue;
            }
            Array * swapInfo = Array::array();
            swapInfo->addObject(vOldIndex);
            swapInfo->addObject(Value::valueWithIntValue(idx));
            indexMoves->addObject(swapInfo);

            if (idx + 1 != vOldIndex->intValue()) {
                swapInfo = Array::array();
                swapInfo->addObject(Value::valueWithIntValue(idx + 1));
                swapInfo->addObject(vOldIndex);
                indexMoves->addObject(swapInfo);
            }

            UnifiedConversationID * v1 = (UnifiedConversationID *) currentConvIDs->objectAtIndex(vOldIndex->intValue());
            v1->retain();
            UnifiedConversationID * v2 = (UnifiedConversationID *) currentConvIDs->objectAtIndex(idx);
            v2->retain();
            currentConvIDs->replaceObject(idx, v1);
            currentConvIDs->replaceObject(vOldIndex->intValue(), v2);
            v2->release();
            v1->release();

            beforeMovePositions->setObjectForKey(v2, vOldIndex);
            beforeMovePositions->setObjectForKey(v1, Value::valueWithIntValue(idx));
        }
    }

    MC_SAFE_RELEASE(currentConvIDs);
    MC_SAFE_RELEASE(filteredUpdatedConversationsIDs);

    // Additions

    mc_foreacharrayIndex(idx, UnifiedConversationID, vConvID, updatedConversationsIDs) {
        if (!lastConversationsIDsSet->containsObject(vConvID)) {
            indexAdditions->addObject(Value::valueWithIntValue(idx));
        }
    }

    {
        mc_foreacharrayIndex(idx, Value, vConvID, lastConversationsIDs) {
            if (mModifiedConversationsIDs->containsObject(vConvID)) {
                indexModified->addObject(Value::valueWithIntValue(idx));
            }
        }
    }

    MC_SAFE_REPLACE_RETAIN(Array, mConversations, updatedConversations);
    
    if (indexDeletions->count() + indexMoves->count() + indexAdditions->count() + indexModified->count() != 0) {
        notifyChangesToObserver(indexDeletions, indexMoves, indexAdditions, indexModified);
    }

    MC_SAFE_RELEASE(beforeMovePositions);

    MC_SAFE_RELEASE(additionsSet);
    MC_SAFE_RELEASE(deletionsSet);

    MC_SAFE_RELEASE(updatedConversationsIDsSet);
    MC_SAFE_RELEASE(lastConversationsIDsSet);

    MC_SAFE_RELEASE(updatedConversationsIDs);
    MC_SAFE_RELEASE(lastConversationsIDs);

    MC_SAFE_RELEASE(updatedConversations);

    MC_SAFE_RELEASE(indexDeletions);
    MC_SAFE_RELEASE(indexAdditions);
    MC_SAFE_RELEASE(indexMoves);
    MC_SAFE_RELEASE(indexModified);

    if (mModifiedConversationsIDs != NULL) {
#warning It happens for unknown reason. See https://rink.hockeyapp.net/manage/apps/253956/app_versions/52/crash_reasons/114892677
        mModifiedConversationsIDs->removeAllObjects();
    }
}

void UnifiedMailStorageView::notifyChangesToObserver(Array * deleted, Array * moved, Array * added,
                                                     Array * modified)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        UnifiedMailStorageViewObserver * observer = (UnifiedMailStorageViewObserver *) carray_get(mObservers, i);
        observer->mailStorageViewChanged(this, deleted, moved, added, modified);
    }
}
