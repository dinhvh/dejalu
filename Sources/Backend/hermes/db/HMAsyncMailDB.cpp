// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMAsyncMailDB.h"

#include "HMMailDB.h"
#include "HMMailDBOpenOperation.h"
#include "HMMailDBCloseOperation.h"
#include "HMMailDBAddMessagesOperation.h"
#include "HMMailDBRemoveMessagesOperation.h"
#include "HMMailDBPeopleConversationsOperation.h"
#include "HMMailDBPeopleConversationInfoOperation.h"
#include "HMMailDBConversationMessagesOperation.h"
#include "HMMailDBChangeMessagesOperation.h"
#include "HMMailDBUidsOperation.h"
#include "HMMailDBAddFoldersOperation.h"
#include "HMMailDBStoreKeyValueOperation.h"
#include "HMMailDBRetrieveKeyValueOperation.h"
#include "HMMailDBNextUIDToFetchOperation.h"
#include "HMMailDBRetrievePartOperation.h"
#include "HMMailDBStorePartOperation.h"
#include "HMMailDBMessageRenderOperation.h"
#include "HMMailDBMarkAsFetchedOperation.h"
#include "HMMailDBMessageInfoOperation.h"
#include "HMMailDBUIDToFetchOperation.h"
#include "HMMailDBChangeMessagesFlagsOperation.h"
#include "HMMailDBChangePeopleConversationsFlagsOperation.h"
#include "HMMailDBMessagesLocalChangesOperation.h"
#include "HMMailDBRemoveMessagesLocalChangesOperation.h"
#include "HMMailDBAddLocalMessagesOperation.h"
#include "HMMailDBSetLocalMessagesPushedOperation.h"
#include "HMMailDBRemoveExpiredLocalMessagesOperation.h"
#include "HMMailDBNextMessageToPushOperation.h"
#include "HMMailDBCopyPeopleOperation.h"
#include "HMMailDBMovePeopleOperation.h"
#include "HMMailDBPurgeMessageOperation.h"
#include "HMMailDBUidsToCopyOperation.h"
#include "HMMailDBRemoveCopyMessagesOperation.h"
#include "HMMailDBRemoveSentDraftWithMessageIDOperation.h"
#include "HMMailDBPurgeSentDraftOperation.h"
#include "HMMailDBChangePeopleConversationsLabelsOperation.h"
#include "HMMailDBValidateFolderOperation.h"
#include "HMMailDBStoreLastSeenUIDOperation.h"
#include "HMMailDBFolderUnseenOperation.h"
#include "HMMailDBPeopleViewIDOperation.h"
#include "HMMailDBMessagesOperation.h"
#include "HMMailDBMessagesRecipientsOperation.h"
#include "HMMailDBAddToSavedRecipientsOperation.h"
#include "HMMailDBCheckFolderSeenOperation.h"
#include "HMMailDBMarkFirstSyncDoneOperation.h"

using namespace hermes;
using namespace mailcore;

AsyncMailDB::AsyncMailDB()
{
    mSyncDB = new MailDB();
    mQueue = new OperationQueue();
}

AsyncMailDB::~AsyncMailDB()
{
    MC_SAFE_RELEASE(mQueue);
    MC_SAFE_RELEASE(mSyncDB);
}

void AsyncMailDB::setPath(String * path)
{
    mSyncDB->setPath(path);
}

mailcore::String * AsyncMailDB::path()
{
    return mSyncDB->path();
}

