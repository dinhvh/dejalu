// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMAccount.h"

#include <sys/stat.h>

#include "HMIMAPAccountSynchronizer.h"
#include "HMAccountObserver.h"
#include "HMMailStorage.h"
#include "HMIMAPAccountInfo.h"
#include "HMMessageQueueSender.h"
#include "HMAccountInfo.h"
#include "HMAccountManager.h"
#include "DJLLog.h"
#include "HMIMAPAttachmentDownloader.h"
#include "HMMailStorageView.h"
#include "HMMailDBMessagesOperation.h"

#define LOG_CLEANUP(...) DJLLogWithID("cleanup", __VA_ARGS__)

using namespace hermes;
using namespace mailcore;

Account::Account()
{
    mSync = new IMAPAccountSynchronizer();
    mSync->setDelegate(this);
    mSendQueue = new MessageQueueSender();
    mSendQueue->setIMAPAccountSynchronizer(mSync);
    mSendQueue->setDelegate(this);
    mObservers = carray_new(4);
    mAccountInfo = new AccountInfo();
    mSync->setAccountInfo(mAccountInfo->imapInfo());
    mSendQueue->setAccountInfo(mAccountInfo->smtpInfo());
}

Account::~Account()
{
    //LOG_CLEANUP("Account dealloced");
    MC_SAFE_RELEASE(mSendQueue);
    if (mSync != NULL) {
        mSync->setDelegate(NULL);
    }
    MC_SAFE_RELEASE(mSync);
    carray_free(mObservers);
    MC_SAFE_RELEASE(mAccountInfo);
}

Object * Account::retain()
{
    //LOG_CLEANUP("Account retain %i", retainCount() + 1);
    Object::retain();

    return this;
}

void Account::release()
{
    //LOG_CLEANUP("Account release %i", retainCount() - 1);
    Object::release();
}

void Account::setLogEnabled(bool enabled)
{
    mSync->setLogEnabled(enabled);
    mSendQueue->setLogEnabled(enabled);
}

void Account::setQuickSyncEnabled(bool enabled)
{
    mSync->setQuickSyncEnabled(enabled);
}

void Account::addObserver(AccountObserver * observer)
{
    carray_add(mObservers, observer, NULL);
}

void Account::removeObserver(AccountObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            return;
        }
    }
}

void Account::setAccountInfo(AccountInfo * info)
{
    MC_SAFE_REPLACE_RETAIN(AccountInfo, mAccountInfo, info);
    mSync->setAccountInfo(info->imapInfo());
    mSendQueue->setAccountInfo(info->smtpInfo());
}

AccountInfo * Account::accountInfo()
{
    return mAccountInfo;
}

mailcore::String * Account::uncheckedShortDisplayName()
{
    String * displayName = mAccountInfo->email()->lowercaseString();
    int location = displayName->locationOfString(MCSTR("@"));
    if (location == -1) {
        return displayName;
    }
    displayName = displayName->substringFromIndex(location + 1);
    if (displayName->length() == 0) {
        return mAccountInfo->email();
    }
    return displayName;
}

mailcore::String * Account::shortDisplayName()
{
    String * displayName = uncheckedShortDisplayName();
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        if (account != this) {
            if (displayName->isEqual(account->uncheckedShortDisplayName())) {
                displayName = mAccountInfo->email();
                break;
            }
        }
    }
    return displayName;
}

mailcore::Set * Account::emailSet()
{
    return currentEmailSet();
}

mailcore::Array * Account::addresses()
{
    return mSync->addresses();
}

void Account::setPath(mailcore::String * path)
{
    mSync->setPath(path);
    mSendQueue->setPath(path);
}

mailcore::String * Account::path()
{
    return mSync->path();
}

void Account::load()
{
    MCAssert(mAccountInfo->email() != NULL);
    String * filename = path()->stringByAppendingPathComponent(mAccountInfo->email())->stringByAppendingPathComponent(MCSTR("account-info.json"));
    mAccountInfo->load(filename);
}

void Account::save()
{
    String * accountFolder = path()->stringByAppendingPathComponent(mAccountInfo->email());
    mkdir(accountFolder->fileSystemRepresentation(), 0700);
    String * filename = path()->stringByAppendingPathComponent(mAccountInfo->email())->stringByAppendingPathComponent(MCSTR("account-info.json"));
    mAccountInfo->save(filename);
}

