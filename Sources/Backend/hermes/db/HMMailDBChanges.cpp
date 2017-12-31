// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBChanges.h"

#include "HMMailDBMessagePartInfo.h"

using namespace hermes;
using namespace mailcore;

// TODO: allow cumulation of changes.

MailDBChanges::MailDBChanges()
{
    mAddedPeopleViewIDs = new Set();
    mModifiedPeopleViewIDs = new Set();
    mRemovedPeopleViewIDs = new Set();
    mConversationsDates = new HashMap();
    mFoldersAddedConversations = new HashMap();
    mFoldersRemovedConversations = new HashMap();
    mExistedBefore = new HashMap();
    mDidntExistBefore = new HashMap();
    mFoldersNeedsPushFlags = new IndexSet();
    mAddedParts = new Array();
    mUnseenFolders = new IndexSet();
    mFolderCountChanges = new HashMap();
    mNotifiedMessages = new Array();
    mPeopleViewCountChanged = new IndexSet();
    mMessageIDsToRemoveFromSendQueue = new Set();
}

MailDBChanges::~MailDBChanges()
{
    MC_SAFE_RELEASE(mMessageIDsToRemoveFromSendQueue);
    MC_SAFE_RELEASE(mPeopleViewCountChanged);
    MC_SAFE_RELEASE(mFolderCountChanges);
    MC_SAFE_RELEASE(mUnseenFolders);
    MC_SAFE_RELEASE(mAddedParts);
    MC_SAFE_RELEASE(mFoldersNeedsPushFlags);
    MC_SAFE_RELEASE(mDidntExistBefore);
    MC_SAFE_RELEASE(mExistedBefore);
    MC_SAFE_RELEASE(mFoldersRemovedConversations);
    MC_SAFE_RELEASE(mFoldersAddedConversations);
    MC_SAFE_RELEASE(mConversationsDates);
    MC_SAFE_RELEASE(mRemovedPeopleViewIDs);
    MC_SAFE_RELEASE(mModifiedPeopleViewIDs);
    MC_SAFE_RELEASE(mAddedPeopleViewIDs);
    MC_SAFE_RELEASE(mNotifiedMessages);
}

void MailDBChanges::addPeopleViewID(int64_t conversationID, int64_t date)
{
    Value * vConvID = Value::valueWithLongLongValue(conversationID);
    mAddedPeopleViewIDs->addObject(vConvID);
    if (date != -1) {
        mConversationsDates->setObjectForKey(vConvID, Value::valueWithLongLongValue(date));
    }
}

void MailDBChanges::modifyPeopleViewID(int64_t conversationID, int64_t date)
{
    Value * vConvID = Value::valueWithLongLongValue(conversationID);
    if (mAddedPeopleViewIDs->containsObject(vConvID)) {
        if (date != -1) {
            mConversationsDates->setObjectForKey(vConvID, Value::valueWithLongLongValue(date));
        }
        return;
    }
    mModifiedPeopleViewIDs->addObject(vConvID);
    if (date != -1) {
        mConversationsDates->setObjectForKey(vConvID, Value::valueWithLongLongValue(date));
    }
}

void MailDBChanges::removePeopleViewID(int64_t conversationID)
{
    Value * vConvID = Value::valueWithLongLongValue(conversationID);
    mAddedPeopleViewIDs->removeObject(vConvID);
    mModifiedPeopleViewIDs->removeObject(vConvID);
    mRemovedPeopleViewIDs->addObject(vConvID);
}

Array * MailDBChanges::addedPeopleViewIDs()
{
    return mAddedPeopleViewIDs->allObjects();
}

Array * MailDBChanges::modifiedPeopleViewIDs()
{
    return mModifiedPeopleViewIDs->allObjects();
}

Array * MailDBChanges::removedPeopleViewIDs()
{
    return mRemovedPeopleViewIDs->allObjects();
}

IndexSet * MailDBChanges::foldersNeedPushFlags()
{
    return mFoldersNeedsPushFlags;
}