MailDBOpenOperation * AsyncMailDB::openOperation()
{
    MailDBOpenOperation * result = new MailDBOpenOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::closeOperation()
{
    MailDBCloseOperation * result = new MailDBCloseOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::addFoldersOperation(mailcore::Array * foldersPathsToAdd,
                                                   mailcore::Array * foldersPathsToRemove,
                                                   mailcore::IMAPNamespace * ns)
{
    MailDBAddFoldersOperation * result = new MailDBAddFoldersOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setPathsToAdd(foldersPathsToAdd);
    result->setPathsToRemove(foldersPathsToRemove);
    result->setDefaultNamespace(ns);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::validateFolderOperation(mailcore::String * folderPath, uint32_t uidValidity)
{
    MailDBValidateFolderOperation * result = new MailDBValidateFolderOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderPath(folderPath);
    result->setUidValidity(uidValidity);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::storeValueForKeyOperation(String * key, Data * value)
{
    MailDBStoreKeyValueOperation * result = new MailDBStoreKeyValueOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setKey(key);
    result->setValue(value);
    result->autorelease();
    return result;
}

MailDBRetrieveKeyValueOperation * AsyncMailDB::retrieveValueForKey(String * key)
{
    MailDBRetrieveKeyValueOperation * result = new MailDBRetrieveKeyValueOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setKey(key);
    result->autorelease();
    return result;
}

MailDBAddMessagesOperation * AsyncMailDB::addMessagesOperation(int64_t folderID,
                                                               mailcore::Array * msgs,
                                                               int64_t draftsFolderID)
{
    MailDBAddMessagesOperation * result = new MailDBAddMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessages(msgs);
    result->setFolderID(folderID);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeMessagesOperation(Array * messagesRowIDs)
{
    MailDBRemoveMessagesOperation * result = new MailDBRemoveMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessagesRowIDs(messagesRowIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeMessagesUidsOperation(int64_t folderID, mailcore::IndexSet * messagesUids)
{
    MailDBRemoveMessagesOperation * result = new MailDBRemoveMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setMessagesUids(messagesUids);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::changeMessagesOperation(int64_t folderID, Array * msgs, int64_t draftsFolderID)
{
    MailDBChangeMessagesOperation * result = new MailDBChangeMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setDraftsFolderID(draftsFolderID);
    result->setMessages(msgs);
    result->autorelease();
    return result;
}

MailDBPeopleConversationsOperation * AsyncMailDB::starredPeopleConversationsOperation()
{
    MailDBPeopleConversationsOperation * result = new MailDBPeopleConversationsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setStarredOnly(true);
    result->autorelease();
    return result;
}

MailDBPeopleConversationsOperation * AsyncMailDB::peopleConversationsOperation(int64_t folderID)
{
    MailDBPeopleConversationsOperation * result = new MailDBPeopleConversationsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBPeopleConversationsOperation * AsyncMailDB::unreadPeopleConversationsOperation(int64_t folderID)
{
    MailDBPeopleConversationsOperation * result = new MailDBPeopleConversationsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setUnreadOnly(true);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBPeopleConversationsOperation * AsyncMailDB::peopleConversationsForKeywords(mailcore::Array * keywords)
{
    MailDBPeopleConversationsOperation * result = new MailDBPeopleConversationsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setKeywords(keywords);
    result->autorelease();
    return result;
}

MailDBPeopleConversationInfoOperation * AsyncMailDB::peopleConversationInfoOperation(int64_t peopleConversationID, HashMap * foldersScores,
                                                                                     int64_t inboxFolderID, mailcore::Set * emailSet,
                                                                                     mailcore::Set * foldersToExcludeFromUnread)
{
    MailDBPeopleConversationInfoOperation * result = new MailDBPeopleConversationInfoOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setConversationID(peopleConversationID);
    result->setInboxFolderID(inboxFolderID);
    result->setFoldersScores(foldersScores);
    result->setEmailSet(emailSet);
    result->setFoldersToExcludeFromUnread(foldersToExcludeFromUnread);
    result->autorelease();
    return result;
}

MailDBMessageInfoOperation * AsyncMailDB::messageInfoOperation(int64_t messageRowID,
                                                               mailcore::Set * emailSet,
                                                               bool renderImageEnabled)
{
    MailDBMessageInfoOperation * result = new MailDBMessageInfoOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setEmailSet(emailSet);
    result->setRenderImageEnabled(renderImageEnabled);
    result->autorelease();
    return result;
}

MailDBConversationMessagesOperation * AsyncMailDB::messagesForPeopleConversationOperation(int64_t peopleConversationID,
                                                                                          HashMap * foldersScores)
{
    MailDBConversationMessagesOperation * result = new MailDBConversationMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setConversationID(peopleConversationID);
    result->setFoldersScores(foldersScores);
    result->autorelease();
    return result;
}

MailDBUidsOperation * AsyncMailDB::uidsOperation(int64_t folderID)
{
    MailDBUidsOperation * result = new MailDBUidsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBRetrievePartOperation * AsyncMailDB::dataForPartOperation(int64_t messageRowID,
                                                                String * partID)
{
    MailDBRetrievePartOperation * result = new MailDBRetrievePartOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setPartID(partID);
    result->autorelease();
    return result;
}

MailDBRetrievePartOperation * AsyncMailDB::dataForPartByUniqueIDOperation(int64_t messageRowID,
                                                                          mailcore::String * uniqueID)
{
    MailDBRetrievePartOperation * result = new MailDBRetrievePartOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setUniqueID(uniqueID);
    result->setRetrieveFilenameEnabled(true);
    result->autorelease();
    return result;
}

MailDBRetrievePartOperation * AsyncMailDB::dataForLocalPartOperation(int64_t messageRowID,
                                                                     mailcore::String * uniqueID)
{
    MailDBRetrievePartOperation * result = new MailDBRetrievePartOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setUniqueID(uniqueID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::storeDataForPartOperation(int64_t messageRowID,
                                                         String * partID,
                                                         Data * data)
{
    MailDBStorePartOperation * result = new MailDBStorePartOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setPartID(partID);
    result->setContent(data);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::storeDataForMessageDataOperation(int64_t messageRowID, mailcore::Data * data)
{
    MailDBStorePartOperation * result = new MailDBStorePartOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setContent(data);
    result->autorelease();
    return result;
}

MailDBMessageRenderOperation * AsyncMailDB::messageRenderSummaryOperation(int64_t messageRowID)
{
    MailDBMessageRenderOperation * result = new MailDBMessageRenderOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->autorelease();
    return result;
}

MailDBNextUIDToFetchOperation * AsyncMailDB::nextUidToFetchOperation(int64_t folderID, uint32_t maxUid)
{
    MailDBNextUIDToFetchOperation * result = new MailDBNextUIDToFetchOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setMaxUid(maxUid);
    result->autorelease();
    return result;
}

MailDBUIDToFetchOperation * AsyncMailDB::uidToFetchOperation(int64_t messageRowID)
{
    MailDBUIDToFetchOperation * result = new MailDBUIDToFetchOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->autorelease();
    return result;
}

MailDBUIDToFetchOperation * AsyncMailDB::uidEncodingToFetchOperation(int64_t messageRowID, mailcore::String * partID)
{
    MailDBUIDToFetchOperation * result = new MailDBUIDToFetchOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->setPartID(partID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markAsFetchedOperation(int64_t messageRowID)
{
    MailDBMarkAsFetchedOperation * result = new MailDBMarkAsFetchedOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageRowID(messageRowID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::archivePeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                   int64_t inboxFolderID, int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkArchived);
    result->setFolderID(inboxFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->setConversationsIDs(conversationIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::purgeFromTrashPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                          int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkDeleted);
    result->setFolderID(trashFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->setConversationsIDs(conversationIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::starPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkFlagged);
    result->setDraftsFolderID(draftsFolderID);
    result->setConversationsIDs(conversationIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::unstarPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkUnflagged);
    result->setDraftsFolderID(draftsFolderID);
    result->setConversationsIDs(conversationIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markAsReadPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkRead);
    result->setDraftsFolderID(draftsFolderID);
    result->setConversationsIDs(conversationIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markAsUnreadPeopleConversationsOperation(mailcore::Array * conversationIDs,
                                                                        int64_t inboxFolderID, int64_t sentFolderID,
                                                                        int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkUnread);
    result->setConversationsIDs(conversationIDs);
    result->setInboxFolderID(inboxFolderID);
    result->setSentFolderID(sentFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::addLabelToPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label, int64_t folderID, int64_t trashFolderID)
{
    MailDBChangePeopleConversationsLabelsOperation * result = new MailDBChangePeopleConversationsLabelsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setRemove(false);
    result->setConversationsIDs(conversationIDs);
    result->setFolderID(folderID);
    result->setTrashFolderID(trashFolderID);
    result->setFolderPath(label);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeLabelFromPeopleConversationsOperation(mailcore::Array * conversationIDs, mailcore::String * label, int64_t folderID, int64_t trashFolderID)
{
    MailDBChangePeopleConversationsLabelsOperation * result = new MailDBChangePeopleConversationsLabelsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setRemove(true);
    result->setConversationsIDs(conversationIDs);
    result->setFolderID(folderID);
    result->setTrashFolderID(trashFolderID);
    result->setFolderPath(label);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeConversationFromFolderOperation(mailcore::Array * conversationIDs, int64_t folderID,
                                                                     int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeRemoveFromFolder);
    result->setFolderID(folderID);
    result->setDraftsFolderID(draftsFolderID);
    result->setConversationsIDs(conversationIDs);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markAsDeletedPeopleConversationsFromFolderOperation(mailcore::Array * conversationIDs,
                                                                                   int64_t folderID, mailcore::String * folderPath,
                                                                                   int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBChangePeopleConversationsFlagsOperation * result = new MailDBChangePeopleConversationsFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    //result->setTweakLabelsEnabled(true);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkDeleted);
    result->setFolderID(folderID);
    result->setConversationsIDs(conversationIDs);
    result->setFolderPath(folderPath);
    result->setTrashFolderID(trashFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markAsDeletedMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID)
{
    MailDBChangeMessagesFlagsOperation * result = new MailDBChangeMessagesFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkDeleted);
    result->setMessagesRowIDs(messagesRowIDs);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markAsReadMessagesOperation(mailcore::Array * messagesRowIDs, int64_t draftsFolderID)
{
    MailDBChangeMessagesFlagsOperation * result = new MailDBChangeMessagesFlagsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setChangeFlagsType(MailDBChangeFlagsTypeMarkRead);
    result->setMessagesRowIDs(messagesRowIDs);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBMessagesLocalChangesOperation * AsyncMailDB::messagesLocalChangesOperation(int64_t folderID)
{
    MailDBMessagesLocalChangesOperation * result = new MailDBMessagesLocalChangesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeMessagesLocalChangesOperation(mailcore::IndexSet * messagesRowIDs)
{
    MailDBRemoveMessagesLocalChangesOperation * result = new MailDBRemoveMessagesLocalChangesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setRowsIDs(messagesRowIDs);
    result->autorelease();
    return result;
}

MailDBAddLocalMessagesOperation * AsyncMailDB::addPendingMessageWithDataOperation(int64_t folderID, mailcore::Data * data,
                                                                                  bool needsToBeSentToServer,
                                                                                  bool hasBeenPushed,
                                                                                  int64_t draftsFolderID)
{
    MailDBAddLocalMessagesOperation * result = new MailDBAddLocalMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessagesData(Array::arrayWithObject(data));
    result->setFolderID(folderID);
    result->setNeedsToBeSentToServer(needsToBeSentToServer);
    result->setHasBeenPushed(hasBeenPushed);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::setLocalMessagePushedOperation(int64_t messageRowID)
{
    MailDBSetLocalMessagesPushedOperation * result = new MailDBSetLocalMessagesPushedOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessagesRowsIDs(IndexSet::indexSetWithIndex(messageRowID));
    result->autorelease();
    return result;
}


MailDBOperation * AsyncMailDB::removeExpiredLocalMessageOperation(int64_t folderID)
{
    MailDBRemoveExpiredLocalMessagesOperation * result = new MailDBRemoveExpiredLocalMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBNextMessageToPushOperation * AsyncMailDB::nextMessageToPush(int64_t folderID, bool draftBehaviorEnabled)
{
    MailDBNextMessageToPushOperation * result = new MailDBNextMessageToPushOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setDraftBehaviorEnabled(draftBehaviorEnabled);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::copyPeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                mailcore::HashMap * foldersScores,
                                                                int64_t draftsFolderID)
{
    MailDBCopyPeopleOperation * result = new MailDBCopyPeopleOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setConversationsIDs(conversationIDs);
    result->setOtherFolderID(otherFolderID);
    //result->setTrashFolderID(trashFolderID);
    result->setFoldersScores(foldersScores);
    //result->setTweakLabelsEnabled(true);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::movePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t otherFolderID,
                                                                mailcore::HashMap * foldersScores,
                                                                int64_t draftsFolderID)
{
    MailDBMovePeopleOperation * result = new MailDBMovePeopleOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setConversationsIDs(conversationIDs);
    result->setOtherFolderID(otherFolderID);
    result->setFoldersScores(foldersScores);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::purgePeopleConversationsOperation(mailcore::Array * conversationIDs, int64_t draftsFolderID,
                                                                 int64_t trashFolderID)
{
    MailDBPurgeMessageOperation * result = new MailDBPurgeMessageOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setConversationsIDs(conversationIDs);
    result->setFolderID(draftsFolderID);
    result->setTrashFolderID(trashFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::purgeMessagesOperation(mailcore::Array * messagesRowIDs, int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBPurgeMessageOperation * result = new MailDBPurgeMessageOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessagesRowIDs(messagesRowIDs);
    result->setTrashFolderID(trashFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBUidsToCopyOperation * AsyncMailDB::messagesUidsToPurgeOperation(int64_t folderID)
{
    MailDBUidsToCopyOperation * result = new MailDBUidsToCopyOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setDeleteOriginal(2);
    result->autorelease();
    return result;
}

MailDBUidsToCopyOperation * AsyncMailDB::messagesUidsToMoveOperation(int64_t folderID)
{
    MailDBUidsToCopyOperation * result = new MailDBUidsToCopyOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setDeleteOriginal(1);
    result->autorelease();
    return result;
}

MailDBUidsToCopyOperation * AsyncMailDB::messagesUidsToCopyOperation(int64_t folderID)
{
    MailDBUidsToCopyOperation * result = new MailDBUidsToCopyOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setDeleteOriginal(0);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeCopyMessagesOperation(mailcore::IndexSet * rowsIDs, mailcore::IndexSet * messagesRowIDs,
                                                           bool clearMoving, int64_t draftsFolderID)
{
    MailDBRemoveCopyMessagesOperation * result = new MailDBRemoveCopyMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setRowsIDs(rowsIDs);
    result->setMessagesRowIDs(messagesRowIDs);
    result->setClearMoving(clearMoving);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::removeSentDraftMessageWithMessageIDOperation(int64_t folderID, mailcore::String * messageID)
{
    MailDBRemoveSentDraftWithMessageIDOperation * result = new MailDBRemoveSentDraftWithMessageIDOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setMessageID(messageID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::purgeSentDraftMessageOperation(int64_t folderID, int64_t trashFolderID, int64_t draftsFolderID)
{
    MailDBPurgeSentDraftOperation * result = new MailDBPurgeSentDraftOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->setTrashFolderID(trashFolderID);
    result->setDraftsFolderID(draftsFolderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::storeLastSeenUIDOperation(int64_t folderID)
{
    MailDBStoreLastSeenUIDOperation * result = new MailDBStoreLastSeenUIDOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBFolderUnseenOperation * AsyncMailDB::isFolderUnseenOperation(int64_t folderID)
{
    MailDBFolderUnseenOperation * result = new MailDBFolderUnseenOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBPeopleViewIDOperation * AsyncMailDB::peopleViewIDOperation(mailcore::String * msgid)
{
    MailDBPeopleViewIDOperation * result = new MailDBPeopleViewIDOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessageID(msgid);
    result->autorelease();
    return result;
}

MailDBMessagesOperation * AsyncMailDB::messagesForFolderOperation(int64_t folderID)
{
    MailDBMessagesOperation * result = new MailDBMessagesOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    //result->setMinimumRowID(minimumRowID);
    result->autorelease();
    return result;
}

MailDBMessagesRecipientsOperation * AsyncMailDB::recipientsForMessagesRowsIDsOperation(mailcore::IndexSet * messagesRowsIDs, int maxCount)
{
    MailDBMessagesRecipientsOperation * result = new MailDBMessagesRecipientsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setMessagesRowsIDs(messagesRowsIDs);
    result->setMaxCount(maxCount);
    result->autorelease();
    return result;
}

MailDBAddToSavedRecipientsOperation * AsyncMailDB::addToSavedRecipientsOperation(mailcore::Array * addresses, int64_t lastRowID)
{
    MailDBAddToSavedRecipientsOperation * result = new MailDBAddToSavedRecipientsOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setAddresses(addresses);
    result->setRowID(lastRowID);
    result->autorelease();
    return result;
}

MailDBCheckFolderSeenOperation * AsyncMailDB::checkFolderSeenOperation(int64_t folderID)
{
    MailDBCheckFolderSeenOperation * result = new MailDBCheckFolderSeenOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}

MailDBOperation * AsyncMailDB::markFirstSyncDoneOperation(int64_t folderID)
{
    MailDBMarkFirstSyncDoneOperation * result = new MailDBMarkFirstSyncDoneOperation();
    result->setSyncDB(mSyncDB);
    result->setOperationQueue(mQueue);
    result->setFolderID(folderID);
    result->autorelease();
    return result;
}