int64_t Account::folderIDForPath(mailcore::String * path)
{
    return mSync->storage()->folderIDForPath(path);
}

mailcore::String * Account::pathForFolderID(int64_t folderID)
{
    return mSync->storage()->pathForFolderID(folderID);
}

int Account::unreadCountForFolderID(int64_t folderID)
{
    return mSync->storage()->unreadCountForFolderID(folderID);
}

int Account::starredCountForFolderID(int64_t folderID)
{
    return mSync->storage()->starredCountForFolderID(folderID);
}

int Account::countForFolderID(int64_t folderID)
{
    return mSync->storage()->countForFolderID(folderID);
}

mailcore::String * Account::inboxFolderPath()
{
    return mSync->inboxFolderPath();
}

mailcore::String * Account::allMailFolderPath()
{
    return mSync->allMailFolderPath();
}

mailcore::String * Account::archiveFolderPath()
{
    return mSync->archiveFolderPath();
}

mailcore::String * Account::sentFolderPath()
{
    return mSync->sentFolderPath();
}

mailcore::String * Account::trashFolderPath()
{
    return mSync->trashFolderPath();
}

mailcore::String * Account::draftsFolderPath()
{
    return mSync->draftsFolderPath();
}

mailcore::String * Account::importantFolderPath()
{
    return mSync->importantFolderPath();
}

mailcore::String * Account::spamFolderPath()
{
    return mSync->spamFolderPath();
}

mailcore::String * Account::starredFolderPath()
{
    return mSync->starredFolderPath();
}

mailcore::Array * Account::folders()
{
    return mSync->folders();
    //return mSync->storage()->folders();
}

mailcore::Array * Account::componentsForFolderPath(mailcore::String * path)
{
    return mSync->componentsForFolderPath(path);
}

void Account::open()
{
    mSync->open();
    mSendQueue->loadQueueFromDisk();
}

void Account::close()
{
    mSendQueue->setDeliveryEnabled(false);
    mSync->close();
}

void Account::openFolderPath(mailcore::String * path)
{
    mSync->openFolderPath(path);
}

void Account::closeFolderPath(mailcore::String * path)
{
    mSync->closeFolderPath(path);
}

void Account::setSearchKeywords(mailcore::Array * keywords)
{
    mSync->setSearchKeywords(keywords);
}

mailcore::Array * Account::searchKeywords()
{
    return mSync->searchKeywords();
}

bool Account::isSearching()
{
    return mSync->isSearching();
}

void Account::fetchMessageSummary(int64_t folderID, int64_t messageRowID, bool urgent)
{
    mSync->fetchMessageSummary(folderID, messageRowID, urgent);
}

bool Account::canFetchMessageSummary(int64_t messageRowID)
{
    return mSync->canFetchMessageSummary(messageRowID);
}

void Account::fetchMessagePart(int64_t folderID, int64_t messageRowID, mailcore::String * partID, bool urgent)
{
    mSync->fetchMessagePart(folderID, messageRowID, partID, urgent);
}

void Account::fetchMessageSource(int64_t folderID, int64_t messageRowID)
{
    mSync->fetchMessageSource(folderID, messageRowID);
}

void Account::disableSync()
{
    mSync->disableSync();
}

void Account::enableSync()
{
    mSync->enableSync();
}

void Account::markFolderAsSeen(int64_t folderID)
{
    mSync->markFolderAsSeen(folderID);
}

bool Account::isFolderUnseen(int64_t folderID)
{
    return mSync->isFolderUnseen(folderID);
}

void Account::archivePeopleConversations(mailcore::Array * conversationIDs, mailcore::HashMap * foldersScores)
{
    mSync->archivePeopleConversations(conversationIDs, foldersScores);
}

void Account::deletePeopleConversations(mailcore::Array * conversationIDs, mailcore::HashMap * foldersScores)
{
    mSync->deletePeopleConversations(conversationIDs, foldersScores);
}

void Account::purgeFromTrashPeopleConversations(mailcore::Array * conversationIDs)
{
    mSync->purgeFromTrashPeopleConversations(conversationIDs);
}

void Account::starPeopleConversations(mailcore::Array * conversationIDs)
{
    mSync->starPeopleConversations(conversationIDs);
}

void Account::unstarPeopleConversations(mailcore::Array * conversationIDs)
{
    mSync->unstarPeopleConversations(conversationIDs);
}

