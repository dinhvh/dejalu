// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailStorage.h"

#include "HMAsyncMailDB.h"
#include "HMMailStorageView.h"
#include "HMMailDBAddMessagesOperation.h"
#include "HMMailDBUidsOperation.h"
#include "HMMailDBOpenOperation.h"
#include "HMMailDBAddFoldersOperation.h"
#include "HMMailDBRetrieveKeyValueOperation.h"
#include "HMMailDBOpenOperation.h"
#include "HMMailDBRetrievePartOperation.h"
#include "HMMailDBNextUIDToFetchOperation.h"
#include "HMMailDBMessageRenderOperation.h"
#include "HMMailDBPeopleConversationsOperation.h"
#include "HMMailDBPeopleConversationInfoOperation.h"
#include "HMMailDBConversationMessagesOperation.h"
#include "HMMailDBMessageInfoOperation.h"
#include "HMMailDBUIDToFetchOperation.h"
#include "HMMailDBMessagesLocalChangesOperation.h"
#include "HMMailDBChangePeopleConversationsFlagsOperation.h"
#include "HMMailDBChangeMessagesFlagsOperation.h"
#include "HMMailDBAddLocalMessagesOperation.h"
#include "HMMailDBNextMessageToPushOperation.h"
#include "HMMailDBUidsToCopyOperation.h"
#include "HMMailDBCopyPeopleOperation.h"
#include "HMMailDBMovePeopleOperation.h"
#include "HMMailDBPurgeMessageOperation.h"
#include "HMMailDBPurgeSentDraftOperation.h"
#include "HMMailDBChangePeopleConversationsLabelsOperation.h"
#include "HMMailDBFolderUnseenOperation.h"
#include "HMMailDBPeopleViewIDOperation.h"
#include "HMMailDBMessagesOperation.h"
#include "HMMailDBMessagesRecipientsOperation.h"
#include "HMMailDBAddToSavedRecipientsOperation.h"
#include "HMMailDBCheckFolderSeenOperation.h"
#include "HMMailDBChanges.h"
#include "DJLLog.h"

#define LOG(...) DJLLogWithID("flags", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("flags", __VA_ARGS__)

using namespace hermes;
using namespace mailcore;

MailStorage::MailStorage()
{
    mFoldersIDsToPath = NULL;
    mFoldersPathsToIDs = NULL;
    mFoldersCounts = NULL;
    mViews = new HashMap();
    mSearchViews = new Array();
    mDb = new AsyncMailDB();
    mStorageViews = carray_new(4);
    mFoldersNeedsPushFlags = new HashMap();
    mFoldersNeedsPushMessage = new HashMap();
    mFoldersNeedsCopyMessage = new HashMap();
    mSortedFolders = NULL;
    mTerminated = false;
    mDefaultNamespace = NULL;
}

MailStorage::~MailStorage()
{
    MC_SAFE_RELEASE(mDefaultNamespace);
    MC_SAFE_RELEASE(mSortedFolders);
    MC_SAFE_RELEASE(mFoldersNeedsCopyMessage);
    MC_SAFE_RELEASE(mFoldersNeedsPushMessage);
    MC_SAFE_RELEASE(mFoldersNeedsPushFlags);
    carray_free(mStorageViews);
    MC_SAFE_RELEASE(mSearchViews);
    MC_SAFE_RELEASE(mViews);
    MC_SAFE_RELEASE(mDb);
    MC_SAFE_RELEASE(mFoldersCounts);
    MC_SAFE_RELEASE(mFoldersPathsToIDs);
    MC_SAFE_RELEASE(mFoldersIDsToPath);
}

void MailStorage::setPath(mailcore::String * path)
{
    mDb->setPath(path);
}

String * MailStorage::path()
{
    return mDb->path();
}

int64_t MailStorage::folderIDForPath(String * path)
{
    if (mFoldersPathsToIDs == NULL)
        return -1;
    if (path == NULL)
        return -1;
    Value * vFolderID = (Value *) mFoldersPathsToIDs->objectForKey(path);
    if (vFolderID == NULL)
        return -1;
    return vFolderID->longLongValue();
}

String * MailStorage::pathForFolderID(int64_t folderID)
{
    if (folderID == -1) {
        return NULL;
    }
    if (mFoldersIDsToPath == NULL) {
        return NULL;
    }
    return (String *) mFoldersIDsToPath->objectForKey(Value::valueWithLongLongValue(folderID));
}

int MailStorage::unreadCountForFolderID(int64_t folderID)
{
    if (folderID == -1) {
        return 0;
    }
    if (mFoldersCounts == NULL) {
        return 0;
    }
    HashMap * info = (HashMap *) mFoldersCounts->objectForKey(Value::valueWithLongLongValue(folderID));
    return ((Value *) info->objectForKey(MCSTR("unread")))->intValue();
}