void MailDBChanges::addFolderForConversation(int64_t peopleViewID, int64_t folderID)
{
    Value * vFolderID = Value::valueWithLongLongValue(folderID);
    Set * conversations = (Set *) mFoldersAddedConversations->objectForKey(vFolderID);
    Value * vPeopleViewID = Value::valueWithLongLongValue(peopleViewID);
    if (conversations != NULL) {
        conversations->removeObject(vPeopleViewID);
    }
    
    conversations = (Set *) mExistedBefore->objectForKey(vFolderID);
    if ((conversations == NULL) || !conversations->containsObject(vPeopleViewID)) {
        conversations = (Set *) mDidntExistBefore->objectForKey(vFolderID);
        if (conversations == NULL) {
            conversations = Set::set();
            mDidntExistBefore->setObjectForKey(vFolderID, conversations);
        }
        conversations->addObject(vPeopleViewID);
        
        conversations = (Set *) mFoldersAddedConversations->objectForKey(vFolderID);
        if (conversations == NULL) {
            conversations = Set::set();
            mFoldersAddedConversations->setObjectForKey(vFolderID, conversations);
        }
        conversations->addObject(vPeopleViewID);
    }
    
    conversations = (Set *) mFoldersRemovedConversations->objectForKey(vFolderID);
    if (conversations != NULL) {
        conversations->removeObject(vPeopleViewID);
    }
}

void MailDBChanges::removeFolderFromConversation(int64_t peopleViewID, int64_t folderID)
{
    Value * vFolderID = Value::valueWithLongLongValue(folderID);
    Set * conversations = (Set *) mFoldersRemovedConversations->objectForKey(vFolderID);
    Value * vPeopleViewID = Value::valueWithLongLongValue(peopleViewID);
    if (conversations != NULL) {
        conversations->removeObject(vPeopleViewID);
    }
    
    conversations = (Set *) mDidntExistBefore->objectForKey(vFolderID);
    if ((conversations == NULL) || !conversations->containsObject(vPeopleViewID)) {
        conversations = (Set *) mExistedBefore->objectForKey(vFolderID);
        if (conversations == NULL) {
            conversations = Set::set();
            mExistedBefore->setObjectForKey(vFolderID, conversations);
        }
        conversations->addObject(vPeopleViewID);
        
        conversations = (Set *) mFoldersRemovedConversations->objectForKey(vFolderID);
        if (conversations == NULL) {
            conversations = Set::set();
            mFoldersRemovedConversations->setObjectForKey(vFolderID, conversations);
        }
        conversations->addObject(vPeopleViewID);
    }
    
    conversations = (Set *) mFoldersAddedConversations->objectForKey(vFolderID);
    if (conversations != NULL) {
        conversations->removeObject(vPeopleViewID);
    }
}

Array * MailDBChanges::addedConversationsForFolder(int64_t folderID)
{
    Set * conversations = (Set *) mFoldersAddedConversations->objectForKey(Value::valueWithLongLongValue(folderID));
    if (conversations == NULL)
        return NULL;
    return conversations->allObjects();
}

Array * MailDBChanges::removedConversationsForFolder(int64_t folderID)
{
    Set * conversations = (Set *) mFoldersRemovedConversations->objectForKey(Value::valueWithLongLongValue(folderID));
    if (conversations == NULL)
        return NULL;
    return conversations->allObjects();
}

time_t MailDBChanges::dateForPeopleViewID(int64_t peopleViewID)
{
    Value * vDate = (Value *) mConversationsDates->objectForKey(Value::valueWithLongLongValue(peopleViewID));
    if (vDate == NULL)
        return -1;
    return vDate->longLongValue();
}

void MailDBChanges::setFolderNeedsPushFlags(int64_t folderID)
{
    mFoldersNeedsPushFlags->addIndex(folderID);
}

void MailDBChanges::addMessagePart(int64_t messageRowID, String * partID)
{
    MailDBMessagePartInfo * info = new MailDBMessagePartInfo();
    info->setMessageRowID(messageRowID);
    info->setPartID(partID);
    mAddedParts->addObject(info);
    MC_SAFE_RELEASE(info);
}