void Account::markAsReadPeopleConversations(mailcore::Array * conversationIDs)
{
    mSync->markAsReadPeopleConversations(conversationIDs);
}

void Account::markAsUnreadPeopleConversations(mailcore::Array * conversationIDs)
{
    mSync->markAsUnreadPeopleConversations(conversationIDs);
}

void Account::markAsReadMessages(mailcore::Array * messageRowIDs)
{
    mSync->markAsReadMessages(messageRowIDs);
}

void Account::removeConversationFromFolder(mailcore::Array * conversationIDs, mailcore::String * folderPath)
{
    mSync->removeConversationFromFolder(conversationIDs, folderPath);
}

void Account::saveMessageToDraft(mailcore::String * messageID, mailcore::Data * messageData, bool pushNow)
{
    mSync->saveMessageToDraft(messageID, messageData, pushNow);
}

#if 0
void Account::saveMessageToSent(mailcore::String * messageID, mailcore::Data * messageData)
{
    mSync->saveMessageToSent(messageID, messageData);
}
#endif

void Account::saveMessageToFolder(mailcore::String * messageID, mailcore::Data * messageData, mailcore::String * folderPath)
{
    mSync->saveMessageToFolder(messageID, messageData, folderPath);
}

void Account::removeDraftForSentMessage(mailcore::String * draftMessageID)
{
    mSync->removeDraftForSentMessage(draftMessageID);
}

bool Account::isSavingDraft(mailcore::String * draftMessageID)
{
    return mSync->isSavingDraft(draftMessageID);
}

void Account::copyPeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, mailcore::HashMap * foldersScores)
{
    mSync->copyPeopleConversations(conversationIDs, folderPath, foldersScores);
}

void Account::movePeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, mailcore::HashMap * foldersScores)
{
    mSync->movePeopleConversations(conversationIDs, folderPath, foldersScores);
}

void Account::purgePeopleConversations(mailcore::Array * conversationIDs)
{
    mSync->purgePeopleConversations(conversationIDs);
}

void Account::purgeMessage(int64_t messageRowID)
{
    mSync->purgeMessage(messageRowID);
}

void Account::addLabelToConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, bool isTrash)
{
    int64_t folderID = isTrash ? folderIDForPath(trashFolderPath()) : -1;
    mSync->addLabelToConversations(conversationIDs, folderPath, folderID);
}

void Account::removeLabelFromConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, bool isTrash)
{
    int64_t folderID = isTrash ? folderIDForPath(trashFolderPath()) : -1;
    mSync->removeLabelFromConversations(conversationIDs, folderPath, folderID);
}

void Account::fetchConversationIDForMessageID(mailcore::String * messageID)
{
    mSync->fetchConversationIDForMessageID(messageID);
}

void Account::createFolder(mailcore::String * folderPath)
{
    mSync->createFolder(folderPath);
}

void Account::renameFolder(mailcore::String * initialFolderPath, mailcore::String * destinationFolderPath)
{
    mSync->renameFolder(initialFolderPath, destinationFolderPath);
}

void Account::deleteFolder(mailcore::String * folderPath)
{
    mSync->deleteFolder(folderPath);
}

bool Account::shouldShowProgressForFolder(int64_t folderID)
{
    return mSync->shouldShowProgressForFolder(folderID);
}

bool Account::canLoadMoreForFolder(int64_t folderID)
{
    return mSync->canLoadMoreForFolder(folderID);
}

void Account::refreshFolder(int64_t folderID)
{
    mSync->refreshFolder(folderID);
}

unsigned int Account::headersProgressValueForFolder(int64_t folderID)
{
    return mSync->headersProgressValueForFolder(folderID);
}

unsigned int Account::headersProgressMaxForFolder(int64_t folderID)
{
    return mSync->headersProgressMaxForFolder(folderID);
}

bool Account::loadMoreForFolder(int64_t folderID)
{
    return mSync->loadMoreForFolder(folderID);
}

void Account::resetMessagesToLoadForFolder(int64_t folderID)
{
    mSync->resetMessagesToLoadForFolder(folderID);
}

bool Account::messagesToLoadCanBeResetForFolder(int64_t folderID)
{
    return mSync->messagesToLoadCanBeResetForFolder(folderID);
}

void Account::setWaitingLoadMoreForFolder(int64_t folderID, bool waitingLoadMore)
{
    mSync->setWaitingLoadMoreForFolder(folderID, waitingLoadMore);
}