int MailStorage::starredCountForFolderID(int64_t folderID)
{
    if (folderID == -1) {
        return 0;
    }
    if (mFoldersCounts == NULL) {
        return 0;
    }
    HashMap * info =  (HashMap *) mFoldersCounts->objectForKey(Value::valueWithLongLongValue(folderID));
    return ((Value *) info->objectForKey(MCSTR("starred")))->intValue();
}

int MailStorage::countForFolderID(int64_t folderID)
{
    if (folderID == -1) {
        return 0;
    }
    if (mFoldersCounts == NULL) {
        return 0;
    }
    HashMap * info =  (HashMap *) mFoldersCounts->objectForKey(Value::valueWithLongLongValue(folderID));
    return ((Value *) info->objectForKey(MCSTR("count")))->intValue();
}

static int compareFolderNames(void * a, void * b, void * context) {
    String * folderA = (String *) a;
    String * folderB = (String *) b;
    return folderA->compare(folderB);
}

Array * MailStorage::folders()
{
    if (mFoldersPathsToIDs == NULL) {
        return Array::array();
    }

    if (mFoldersPathsToIDs->count() == 0) {
        return Array::array();
    }

    if (mSortedFolders == NULL) {
        mSortedFolders = mFoldersPathsToIDs->allKeys()->sortedArray(compareFolderNames, NULL);
        MC_SAFE_RETAIN(mSortedFolders);
    }

    return mSortedFolders;
}

//mailcore::IMAPNamespace * MailStorage::defaultNamespace()
//{
//    return mDefaultNamespace;
//}

mailcore::Array * MailStorage::componentsForFolderPath(mailcore::String * path)
{
    if (mDefaultNamespace == NULL) {
        return NULL;
    }
    return mDefaultNamespace->componentsFromPath(path);
}

MailStorageView * MailStorage::viewForCounters()
{
    MailStorageView * view = new MailStorageView();
    view->setStorage(this);
    view->setFolderID(-1);
    view->setEmailSet(Set::set());
    view->setStandardFolders(HashMap::hashMap());
    addStorageView(view);
    return (MailStorageView *) view->autorelease();
}

void MailStorage::closeViewForCounters(MailStorageView * view)
{
    removeStorageView(view);
}

void MailStorage::openViewForFolder(int64_t folderID, mailcore::HashMap * standardFolders, Set * emailSet, time_t ageLimit)
{
    MailStorageView * view = viewForFolder(folderID);
    if (view == NULL) {
        view = new MailStorageView();
        view->setStorage(this);
        view->setFolderID(folderID);
        view->setEmailSet(emailSet);
        view->setStandardFolders(standardFolders);
        view->setAgeLimit(ageLimit);
        addStorageView(view);
        mViews->setObjectForKey(Value::valueWithLongLongValue(folderID), view);
        view->release();
    }
    view->open();
}

MailStorageView * MailStorage::viewForFolder(int64_t folderID)
{
    return (MailStorageView *) mViews->objectForKey(Value::valueWithLongLongValue(folderID));
}

void MailStorage::closeViewForFolder(int64_t folderID)
{
    MailStorageView * view = viewForFolder(folderID);
    MCAssert(view != NULL);
    view->close();
    if (view->openedCount() == 0) {
        removeStorageView(view);
        mViews->removeObjectForKey(Value::valueWithLongLongValue(folderID));
    }
}

MailStorageView * MailStorage::openViewForSearchKeywords(mailcore::Array * keywords, mailcore::HashMap * standardFolders, mailcore::Set * emailSet)
{
    MailStorageView * view = new MailStorageView();
    view->setStorage(this);
    view->setKeywords(keywords);
    view->setEmailSet(emailSet);
    view->setStandardFolders(standardFolders);
    view->open();
    addStorageView(view);
    mSearchViews->addObject(view);
    view->release();
    return view;
}

void MailStorage::closeViewForSearch(MailStorageView * view)
{
    view->close();
    removeStorageView(view);
    mSearchViews->removeObject(view);
}

void MailStorage::addStorageView(MailStorageView * view)
{
    carray_add(mStorageViews, view, NULL);
}

void MailStorage::removeStorageView(MailStorageView * view)
{
    for(unsigned int i = 0 ; i < carray_count(mStorageViews) ; i ++) {
        if (carray_get(mStorageViews, i) == view) {
            carray_delete(mStorageViews, i);
            break;
        }
    }
}

