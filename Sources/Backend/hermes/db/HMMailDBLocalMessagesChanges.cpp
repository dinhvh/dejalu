// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBLocalMessagesChanges.h"

using namespace hermes;
using namespace mailcore;

MailDBLocalMessagesChanges::MailDBLocalMessagesChanges()
{
    mAddedDeleted = new IndexSet();
    mRemovedDeleted = new IndexSet();
    mAddedFlagged = new IndexSet();
    mRemovedFlagged = new IndexSet();
    mAddedSeen = new IndexSet();
    mRemovedSeen = new IndexSet();
    mRowIDs = new IndexSet();
    mLabelsAddition = new HashMap();
    mLabelsRemoval = new HashMap();
}

MailDBLocalMessagesChanges::~MailDBLocalMessagesChanges()
{
    MC_SAFE_RELEASE(mLabelsRemoval);
    MC_SAFE_RELEASE(mLabelsAddition);
    MC_SAFE_RELEASE(mRowIDs);
    MC_SAFE_RELEASE(mRemovedSeen);
    MC_SAFE_RELEASE(mAddedSeen);
    MC_SAFE_RELEASE(mRemovedFlagged);
    MC_SAFE_RELEASE(mAddedFlagged);
    MC_SAFE_RELEASE(mRemovedDeleted);
    MC_SAFE_RELEASE(mAddedDeleted);
}

mailcore::IndexSet * MailDBLocalMessagesChanges::messagesWithAddedDeletedFlag()
{
    return mAddedDeleted;
}

mailcore::IndexSet * MailDBLocalMessagesChanges::messagesWithRemovedDeletedFlag()
{
    return mRemovedDeleted;
}

mailcore::IndexSet * MailDBLocalMessagesChanges::messagesWithAddedFlaggedFlag()
{
    return mAddedFlagged;
}

mailcore::IndexSet * MailDBLocalMessagesChanges::messagesWithRemovedFlaggedFlag()
{
    return mRemovedFlagged;
}

mailcore::IndexSet * MailDBLocalMessagesChanges::messagesWithAddedSeenFlag()
{
    return mAddedSeen;
}

mailcore::IndexSet * MailDBLocalMessagesChanges::messagesWithRemovedSeenFlag()
{
    return mRemovedSeen;
}

mailcore::HashMap * MailDBLocalMessagesChanges::labelsRemoval()
{
    return mLabelsRemoval;
}

mailcore::HashMap * MailDBLocalMessagesChanges::labelsAdditions()
{
    return mLabelsAddition;
}

void MailDBLocalMessagesChanges::setFlagsChangeForMessage(int64_t changeRowID, int64_t messageRowID, uint32_t uid, int deleted, int starred, int unread)
{
    mRowIDs->addIndex(changeRowID);
    if (deleted > 0) {
        mRemovedDeleted->removeIndex(uid);
        mAddedDeleted->addIndex(uid);
    }
    else if (deleted < 0) {
        mRemovedDeleted->addIndex(uid);
        mAddedDeleted->removeIndex(uid);
    }
    if (starred > 0) {
        mRemovedFlagged->removeIndex(uid);
        mAddedFlagged->addIndex(uid);
    }
    else if (starred < 0) {
        mRemovedFlagged->addIndex(uid);
        mAddedFlagged->removeIndex(uid);
    }
    if (unread > 0) {
        mRemovedSeen->addIndex(uid);
        mAddedSeen->removeIndex(uid);
    }
    else if (unread < 0) {
        mRemovedSeen->removeIndex(uid);
        mAddedSeen->addIndex(uid);
    }
}

IndexSet * MailDBLocalMessagesChanges::rowIDs()
{
    return mRowIDs;
}

void MailDBLocalMessagesChanges::addMessageLabel(int64_t changeRowID, int64_t messageRowID, uint32_t uid, mailcore::String * label)
{
    mRowIDs->addIndex(changeRowID);
    IndexSet * indexSet = (IndexSet *) mLabelsAddition->objectForKey(label);
    if (indexSet == NULL) {
        indexSet = IndexSet::indexSet();
        mLabelsAddition->setObjectForKey(label, indexSet);
    }
    indexSet->addIndex(uid);
    indexSet = (IndexSet *) mLabelsRemoval->objectForKey(label);
    if (indexSet != NULL) {
        indexSet->removeIndex(uid);
    }
}

void MailDBLocalMessagesChanges::removeMessageLabel(int64_t changeRowID, int64_t messageRowID, uint32_t uid, mailcore::String * label)
{
    mRowIDs->addIndex(changeRowID);
    IndexSet * indexSet = (IndexSet *) mLabelsAddition->objectForKey(label);
    if (indexSet != NULL) {
        indexSet->removeIndex(uid);
    }
    indexSet = (IndexSet *) mLabelsRemoval->objectForKey(label);
    if (indexSet == NULL) {
        indexSet = IndexSet::indexSet();
        mLabelsRemoval->setObjectForKey(label, indexSet);
    }
    indexSet->addIndex(uid);
}