bool Account::isWaitingLoadMoreForFolder(int64_t folderID)
{
    return mSync->isWaitingLoadMoreForFolder(folderID);
}

IMAPAttachmentDownloader * Account::attachmentDownloader()
{
    IMAPAttachmentDownloader * downloader = new IMAPAttachmentDownloader();
    downloader->setAccount(this);
    downloader->autorelease();
    return downloader;
}

void Account::registerPartDownloader(IMAPAttachmentDownloader * downloader)
{
    mSync->registerPartDownloader(downloader);
}

void Account::unregisterPartDownloader(IMAPAttachmentDownloader * downloader)
{
    mSync->unregisterPartDownloader(downloader);
}

bool Account::isSyncingFolder(mailcore::String * folderPath)
{
    return mSync->isSyncingFolder(folderPath);
}

mailcore::String * Account::urgentTaskDescriptionForFolder(mailcore::String * folderPath)
{
    return mSync->urgentTaskDescriptionForFolder(folderPath);
}

mailcore::String * Account::syncStateDescriptionForFolder(mailcore::String * folderPath)
{
    return mSync->syncStateDescriptionForFolder(folderPath);
}

mailcore::HashMap * Account::standardFolders()
{
    HashMap * result = HashMap::hashMap();
    if (inboxFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(inboxFolderPath())), MCSTR("\\Inbox"));
    }
    if (allMailFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(allMailFolderPath())), MCSTR("\\All"));
    }
    if (archiveFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(archiveFolderPath())), MCSTR("\\Archive"));
    }
    if (draftsFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(draftsFolderPath())), MCSTR("\\Draft"));
    }
    if (trashFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(trashFolderPath())), MCSTR("\\Trash"));
    }
    if (importantFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(importantFolderPath())), MCSTR("\\Important"));
    }
    if (starredFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(starredFolderPath())), MCSTR("\\Starred"));
    }
    if (spamFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(spamFolderPath())), MCSTR("\\Spam"));
    }
    if (sentFolderPath() != NULL) {
        result->setObjectForKey(Value::valueWithLongLongValue(folderIDForPath(sentFolderPath())), MCSTR("\\Sent"));
    }
    return result;
}

MailStorageView * Account::openViewForSearchKeywords(mailcore::Array * keywords)
{
    MailStorageView * result = mSync->storage()->openViewForSearchKeywords(keywords, standardFolders(), currentEmailSet());
    result->setInboxFolderID(folderIDForPath(inboxFolderPath()));
    result->setAllMailFolderID(folderIDForPath(allMailFolderPath()));
    result->setArchiveFolderID(folderIDForPath(archiveFolderPath()));
    result->setDraftsFolderID(folderIDForPath(draftsFolderPath()));
    result->setTrashFolderID(folderIDForPath(trashFolderPath()));
    result->setSpamFolderID(folderIDForPath(spamFolderPath()));
    result->setSentFolderID(folderIDForPath(sentFolderPath()));
    return result;
}

void Account::closeViewForSearch(MailStorageView * view)
{
    mSync->storage()->closeViewForSearch(view);
}

void Account::openViewForFolder(int64_t folderID, time_t ageLimit)
{
    openFolderPath(pathForFolderID(folderID));
    mSync->storage()->openViewForFolder(folderID, standardFolders(), currentEmailSet(), ageLimit);
    MailStorageView * view = viewForFolder(folderID);
    if (view->openedCount() == 1) {
        view->setInboxFolderID(folderIDForPath(inboxFolderPath()));
        view->setAllMailFolderID(folderIDForPath(allMailFolderPath()));
        view->setArchiveFolderID(folderIDForPath(archiveFolderPath()));
        view->setDraftsFolderID(folderIDForPath(draftsFolderPath()));
        view->setTrashFolderID(folderIDForPath(trashFolderPath()));
        view->setSpamFolderID(folderIDForPath(spamFolderPath()));
        view->setSentFolderID(folderIDForPath(sentFolderPath()));
    }
}

MailStorageView * Account::viewForFolder(int64_t folderID)
{
    return mSync->storage()->viewForFolder(folderID);
}

void Account::closeViewForFolder(int64_t folderID)
{
    mSync->storage()->closeViewForFolder(folderID);
    closeFolderPath(pathForFolderID(folderID));
}

MailStorageView * Account::viewForCounters()
{
    return mSync->storage()->viewForCounters();
}