mailcore::Array * MailDBChanges::addedMessageParts()
{
    return mAddedParts;
}

void MailDBChanges::setFolderUnseen(int64_t folderID)
{
    mUnseenFolders->addIndex(folderID);
}

void MailDBChanges::removeMessageIDFromSendQueue(mailcore::String * messageID)
{
    mMessageIDsToRemoveFromSendQueue->addObject(messageID);
}

mailcore::IndexSet * MailDBChanges::unseenFolders()
{
    return mUnseenFolders;
}

void MailDBChanges::changeCountForFolderID(int64_t folderID, int unreadCount, int starredCount, int totalCount)
{
    HashMap * result = HashMap::hashMap();
    result->setObjectForKey(MCSTR("unread"),  Value::valueWithIntValue(unreadCount));
    result->setObjectForKey(MCSTR("starred"),  Value::valueWithIntValue(starredCount));
    result->setObjectForKey(MCSTR("count"),  Value::valueWithIntValue(totalCount));
    mFolderCountChanges->setObjectForKey(Value::valueWithLongLongValue(folderID), result);
}

Array * MailDBChanges::changedFoldersIDs()
{
    return mFolderCountChanges->allKeys();
}

void MailDBChanges::addChangedFoldersIDs(mailcore::HashMap * info)
{
    mc_foreachhashmapKeyAndValue(Value, key, HashMap, value, info) {
        mFolderCountChanges->setObjectForKey(key, value);
    }
}

int MailDBChanges::unreadCountForFolderID(int64_t folderID)
{
    HashMap * result = (HashMap *) mFolderCountChanges->objectForKey(Value::valueWithLongLongValue(folderID));
    MCAssert(result != NULL);
    return ((Value *) result->objectForKey(MCSTR("unread")))->intValue();
}

int MailDBChanges::starredCountForFolderID(int64_t folderID)
{
    HashMap * result = (HashMap *) mFolderCountChanges->objectForKey(Value::valueWithLongLongValue(folderID));
    MCAssert(result != NULL);
    return ((Value *) result->objectForKey(MCSTR("starred")))->intValue();
}

int MailDBChanges::countForFolderID(int64_t folderID)
{
    HashMap * result = (HashMap *) mFolderCountChanges->objectForKey(Value::valueWithLongLongValue(folderID));
    MCAssert(result != NULL);
    return ((Value *) result->objectForKey(MCSTR("count")))->intValue();
}

mailcore::Set * MailDBChanges::messageIDsToRemoveFromSendQueue()
{
    return mMessageIDsToRemoveFromSendQueue;
}

void MailDBChanges::notifyMessage(int64_t folderID, int64_t rowid)
{
    HashMap * result = HashMap::hashMap();
    result->setObjectForKey(MCSTR("folderid"),  Value::valueWithLongLongValue(folderID));
    result->setObjectForKey(MCSTR("rowid"),  Value::valueWithLongLongValue(rowid));
    mNotifiedMessages->addObject(result);
}

mailcore::Array * MailDBChanges::notifiedMessages()
{
    return mNotifiedMessages;
}

void MailDBChanges::changePeopleViewCount(int64_t peopleViewID)
{
    mPeopleViewCountChanged->addIndex(peopleViewID);
}

mailcore::IndexSet * MailDBChanges::changedCountPeopleViewIDs()
{
    return mPeopleViewCountChanged;
}

mailcore::String * MailDBChanges::description()
{
    return String::stringWithUTF8Format("<MailDBChanges:\n    added: %s\n    modified: %s\n    removed: %s\n    folders added: %s\n    folders removed: %s\n>",
                                        MCUTF8DESC(mAddedPeopleViewIDs), MCUTF8DESC(mModifiedPeopleViewIDs), MCUTF8DESC(mRemovedPeopleViewIDs),
                                        MCUTF8DESC(mFoldersAddedConversations), MCUTF8DESC(mFoldersRemovedConversations));
}