MailDBPeopleConversationsOperation * MailStorage::peopleConversationsOperation(int64_t folderID)
{
    MailDBPeopleConversationsOperation * op = mDb->peopleConversationsOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBPeopleConversationsOperation * MailStorage::starredPeopleConversationsOperation()
{
    MailDBPeopleConversationsOperation * op = mDb->starredPeopleConversationsOperation();
    op->setStorage(this);
    return op;
}

MailDBPeopleConversationsOperation * MailStorage::unreadPeopleConversationsOperation(int64_t folderID)
{
    MailDBPeopleConversationsOperation * op = mDb->unreadPeopleConversationsOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBPeopleConversationsOperation * MailStorage::peopleConversationsForKeywords(mailcore::Array * keywords)
{
    MailDBPeopleConversationsOperation * op = mDb->peopleConversationsForKeywords(keywords);
    op->setStorage(this);
    return op;
}

MailDBPeopleConversationInfoOperation * MailStorage::peopleConversationInfoOperation(int64_t peopleConversationID, HashMap * foldersScores,
                                                                                     int64_t inboxFolderID, Set * emailSet,
                                                                                     mailcore::Set * foldersToExcludeFromUnread)
{
    MailDBPeopleConversationInfoOperation * op = mDb->peopleConversationInfoOperation(peopleConversationID, foldersScores,
                                                                                      inboxFolderID, emailSet, foldersToExcludeFromUnread);
    op->setStorage(this);
    return op;
}

MailDBMessageInfoOperation * MailStorage::messageInfoOperation(int64_t messageRowID, Set * emailSet, bool renderImageEnabled)
{
    MailDBMessageInfoOperation * op = mDb->messageInfoOperation(messageRowID, emailSet, renderImageEnabled);
    op->setStorage(this);
    return op;
}

MailDBConversationMessagesOperation * MailStorage::messagesForPeopleConversationOperation(int64_t peopleConversationID,
                                                                                          HashMap * foldersScores)
{
    MailDBConversationMessagesOperation * op = mDb->messagesForPeopleConversationOperation(peopleConversationID, foldersScores);
    op->setStorage(this);
    return op;
}

MailDBMessagesOperation * MailStorage::messagesForFolderOperation(int64_t folderID)
{
    MailDBMessagesOperation * op = mDb->messagesForFolderOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBMessagesRecipientsOperation * MailStorage::recipientsForMessagesRowsIDsOperation(mailcore::IndexSet * messagesRowsIDs, int maxCount)
{
    MailDBMessagesRecipientsOperation * op = mDb->recipientsForMessagesRowsIDsOperation(messagesRowsIDs, maxCount);
    op->setStorage(this);
    return op;
}

MailDBAddToSavedRecipientsOperation * MailStorage::addToSavedRecipientsOperation(mailcore::Array * addresses, int64_t lastRowID)
{
    MailDBAddToSavedRecipientsOperation * op = mDb->addToSavedRecipientsOperation(addresses, lastRowID);
    op->setStorage(this);
    return op;
}

//MailDBRecipientsOperation * MailStorage::recipientsOperation()
//{
//    MailDBRecipientsOperation * op = mDb->recipientsOperation();
//    op->setStorage(this);
//    return op;
//}

mailcore::Operation * MailStorage::addFoldersOperation(mailcore::Array * foldersPathsToAdd,
                                                       mailcore::Array * foldersPathsToRemove,
                                                       mailcore::IMAPNamespace * ns)
{
    MC_SAFE_REPLACE_COPY(IMAPNamespace, mDefaultNamespace, ns);
    mc_foreacharray(String, folderPath, foldersPathsToRemove) {
        Value * vFolderID = (Value *) mFoldersPathsToIDs->objectForKey(folderPath);
        if (vFolderID != NULL) {
            mFoldersCounts->removeObjectForKey(vFolderID);
            mFoldersIDsToPath->removeObjectForKey(vFolderID);
            mFoldersNeedsPushFlags->removeObjectForKey(vFolderID);
            mFoldersNeedsPushMessage->removeObjectForKey(vFolderID);
            mFoldersNeedsCopyMessage->removeObjectForKey(vFolderID);
        }
        mFoldersPathsToIDs->removeObjectForKey(folderPath);
    }
    MC_SAFE_RELEASE(mSortedFolders);

    MailDBOperation * op = mDb->addFoldersOperation(foldersPathsToAdd,
                                                    foldersPathsToRemove,
                                                    ns);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::validateFolderOperation(mailcore::String * folderPath, uint32_t uidValidity)
{
    MailDBOperation * op = mDb->validateFolderOperation(folderPath, uidValidity);
    op->setStorage(this);
    return op;
}

Operation * MailStorage::storeValueForKeyOperation(String * key, Data * value)
{
    MailDBOperation * op = mDb->storeValueForKeyOperation(key, value);
    op->setStorage(this);
    return op;
}

MailDBRetrieveKeyValueOperation * MailStorage::retrieveValueForKey(String * key)
{
    MailDBRetrieveKeyValueOperation * op = mDb->retrieveValueForKey(key);
    op->setStorage(this);
    return op;
}

#if 0
Operation * MailStorage::removeFoldersOperation(Array * paths)
{
    Array * foldersIDs = new Array();
    mc_foreacharray(String, path, paths) {
        foldersIDs->addObject(Value::valueWithLongLongValue(folderIDForPath(path)));
        
        int64_t folderID = folderIDForPath(path);
        mFoldersPathsToIDs->removeObjectForKey(path);
        mFoldersIDsToPath->removeObjectForKey(Value::valueWithLongLongValue(folderID));
        mFoldersNeedsPushFlags->removeObjectForKey(Value::valueWithLongLongValue(folderID));
    }
    MC_SAFE_RELEASE(mSortedFolders);
    MailDBOperation * op = mDb->removeFoldersOperation(foldersIDs);
    op->setStorage(this);
    foldersIDs->release();
    return op;
}
#endif

MailDBAddMessagesOperation * MailStorage::addMessagesOperation(int64_t folderID, mailcore::Array * /* IMAPMessage */ msgs, int64_t draftsFolderID)
{
    MailDBAddMessagesOperation * op = mDb->addMessagesOperation(folderID, msgs, draftsFolderID);
    op->setStorage(this);
    return op;
}

Operation * MailStorage::removeMessagesOperation(int64_t folderID, mailcore::Array * /* uint32_t */ msgsUids)\
{
    MailDBOperation * op = mDb->removeMessagesOperation(msgsUids);
    op->setStorage(this);
    return op;
}

Operation * MailStorage::removeMessagesUidsOperation(int64_t folderID, mailcore::IndexSet * messagesUids)
{
    MailDBOperation * op = mDb->removeMessagesUidsOperation(folderID, messagesUids);
    op->setStorage(this);
    return op;
}

Operation * MailStorage::changeMessagesOperation(int64_t folderID, mailcore::Array * /* IMAPMessage */ msgs, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->changeMessagesOperation(folderID, msgs, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBUidsOperation * MailStorage::uidsOperation(int64_t folderID)
{
    MailDBUidsOperation * op = mDb->uidsOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBOpenOperation * MailStorage::openOperation()
{
    MailDBOpenOperation * op = mDb->openOperation();
    op->setStorage(this);
    return op;
}

void MailStorage::cancelViews()
{
    for(unsigned int i = 0 ; i < carray_count(mStorageViews) ; i ++) {
        MailStorageView * view = (MailStorageView *) carray_get(mStorageViews, i);
        view->cancel();
    }
}

// HACK
void MailStorage::setTerminated()
{
    mTerminated = true;
}

bool MailStorage::isTerminated()
{
    return mTerminated;
}

Operation * MailStorage::closeOperation()
{
    setTerminated();
    MailDBOperation * op = mDb->closeOperation();
    op->setStorage(this);
    return op;
}

MailDBRetrievePartOperation * MailStorage::dataForPartOperation(int64_t messageRowID,
                                                                String * partID)
{
    MailDBRetrievePartOperation * op = mDb->dataForPartOperation(messageRowID, partID);
    op->setStorage(this);
    return op;
}

MailDBRetrievePartOperation * MailStorage::dataForPartByUniqueIDOperation(int64_t messageRowID,
                                                                          mailcore::String * uniqueID)
{
    MailDBRetrievePartOperation * op = mDb->dataForPartByUniqueIDOperation(messageRowID, uniqueID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::storeDataForPartOperation(int64_t messageRowID,
                                                         String * partID,
                                                         Data * data)
{
    MailDBOperation * op = mDb->storeDataForPartOperation(messageRowID, partID, data);
    op->setStorage(this);
    return op;
}

MailDBRetrievePartOperation * MailStorage::dataForLocalPartOperation(int64_t messageRowID,
                                                                     mailcore::String * uniqueID)
{
    MailDBRetrievePartOperation * op = mDb->dataForLocalPartOperation(messageRowID, uniqueID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::storeDataForMessageDataOperation(int64_t messageRowID, mailcore::Data * data)
{
    MailDBOperation * op = mDb->storeDataForMessageDataOperation(messageRowID, data);
    op->setStorage(this);
    return op;
}

MailDBMessageRenderOperation * MailStorage::messageRenderSummaryOperation(int64_t messageRowID)
{
    MailDBMessageRenderOperation * op = mDb->messageRenderSummaryOperation(messageRowID);
    op->setStorage(this);
    return op;
}

MailDBNextUIDToFetchOperation * MailStorage::nextUidToFetchOperation(int64_t folderID, uint32_t maxUid)
{
    MailDBNextUIDToFetchOperation * op = mDb->nextUidToFetchOperation(folderID, maxUid);
    op->setStorage(this);
    return op;
}

MailDBUIDToFetchOperation * MailStorage::uidToFetchOperation(int64_t messageRowID)
{
    MailDBUIDToFetchOperation * op = mDb->uidToFetchOperation(messageRowID);
    op->setStorage(this);
    return op;
}

MailDBUIDToFetchOperation * MailStorage::uidEncodingToFetchOperation(int64_t messageRowID, mailcore::String * partID)
{
    MailDBUIDToFetchOperation * op = mDb->uidEncodingToFetchOperation(messageRowID, partID);
    op->setStorage(this);
    return op;
}

Operation * MailStorage::markAsFetchedOperation(int64_t messageRowID)
{
    MailDBOperation * op = mDb->markAsFetchedOperation(messageRowID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::archivePeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                   int64_t folderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->archivePeopleConversationsOperation(conversationIDs, folderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::purgeFromTrashPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                          int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->purgeFromTrashPeopleConversationsOperation(conversationIDs, trashFolderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::starPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->starPeopleConversationsOperation(conversationIDs, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::unstarPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->unstarPeopleConversationsOperation(conversationIDs, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::markAsReadPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->markAsReadPeopleConversationsOperation(conversationIDs, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::markAsUnreadPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                        int64_t inboxFolderID, int64_t sentFolderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->markAsUnreadPeopleConversationsOperation(conversationIDs, inboxFolderID, sentFolderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::removeConversationFromFolderOperation(mailcore::Array * conversationIDs,
                                                                     int64_t folderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->removeConversationFromFolderOperation(conversationIDs, folderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::addLabelToPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label,
                                                                      int64_t folderID, int64_t trashFolderID)
{
    MailDBOperation * op = mDb->addLabelToPeopleConversationsOperation(conversationIDs, label, folderID, trashFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::removeLabelFromPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label,
                                                                           int64_t folderID, int64_t trashFolderID)
{
    MailDBOperation * op = mDb->removeLabelFromPeopleConversationsOperation(conversationIDs, label, folderID, trashFolderID);
    op->setStorage(this);
    return op;
}

#if 0
MailDBOperation * MailStorage::starMessagesOperation(mailcore::Array * messageRowIDs)
{
    MailDBOperation * op = mDb->starMessagesOperation(messageRowIDs);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::unstarMessagesOperation(mailcore::Array * messageRowIDs)
{
    MailDBOperation * op = mDb->unstarMessagesOperation(messageRowIDs);
    op->setStorage(this);
    return op;
}
#endif

MailDBOperation * MailStorage::markAsReadMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->markAsReadMessagesOperation(messagesRowIDs, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::markAsDeletedMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->markAsDeletedMessagesOperation(messagesRowIDs, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::markAsDeletedPeopleConversationsFromFolderOperation(mailcore::Array * conversationIDs,
                                                                                   int64_t folderID, mailcore::String * folderPath,
                                                                                   int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->markAsDeletedPeopleConversationsFromFolderOperation(conversationIDs, folderID, folderPath, trashFolderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBMessagesLocalChangesOperation * MailStorage::messagesLocalChangesOperation(int64_t folderID)
{
    MailDBMessagesLocalChangesOperation * op = mDb->messagesLocalChangesOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBOperation * MailStorage::removeMessagesLocalChangesOperation(mailcore::IndexSet * messagesRowIDs)
{
    MailDBOperation * op = mDb->removeMessagesLocalChangesOperation(messagesRowIDs);
    op->setStorage(this);
    return op;
}

void MailStorage::addLabelToConversation(int64_t conversation, mailcore::Array * labels)
{
}

void MailStorage::removeLabelFromConversation(int64_t conversation, mailcore::Array * labels)
{
}

void MailStorage::notifyStorageOperationFinished(MailDBOperation * op)
{
    if (op->className()->isEqual(MCSTR("hermes::MailDBOpenOperation"))) {
        MC_SAFE_REPLACE_RETAIN(IMAPNamespace, mDefaultNamespace, ((MailDBOpenOperation *) op)->defaultNamespace());
        MC_SAFE_REPLACE_RETAIN(HashMap, mFoldersPathsToIDs, ((MailDBOpenOperation *) op)->folders());
        if (mFoldersPathsToIDs == NULL) {
            mFoldersPathsToIDs = new HashMap();
        }
        MC_SAFE_RELEASE(mFoldersCounts);
        mFoldersCounts = new HashMap();
        MC_SAFE_RELEASE(mFoldersIDsToPath);
        mFoldersIDsToPath = new HashMap();
        {
            mc_foreachhashmapKeyAndValue(String, path, Value, vFolderID, mFoldersPathsToIDs) {
                mFoldersIDsToPath->setObjectForKey(vFolderID, path);
                setNeedsPushFlagsToServer(vFolderID->longLongValue());
                setNeedsPushMessagesToServer(vFolderID->longLongValue());
                setNeedsCopyMessages(vFolderID->longLongValue());
            }
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBAddFoldersOperation"))) {
        MailDBAddFoldersOperation * addFoldersOp = (MailDBAddFoldersOperation *) op;
        for(unsigned int i = 0 ; i < addFoldersOp->pathsToAdd()->count() ; i ++) {
            String * path = (String *) addFoldersOp->pathsToAdd()->objectAtIndex(i);
            Value * vFolderID = (Value *) addFoldersOp->foldersToAddIDs()->objectAtIndex(i);
            mFoldersPathsToIDs->setObjectForKey(path, vFolderID);
            mFoldersIDsToPath->setObjectForKey(vFolderID, path);
            HashMap * info = HashMap::hashMap();
            info->setObjectForKey(MCSTR("unread"), Value::valueWithIntValue(0));
            info->setObjectForKey(MCSTR("starred"), Value::valueWithIntValue(0));
            info->setObjectForKey(MCSTR("count"), Value::valueWithIntValue(0));
            mFoldersCounts->setObjectForKey(vFolderID, info);
            setNeedsPushFlagsToServer(vFolderID->longLongValue());
            setNeedsPushMessagesToServer(vFolderID->longLongValue());
            setNeedsCopyMessages(vFolderID->longLongValue());
        }
        for(unsigned int i = 0 ; i < addFoldersOp->pathsToRemove()->count() ; i ++) {
            String * path = (String *) addFoldersOp->pathsToRemove()->objectAtIndex(i);
            Value * vFolderID = (Value *) mFoldersPathsToIDs->objectForKey(path);
            if (vFolderID != NULL) {
                mFoldersIDsToPath->removeObjectForKey(vFolderID);
                mFoldersCounts->removeObjectForKey(vFolderID);
                mFoldersNeedsPushFlags->removeObjectForKey(vFolderID);
                mFoldersNeedsPushMessage->removeObjectForKey(vFolderID);
                mFoldersNeedsCopyMessage->removeObjectForKey(vFolderID);
            }
            mFoldersPathsToIDs->removeObjectForKey(path);
        }
        MC_SAFE_RELEASE(mSortedFolders);
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBChangePeopleConversationsFlagsOperation"))) {
        MailDBChangePeopleConversationsFlagsOperation * changeFlagsOp = (MailDBChangePeopleConversationsFlagsOperation *) op;
        mc_foreachindexset(folderID, changeFlagsOp->changes()->foldersNeedPushFlags()) {
            setNeedsPushFlagsToServer(folderID);
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBChangeMessagesFlagsOperation"))) {
        MailDBChangeMessagesFlagsOperation * changeFlagsOp = (MailDBChangeMessagesFlagsOperation *) op;
        mc_foreachindexset(folderID, changeFlagsOp->changes()->foldersNeedPushFlags()) {
            setNeedsPushFlagsToServer(folderID);
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBChangePeopleConversationsLabelsOperation"))) {
        MailDBChangePeopleConversationsLabelsOperation * changeLabelsOp = (MailDBChangePeopleConversationsLabelsOperation *) op;
        mc_foreachindexset(folderID, changeLabelsOp->changes()->foldersNeedPushFlags()) {
            setNeedsPushFlagsToServer(folderID);
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBAddLocalMessagesOperation"))) {
        MailDBAddLocalMessagesOperation * addLocalMessagesOp = (MailDBAddLocalMessagesOperation *) op;
        setNeedsPushMessagesToServer(addLocalMessagesOp->folderID());
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBCopyPeopleOperation"))) {
        MailDBCopyPeopleOperation * copyOp = (MailDBCopyPeopleOperation *) op;
        mc_foreachindexset(folderID, copyOp->foldersNeedCopyMessages()) {
            setNeedsCopyMessages(folderID);
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBMovePeopleOperation"))) {
        MailDBMovePeopleOperation * moveOp = (MailDBMovePeopleOperation *) op;
        mc_foreachindexset(folderID, moveOp->foldersNeedCopyMessages()) {
            setNeedsCopyMessages(folderID);
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBPurgeMessageOperation"))) {
        MailDBPurgeMessageOperation * purgeOp = (MailDBPurgeMessageOperation *) op;
        mc_foreachindexset(folderID, purgeOp->foldersNeedCopyMessages()) {
            setNeedsCopyMessages(folderID);
        }
    }
    else if (op->className()->isEqual(MCSTR("hermes::MailDBPurgeSentDraftOperation"))) {
        MailDBPurgeSentDraftOperation * purgeSendDraftOp = (MailDBPurgeSentDraftOperation *) op;
        mc_foreachindexset(folderID, purgeSendDraftOp->foldersNeedCopyMessages()) {
            setNeedsCopyMessages(folderID);
        }
    }
    mc_foreacharray(Value, vFolderID, op->changes()->changedFoldersIDs()) {
        int unread = op->changes()->unreadCountForFolderID(vFolderID->longLongValue());
        int starred = op->changes()->starredCountForFolderID(vFolderID->longLongValue());
        int count = op->changes()->countForFolderID(vFolderID->longLongValue());
        HashMap * info = HashMap::hashMap();
        info->setObjectForKey(MCSTR("unread"), Value::valueWithIntValue(unread));
        info->setObjectForKey(MCSTR("starred"), Value::valueWithIntValue(starred));
        info->setObjectForKey(MCSTR("count"), Value::valueWithIntValue(count));
        mFoldersCounts->setObjectForKey(vFolderID, info);
    }
    for(unsigned int i = 0 ; i < carray_count(mStorageViews) ; i ++) {
        MailStorageView * view = (MailStorageView *) carray_get(mStorageViews, i);
        view->notifyChanges(op->changes());
    }
}

enum {
    NOTHING_TO_DO,
    HAS_TASK,
    IS_PUSHING,
    IS_PUSHING_AND_HAS_TASK,
};

bool MailStorage::isTaskPending(HashMap * taskMap, int64_t folderID)
{
    return taskMap->objectForKey(Value::valueWithLongLongValue(folderID)) != NULL;
}

void MailStorage::startTask(HashMap * taskMap, int64_t folderID)
{
    taskMap->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(IS_PUSHING));
}

void MailStorage::finishedTask(HashMap * taskMap, int64_t folderID)
{
    Value * vState = (Value *) taskMap->objectForKey(Value::valueWithLongLongValue(folderID));
    if (vState == NULL) {
        return;
    }
    switch (vState->intValue()) {
        case IS_PUSHING:
            taskMap->removeObjectForKey(Value::valueWithLongLongValue(folderID));
            break;
        case IS_PUSHING_AND_HAS_TASK:
            taskMap->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(HAS_TASK));
            break;
    }
}

void MailStorage::cancelledTask(mailcore::HashMap * taskMap, int64_t folderID)
{
    taskMap->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(HAS_TASK));
}

void MailStorage::setTaskPending(HashMap * taskMap, int64_t folderID)
{
    Value * vState = (Value *) taskMap->objectForKey(Value::valueWithLongLongValue(folderID));
    if (vState == NULL) {
        taskMap->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(HAS_TASK));
    }
    else {
        switch (vState->intValue()) {
            case IS_PUSHING:
                taskMap->setObjectForKey(Value::valueWithLongLongValue(folderID), Value::valueWithIntValue(IS_PUSHING_AND_HAS_TASK));
                break;
        }
    }
}

bool MailStorage::pushFlagsToServerNeeded(int64_t folderID)
{
    return isTaskPending(mFoldersNeedsPushFlags, folderID);
}

void MailStorage::startPushFlagsToServer(int64_t folderID)
{
    startTask(mFoldersNeedsPushFlags, folderID);
}

void MailStorage::finishedPushFlagsToServer(int64_t folderID)
{
    finishedTask(mFoldersNeedsPushFlags, folderID);
}

void MailStorage::cancelledPushFlagsToServer(int64_t folderID)
{
    cancelledTask(mFoldersNeedsPushFlags, folderID);
}

void MailStorage::setNeedsPushFlagsToServer(int64_t folderID)
{
    setTaskPending(mFoldersNeedsPushFlags, folderID);
}

bool MailStorage::pushMessagesToServerNeeded(int64_t folderID)
{
    return isTaskPending(mFoldersNeedsPushMessage, folderID);
}

void MailStorage::startPushMessagesToServer(int64_t folderID)
{
    startTask(mFoldersNeedsPushMessage, folderID);
}

void MailStorage::finishedPushMessagesToServer(int64_t folderID)
{
    finishedTask(mFoldersNeedsPushMessage, folderID);
}

void MailStorage::cancelledPushMessagesToServer(int64_t folderID)
{
    cancelledTask(mFoldersNeedsPushMessage, folderID);
}

void MailStorage::setNeedsPushMessagesToServer(int64_t folderID)
{
    setTaskPending(mFoldersNeedsPushMessage, folderID);
}

bool MailStorage::copyMessagesNeeded(int64_t folderID)
{
    return isTaskPending(mFoldersNeedsCopyMessage, folderID);
}

void MailStorage::startCopyMessages(int64_t folderID)
{
    startTask(mFoldersNeedsCopyMessage, folderID);
}

void MailStorage::finishedCopyMessages(int64_t folderID)
{
    finishedTask(mFoldersNeedsCopyMessage, folderID);
}

void MailStorage::cancelledCopyMessages(int64_t folderID)
{
    cancelledTask(mFoldersNeedsCopyMessage, folderID);
}

void MailStorage::setNeedsCopyMessages(int64_t folderID)
{
    setTaskPending(mFoldersNeedsCopyMessage, folderID);
}

MailDBAddLocalMessagesOperation * MailStorage::addPendingMessageWithDataOperation(int64_t folderID, mailcore::Data * data,
                                                                                  bool needsToBeSentToServer,
                                                                                  bool hasBeenPushed,
                                                                                  int64_t draftsFolderID)
{
    MailDBAddLocalMessagesOperation * op = mDb->addPendingMessageWithDataOperation(folderID, data, needsToBeSentToServer, hasBeenPushed, draftsFolderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::setLocalMessagePushedOperation(int64_t messageRowID)
{
    MailDBOperation * op = mDb->setLocalMessagePushedOperation(messageRowID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::removeExpiredLocalMessageOperation(int64_t folderID)
{
    MailDBOperation * op = mDb->removeExpiredLocalMessageOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBNextMessageToPushOperation * MailStorage::nextMessageToPush(int64_t folderID, bool draftBehaviorEnabled)
{
    MailDBNextMessageToPushOperation * op = mDb->nextMessageToPush(folderID, draftBehaviorEnabled);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::copyPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                    mailcore::HashMap * foldersScores, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->copyPeopleConversationsOperation(conversationIDs, otherFolderID, foldersScores, draftsFolderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::movePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                    mailcore::HashMap * foldersScores, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->movePeopleConversationsOperation(conversationIDs, otherFolderID, foldersScores, draftsFolderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::purgePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID,
                                                                     int64_t trashFolderID)
{
    MailDBOperation * op = mDb->purgePeopleConversationsOperation(conversationIDs, draftsFolderID, trashFolderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::purgeMessagesOperation(mailcore::Array * messagesRowIDs, int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->purgeMessagesOperation(messagesRowIDs, trashFolderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

MailDBUidsToCopyOperation * MailStorage::messagesUidsToPurgeOperation(int64_t folderID)
{
    MailDBUidsToCopyOperation * op = mDb->messagesUidsToPurgeOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBUidsToCopyOperation * MailStorage::messagesUidsToMoveOperation(int64_t folderID)
{
    MailDBUidsToCopyOperation * op = mDb->messagesUidsToMoveOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBUidsToCopyOperation * MailStorage::messagesUidsToCopyOperation(int64_t folderID)
{
    MailDBUidsToCopyOperation * op = mDb->messagesUidsToCopyOperation(folderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::removeCopyMessagesOperation(mailcore::IndexSet * rowsIDs, mailcore::IndexSet * messagesRowIDs,
                                                               bool clearMoving, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->removeCopyMessagesOperation(rowsIDs, messagesRowIDs, clearMoving, draftsFolderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::removeSentDraftMessageWithMessageIDOperation(int64_t folderID, mailcore::String * messageID)
{
    MailDBOperation * op = mDb->removeSentDraftMessageWithMessageIDOperation(folderID, messageID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::purgeSentDraftMessageOperation(int64_t folderID, int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBOperation * op = mDb->purgeSentDraftMessageOperation(folderID, trashFolderID, draftsFolderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::storeLastSeenUIDOperation(int64_t folderID)
{
    MailDBOperation * op = mDb->storeLastSeenUIDOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBFolderUnseenOperation * MailStorage::isFolderUnseenOperation(int64_t folderID)
{
    MailDBFolderUnseenOperation * op = mDb->isFolderUnseenOperation(folderID);
    op->setStorage(this);
    return op;
}

MailDBPeopleViewIDOperation * MailStorage::peopleViewIDOperation(mailcore::String * msgid)
{
    MailDBPeopleViewIDOperation * op = mDb->peopleViewIDOperation(msgid);
    op->setStorage(this);
    return op;
}

MailDBCheckFolderSeenOperation * MailStorage::checkFolderSeenOperation(int64_t folderID)
{
    MailDBCheckFolderSeenOperation * op = mDb->checkFolderSeenOperation(folderID);
    op->setStorage(this);
    return op;
}

mailcore::Operation * MailStorage::markFirstSyncDoneOperation(int64_t folderID)
{
    MailDBOperation * op = mDb->markFirstSyncDoneOperation(folderID);
    op->setStorage(this);
    return op;
}