void Account::closeViewForCounters(MailStorageView * view)
{
    mSync->storage()->closeViewForCounters(view);
}

mailcore::Set * Account::currentEmailSet()
{
    Set * emailSet = Set::set();
    emailSet->addObject(accountInfo()->email());
    mc_foreacharray(Address, address, accountInfo()->aliases()) {
        emailSet->addObject(address->mailbox());
    }
    return emailSet;
}

MailDBMessageInfoOperation * Account::messageInfoOperation(int64_t messageRowID,
                                                           bool renderImageEnabled)
{
    return mSync->storage()->messageInfoOperation(messageRowID, currentEmailSet(), renderImageEnabled);
}

MailDBConversationMessagesOperation * Account::messagesForPeopleConversationOperation(int64_t peopleConversationID,
                                                                                      mailcore::HashMap * foldersScores)
{
    return mSync->storage()->messagesForPeopleConversationOperation(peopleConversationID, foldersScores);
}

MailDBRetrievePartOperation * Account::dataForPartOperation(int64_t messageRowID,
                                                            mailcore::String * partID)
{
    return mSync->storage()->dataForPartOperation(messageRowID, partID);
}

MailDBRetrievePartOperation * Account::dataForLocalPartOperation(int64_t messageRowID,
                                                                 mailcore::String * uniqueID)
{
    return mSync->storage()->dataForLocalPartOperation(messageRowID, uniqueID);
}

MailDBRetrievePartOperation * Account::dataForPartByUniqueIDOperation(int64_t messageRowID,
                                                                      mailcore::String * uniqueID)
{
    return mSync->storage()->dataForPartByUniqueIDOperation(messageRowID, uniqueID);
}

void Account::sendMessage(mailcore::String * draftMessageID, mailcore::Data * messageData)
{
    mSendQueue->sendMessage(draftMessageID, messageData);
}

bool Account::isSending()
{
    return mSendQueue->isSending();
}

unsigned int Account::currentMessageIndex()
{
    return mSendQueue->currentMessageIndex();
}

unsigned int Account::totalMessagesCount()
{
    return mSendQueue->totalMessagesCount();
}

unsigned int Account::currentMessageProgress()
{
    return mSendQueue->currentMessageProgress();
}

unsigned int Account::currentMessageProgressMax()
{
    return mSendQueue->currentMessageProgressMax();
}

mailcore::String * Account::currentMessageSubject()
{
    return mSendQueue->currentMessageSubject();
}

void Account::setDeliveryEnabled(bool enabled)
{
    return mSendQueue->setDeliveryEnabled(enabled);
}

#pragma mark delegate

mailcore::Array * Account::accountSynchronizerFavoriteFolders(IMAPAccountSynchronizer * account)
{
    return accountInfo()->favoriteFolders();
}

void Account::accountSynchronizerOpened(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountOpened(this);
    }
}

void Account::accountSynchronizerClosed(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountClosed(this);
    }
}

void Account::accountSynchronizerGotFolders(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountGotFolders(this);
    }
}

void Account::accountSynchronizerConnected(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountConnected(this);
    }
}

void Account::accountSynchronizerFetchSummaryDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountFetchSummaryDone(this, error, messageRowID);
    }
}

void Account::accountSynchronizerFetchPartDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountFetchPartDone(this, error, messageRowID, partID);
    }
}

void Account::accountSynchronizerMessageSourceFetched(IMAPAccountSynchronizer * account, hermes::ErrorCode error,
                                                      int64_t folderID, int64_t messageRowID,
                                                      mailcore::Data * messageData)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountMessageSourceFetched(this, error, folderID, messageRowID, messageData);
    }
}

void Account::accountSynchronizerStateUpdated(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountStateUpdated(this);
    }
}

void Account::accountSynchronizerLocalMessageSaved(IMAPAccountSynchronizer * account, int64_t folderID, mailcore::String * messageID, int64_t messageRowID, bool willPushToServer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountLocalMessageSaved(this, folderID, messageID, messageRowID, willPushToServer);
    }
}

void Account::accountSynchronizerPushMessageDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, int64_t messageRowID)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountPushMessageDone(this, error, messageRowID);
    }
}

void Account::accountSynchronizerMessageSaved(IMAPAccountSynchronizer * account, int64_t folderID, mailcore::String * messageID)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountMessageSaved(this, folderID, messageID);
    }
}

void Account::accountSynchronizerSyncDone(IMAPAccountSynchronizer * account, hermes::ErrorCode error, mailcore::String * folderPath)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSyncDone(this, error, folderPath);
    }
}

void Account::accountSynchronizerNotifyAuthenticationError(IMAPAccountSynchronizer * account, hermes::ErrorCode error)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountNotifyAuthenticationError(this, error);
    }
}

void Account::accountSynchronizerNotifyConnectionError(IMAPAccountSynchronizer * account, hermes::ErrorCode error)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountNotifyConnectionError(this, error);
    }
}

void Account::accountSynchronizerNotifyFatalError(IMAPAccountSynchronizer * account, hermes::ErrorCode error)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountNotifyFatalError(this, error);
    }
}

void Account::accountSynchronizerNotifyCopyError(IMAPAccountSynchronizer * account, hermes::ErrorCode error)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountNotifyCopyError(this, error);
    }
}

void Account::accountSynchronizerNotifyAppendError(IMAPAccountSynchronizer * account, hermes::ErrorCode error)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountNotifyAppendError(this, error);
    }
}

void Account::accountSynchronizerAccountInfoChanged(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountIMAPInfoChanged(this);
    }
}

void Account::accountSynchronizerFoldersUpdated(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountFoldersUpdated(this);
    }
}

void Account::accountSynchronizerFoldersChanged(IMAPAccountSynchronizer * account, hermes::ErrorCode error)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountFoldersChanged(this, error);
    }
}

void Account::accountSynchronizerFolderUnseenChanged(IMAPAccountSynchronizer * account, mailcore::String * folderPath)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountFolderUnseenChanged(this, folderPath);
    }
}

void Account::accountSynchronizerNotifyUnreadEmail(IMAPAccountSynchronizer * account, mailcore::String * folderPath)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountNotifyUnreadEmail(this, folderPath);
    }
}

void Account::accountSynchronizerHasConversationIDForMessageID(IMAPAccountSynchronizer * account, mailcore::String * messageID, int64_t conversationID)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountHasConversationIDForMessageID(this, messageID, conversationID);
    }
}

void Account::accountSynchronizerHasNewContacts(IMAPAccountSynchronizer * account)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountHasNewContacts(this);
    }
}

void Account::accountSynchronizerRemoveMessageIDsFromSendQueue(mailcore::Set * messageIDs)
{
    mc_foreacharray(String, messageID, messageIDs->allObjects()) {
        mSendQueue->removeMessageWithDraftMessageID(messageID);
    }
}

void Account::messageQueueSenderSendDone(MessageQueueSender * sender)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSendDone(this);
    }
}

void Account::messageQueueSenderSendingStateChanged(MessageQueueSender * sender)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSendingStateChanged(this);
    }
}

void Account::messageQueueSenderSent(MessageQueueSender * sender, mailcore::MessageParser * parsedMessage)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountMessageSent(this, parsedMessage);
    }
}

void Account::messageQueueSenderAccountInfoChanged(MessageQueueSender * sender)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSMTPInfoChanged(this);
    }
}

void Account::messageQueueSenderProgress(MessageQueueSender * sender)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSenderProgress(this);
    }
}

void Account::messageQueueSenderNotifyAuthenticationError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSenderNotifyAuthenticationError(this, error, parsedMessage);
    }
}

void Account::messageQueueSenderNotifyConnectionError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSenderNotifyConnectionError(this, error, parsedMessage);
    }
}

void Account::messageQueueSenderNotifyFatalError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSenderNotifyFatalError(this, error, parsedMessage);
    }
}

void Account::messageQueueSenderNotifySendError(MessageQueueSender * sender, hermes::ErrorCode error, mailcore::MessageParser * parsedMessage)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        AccountObserver * observer = (AccountObserver *) carray_get(mObservers, i);
        observer->accountSenderNotifySendError(this, error, parsedMessage);
    }
}

#pragma mark override default behavior

mailcore::String * Account::description()
{
    if (accountInfo() != NULL) {
        return String::stringWithUTF8Format("<%s:%p:%s>", className()->UTF8Characters(), this, MCUTF8(accountInfo()->email()));
    }
    else {
        return String::stringWithUTF8Format("<%s:%p:[no config set]>", className()->UTF8Characters(), this);
    }
}
