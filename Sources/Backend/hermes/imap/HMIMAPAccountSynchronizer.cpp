// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPAccountSynchronizer.h"

#include <sys/stat.h>

#include "HMIMAPFolderSynchronizer.h"
#include "HMMailStorage.h"
#include "HMMailDBOpenOperation.h"
#include "HMMailDBAddLocalMessagesOperation.h"
#include "HMMailDBPeopleViewIDOperation.h"
#include "HMIMAPAccountSynchronizerDelegate.h"
#include "DJLLog.h"
#include "HMActivityItem.h"
#include "HMOAuth2.h"
#include "HMUtils.h"
#include "HMIMAPAccountInfo.h"
#include "HMReachability.h"
#include "HMIMAPAttachmentDownloader.h"
#include "HMMailDBMessagesOperation.h"
#include "HMMailDBMessagesRecipientsOperation.h"
#include "HMMailDBAddToSavedRecipientsOperation.h"
#include "DJLAssert.h"
#include "HMSerialization.h"
#include "HMIMAPSyncTypesUtils.h"
#include "HMMailDBChanges.h"

using namespace hermes;
using namespace mailcore;

#define MAX_SYNCING_FOLDERS 3
#define MAX_CONNECTION_ERRORS_COUNT 3

#define LOG_CLEANUP(...) DJLLogWithID("cleanup", __VA_ARGS__)
#define LOG(...) DJLLogWithID("sync", __VA_ARGS__)
#define LOGSTACK(...) DJLLogStackWithID("sync", __VA_ARGS__)

enum {
    CONNECTION_STATE_SHOULD_RETRY,
    CONNECTION_STATE_SHOULD_AUTODETECT,
    CONNECTION_STATE_SHOULD_FAIL,
};

enum {
    SETUP_SESSION_CALLBACK_NONE,
    SETUP_SESSION_CALLBACK_OPEN,
    SETUP_SESSION_CALLBACK_CONNECT,
};

#define FOLDERS_REFRESH_DELAY (30 * 60)

IMAPAccountSynchronizer::IMAPAccountSynchronizer()
{
    mInboxFolderPath = NULL;
    mDraftsFolderPath = NULL;
    mImportantFolderPath = NULL;
    mAllMailFolderPath = NULL;
    mStarredFolderPath = NULL;
    mSentFolderPath = NULL;
    mTrashFolderPath = NULL;
    mSpamFolderPath = NULL;
    mArchiveFolderPath = NULL;
    mFoldersSynchronizers = new HashMap();
    mPath = NULL;

    mAccountInfo = NULL;

    mDelegate = NULL;
    
    mStorage = NULL;
    mSession = NULL;
    
    mOpenOperation = NULL;
    mCloseOperation = NULL;
    mFetchFoldersOp = NULL;
    mStoreFoldersOp = NULL;
    mStoreMainFoldersOp = NULL;

    mFetchFoldersActivity = NULL;
    
    mSyncingFolders = new Set();
    mOpenFoldersPaths = new Set();
    mOpenCountFoldersPaths = new HashMap();
    
    mDisableSyncCount = 0;
    
    mMessageFetchFailedSet = new IndexSet();
    
    pthread_mutex_init(&mProtocolLogFileLock, NULL);
    mProtocolLogFiles = chash_new(CHASH_DEFAULTSIZE, CHASH_COPYKEY);
    
    mPendingFlagsOperations = new Array();
    mPendingSaveMessageOperations = new Array();
    mPendingCopyOperations = new Array();
    mPendingMoveOperations = new Array();
    mPendingPurgeOperations = new Array();
    mRemoveDraftForSendOperations = new Array();
    mPendingLabelOperations = new Array();
    mPendingFolderOperations = new Array();
    mFetchConversationIDOperations = new Array();
    mFolderOperationNotification = false;
    mDisabledIdleSinceFolderOperation = false;

    mSearchKeywords = NULL;
    mFoldersThatNeedsPushMessages = new IndexSet();

    mSetupSessionCallback = SETUP_SESSION_CALLBACK_NONE;

    mError = hermes::ErrorNone;
    mConnectionErrorCount = 0;
    mAuthenticationErrorCount = 0;
    mConnectionRetryState = CONNECTION_STATE_SHOULD_RETRY;

    mValidator = NULL;
    mGotFolders = false;
    mAttachmentDownloaders = new Array();

    mMessageSavingInfo = new HashMap();
    mSettingUpSession = false;
    mOpenedDatabase = false;
    mRetrieveAuth2TokenTries = 0;
    mFoldersFetched = false;
    mFetchingFolders = false;

    mPendingAddressCollection = false;
    mCollectingAddresses = false;
    mScheduledAddressCollection = false;
    mMessagesOp = NULL;
    mAddressCollectionStartTime = 0;
    mCollectAddressesMessagesRowIDs = NULL;
    mCollectAddressesMessagesLastRowID = 0;
    mFetchedRecipients = NULL;
    mFetchRecipientOp = NULL;
    mSaveRecipientsOp = NULL;
    mRecipients = NULL;
    mClosed = false;
    mLogEnabled = false;
    mSyncType = IMAPSyncTypeOther;
    mCreatedMissingFolders = false;
    mCreateMissingFolderIndex = 0;
    mMissingFolderToCreate = NULL;
    mMissingFolderCreateOp = NULL;

    Reachability::sharedManager()->addObserver(this);
}

IMAPAccountSynchronizer::~IMAPAccountSynchronizer()
{
    LOG_CLEANUP("IMAPAccountSynchronizer dealloced");
    Reachability::sharedManager()->removeObserver(this);

    MC_SAFE_RELEASE(mMissingFolderCreateOp);
    MC_SAFE_RELEASE(mMissingFolderToCreate);

    MC_SAFE_RELEASE(mRecipients);
    MC_SAFE_RELEASE(mSaveRecipientsOp);
    MC_SAFE_RELEASE(mFetchRecipientOp);
    MC_SAFE_RELEASE(mFetchedRecipients);
    MC_SAFE_RELEASE(mCollectAddressesMessagesRowIDs);
    MC_SAFE_RELEASE(mMessagesOp);

    MC_SAFE_RELEASE(mMessageSavingInfo);
    MC_SAFE_RELEASE(mAttachmentDownloaders);
    MC_SAFE_RELEASE(mValidator);

    MC_SAFE_RELEASE(mInboxFolderPath);
    MC_SAFE_RELEASE(mDraftsFolderPath);
    MC_SAFE_RELEASE(mImportantFolderPath);
    MC_SAFE_RELEASE(mAllMailFolderPath);
    MC_SAFE_RELEASE(mStarredFolderPath);
    MC_SAFE_RELEASE(mSentFolderPath);
    MC_SAFE_RELEASE(mTrashFolderPath);
    MC_SAFE_RELEASE(mSpamFolderPath);
    MC_SAFE_RELEASE(mArchiveFolderPath);

    MC_SAFE_RELEASE(mPath);

    MC_SAFE_RELEASE(mAccountInfo);

    MC_SAFE_RELEASE(mStorage);
    unsetupSession();

    MC_SAFE_RELEASE(mOpenOperation);
    MC_SAFE_RELEASE(mCloseOperation);
    MC_SAFE_RELEASE(mFetchFoldersOp);
    MC_SAFE_RELEASE(mStoreFoldersOp);
    MC_SAFE_RELEASE(mStoreFoldersOp);
    MC_SAFE_RELEASE(mStoreMainFoldersOp);

    MC_SAFE_RELEASE(mFetchFoldersActivity);

    MC_SAFE_RELEASE(mFoldersThatNeedsPushMessages);
    MC_SAFE_RELEASE(mSearchKeywords);
    MC_SAFE_RELEASE(mFetchConversationIDOperations);
    MC_SAFE_RELEASE(mPendingFolderOperations);
    MC_SAFE_RELEASE(mPendingLabelOperations);
    MC_SAFE_RELEASE(mRemoveDraftForSendOperations);
    MC_SAFE_RELEASE(mPendingPurgeOperations);
    MC_SAFE_RELEASE(mPendingMoveOperations);
    MC_SAFE_RELEASE(mPendingCopyOperations);
    MC_SAFE_RELEASE(mPendingSaveMessageOperations);
    MC_SAFE_RELEASE(mPendingFlagsOperations);
    chash_free(mProtocolLogFiles);
    pthread_mutex_destroy(&mProtocolLogFileLock);
    MC_SAFE_RELEASE(mSyncingFolders);
    MC_SAFE_RELEASE(mOpenCountFoldersPaths);
    MC_SAFE_RELEASE(mOpenFoldersPaths);
    MC_SAFE_RELEASE(mFoldersSynchronizers);
    MC_SAFE_RELEASE(mMessageFetchFailedSet);
}

void IMAPAccountSynchronizer::reachabilityChanged(Reachability * reachability)
{
    if (reachability->isReachable()) {
        LOG_ERROR("reachability changed - is reachable");
        mConnectionErrorCount = 0;
        mAuthenticationErrorCount = 0;
        disconnect();
        notifyChangedNetwork();
        connect();
    }
    else {
        LOG_ERROR("reachability changed - is not reachable");
        failPendingRequests(ErrorNoNetwork);
        disconnect();
    }
}

Object * IMAPAccountSynchronizer::retain()
{
    LOG_CLEANUP("Accountsync %p retain %i", this, retainCount() + 1);
    Object::retain();

    return this;
}

void IMAPAccountSynchronizer::release()
{
    LOG_CLEANUP("Accountsync %p release %i", this, retainCount() - 1);
    Object::release();
}

void IMAPAccountSynchronizer::setLogEnabled(bool enabled)
{
    pthread_mutex_lock(&mProtocolLogFileLock);
    mLogEnabled = enabled;
    pthread_mutex_unlock(&mProtocolLogFileLock);
}

void IMAPAccountSynchronizer::setAccountInfo(IMAPAccountInfo * info)
{
    MC_SAFE_REPLACE_RETAIN(IMAPAccountInfo, mAccountInfo, info);
}

IMAPAccountInfo * IMAPAccountSynchronizer::accountInfo()
{
    return mAccountInfo;
}

void IMAPAccountSynchronizer::setDelegate(IMAPAccountSynchronizerDelegate * delegate)
{
    mDelegate = delegate;
}

IMAPAccountSynchronizerDelegate * IMAPAccountSynchronizer::delegate()
{
    return mDelegate;
}

void IMAPAccountSynchronizer::setPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mPath, path);
}

String * IMAPAccountSynchronizer::path()
{
    return mPath;
}

#pragma mark -
#pragma mark main folders

String * IMAPAccountSynchronizer::inboxFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mInboxFolderPath;
}

String * IMAPAccountSynchronizer::allMailFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mAllMailFolderPath;
}

String * IMAPAccountSynchronizer::archiveFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mArchiveFolderPath;
}

String * IMAPAccountSynchronizer::trashFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mTrashFolderPath;
}

String * IMAPAccountSynchronizer::sentFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mSentFolderPath;
}

String * IMAPAccountSynchronizer::draftsFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mDraftsFolderPath;
}

String * IMAPAccountSynchronizer::importantFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mImportantFolderPath;
}

String * IMAPAccountSynchronizer::spamFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mSpamFolderPath;
}

String * IMAPAccountSynchronizer::starredFolderPath()
{
    if (!mGotFolders) {
        return NULL;
    }
    return mStarredFolderPath;
}

mailcore::Array * IMAPAccountSynchronizer::componentsForFolderPath(mailcore::String * path)
{
    if (mStorage == NULL) {
        return NULL;
    }
    return mStorage->componentsForFolderPath(path);
//    if (mStorage->defaultNamespace() == NULL) {
//        return NULL;
//    }
//    return mStorage->defaultNamespace()->componentsFromPath(path);
}

#pragma mark addresses to complete from

mailcore::Array * IMAPAccountSynchronizer::addresses()
{
    return mRecipients;
}

#pragma mark open/close folders

void IMAPAccountSynchronizer::openFolderPath(mailcore::String * path)
{
    if (mOpenFoldersPaths->containsObject(path)) {
        Value * value = (Value *) mOpenCountFoldersPaths->objectForKey(path);
        value = Value::valueWithIntValue(value->intValue() + 1);
        mOpenCountFoldersPaths->setObjectForKey(path, value);
    }
    else if (path != NULL) {
        mOpenCountFoldersPaths->setObjectForKey(path, Value::valueWithIntValue(1));
        mOpenFoldersPaths->addObject(path);
    }
}

void IMAPAccountSynchronizer::closeFolderPath(mailcore::String * path)
{
    if (path == NULL) {
        return;
    }
    Value * value = (Value *) mOpenCountFoldersPaths->objectForKey(path);
    if (value == NULL) {
        return;
    }
    if (value->intValue() == 1) {
        mOpenCountFoldersPaths->removeObjectForKey(path);
        mOpenFoldersPaths->removeObject(path);
    }
    else {
        value = Value::valueWithIntValue(value->intValue() - 1);
        mOpenCountFoldersPaths->setObjectForKey(path, value);
    }
}

Array * IMAPAccountSynchronizer::folders()
{
    return mFoldersSynchronizers->allKeys();
}

MailStorage * IMAPAccountSynchronizer::storage()
{
    return mStorage;
}

IMAPAsyncSession * IMAPAccountSynchronizer::session()
{
    return mSession;
}

#pragma mark -
#pragma mark update folders list

void IMAPAccountSynchronizer::setupSession()
{
    if (mSettingUpSession) {
        LOG_ERROR("%s: setup session while setup session is not progress", MCUTF8(mAccountInfo->email()));
        return;
    }

    mFoldersFetched = false;
    mSettingUpSession = true;
    mRetrieveAuth2TokenTries = 0;
    LOG_ERROR("%s: setup session, getting oauth2 token", MCUTF8(mAccountInfo->email()));
    retain();
    if (accountInfo()->password() != NULL) {
        setupSessionWithPassword();
    }
    else {
        retrieveOAuth2Token();
    }
}

void IMAPAccountSynchronizer::retrieveOAuth2Token()
{
    mRetrieveAuth2TokenTries ++;
    LOG_ERROR("%s: getting oauth2 token", MCUTF8(mAccountInfo->email()));
    //OAuth2GetTokenForEmail(accountInfo()->email(), &oauth2GetTokenCallback, (void *) this);
    OAuth2GetToken(accountInfo()->OAuth2RefreshToken(), mAccountInfo->providerIdentifier(), &oauth2GetTokenCallback, (void *) this);
}

void IMAPAccountSynchronizer::oauth2GetTokenCallback(hermes::ErrorCode code, mailcore::String * oauth2Token, void * data)
{
    IMAPAccountSynchronizer * sync = (IMAPAccountSynchronizer *) data;
    LOG_ERROR("%s: got oauth2 token %i %s", MCUTF8(sync->mAccountInfo->email()), code, MCUTF8(oauth2Token));

    if ((code == ErrorConnection) && (sync->mRetrieveAuth2TokenTries <= 1)) {
        LOG_ERROR("%s: retry getting oauth2 token", MCUTF8(sync->mAccountInfo->email()));
        sync->retrieveOAuth2Token();
        return;
    }
    else if (code == ErrorAuthentication) {
        sync->mSettingUpSession = false;
        sync->delegate()->accountSynchronizerNotifyAuthenticationError(sync, code);
        return;
    }

    MCAssert(sync != NULL);
    sync->setupSessionDone(code, oauth2Token);
}

void IMAPAccountSynchronizer::setupSessionDone(hermes::ErrorCode code, mailcore::String * oauth2Token)
{
    mSettingUpSession = false;

    if (code != hermes::ErrorNone) {
        connectionError(code);
        if (mSetupSessionCallback == SETUP_SESSION_CALLBACK_OPEN) {
            openSetupSessionDone(code);
        }
        else if (mSetupSessionCallback == SETUP_SESSION_CALLBACK_CONNECT) {
            connectSetupSessionDone(code);
        }
        release();
        return;
    }

    accountInfo()->setOAuth2Token(oauth2Token);

    mSession = new IMAPAsyncSession();
    mSession->clientIdentity()->setVendor(MCSTR("etpan"));
    mSession->clientIdentity()->setName(MCSTR("dejalu"));
    mSession->clientIdentity()->setVersion(MCSTR("0.1"));
    mSession->setHostname(accountInfo()->hostname());
    mSession->setPort(accountInfo()->port());
    mSession->setUsername(accountInfo()->username());
    //mSession->setPassword(mPassword);
    mSession->setOAuth2Token(oauth2Token);
    mSession->setAuthType(AuthTypeXOAuth2);
    mSession->setConnectionType(accountInfo()->connectionType());
    mSession->setTimeout(30);
    mSession->setAllowsFolderConcurrentAccessEnabled(true);
    mSession->setConnectionLogger(this);

    LOG_ERROR("%s: created session", MCUTF8(mAccountInfo->email()));

    setFoldersSynchronizers();

    if (code == hermes::ErrorNone) {
        unsigned int count = 0;
        if (mStorage->folders() != NULL) {
            count = mStorage->folders()->count();
        }
        
        if ((count == 0) || (inboxFolderPath() == NULL)) {
            LOG_ERROR("%s: fetch folders", MCUTF8(mAccountInfo->email()));
            fetchFolders();
        }
        else {
            LOG_ERROR("%s: start sync", MCUTF8(mAccountInfo->email()));
            startSync();
        }
    }

    if (mSetupSessionCallback == SETUP_SESSION_CALLBACK_OPEN) {
        openSetupSessionDone(code);
    }
    else if (mSetupSessionCallback == SETUP_SESSION_CALLBACK_CONNECT) {
        connectSetupSessionDone(code);
    }
    release();
}

void IMAPAccountSynchronizer::setupSessionWithPassword()
{
    mSettingUpSession = false;

    mSession = new IMAPAsyncSession();
    mSession->clientIdentity()->setVendor(MCSTR("etpan"));
    mSession->clientIdentity()->setName(MCSTR("dejalu"));
    mSession->clientIdentity()->setVersion(MCSTR("0.1"));
    mSession->setHostname(accountInfo()->hostname());
    mSession->setPort(accountInfo()->port());
    mSession->setUsername(accountInfo()->username());
    mSession->setPassword(accountInfo()->password());
    mSession->setAuthType(AuthTypeSASLNone);
    mSession->setConnectionType(accountInfo()->connectionType());
    mSession->setTimeout(30);
    mSession->setAllowsFolderConcurrentAccessEnabled(true);
    mSession->setConnectionLogger(this);

    LOG_ERROR("%s: created session", MCUTF8(mAccountInfo->email()));

    setFoldersSynchronizers();

    unsigned int count = 0;
    if (mStorage->folders() != NULL) {
        count = mStorage->folders()->count();
    }

    if ((count == 0) || (inboxFolderPath() == NULL)) {
        LOG_ERROR("%s: fetch folders", MCUTF8(mAccountInfo->email()));
        fetchFolders();
    }
    else {
        LOG_ERROR("%s: start sync", MCUTF8(mAccountInfo->email()));
        startSync();
    }

    if (mSetupSessionCallback == SETUP_SESSION_CALLBACK_OPEN) {
        openSetupSessionDone(ErrorNone);
    }
    else if (mSetupSessionCallback == SETUP_SESSION_CALLBACK_CONNECT) {
        connectSetupSessionDone(ErrorNone);
    }
    release();
}

void IMAPAccountSynchronizer::open()
{
    mSyncType = hermes::syncTypeWithProviderIdentifier(mAccountInfo->providerIdentifier());

    mStorage = new MailStorage();
    String * path = String::stringWithUTF8Format("%s/%s", mPath->UTF8Characters(), accountInfo()->email()->UTF8Characters());
    mStorage->setPath(path);
    
    mOpenOperation = mStorage->openOperation();
    mOpenOperation->retain();
    mOpenOperation->setCallback(this);
    mOpenOperation->start();
}

void IMAPAccountSynchronizer::openFinished()
{
    bool hasMainFolders = (mOpenOperation->mainFolders() != NULL);
    applyMainFolders(mOpenOperation->mainFolders());
    MC_SAFE_RELEASE(mOpenOperation);

    unsigned int count = 0;
    if (mStorage->folders() != NULL) {
        count = mStorage->folders()->count();
    }
    if (count != 0) {
        setupFolders(hasMainFolders);
    }

    mSetupSessionCallback = SETUP_SESSION_CALLBACK_OPEN;
    mOpenedDatabase = true;
    LOG_ERROR("%s: open finished", MCUTF8(mAccountInfo->email()));
    setupSession();
}

void IMAPAccountSynchronizer::openSetupSessionDone(hermes::ErrorCode code)
{
    mDelegate->accountSynchronizerOpened(this);
}

void IMAPAccountSynchronizer::close()
{
    mClosed = true;
    cancelTryReconnectNow();
    closeConnection();

    {
        mc_foreacharray(Operation, op, mPendingFlagsOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mPendingSaveMessageOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mPendingCopyOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mPendingMoveOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mPendingPurgeOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mRemoveDraftForSendOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mPendingLabelOperations) {
            op->cancel();
        }
    }
    {
        mc_foreacharray(Operation, op, mFetchConversationIDOperations) {
            op->cancel();
        }
    }
    if (mOpenOperation != NULL) {
        mOpenOperation->cancel();
    }
    if (mFetchRecipientOp != NULL) {
        mFetchRecipientOp->cancel();
    }
    if (mSaveRecipientsOp != NULL) {
        mSaveRecipientsOp->cancel();
    }
    if (mStoreFoldersOp != NULL) {
        mStoreFoldersOp->cancel();
    }
    if (mStoreMainFoldersOp != NULL) {
        mStoreMainFoldersOp->cancel();
    }
    if (mMessagesOp != NULL) {
        mMessagesOp->cancel();
    }

    retain();
    mCloseOperation = mStorage->closeOperation();
    mCloseOperation->retain();
    mCloseOperation->setCallback(this);
    mCloseOperation->start();
}

void IMAPAccountSynchronizer::closeFinished()
{
    MC_SAFE_RELEASE(mCloseOperation);
    mDelegate->accountSynchronizerClosed(this);
    release();
}

void IMAPAccountSynchronizer::failPendingRequests(hermes::ErrorCode error)
{
    //fprintf(stderr, "fail pending requests %i\n", error);
    mc_foreachhashmapValue(IMAPFolderSynchronizer, synchronizer, mFoldersSynchronizers) {
        synchronizer->failPendingRequests(error);
    }
}

void IMAPAccountSynchronizer::disconnect()
{
    //MCAssert(mSession != NULL);
    
    closeConnection();
    
    //mFoldersSynchronizers->removeAllObjects();
}

void IMAPAccountSynchronizer::connect()
{
    cancelTryReconnectNow();

    if (mValidator != NULL) {
        LOG_ERROR("%s: tried to connect while a session is being autodetected", MCUTF8(mAccountInfo->email()));
        return;
    }

    MCAssert(mSession == NULL);

    if (mSettingUpSession) {
        LOG_ERROR("%s: setup session in progress", MCUTF8(mAccountInfo->email()));
        return;
    }

    mSetupSessionCallback = SETUP_SESSION_CALLBACK_CONNECT;
    LOG_ERROR("%s: connect", MCUTF8(mAccountInfo->email()));
    setupSession();
}

void IMAPAccountSynchronizer::notifyChangedNetwork()
{
    mConnectionRetryState = CONNECTION_STATE_SHOULD_RETRY;
}

void IMAPAccountSynchronizer::connectSetupSessionDone(hermes::ErrorCode code)
{
    // Do nothing.
    mDelegate->accountSynchronizerConnected(this);
}

void IMAPAccountSynchronizer::fetchFolders()
{
    if (mFetchingFolders) {
        return;
    }
    mCreatedMissingFolders = false;
    refetchFolders();
}

void IMAPAccountSynchronizer::refetchFolders()
{
    LOG_ERROR("%s: fetch folders", MCUTF8(accountInfo()->email()));
    
    cancelDelayedPerformMethod((Object::Method) &IMAPAccountSynchronizer::refreshFoldersAfterDelay, NULL);

    mFetchingFolders = true;
    retain();
    mFetchFoldersActivity = new ActivityItem();
    mFetchFoldersActivity->setProgressString(MCSTR("fetch folders"));
    mFetchFoldersActivity->registerActivity();
    mFetchFoldersOp = mSession->fetchAllFoldersOperation();
    mFetchFoldersOp->retain();
    mFetchFoldersOp->setCallback(this);
    mFetchFoldersOp->start();
}

void IMAPAccountSynchronizer::fetchFoldersFinished()
{
    mError = hermes::ErrorNone;
    hermes::ErrorCode error = (hermes::ErrorCode) mFetchFoldersOp->error();
    mError = error;
//    if (isAuthenticationError(error) || isConnectionError(error) || isFatalError(error)) {
//        mError = error;
//    }

    if (mError != hermes::ErrorNone) {
        notifyFolderOperation(mError);
        mFetchFoldersActivity->unregisterActivity();
        MC_SAFE_RELEASE(mFetchFoldersActivity);
        MC_SAFE_RELEASE(mFetchFoldersOp);
        mFetchingFolders = false;
        handleError();
        release();
        return;
    }
    else {
        mConnectionErrorCount = 0;
        mAuthenticationErrorCount = 0;
    }

    mFetchFoldersActivity->unregisterActivity();
    MC_SAFE_RELEASE(mFetchFoldersActivity);
    LOG_ERROR("%s: folders: %s, namespace: %s\n", MCUTF8(accountInfo()->email()), MCUTF8(mFetchFoldersOp->folders()), MCUTF8(mSession->defaultNamespace()));
    storeFolders(mFetchFoldersOp->folders(), mSession->defaultNamespace());
    MC_SAFE_RELEASE(mFetchFoldersOp);
    release();
}

void IMAPAccountSynchronizer::storeFolders(Array * folders, mailcore::IMAPNamespace * ns)
{
    Array * foldersNames = new Array();

    MC_SAFE_RELEASE(mInboxFolderPath);
    MC_SAFE_RELEASE(mDraftsFolderPath);
    MC_SAFE_RELEASE(mImportantFolderPath);
    MC_SAFE_RELEASE(mAllMailFolderPath);
    MC_SAFE_RELEASE(mStarredFolderPath);
    MC_SAFE_RELEASE(mSentFolderPath);
    MC_SAFE_RELEASE(mTrashFolderPath);
    MC_SAFE_RELEASE(mSpamFolderPath);
    MC_SAFE_RELEASE(mArchiveFolderPath);
    
    MC_SAFE_REPLACE_COPY(String, mInboxFolderPath, MCSTR("INBOX"));
    mc_foreacharray(IMAPFolder, folder, folders) {
        if ((folder->flags() & IMAPFolderFlagNoSelect) != 0) {
            continue;
        }
        IMAPFolderFlag type = (IMAPFolderFlag) (folder->flags() & IMAPFolderFlagFolderTypeMask);
        switch (type) {
            case IMAPFolderFlagSentMail:
                MC_SAFE_REPLACE_COPY(String, mSentFolderPath, folder->path());
                break;
            case IMAPFolderFlagStarred:
                MC_SAFE_REPLACE_COPY(String, mStarredFolderPath, folder->path());
                break;
            case IMAPFolderFlagAllMail:
                MC_SAFE_REPLACE_COPY(String, mAllMailFolderPath, folder->path());
                break;
            case IMAPFolderFlagTrash:
                MC_SAFE_REPLACE_COPY(String, mTrashFolderPath, folder->path());
                break;
            case IMAPFolderFlagDrafts:
                MC_SAFE_REPLACE_COPY(String, mDraftsFolderPath, folder->path());
                break;
            case IMAPFolderFlagSpam:
                MC_SAFE_REPLACE_COPY(String, mSpamFolderPath, folder->path());
                break;
            case IMAPFolderFlagImportant:
                MC_SAFE_REPLACE_COPY(String, mImportantFolderPath, folder->path());
                break;
            case IMAPFolderFlagArchive:
                MC_SAFE_REPLACE_COPY(String, mArchiveFolderPath, folder->path());
                break;
            default:
                break;
        }
        LOG("add %s", MCUTF8(folder->path()));
        foldersNames->addObject(folder->path());
    }

    Set * updatedFoldersSet = Set::setWithArray(foldersNames);

    if (mSyncType != IMAPSyncTypeGmail) {
        HashMap * folders = HashMap::hashMap();
        completeWithStandardFolders(folders);
        if (mSentFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("sent")))) {
                MC_SAFE_REPLACE_COPY(String, mSentFolderPath, folders->objectForKey(MCSTR("sent")));
            }
        }
        if (mStarredFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("starred")))) {
                MC_SAFE_REPLACE_COPY(String, mStarredFolderPath, folders->objectForKey(MCSTR("starred")));
            }
        }
        if (mAllMailFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("allmail")))) {
                MC_SAFE_REPLACE_COPY(String, mAllMailFolderPath, folders->objectForKey(MCSTR("allmail")));
            }
        }
        if (mTrashFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("trash")))) {
                MC_SAFE_REPLACE_COPY(String, mTrashFolderPath, folders->objectForKey(MCSTR("trash")));
            }
        }
        if (mDraftsFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("drafts")))) {
                MC_SAFE_REPLACE_COPY(String, mDraftsFolderPath, folders->objectForKey(MCSTR("drafts")));
            }
        }
        if (mSpamFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("spam")))) {
                MC_SAFE_REPLACE_COPY(String, mSpamFolderPath, folders->objectForKey(MCSTR("spam")));
            }
        }
        if (mImportantFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("important")))) {
                MC_SAFE_REPLACE_COPY(String, mImportantFolderPath, folders->objectForKey(MCSTR("important")));
            }
        }
        if (mArchiveFolderPath == NULL) {
            if (updatedFoldersSet->containsObject(folders->objectForKey(MCSTR("archive")))) {
                MC_SAFE_REPLACE_COPY(String, mArchiveFolderPath, folders->objectForKey(MCSTR("archive")));
            }
        }
    }

    Array * existingFolders = storage()->folders();
    Set * existingFoldersSet = Set::setWithArray(existingFolders);

    Array * foldersToAdd = Array::array();
    //Array * foldersToValidate = Array::array();
    Array * foldersToRemove = Array::array();
    //HashMap * uidValidities = HashMap::hashMap();
    {
        mc_foreacharray(String, folderPath, foldersNames) {
            if (!existingFoldersSet->containsObject(folderPath)) {
                foldersToAdd->addObject(folderPath);
            }
        }
    }
    {
        mc_foreacharray(String, folderPath, existingFolders) {
            if (!updatedFoldersSet->containsObject(folderPath)) {
                foldersToRemove->addObject(folderPath);
                LOG("remove %s", MCUTF8(folderPath));
            }
        }
    }

    MC_SAFE_RELEASE(foldersNames);

    LOG_ERROR("namespace: %s %s", MCUTF8(accountInfo()->email()), MCUTF8(ns));
    mStoreFoldersOp = mStorage->addFoldersOperation(foldersToAdd, foldersToRemove, ns);
    mStoreFoldersOp->retain();
    mStoreFoldersOp->setCallback(this);
    mStoreFoldersOp->start();
}

void IMAPAccountSynchronizer::storeFoldersFinished()
{
    MC_SAFE_RELEASE(mStoreFoldersOp);
    
    LOG("stored %s", MCUTF8DESC(mStorage->folders()));

    createMainFoldersIfNeeded();
}

HashMap * IMAPAccountSynchronizer::mainFolders()
{
    HashMap * result = HashMap::hashMap();
    if (mSentFolderPath != NULL) {
        result->setObjectForKey(MCSTR("sent"), mSentFolderPath);
    }
    if (mStarredFolderPath != NULL) {
        result->setObjectForKey(MCSTR("starred"), mStarredFolderPath);
    }
    if (mAllMailFolderPath != NULL) {
        result->setObjectForKey(MCSTR("allmail"), mAllMailFolderPath);
    }
    if (mTrashFolderPath != NULL) {
        result->setObjectForKey(MCSTR("trash"), mTrashFolderPath);
    }
    if (mDraftsFolderPath != NULL) {
        result->setObjectForKey(MCSTR("drafts"), mDraftsFolderPath);
    }
    if (mSpamFolderPath != NULL) {
        result->setObjectForKey(MCSTR("spam"), mSpamFolderPath);
    }
    if (mImportantFolderPath != NULL) {
        result->setObjectForKey(MCSTR("important"), mImportantFolderPath);
    }
    if (mArchiveFolderPath != NULL) {
        result->setObjectForKey(MCSTR("archive"), mArchiveFolderPath);
    }
    return result;
}

void IMAPAccountSynchronizer::applyMainFolders(HashMap * folders)
{
    if (folders == NULL)
        return;
    
    MC_SAFE_REPLACE_COPY(String, mInboxFolderPath, MCSTR("INBOX"));
    MC_SAFE_REPLACE_RETAIN(String, mSentFolderPath, folders->objectForKey(MCSTR("sent")));
    MC_SAFE_REPLACE_RETAIN(String, mStarredFolderPath, folders->objectForKey(MCSTR("starred")));
    MC_SAFE_REPLACE_RETAIN(String, mAllMailFolderPath, folders->objectForKey(MCSTR("allmail")));
    MC_SAFE_REPLACE_RETAIN(String, mTrashFolderPath, folders->objectForKey(MCSTR("trash")));
    MC_SAFE_REPLACE_RETAIN(String, mDraftsFolderPath, folders->objectForKey(MCSTR("drafts")));
    MC_SAFE_REPLACE_RETAIN(String, mSpamFolderPath, folders->objectForKey(MCSTR("spam")));
    MC_SAFE_REPLACE_RETAIN(String, mImportantFolderPath, folders->objectForKey(MCSTR("important")));
    MC_SAFE_REPLACE_RETAIN(String, mArchiveFolderPath, folders->objectForKey(MCSTR("archive")));
    
    if (mSentFolderPath != NULL) {
        if (mStorage->folderIDForPath(mSentFolderPath) == -1) {
            MC_SAFE_RELEASE(mSentFolderPath);
        }
    }
    if (mStarredFolderPath != NULL) {
        if (mStorage->folderIDForPath(mStarredFolderPath) == -1) {
            MC_SAFE_RELEASE(mStarredFolderPath);
        }
    }
    if (mAllMailFolderPath != NULL) {
        if (mStorage->folderIDForPath(mAllMailFolderPath) == -1) {
            MC_SAFE_RELEASE(mAllMailFolderPath);
        }
    }
    if (mTrashFolderPath != NULL) {
        if (mStorage->folderIDForPath(mTrashFolderPath) == -1) {
            MC_SAFE_RELEASE(mTrashFolderPath);
        }
    }
    if (mDraftsFolderPath != NULL) {
        if (mStorage->folderIDForPath(mDraftsFolderPath) == -1) {
            MC_SAFE_RELEASE(mDraftsFolderPath);
        }
    }
    if (mSpamFolderPath != NULL) {
        if (mStorage->folderIDForPath(mSpamFolderPath) == -1) {
            MC_SAFE_RELEASE(mSpamFolderPath);
        }
    }
    if (mDraftsFolderPath != NULL) {
        if (mStorage->folderIDForPath(mDraftsFolderPath) == -1) {
            MC_SAFE_RELEASE(mDraftsFolderPath);
        }
    }
    if (mImportantFolderPath != NULL) {
        if (mStorage->folderIDForPath(mImportantFolderPath) == -1) {
            MC_SAFE_RELEASE(mImportantFolderPath);
        }
    }
    if (mArchiveFolderPath != NULL) {
        if (mStorage->folderIDForPath(mArchiveFolderPath) == -1) {
            MC_SAFE_RELEASE(mArchiveFolderPath);
        }
    }
}

void IMAPAccountSynchronizer::createMainFoldersIfNeeded()
{
    LOG_ERROR("%s: create mail folders if needed", MCUTF8(accountInfo()->email()));
    if (mSyncType == IMAPSyncTypeGmail) {
        storeMainFolders();
        return;
    }

    if (mCreatedMissingFolders) {
        storeMainFolders();
        return;
    }

    mCreatedMissingFolders = true;

    LOG_ERROR("%s: create main folders", MCUTF8(accountInfo()->email()));
    createMainFolders();
}

void IMAPAccountSynchronizer::completeWithStandardFolders(HashMap * folders)
{
    MailProvider * provider = NULL;
    if (accountInfo()->providerIdentifier() != NULL) {
        provider = MailProvidersManager::sharedManager()->providerForIdentifier(accountInfo()->providerIdentifier());
    }
    if (provider == NULL) {
        provider = MailProvidersManager::sharedManager()->providerForIdentifier(MCSTR("default"));
    }
    MCAssert(provider != NULL);
    if (folders->objectForKey(MCSTR("sent")) == NULL) {
        if (provider->sentMailFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("sent"), provider->sentMailFolderPath());
        }
    }
    if (folders->objectForKey(MCSTR("starred")) == NULL) {
        if (provider->starredFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("starred"), provider->starredFolderPath());
        }
    }
    if (folders->objectForKey(MCSTR("archive")) == NULL) {
        if (provider->allMailFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("archive"), provider->allMailFolderPath());
        }
    }
    if (folders->objectForKey(MCSTR("trash")) == NULL) {
        if (provider->trashFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("trash"), provider->trashFolderPath());
        }
    }
    if (folders->objectForKey(MCSTR("drafts")) == NULL) {
        if (provider->draftsFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("drafts"), provider->draftsFolderPath());
        }
    }
    if (folders->objectForKey(MCSTR("spam")) == NULL) {
        if (provider->spamFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("spam"), provider->spamFolderPath());
        }
    }
    if (folders->objectForKey(MCSTR("important")) == NULL) {
        if (provider->importantFolderPath() != NULL) {
            folders->setObjectForKey(MCSTR("important"), provider->importantFolderPath());
        }
    }
}

void IMAPAccountSynchronizer::createMainFolders()
{
    HashMap * folders = mainFolders();
    // for non-gmail, complete with standard folders.
    completeWithStandardFolders(folders);

    Array * folderToCreate = Array::array();
    Array * existingFolders = storage()->folders();
    Set * existingFoldersSet = Set::setWithArray(existingFolders);
    mc_foreachhashmapValue(String, folderPath, folders) {
        if (!existingFoldersSet->containsObject(folderPath)) {
            folderToCreate->addObject(folderPath);
        }
    }

    MC_SAFE_REPLACE_RETAIN(Array, mMissingFolderToCreate, folderToCreate);

    if (folderToCreate->count() == 0) {
        storeMainFolders();
        return;
    }

    mCreateMissingFoldersActivity = new ActivityItem();
    mCreateMissingFoldersActivity->setProgressString(MCSTR("create folders"));
    mCreateMissingFoldersActivity->registerActivity();

    mCreateMissingFolderIndex = 0;
    createNextMainFolder();
}

void IMAPAccountSynchronizer::createNextMainFolder()
{
    if (mCreateMissingFolderIndex >= mMissingFolderToCreate->count()) {
        createMainFoldersDone();
        return;
    }

    String * folderPath = (String *) mMissingFolderToCreate->objectAtIndex(mCreateMissingFolderIndex);

    retain();

    mMissingFolderCreateOp = mSession->createFolderOperation(folderPath);
    MC_SAFE_RETAIN(mMissingFolderCreateOp);
    mMissingFolderCreateOp->setCallback(this);
    mMissingFolderCreateOp->start();
}

void IMAPAccountSynchronizer::createNextMainFolderDone()
{
    mError = hermes::ErrorNone;
    hermes::ErrorCode error = (hermes::ErrorCode) mMissingFolderCreateOp->error();
    if (isAuthenticationError(error) || isConnectionError(error) || isFatalError(error)) {
        mError = error;
    }

    if (mError != hermes::ErrorNone) {
        notifyFolderOperation(mError);
        mCreateMissingFoldersActivity->unregisterActivity();
        MC_SAFE_RELEASE(mCreateMissingFoldersActivity);
        MC_SAFE_RELEASE(mMissingFolderCreateOp);
        mFetchingFolders = false;
        handleError();
        release();
        return;
    }
    else {
        mConnectionErrorCount = 0;
        mAuthenticationErrorCount = 0;
    }

    mCreateMissingFolderIndex ++;

    MC_SAFE_RELEASE(mMissingFolderCreateOp);

    createNextMainFolder();

    release();
}

void IMAPAccountSynchronizer::createMainFoldersDone()
{
    MC_SAFE_RELEASE(mMissingFolderToCreate);

    mCreateMissingFoldersActivity->unregisterActivity();
    MC_SAFE_RELEASE(mCreateMissingFoldersActivity);

    refetchFolders();
}

void IMAPAccountSynchronizer::storeMainFolders()
{
    LOG_ERROR("%s: store main folders", MCUTF8(accountInfo()->email()));
    HashMap * folders = mainFolders();
    //mStoreMainFoldersOp = mStorage->storeValueForKeyOperation(MCSTR("mainfolders"), JSON::objectToJSONData(folders));
    mStoreMainFoldersOp = mStorage->storeValueForKeyOperation(MCSTR("mainfolders"), hermes::fastSerializedData(folders));
    mStoreMainFoldersOp->retain();
    mStoreMainFoldersOp->setCallback(this);
    mStoreMainFoldersOp->start();
}

void IMAPAccountSynchronizer::storeMainFoldersFinished()
{
    MC_SAFE_RELEASE(mStoreMainFoldersOp);

    setupFolders(true);

    notifyFolderOperation(ErrorNone);

    mFoldersFetched = true;
    mFetchingFolders = false;
    performMethodAfterDelay((Object::Method) &IMAPAccountSynchronizer::refreshFoldersAfterDelay, NULL, FOLDERS_REFRESH_DELAY);

    LOG_ERROR("%s: store main folders finished", MCUTF8(accountInfo()->email()));
    startSync();
}

void IMAPAccountSynchronizer::refreshFoldersAfterDelay()
{
    fprintf(stderr, "refresh folders\n");
    fetchFolders();
}

void IMAPAccountSynchronizer::setupFolders(bool hasMainFolders)
{
    setFoldersSynchronizers();

    if (!mGotFolders && hasMainFolders) {
        mGotFolders = true;
        delegate()->accountSynchronizerGotFolders(this);

        scheduleCollectAddresses();
    }
}

void IMAPAccountSynchronizer::setFoldersSynchronizers()
{
    bool modified = false;

    LOG_ERROR("set folders synchronizer %s", MCUTF8(accountInfo()->email()));
    Set * existingFolders = Set::setWithArray(mStorage->folders());
    LOG_ERROR("%s: existing folders %s", MCUTF8(accountInfo()->email()), MCUTF8(mStorage->folders()));
    Array * foldersToRemove = Array::array();
    {
        mc_foreachhashmapKey(String, folderPath, mFoldersSynchronizers) {
            if (!existingFolders->containsObject(folderPath)) {
                foldersToRemove->addObject(folderPath);
            }
        }
    }
    LOG_ERROR("%s: folders to remove %s", MCUTF8(accountInfo()->email()), MCUTF8(foldersToRemove));

    {
        mc_foreacharray(String, folderPath, foldersToRemove) {
            modified = true;
            IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(folderPath);
            synchronizer->closeConnection();
            mFoldersSynchronizers->removeObjectForKey(folderPath);
            // XXX - it's not paired.
            //closeFolderPath(folderPath);
            if (mOpenFoldersPaths->containsObject(folderPath)) {
                LOG_ERROR("The following folder is still opened: %s - %s", MCUTF8(accountInfo()->email()), MCUTF8(folderPath));
            }
        }
    }

    mc_foreacharray(String, folderPath, mStorage->folders()) {
        IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(folderPath);

        if (folderSync != NULL) {
            folderSync->setSession(mSession);
            folderSync->reset();
            continue;
        }

        modified = true;
        folderSync = new IMAPFolderSynchronizer();

        LOG("create folder sync for %s", MCUTF8(folderPath));

        folderSync->setSyncType(mSyncType);
        if (folderPath->isEqual(mInboxFolderPath)) {
            folderSync->setRefreshDelay(2 * 60);
        }
        if (folderPath->isEqual(mDraftsFolderPath)) {
            folderSync->setDraftBehaviorEnabled(true);
        }

        folderSync->setSession(mSession);
        folderSync->setFolderPath(folderPath);
        folderSync->setStorage(mStorage);
        folderSync->setDelegate(this);
        
        mFoldersSynchronizers->setObjectForKey(folderPath, folderSync);
        
        folderSync->release();
    }

    if (modified) {
        delegate()->accountSynchronizerFoldersUpdated(this);
    }
}

#pragma mark -
#pragma mark sync

bool IMAPAccountSynchronizer::hasUrgentTask()
{
    bool result = false;
    AutoreleasePool * pool = new AutoreleasePool();
    mc_foreachhashmapKeyAndValue(String, folderPath, IMAPFolderSynchronizer, folderSync, mFoldersSynchronizers) {
        if (folderSync->hasUrgentTask()) {
            result = true;
            break;
        }
    }
    MC_SAFE_RELEASE(pool);
    return result;
}

void IMAPAccountSynchronizer::syncNext()
{
    if (mClosed) {
        LOG_ERROR("%s: closed", MCUTF8(mAccountInfo->email()));
        return;
    }

    cancelTryReconnectNow();

    //fprintf(stderr, "syncing folders: %s\n", MCUTF8(mSyncingFolders));

    if (!Reachability::sharedManager()->isReachable()) {
        LOG_ERROR("%s: not reachable", MCUTF8(mAccountInfo->email()));
        return;
    }
    if (mSession == NULL) {
        LOG_ERROR("%s: no session", MCUTF8(mAccountInfo->email()));
        if (mOpenedDatabase && !mSettingUpSession) {
            LOG_ERROR("%s: setup session", MCUTF8(mAccountInfo->email()));
            setupSession();
        }
        return;
    }
    if ((mSession != NULL) && (mSession->password() != NULL)) {
        // everything is fine.
    }
    else if ((mSession != NULL) && (mSession->OAuth2Token() == NULL)) {
        LOG_ERROR("%s: no oauth2 token", MCUTF8(mAccountInfo->email()));
        return;
    }

    if (hasUrgentTask()) {
        IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(MCSTR("INBOX"));
        if (folderSync != NULL) {
            if (folderSync->isIdling()) {
                folderSync->interruptIdle();
            }
        }
    }

    if (mFetchingFolders) {
        LOG_ERROR("%s: fetching folders, don't sync", MCUTF8(mAccountInfo->email()));
        return;
    }

    trySyncUrgent(mInboxFolderPath);
    trySyncUrgent(mDraftsFolderPath);
    trySyncUrgent(mSentFolderPath);
    trySyncUrgent(mAllMailFolderPath);
    trySyncUrgent(mArchiveFolderPath);
    trySyncUrgent(mStarredFolderPath);
    trySyncUrgent(mImportantFolderPath);
    //trySyncUrgent(mTrashFolderPath);
    {
        mc_foreachhashmapKey(String, folderPath, mFoldersSynchronizers) {
            trySyncUrgent(folderPath);
        }
    }
    
    mc_foreacharray(String, folderPath, mOpenFoldersPaths->allObjects()) {
        trySync(folderPath);
    }
    
    trySync(mInboxFolderPath);
    trySync(mDraftsFolderPath);
    trySync(mSentFolderPath);
    trySync(mAllMailFolderPath);
    trySync(mArchiveFolderPath);
    trySync(mStarredFolderPath);
    trySync(mImportantFolderPath);
    //trySync(mTrashFolderPath);

    Array * favoriteFolders = delegate()->accountSynchronizerFavoriteFolders(this);
    {
        mc_foreacharray(String, folderPath, favoriteFolders) {
            trySync(folderPath);
        }
    }
}

void IMAPAccountSynchronizer::trySyncUrgent(String * folderPath)
{
    if (!canSyncFolder(folderPath)) {
        return;
    }
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(folderPath);
    //fprintf(stderr, "%s: urgent %s %i %i %i\n", MCUTF8(folderPath), MCUTF8(mSyncingFolders), folderSync->isSyncDone(), isSyncDisabled(), folderSync->hasUrgentTask());
	if (!folderSync->isSyncDone()) {
        if (folderSync->hasUrgentTask()) {
            mSyncingFolders->addObject(folderPath);
            LOG("urgent syncing %s", MCUTF8(folderPath));
            LOG("syncing urgent %s", MCUTF8DESC(mSyncingFolders));
            folderSync->syncNext();
        }
    }
}

bool IMAPAccountSynchronizer::canSyncFolder(String * folderPath)
{
    if (folderPath == NULL)
        return false;
    if (mFoldersSynchronizers->objectForKey(folderPath) == NULL) {
        //fprintf(stderr, "no synchronizer %s\n", MCUTF8(folderPath));
        LOG_ERROR("%s: no synchronizer: %s", MCUTF8(mAccountInfo->email()), MCUTF8(folderPath));
        return false;
    }
    
    if (mSyncingFolders->containsObject(folderPath)) {
        //fprintf(stderr, "alreading %s\n", MCUTF8(folderPath));
        //LOG_ERROR("%s: already syncing: %s", MCUTF8(mAccountInfo->email()), MCUTF8(folderPath));
        return false;
    }
    if (mSyncingFolders->count() >= MAX_SYNCING_FOLDERS) {
        //fprintf(stderr, "sync full %s\n", MCUTF8(folderPath));
        //LOG_ERROR("%s: sync full: %s", MCUTF8(mAccountInfo->email()), MCUTF8(folderPath));
        return false;
    }
    return true;
}

bool IMAPAccountSynchronizer::isSyncingFolder(String * folderPath)
{
    if (mFoldersSynchronizers->objectForKey(folderPath) == NULL)
        return false;
    if (mSyncingFolders->containsObject(folderPath))
        return true;
    return false;
}

void IMAPAccountSynchronizer::trySync(String * folderPath)
{
    if (!canSyncFolder(folderPath)) {
        //fprintf(stderr, "can't sync %s\n", MCUTF8(folderPath));
        return;
    }

    //fprintf(stderr, "sync %s\n", MCUTF8(folderPath));
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(folderPath);
    //fprintf(stderr, "%s: %s %i %i\n", MCUTF8(folderPath), MCUTF8(mSyncingFolders), folderSync->isSyncDone(), isSyncDisabled());
    //LOG("syncing %s %i %i\n", MCUTF8DESC(folderPath), folderSync->isSyncDone(), isSyncDisabled());
	if (!folderSync->isSyncDone() && !isSyncDisabled()) {
        mSyncingFolders->addObject(folderPath);
        LOG("syncing %s", MCUTF8DESC(mSyncingFolders));
        folderSync->syncNext();
    }
    else {
//        LOG_ERROR("%s: did not sync: %s -> %i %i",
//                  MCUTF8(mAccountInfo->email()), MCUTF8(folderPath), folderSync->isSyncDone(), isSyncDisabled());
    }
}

#pragma mark delegate for folder synchronizer.

void IMAPAccountSynchronizer::folderSynchronizerSyncDone(IMAPFolderSynchronizer * synchronizer)
{
    syncDone(synchronizer->lastError(), synchronizer->folderPath());

    if (synchronizer->folderPath()->isEqual(MCSTR("INBOX"))) {
        if (!mFoldersFetched) {
            fetchFolders();
        }
    }
}

void IMAPAccountSynchronizer::syncDone(hermes::ErrorCode error, mailcore::String * path)
{
    mc_foreacharray(String, key, mMessageSavingInfo->allKeys()) {
        HashMap * info = (HashMap *) mMessageSavingInfo->objectForKey(key);
        String * messageID = (String *) info->objectForKey(MCSTR("messageid"));
        Value * vFolderID = (Value *) info->objectForKey(MCSTR("folderid"));
        info->setObjectForKey(MCSTR("remotesavestate"), Value::valueWithIntValue(0));
        checkSaveFinished(messageID, vFolderID->longLongValue());
    }

    delegate()->accountSynchronizerSyncDone(this, error, path);
}

void IMAPAccountSynchronizer::folderSynchronizerSyncStepDone(IMAPFolderSynchronizer * synchronizer)
{
    if (synchronizer->lastError() != hermes::ErrorNone) {
        mError = synchronizer->lastError();
        handleError();
        return;
    }

    if ((synchronizer->lastError() == hermes::ErrorNone) && synchronizer->lastOperationIsNetwork()) {
        mConnectionErrorCount = 0;
        mAuthenticationErrorCount = 0;
    }

    if (synchronizer->canLoadMore()) {
        LOG("show loading more %s", MCUTF8(synchronizer->folderPath()));
    }
    
    mSyncingFolders->removeObject(synchronizer->folderPath());
    LOG("syncing %s done", MCUTF8DESC(mSyncingFolders));
    
    mDelegate->accountSynchronizerStateUpdated(this);
    //tmpSyncNextDone();
    syncNext();
}

void IMAPAccountSynchronizer::folderSynchronizerSyncShouldSync(IMAPFolderSynchronizer * synchronizer)
{
    syncNext();
}

void IMAPAccountSynchronizer::folderSynchronizerSyncFetchSummaryDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID)
{
    if (error != ErrorNone) {
        mMessageFetchFailedSet->addIndex(messageRowID);
    }
    mDelegate->accountSynchronizerFetchSummaryDone(this, error, messageRowID);
}

void IMAPAccountSynchronizer::folderSynchronizerSyncFetchPartDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID)
{
    notifyAttachmentDownloaders(error, messageRowID, partID);
    mDelegate->accountSynchronizerFetchPartDone(this, error, messageRowID, partID);
}

void IMAPAccountSynchronizer::folderSynchronizerMessageSourceFetched(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error,
                                                                     int64_t messageRowID,
                                                                     mailcore::Data * messageData)
{
    mDelegate->accountSynchronizerMessageSourceFetched(this, error, storage()->folderIDForPath(synchronizer->folderPath()), messageRowID, messageData);
}

void IMAPAccountSynchronizer::folderSynchronizerStateUpdated(IMAPFolderSynchronizer * folderSync)
{
    mDelegate->accountSynchronizerStateUpdated(this);
}

mailcore::String * IMAPAccountSynchronizer::folderSynchronizerTrashFolder(IMAPFolderSynchronizer * synchronizer)
{
    return mTrashFolderPath;
}

mailcore::String * IMAPAccountSynchronizer::folderSynchronizerDraftsFolder(IMAPFolderSynchronizer * synchronizer)
{
    return mDraftsFolderPath;
}

void IMAPAccountSynchronizer::folderSynchronizerSyncPushMessageDone(IMAPFolderSynchronizer * synchronizer, hermes::ErrorCode error, int64_t messageRowID)
{
    mc_foreachhashmapKey(String, key, mMessageSavingInfo) {
        HashMap * info = (HashMap *) mMessageSavingInfo->objectForKey(key);
        IndexSet * rowids = (IndexSet *) info->objectForKey(MCSTR("rowid"));
        if (rowids->containsIndex(messageRowID)) {
            Value * vRemoteSaveSate = (Value *) info->objectForKey(MCSTR("remotesavestate"));
            if (vRemoteSaveSate->intValue() == 2) {
                info->setObjectForKey(MCSTR("remotesavestate"), Value::valueWithIntValue(0));
                String * messageID = (String *) info->objectForKey(MCSTR("messageid"));
                Value * vFolderID = (Value *) info->objectForKey(MCSTR("folderid"));
                checkSaveFinished(messageID, vFolderID->longLongValue());
            }
            break;
        }
    }

    mDelegate->accountSynchronizerPushMessageDone(this, error, messageRowID);
}

void IMAPAccountSynchronizer::folderSynchronizerUnseenChanged(IMAPFolderSynchronizer * synchronizer)
{
    delegate()->accountSynchronizerFolderUnseenChanged(this, synchronizer->folderPath());
}

void IMAPAccountSynchronizer::folderSynchronizerNotifyUnreadEmail(IMAPFolderSynchronizer * synchronizer)
{
    delegate()->accountSynchronizerNotifyUnreadEmail(this, synchronizer->folderPath());
}

void IMAPAccountSynchronizer::folderSynchronizerFetchedHeaders(IMAPFolderSynchronizer * synchronizer)
{
    if (synchronizer->folderPath()->isEqual(sentFolderPath())) {
        scheduleCollectAddresses();
    }
}

void IMAPAccountSynchronizer::operationFinished(Operation * op)
{
    if (op == mOpenOperation) {
        openFinished();
    }
    else if (op == mCloseOperation) {
        closeFinished();
    }
    else if (op == mFetchFoldersOp) {
        fetchFoldersFinished();
    }
    else if (op == mStoreFoldersOp) {
        storeFoldersFinished();
    }
    else if (op == mStoreMainFoldersOp) {
        storeMainFoldersFinished();
    }
    else if (mPendingFlagsOperations->containsObject(op)) {
        flagsOperationFinished((MailDBOperation *) op);
    }
    else if (mPendingSaveMessageOperations->containsObject(op)) {
        saveMessageOperationFinished((MailDBAddLocalMessagesOperation *) op);
    }
    else if (mPendingCopyOperations->containsObject(op)) {
        copyPeopleConversationsOperationFinished(op);
    }
    else if (mPendingMoveOperations->containsObject(op)) {
        movePeopleConversationsOperationFinished(op);
    }
    else if (mPendingPurgeOperations->containsObject(op)) {
        MailDBOperation * dbOp = (MailDBOperation *) op;
        if (dbOp->changes()->messageIDsToRemoveFromSendQueue()->count() > 0) {
            delegate()->accountSynchronizerRemoveMessageIDsFromSendQueue(dbOp->changes()->messageIDsToRemoveFromSendQueue());
        }
        purgeOperationFinished(op);
    }
    else if (mRemoveDraftForSendOperations->containsObject(op)) {
        removeDraftForSentMessageOperationFinished(op);
    }
    else if (mPendingLabelOperations->containsObject(op)) {
        labelOperationFinished(op);
    }
    else if (mPendingFolderOperations->containsObject(op)) {
        folderOperationFinished(op);
    }
    else if (mFetchConversationIDOperations->containsObject(op)) {
        fetchConversationIDForMessageIDFinished((MailDBPeopleViewIDOperation *) op);
    }
    else if (op == mValidator) {
        autodetectDone();
    }
    else if (op == mMessagesOp) {
        fetchSentMessagesDone();
    }
    else if (op == mFetchRecipientOp) {
        fetchNextRecipientsDone();
    }
    else if (op == mSaveRecipientsOp) {
        saveFetchedRecipientsDone();
    }
    else if (op == mMissingFolderCreateOp) {
        createNextMainFolderDone();
    }
}

#pragma mark sync hints

void IMAPAccountSynchronizer::startSync()
{
    //delegate()->accountSynchronizerGotFolders(this);

    if (Reachability::sharedManager()->isReachable()) {
        LOG_ERROR("%s: start sync", MCUTF8(mAccountInfo->email()));
        syncNext();
    }
    else {
        LOG_ERROR("%s: could not start sync not reachable", MCUTF8(mAccountInfo->email()));
    }
}

void IMAPAccountSynchronizer::log(void * sender, ConnectionLogType logType, Data * buffer)
{
    bool enabled;
    pthread_mutex_lock(&mProtocolLogFileLock);
    enabled = mLogEnabled;
    pthread_mutex_unlock(&mProtocolLogFileLock);
    if (!enabled) {
        return;
    }

    if (logType == ConnectionLogTypeSentPrivate) {
        return;
    }

    AutoreleasePool * pool = new AutoreleasePool();
    pthread_mutex_lock(&mProtocolLogFileLock);
    chashdatum key;
    chashdatum value;
    struct timeval tv;
    struct tm tm_value;

    key.data = &sender;
    key.len = sizeof(sender);
    int r = chash_get(mProtocolLogFiles, &key, &value);
    FILE * f = NULL;
    if (r == 0) {
        f = (FILE *) value.data;
    }
    else {
        gettimeofday(&tv, NULL);
        localtime_r(&tv.tv_sec, &tm_value);
        char * dateBuffer = NULL;
        asprintf(&dateBuffer, "%04u-%02u-%02u--%02u:%02u", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min);

        String * path = String::stringWithUTF8Format("%s/%s/Logs", MCUTF8(mPath), MCUTF8(accountInfo()->email()), sender);
        mkdir(path->fileSystemRepresentation(), 0700);
        int count = 0;
        while (1) {
            struct stat statInfo;
            if (count == 0) {
                path = String::stringWithUTF8Format("%s/%s/Logs/imap-%s.log", MCUTF8(mPath), MCUTF8(accountInfo()->email()), dateBuffer);
            }
            else {
                path = String::stringWithUTF8Format("%s/%s/Logs/imap-%s-%i.log", MCUTF8(mPath), MCUTF8(accountInfo()->email()), dateBuffer, count);
            }
            if (stat(path->fileSystemRepresentation(), &statInfo) < 0) {
                break;
            }
            count ++;
        }
        free(dateBuffer);
        f = fopen(path->fileSystemRepresentation(), "wb");
        if (f == NULL) {
            LOG_ERROR("Could not create %s", MCUTF8(path));
        }
        else {
            value.data = f;
            value.len = 0;
            chash_set(mProtocolLogFiles, &key, &value, NULL);
        }
    }

    gettimeofday(&tv, NULL);
    localtime_r(&tv.tv_sec, &tm_value);
    char * dateBuffer = NULL;
    asprintf(&dateBuffer, "%04u-%02u-%02u %02u:%02u:%02u.%03u", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min, tm_value.tm_sec, (int) (tv.tv_usec / 1000));

    HashMap * logInfo = new HashMap();
    if (buffer != NULL) {
        String * str = buffer->stringWithCharset("utf-8");
        if (str != NULL) {
            logInfo->setObjectForKey(MCSTR("data"), str);
        }
    }
    logInfo->setObjectForKey(MCSTR("date"), String::stringWithUTF8Characters(dateBuffer));
    free(dateBuffer);

    String * type = NULL;
    switch (logType) {
        case ConnectionLogTypeReceived:
            type = MCSTR("recv");
            break;
        case ConnectionLogTypeSent:
            type = MCSTR("sent");
            break;
        case ConnectionLogTypeSentPrivate:
            type = MCSTR("sentpriv");
            break;
        case ConnectionLogTypeErrorParse:
            type = MCSTR("errorparse");
            break;
        case ConnectionLogTypeErrorReceived:
            type = MCSTR("errorecv");
            break;
        case ConnectionLogTypeErrorSent:
            type = MCSTR("errorsent");
            break;
    }
    if (type != NULL) {
        logInfo->setObjectForKey(MCSTR("type"), type);
    }

    if (f == NULL) {
        MC_SAFE_RELEASE(logInfo);
        pthread_mutex_unlock(&mProtocolLogFileLock);
        pool->release();
        return;
    }
    Data * json = JSON::objectToJSONData(logInfo);
    fwrite(json->bytes(), 1, json->length(), f);
    fputs("\n", f);
    MC_SAFE_RELEASE(logInfo);
    fflush(f);
    pthread_mutex_unlock(&mProtocolLogFileLock);
    pool->release();
}

void IMAPAccountSynchronizer::fetchMessageSummary(int64_t folderID, int64_t messageRowID, bool urgent)
{
    String * path = storage()->pathForFolderID(folderID);
    if (path == NULL)
        return;

    if (!Reachability::sharedManager()->isReachable()) {
        LOG_ERROR("not reachable");
        delegate()->accountSynchronizerFetchSummaryDone(this, hermes::ErrorNoNetwork, messageRowID);
        return;
    }
    /*
    if (mSession == NULL) {
        fprintf(stderr, "no session\n");
        delegate()->accountSynchronizerFetchSummaryDone(this, hermes::ErrorNoNetwork, messageRowID);
        return;
    }
     */
    if ((mSession != NULL) && (mSession->password() != NULL)) {
        // everything is fine.
    }
    else if ((mSession != NULL) && (mSession->OAuth2Token() == NULL)) {
        LOG_ERROR("no oauth2 token");
        delegate()->accountSynchronizerFetchSummaryDone(this, hermes::ErrorNoNetwork, messageRowID);
        return;
    }

    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(path);
    if (synchronizer == NULL)
        return;
    
    synchronizer->fetchMessageSummary(messageRowID, urgent);
}

bool IMAPAccountSynchronizer::canFetchMessageSummary(int64_t messageRowID)
{
    if (!Reachability::sharedManager()->isReachable()) {
        return false;
    }
    if ((mSession != NULL) && (mSession->password() != NULL)) {
        // everything is fine.
    }
    else if ((mSession != NULL) && (mSession->OAuth2Token() == NULL)) {
        return false;
    }
    return !mMessageFetchFailedSet->containsIndex(messageRowID);
}

void IMAPAccountSynchronizer::fetchMessagePart(int64_t folderID, int64_t messageRowID, mailcore::String * partID, bool urgent)
{
    String * path = storage()->pathForFolderID(folderID);
    if (path == NULL)
        return;

    if (!Reachability::sharedManager()->isReachable()) {
        LOG_ERROR("not reachable");
        notifyAttachmentDownloaders(hermes::ErrorNoNetwork, messageRowID, partID);
        delegate()->accountSynchronizerFetchPartDone(this, hermes::ErrorNoNetwork, messageRowID, partID);
        return;
    }
    /*
    if (mSession == NULL) {
        fprintf(stderr, "no session\n");
        notifyAttachmentDownloaders(hermes::ErrorNoNetwork, messageRowID, partID);
        delegate()->accountSynchronizerFetchPartDone(this, hermes::ErrorNoNetwork, messageRowID, partID);
        return;
    }
     */
    if ((mSession != NULL) && (mSession->password() != NULL)) {
        // everything is fine.
    }
    else if ((mSession != NULL) && (mSession->OAuth2Token() == NULL)) {
        LOG_ERROR("no oauth2 token");
        notifyAttachmentDownloaders(hermes::ErrorNoNetwork, messageRowID, partID);
        delegate()->accountSynchronizerFetchPartDone(this, hermes::ErrorNoNetwork, messageRowID, partID);
        return;
    }

    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(path);
    if (synchronizer == NULL)
        return;
    
    synchronizer->fetchMessagePart(messageRowID, partID, urgent);
}

void IMAPAccountSynchronizer::fetchMessageSource(int64_t folderID, int64_t messageRowID)
{
    String * path = storage()->pathForFolderID(folderID);
    if (path == NULL)
        return;

    if (!Reachability::sharedManager()->isReachable()) {
        LOG_ERROR("not reachable");
        delegate()->accountSynchronizerMessageSourceFetched(this, hermes::ErrorNoNetwork, folderID, messageRowID, NULL);
        return;
    }
    if ((mSession != NULL) && (mSession->password() != NULL)) {
        // everything is fine.
    }
    else if ((mSession != NULL) && (mSession->OAuth2Token() == NULL)) {
        LOG_ERROR("no oauth2 token");
        delegate()->accountSynchronizerMessageSourceFetched(this, hermes::ErrorNoNetwork, folderID, messageRowID, NULL);
        return;
    }

    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(path);
    if (synchronizer == NULL)
        return;

    synchronizer->fetchMessageSource(messageRowID);
}

void IMAPAccountSynchronizer::disableIdle()
{
    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(MCSTR("INBOX"));
    if (synchronizer == NULL)
        return;
    
    synchronizer->disableIdle();
}

void IMAPAccountSynchronizer::enableIdle()
{
    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(MCSTR("INBOX"));
    if (synchronizer == NULL)
        return;
    
    synchronizer->enableIdle();
}

bool IMAPAccountSynchronizer::isSyncDisabled()
{
    return mDisableSyncCount > 0;
}

void IMAPAccountSynchronizer::disableSync()
{
    mDisableSyncCount ++;
    disableIdle();
}

void IMAPAccountSynchronizer::enableSync()
{
    enableIdle();
    mDisableSyncCount --;
    if (mDisableSyncCount == 0) {
        syncNext();
    }
}

void IMAPAccountSynchronizer::closeConnection()
{
    if (mFetchFoldersOp != NULL) {
        mFetchFoldersOp->cancel();
        MC_SAFE_RELEASE(mFetchFoldersOp);
        mFetchFoldersActivity->unregisterActivity();
        MC_SAFE_RELEASE(mFetchFoldersActivity);
        mFetchingFolders = false;
        release();
    }
    if (mMissingFolderCreateOp != NULL) {
        mMissingFolderCreateOp->cancel();
        MC_SAFE_RELEASE(mMissingFolderCreateOp);
        mCreateMissingFoldersActivity->unregisterActivity();
        MC_SAFE_RELEASE(mCreateMissingFoldersActivity);
        release();
    }
    mMessageFetchFailedSet->removeAllIndexes();
    mSyncingFolders->removeAllObjects();
    mc_foreachhashmapKeyAndValue(String, folderPath, IMAPFolderSynchronizer, folderSync, mFoldersSynchronizers) {
        folderSync->closeConnection();
    }
    {
        mc_foreacharray(Operation, op, mPendingFolderOperations) {
            op->cancel();
        }
    }
    mPendingFolderOperations->removeAllObjects();
    notifyFolderOperation(ErrorConnection);
    if (mSession != NULL) {
        IMAPOperation * disconnectOp = mSession->disconnectOperation();
        disconnectOp->start();
    }
    cancelDelayedPerformMethod((Object::Method) &IMAPAccountSynchronizer::refreshFoldersAfterDelay, NULL);
    unsetupSession();
}

void IMAPAccountSynchronizer::unsetupSession()
{
    if (mSession != NULL) {
        mSession->setConnectionLogger(NULL);
    }
    pthread_mutex_lock(&mProtocolLogFileLock);
    chashiter * iter = chash_begin(mProtocolLogFiles);
    while (iter != NULL) {
        chashdatum value;
        chash_value(iter, &value);
        FILE * f = (FILE *) value.data;
        fclose(f);
        iter = chash_next(mProtocolLogFiles, iter);
    }
    chash_clear(mProtocolLogFiles);
    pthread_mutex_unlock(&mProtocolLogFileLock);
    MC_SAFE_RELEASE(mSession);
}

#pragma mark -
#pragma mark operations

void IMAPAccountSynchronizer::archivePeopleConversations(mailcore::Array * conversationIDs, mailcore::HashMap * foldersScores)
{
    if (mSyncType == IMAPSyncTypeGmail) {
        MailDBOperation * op = mStorage->archivePeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(mInboxFolderPath), mStorage->folderIDForPath(mDraftsFolderPath));
        op->setCallback(this);
        mPendingFlagsOperations->addObject(op);
        op->start();
    }
    else {
        movePeopleConversations(conversationIDs, mArchiveFolderPath, foldersScores);
    }
}

void IMAPAccountSynchronizer::deletePeopleConversations(mailcore::Array * conversationIDs, mailcore::HashMap * foldersScores)
{
    if (mTrashFolderPath == NULL) {
        return;
    }
    movePeopleConversations(conversationIDs, mTrashFolderPath, foldersScores);
}

void IMAPAccountSynchronizer::purgeFromTrashPeopleConversations(mailcore::Array * conversationIDs)
{
    if (mSyncType == IMAPSyncTypeGmail) {
        if (mTrashFolderPath == NULL) {
            return;
        }
        MailDBOperation * op = mStorage->purgeFromTrashPeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(mTrashFolderPath), mStorage->folderIDForPath(mDraftsFolderPath));
        op->setCallback(this);
        mPendingFlagsOperations->addObject(op);
        op->start();
    }
    else {
        MailDBOperation * op = mStorage->markAsDeletedPeopleConversationsFromFolderOperation(conversationIDs, mStorage->folderIDForPath(mTrashFolderPath), mTrashFolderPath, mStorage->folderIDForPath(mTrashFolderPath), mStorage->folderIDForPath(mDraftsFolderPath));
        op->setCallback(this);
        mPendingFlagsOperations->addObject(op);
        op->start();
    }
}

void IMAPAccountSynchronizer::starPeopleConversations(mailcore::Array * conversationIDs)
{
    MailDBOperation * op = mStorage->starPeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingFlagsOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::unstarPeopleConversations(mailcore::Array * conversationIDs)
{
    MailDBOperation * op = mStorage->unstarPeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingFlagsOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::markAsReadPeopleConversations(mailcore::Array * conversationIDs)
{
    MailDBOperation * op = mStorage->markAsReadPeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingFlagsOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::markAsUnreadPeopleConversations(mailcore::Array * conversationIDs)
{
    int64_t inboxFolderID = mStorage->folderIDForPath(inboxFolderPath());
    int64_t sentFolderID = mStorage->folderIDForPath(sentFolderPath());
    MailDBOperation * op = mStorage->markAsUnreadPeopleConversationsOperation(conversationIDs, inboxFolderID, sentFolderID, mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingFlagsOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::markAsReadMessages(mailcore::Array * messageRowIDs)
{
    MailDBOperation * op = mStorage->markAsReadMessagesOperation(messageRowIDs, mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingFlagsOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::removeConversationFromFolder(mailcore::Array * conversationIDs, mailcore::String * folderPath)
{
    MailDBOperation * op = mStorage->removeConversationFromFolderOperation(conversationIDs, mStorage->folderIDForPath(folderPath), mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingFlagsOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::flagsOperationFinished(MailDBOperation * op)
{
    mPendingFlagsOperations->removeObject(op);
    if (mPendingFlagsOperations->count() == 0) {
        syncNext();
    }
}

void IMAPAccountSynchronizer::saveMessageToDraft(mailcore::String * messageID, mailcore::Data * messageData, bool pushNow)
{
    MCAssert(mDraftsFolderPath != NULL);
    saveMessageToFolderCommon(messageID, messageData, mDraftsFolderPath, pushNow, false);
}

void IMAPAccountSynchronizer::saveMessageToSent(mailcore::String * messageID, mailcore::Data * messageData)
{
    MCAssert(mSentFolderPath != NULL);
    bool isGmail = (mSyncType == IMAPSyncTypeGmail);
    saveMessageToFolderCommon(messageID, messageData, mSentFolderPath, true, isGmail);
}

void IMAPAccountSynchronizer::saveMessageToFolder(mailcore::String * messageID, mailcore::Data * messageData, mailcore::String * folderPath)
{
    MCAssert(mStorage->folderIDForPath(folderPath) != -1);
    saveMessageToFolderCommon(messageID, messageData, folderPath, true, false);
}

void IMAPAccountSynchronizer::saveMessageToFolderCommon(mailcore::String * messageID,
                                                        mailcore::Data * messageData, mailcore::String * folderPath,
                                                        bool needsToBeSentToServer,
                                                        bool hasBeenPushed)
{
    /*
     message id / folder path ->
     
     localsavecount
     remotesavestate
     
     push state:
     0: no need push
     1: needs push
     2: pushing -> no need push
     */
    int64_t folderID = mStorage->folderIDForPath(folderPath);

    String * key = String::stringWithUTF8Format("%s/%lli", MCUTF8(messageID), (long long) folderID);
    HashMap * info = (HashMap *) mMessageSavingInfo->objectForKey(key);
    if (info == NULL) {
        info = HashMap::hashMap();
        info->setObjectForKey(MCSTR("localsavecount"), Value::valueWithIntValue(0));
        info->setObjectForKey(MCSTR("remotesavestate"), Value::valueWithIntValue(0));
        info->setObjectForKey(MCSTR("rowid"), IndexSet::indexSet());
        info->setObjectForKey(MCSTR("folderid"), Value::valueWithLongLongValue(folderID));
        info->setObjectForKey(MCSTR("messageid"), messageID);
        mMessageSavingInfo->setObjectForKey(key, info);
    }
    Value * vLocalSaveCount = (Value *) info->objectForKey(MCSTR("localsavecount"));
    info->setObjectForKey(MCSTR("localsavecount"), Value::valueWithIntValue(vLocalSaveCount->intValue() + 1));
    if (needsToBeSentToServer && !hasBeenPushed) {
        info->setObjectForKey(MCSTR("remotesavestate"), Value::valueWithIntValue(1));
    }

    LOG_ERROR("%s: save message %s", MCUTF8(mAccountInfo->email()), MCUTF8(messageID));
    MailDBOperation * op = mStorage->addPendingMessageWithDataOperation(folderID, messageData, needsToBeSentToServer, hasBeenPushed,
                                                                        mStorage->folderIDForPath(draftsFolderPath()));
    op->setCallback(this);
    mPendingSaveMessageOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::saveMessageOperationFinished(MailDBAddLocalMessagesOperation * op)
{
    bool willPushToServer = op->needsToBeSentToServer() && !op->hasBeenPushed();

    for(unsigned int i = 0 ; i < op->messageIDs()->count() ; i ++) {
        String * messageID = (String *) op->messageIDs()->objectAtIndex(i);
        Value * value = (Value *) op->messagesRowsIDs()->objectAtIndex(i);
        delegate()->accountSynchronizerLocalMessageSaved(this, op->folderID(), messageID, value->longLongValue(), willPushToServer);
        String * key = String::stringWithUTF8Format("%s/%lli", MCUTF8(messageID), (long long) op->folderID());
        HashMap * info = (HashMap *) mMessageSavingInfo->objectForKey(key);
        if (info == NULL) {
            LOG_ERROR("messageIDs saved %s", MCUTF8(op->messageIDs()));
        }
        MCAssert(info != NULL);
        IndexSet * rowids = (IndexSet *) info->objectForKey(MCSTR("rowid"));
        rowids->addIndex(value->longLongValue());

        Value * vLocalSaveCount = (Value *) info->objectForKey(MCSTR("localsavecount"));
        info->setObjectForKey(MCSTR("localsavecount"), Value::valueWithIntValue(vLocalSaveCount->intValue() - 1));
        if (willPushToServer) {
            info->setObjectForKey(MCSTR("remotesavestate"), Value::valueWithIntValue(2));
        }
        checkSaveFinished(messageID, op->folderID());
    }

    if (willPushToServer) {
        mFoldersThatNeedsPushMessages->addIndex(op->folderID());
    }
    mPendingSaveMessageOperations->removeObject(op);
    if (mPendingSaveMessageOperations->count() == 0) {
        mc_foreachindexset(folderID, mFoldersThatNeedsPushMessages) {
            LOG_ERROR("refresh folder when saving");
            refreshFolder(folderID);
        }
        mFoldersThatNeedsPushMessages->removeAllIndexes();
    }
}

void IMAPAccountSynchronizer::checkSaveFinished(mailcore::String * messageID, int64_t folderID)
{
    String * key = String::stringWithUTF8Format("%s/%lli", MCUTF8(messageID), (long long) folderID);
    HashMap * info = (HashMap *) mMessageSavingInfo->objectForKey(key);
    MCAssert(info != NULL);
    LOG_ERROR("save finished? %s", MCUTF8(info));
    Value * vRemoveSaveState = (Value *) info->objectForKey(MCSTR("remotesavestate"));
    Value * vLocalSaveCount = (Value *) info->objectForKey(MCSTR("localsavecount"));
    if ((vRemoveSaveState->intValue() == 0) && (vLocalSaveCount->intValue() == 0)) {
        messageID = (String *) messageID->copy()->autorelease();
        LOG_ERROR("remove saving msg info %s", MCUTF8(info));
        mMessageSavingInfo->removeObjectForKey(key);
        delegate()->accountSynchronizerMessageSaved(this, folderID, messageID);
    }
}

bool IMAPAccountSynchronizer::isSavingDraft(mailcore::String * draftMessageID)
{
    return mMessageSavingInfo->objectForKey(draftMessageID) != NULL;
}

void IMAPAccountSynchronizer::removeDraftForSentMessage(mailcore::String * draftMessageID)
{
    if (mDraftsFolderPath == NULL) {
        return;
    }
    mailcore::Operation * op = mStorage->removeSentDraftMessageWithMessageIDOperation(mStorage->folderIDForPath(mDraftsFolderPath), draftMessageID);
    op->setCallback(this);
    mRemoveDraftForSendOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::removeDraftForSentMessageOperationFinished(mailcore::Operation * op)
{
    mRemoveDraftForSendOperations->removeObject(op);
    if (mRemoveDraftForSendOperations->count() == 0) {
        refreshFolder(mStorage->folderIDForPath(mDraftsFolderPath));
    }
}

void IMAPAccountSynchronizer::copyPeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath,
                                                      mailcore::HashMap * foldersScores)
{
    if (folderPath == NULL) {
        return;
    }
    mailcore::Operation * op = mStorage->copyPeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(folderPath),
                                                                          foldersScores, mStorage->folderIDForPath(draftsFolderPath()));
    op->setCallback(this);
    mPendingCopyOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::copyPeopleConversationsOperationFinished(mailcore::Operation * op)
{
    mPendingCopyOperations->removeObject(op);
    if (mPendingCopyOperations->count() == 0) {
        syncNext();
    }
}

void IMAPAccountSynchronizer::movePeopleConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath,
                                                      mailcore::HashMap * foldersScores)
{
    if (folderPath == NULL) {
        return;
    }
    mailcore::Operation * op = mStorage->movePeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(folderPath),
                                                                          foldersScores, mStorage->folderIDForPath(draftsFolderPath()));
    op->setCallback(this);
    mPendingMoveOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::movePeopleConversationsOperationFinished(mailcore::Operation * op)
{
    mPendingMoveOperations->removeObject(op);
    if (mPendingMoveOperations->count() == 0) {
        syncNext();
    }
}

void IMAPAccountSynchronizer::purgePeopleConversations(mailcore::Array * conversationIDs)
{
    if (mTrashFolderPath == NULL) {
        return;
    }
    mailcore::Operation * op = mStorage->purgePeopleConversationsOperation(conversationIDs, mStorage->folderIDForPath(mDraftsFolderPath),
                                                                           mStorage->folderIDForPath(mTrashFolderPath));
    op->setCallback(this);
    mPendingPurgeOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::purgeMessage(int64_t messageRowID)
{
    if (mTrashFolderPath == NULL) {
        return;
    }
    mailcore::Operation * op = mStorage->purgeMessagesOperation(Array::arrayWithObject(Value::valueWithLongLongValue(messageRowID)),
                                                                mStorage->folderIDForPath(mTrashFolderPath),
                                                                mStorage->folderIDForPath(mDraftsFolderPath));
    op->setCallback(this);
    mPendingPurgeOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::purgeOperationFinished(mailcore::Operation * op)
{
    mPendingPurgeOperations->removeObject(op);
    if (mPendingPurgeOperations->count() == 0) {
        syncNext();
    }
}

void IMAPAccountSynchronizer::addLabelToConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, int64_t folderID)
{
    mailcore::Operation * op = mStorage->addLabelToPeopleConversationsOperation(conversationIDs, folderPath, folderID, mStorage->folderIDForPath(mTrashFolderPath));
    op->setCallback(this);
    mPendingLabelOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::removeLabelFromConversations(mailcore::Array * conversationIDs, mailcore::String * folderPath, int64_t folderID)
{
    mailcore::Operation * op = mStorage->removeLabelFromPeopleConversationsOperation(conversationIDs, folderPath, folderID, mStorage->folderIDForPath(mTrashFolderPath));
    op->setCallback(this);
    mPendingLabelOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::labelOperationFinished(mailcore::Operation * op)
{
    mPendingLabelOperations->removeObject(op);
    if (mPendingLabelOperations->count() == 0) {
        syncNext();
    }
}

void IMAPAccountSynchronizer::fetchConversationIDForMessageID(mailcore::String * messageID)
{
    MailDBPeopleViewIDOperation * op = mStorage->peopleViewIDOperation(messageID);
    op->setCallback(this);
    mFetchConversationIDOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::fetchConversationIDForMessageIDFinished(MailDBPeopleViewIDOperation * op)
{
    delegate()->accountSynchronizerHasConversationIDForMessageID(this, op->messageID(), op->peopleViewID());
    mFetchConversationIDOperations->removeObject(op);
}

void IMAPAccountSynchronizer::createFolder(mailcore::String * folderPath)
{
    if (!mDisabledIdleSinceFolderOperation) {
        disableIdle();
    }
    IMAPOperation * op = mSession->createFolderOperation(folderPath);
    op->setCallback(this);
    mPendingFolderOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::renameFolder(mailcore::String * initialFolderPath, mailcore::String * destinationFolderPath)
{
    if (!mDisabledIdleSinceFolderOperation) {
        disableIdle();
    }
    IMAPOperation * op = mSession->renameFolderOperation(initialFolderPath, destinationFolderPath);
    op->setCallback(this);
    mPendingFolderOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::deleteFolder(mailcore::String * folderPath)
{
    if (!mDisabledIdleSinceFolderOperation) {
        disableIdle();
    }
    IMAPOperation * op = mSession->deleteFolderOperation(folderPath);
    op->setCallback(this);
    mPendingFolderOperations->addObject(op);
    op->start();
}

void IMAPAccountSynchronizer::folderOperationFinished(mailcore::Operation * op)
{
    mPendingFolderOperations->removeObject(op);
    if (mPendingFolderOperations->count() == 0) {
        mFolderOperationNotification = true;
        fetchFolders();
    }
}

void IMAPAccountSynchronizer::notifyFolderOperation(hermes::ErrorCode error)
{
    if (mDisabledIdleSinceFolderOperation) {
        enableIdle();
    }
    if (!mFolderOperationNotification) {
        return;
    }
    mFolderOperationNotification = false;

    delegate()->accountSynchronizerFoldersChanged(this, error);
}

void IMAPAccountSynchronizer::setSearchKeywords(mailcore::Array * keywords)
{
    MC_SAFE_REPLACE_RETAIN(Array, mSearchKeywords, keywords);
    setFolderSearchKeywords(mInboxFolderPath, keywords);
    if (mAllMailFolderPath != nil) {
        setFolderSearchKeywords(mAllMailFolderPath, keywords);
    }
    else {
        setFolderSearchKeywords(mSentFolderPath, keywords);
        setFolderSearchKeywords(mArchiveFolderPath, keywords);
    }
}

mailcore::Array * IMAPAccountSynchronizer::searchKeywords()
{
    return mSearchKeywords;
}

void IMAPAccountSynchronizer::setFolderSearchKeywords(String * path, mailcore::Array * keywords)
{
    if (path == NULL) {
        return;
    }
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return;
    }
    folderSync->setSearchKeywords(keywords);
}

bool IMAPAccountSynchronizer::isSearching()
{
    return isFolderSearching(mInboxFolderPath) || isFolderSearching(mAllMailFolderPath) || isFolderSearching(mArchiveFolderPath) || isFolderSearching(mSentFolderPath);
}

bool IMAPAccountSynchronizer::isFolderSearching(mailcore::String * path)
{
    if (path == NULL) {
        return false;
    }
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return false;
    }
    return folderSync->isSearching();
}

#pragma mark account state

bool IMAPAccountSynchronizer::shouldShowProgressForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return false;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return false;
    }
    return folderSync->shouldShowProgress();
}

bool IMAPAccountSynchronizer::canLoadMoreForFolder(int64_t folderID)
{
    if (mStorage == NULL) {
        return false;
    }
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return false;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return false;
    }
    return folderSync->canLoadMore();
}

void IMAPAccountSynchronizer::refreshFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return;

    if (!Reachability::sharedManager()->isReachable()) {
        LOG_ERROR("not reachable");
        syncDone(hermes::ErrorNoNetwork, path);
        return;
    }
    /*
    if (mSession == NULL) {
        fprintf(stderr, "no session\n");
        syncDone(hermes::ErrorNoNetwork, path);
        return;
    }
     */
    if ((mSession != NULL) && (mSession->password() != NULL)) {
        // everything is fine.
    }
    else if ((mSession != NULL) && (mSession->OAuth2Token() == NULL)) {
        LOG_ERROR("no oauth2 token");
        syncDone(hermes::ErrorNoNetwork, path);
        return;
    }

    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return;
    }
    folderSync->refresh();
    
    mDelegate->accountSynchronizerStateUpdated(this);
}

unsigned int IMAPAccountSynchronizer::headersProgressValueForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return 0;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return 0;
    }
    return folderSync->headersProgressValue();
}

unsigned int IMAPAccountSynchronizer::headersProgressMaxForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return 0;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return 0;
    }
    return folderSync->headersProgressMax();
}

bool IMAPAccountSynchronizer::loadMoreForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return false;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return false;
    }
    return folderSync->loadMore();
}

void IMAPAccountSynchronizer::resetMessagesToLoadForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return;
    }
    folderSync->resetMessagesToLoad();
}

bool IMAPAccountSynchronizer::messagesToLoadCanBeResetForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return false;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return false;
    }
    return folderSync->messagesToLoadCanBeReset();
}

void IMAPAccountSynchronizer::setWaitingLoadMoreForFolder(int64_t folderID, bool waitingLoadMore)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return;
    }
    folderSync->setWaitingLoadMore(waitingLoadMore);
}

bool IMAPAccountSynchronizer::isWaitingLoadMoreForFolder(int64_t folderID)
{
    String * path = mStorage->pathForFolderID(folderID);
    if (path == NULL)
        return false;
    
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(path);
    if (folderSync == NULL) {
        return false;
    }
    return folderSync->isWaitingLoadMore();
}

mailcore::String * IMAPAccountSynchronizer::urgentTaskDescriptionForFolder(mailcore::String * folderPath)
{
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(folderPath);
    if (folderSync == NULL) {
        return NULL;
    }
    return folderSync->urgentTaskDescription();
}

mailcore::String * IMAPAccountSynchronizer::syncStateDescriptionForFolder(mailcore::String * folderPath)
{
    IMAPFolderSynchronizer * folderSync = (IMAPFolderSynchronizer*) mFoldersSynchronizers->objectForKey(folderPath);
    if (folderSync == NULL) {
        return NULL;
    }
    return folderSync->syncStateDescription();
}

#pragma mark -
#pragma mark downloader

void IMAPAccountSynchronizer::registerPartDownloader(IMAPAttachmentDownloader * downloader)
{
    mAttachmentDownloaders->addObject(downloader);
}

void IMAPAccountSynchronizer::unregisterPartDownloader(IMAPAttachmentDownloader * downloader)
{
    mAttachmentDownloaders->removeObject(downloader);
}

void IMAPAccountSynchronizer::notifyAttachmentDownloaders(hermes::ErrorCode error, int64_t messageRowID, mailcore::String * partID)
{
    mc_foreacharray(IMAPAttachmentDownloader, downloader, mAttachmentDownloaders) {
        if (downloader->partID() != NULL) {
            if ((downloader->messageRowID() == messageRowID) && (downloader->partID()->isEqual(partID))) {
                downloader->notifyDownloadFinished(error);
                break;
            }
        }
    }
}

#pragma mark -
#pragma mark error management

void IMAPAccountSynchronizer::handleError()
{
    mDelegate->accountSynchronizerStateUpdated(this);

    LOG_ERROR("%s: sync error detected: %i", MCUTF8(mAccountInfo->email()), mError);
    if (isAuthenticationError(mError)) {
        if (mAccountInfo->OAuth2Token() != NULL) {
            LOG_ERROR("%s: oauth authentication error: %i", MCUTF8(mAccountInfo->email()), mError);
            handleOAuth2Error(mError);
        }
        else {
            LOG_ERROR("%s: authentication error: %i", MCUTF8(mAccountInfo->email()), mError);
            authenticationError(mError);
        }
        return;
    }
    else if (isFatalError(mError)) {
        LOG_ERROR("%s: fatal error: %i", MCUTF8(mAccountInfo->email()), mError);
        fatalError(mError);
        return;
    }
    else if (mError == ErrorAppend) {
        LOG_ERROR("%s: append error: %i", MCUTF8(mAccountInfo->email()), mError);
        appendError(mError);
        return;
    }
    else if (mError == ErrorCopy) {
        LOG_ERROR("%s: copy error: %i", MCUTF8(mAccountInfo->email()), mError);
        copyError(mError);
        return;
    }
    else if (mError == ErrorNonExistantFolder) {
        LOG_ERROR("%s: folder doesn't exist: %i", MCUTF8(mAccountInfo->email()), mError);
        return;
    }
    else {
        LOG_ERROR("%s: ignore error: %i", MCUTF8(mAccountInfo->email()), mError);
    }

    if (!Reachability::sharedManager()->isReachable()) {
        failPendingRequests(mError);
        disconnect();
        connectionError(mError);
        return;
    }

    // connection error.
    // fetch error will also result in reconnection.
    if (mConnectionErrorCount == 0) {
        mConnectionRetryState = CONNECTION_STATE_SHOULD_RETRY;
    }
    mConnectionErrorCount = 1;

    failPendingRequests(mError);
    disconnect();

    // retry once.
    // then, try to autodetect.
    // then, fail.
    switch (mConnectionRetryState) {
        case CONNECTION_STATE_SHOULD_RETRY:
        {
            LOG_ERROR("%s: connect error, retry: %i", MCUTF8(mAccountInfo->email()), mError);
            if (accountInfo()->providerIdentifier() == NULL) {
                mConnectionRetryState = CONNECTION_STATE_SHOULD_FAIL;
            }
            else {
                mConnectionRetryState = CONNECTION_STATE_SHOULD_AUTODETECT;
            }
            connect();
            break;
        }
        case CONNECTION_STATE_SHOULD_AUTODETECT:
        {
            LOG_ERROR("%s: connect error, autodetect: %i", MCUTF8(mAccountInfo->email()), mError);
            mConnectionRetryState = CONNECTION_STATE_SHOULD_FAIL;
            autodetect();
            break;
        }
        case CONNECTION_STATE_SHOULD_FAIL:
        {
            LOG_ERROR("%s: connect error, fail: %i", MCUTF8(mAccountInfo->email()), mError);
            connectionError(mError);
            break;
        }
    }
}

void IMAPAccountSynchronizer::autodetect()
{
    if (mSettingUpSession) {
        LOG_ERROR("%s: Trying to autodetect while a connection is in progress", MCUTF8(mAccountInfo->email()));
        return;
    }

    mValidator = new AccountValidator();
    mValidator->setEmail(accountInfo()->email());
    mValidator->setUsername(accountInfo()->username());
    mValidator->setPassword(accountInfo()->password());
    mValidator->setOAuth2Token(accountInfo()->OAuth2Token());
    LOG_ERROR("%s: user: %s", MCUTF8(mAccountInfo->email()), MCUTF8(mAccountInfo->username()));
    mValidator->setImapEnabled(true);
    mValidator->setCallback(this);

    mValidator->start();
}

void IMAPAccountSynchronizer::autodetectDone()
{
    if (mValidator->imapError() != mailcore::ErrorNone) {
        mError = (hermes::ErrorCode) mValidator->imapError();
        MC_SAFE_RELEASE(mValidator);

        handleError();

        return;
    }

    IMAPAccountInfo * accountInfo = (IMAPAccountInfo *) mAccountInfo->copy();
    LOG_ERROR("%s: found %s:%i\n", MCUTF8(mAccountInfo->email()), MCUTF8(mValidator->imapServer()->hostname()), mValidator->imapServer()->port());
    accountInfo->setHostname(mValidator->imapServer()->hostname());
    accountInfo->setPort(mValidator->imapServer()->port());
    accountInfo->setConnectionType(mValidator->imapServer()->connectionType());
    MC_SAFE_REPLACE_COPY(IMAPAccountInfo, mAccountInfo, accountInfo);
    delegate()->accountSynchronizerAccountInfoChanged(this);

    MC_SAFE_RELEASE(mValidator);

    // reconnect.
    disconnect();
    connect();
}

void IMAPAccountSynchronizer::fatalError(hermes::ErrorCode error)
{
    failPendingRequests(error);
    disconnect();
    mDelegate->accountSynchronizerNotifyFatalError(this, error);
}

void IMAPAccountSynchronizer::handleOAuth2Error(hermes::ErrorCode error)
{
    if (mAuthenticationErrorCount == 0) {
        LOG_ERROR("retry OAuth2 authentication");
        mAuthenticationErrorCount = 1;
        failPendingRequests(error);
        disconnect();
        connect();
    }
    else {
        LOG_ERROR("authentication failed");
        authenticationError(error);
    }
}

void IMAPAccountSynchronizer::authenticationError(hermes::ErrorCode error)
{
    failPendingRequests(error);
    disconnect();
    mDelegate->accountSynchronizerNotifyAuthenticationError(this, error);
}

void IMAPAccountSynchronizer::connectionError(hermes::ErrorCode error)
{
    LOG_ERROR("Connection error");
    failPendingRequests(error);
    disconnect();
    mDelegate->accountSynchronizerNotifyConnectionError(this, error);

    tryReconnectAfterDelay();
}

void IMAPAccountSynchronizer::copyError(hermes::ErrorCode error)
{
    mDelegate->accountSynchronizerNotifyCopyError(this, error);
}

void IMAPAccountSynchronizer::appendError(hermes::ErrorCode error)
{
    mDelegate->accountSynchronizerNotifyAppendError(this, error);
}

void IMAPAccountSynchronizer::markFolderAsSeen(int64_t folderID)
{
    String * folderPath = storage()->pathForFolderID(folderID);
    if (folderPath == NULL) {
        return;
    }
    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(folderPath);
    if (synchronizer == NULL) {
        return;
    }
    synchronizer->markFolderAsSeen();
}

bool IMAPAccountSynchronizer::isFolderUnseen(int64_t folderID)
{
    String * folderPath = storage()->pathForFolderID(folderID);
    if (folderPath == NULL) {
        return false;
    }
    IMAPFolderSynchronizer * synchronizer = (IMAPFolderSynchronizer *) mFoldersSynchronizers->objectForKey(folderPath);
    if (synchronizer == NULL) {
        return false;
    }
    return synchronizer->isFolderUnseen();
}

#pragma mark -
#pragma mark address collections for completion

void IMAPAccountSynchronizer::startCollectingAddresses()
{
    if (mClosed) {
        return;
    }

    retain();
    MCAssert(mFetchedRecipients == NULL);
    mCollectingAddresses = true;
    mPendingAddressCollection = false;
    cancelDelayedPerformMethod((Object::Method) &IMAPAccountSynchronizer::startCollectingAddresses, NULL);
    mScheduledAddressCollection = false;
    mAddressCollectionStartTime = hermes::currentTime();
    mFetchedRecipients = new Array();
    fetchSentMessages();
}

void IMAPAccountSynchronizer::fetchSentMessages()
{
    int64_t folderID = storage()->folderIDForPath(sentFolderPath());
    if (folderID == -1) {
        finishedCollectingAddresses();
        return;
    }
    mMessagesOp = storage()->messagesForFolderOperation(folderID);
    mMessagesOp->setCallback(this);
    mMessagesOp->retain();
    mMessagesOp->start();
}

void IMAPAccountSynchronizer::fetchSentMessagesDone()
{
    LOG_ERROR("duration: %g for %s", hermes::currentTime() - mAddressCollectionStartTime, MCUTF8(accountInfo()->email()));

    MC_SAFE_REPLACE_RETAIN(IndexSet, mCollectAddressesMessagesRowIDs, mMessagesOp->messagesRowsIDs());
    unsigned int count = mCollectAddressesMessagesRowIDs->rangesCount();
    mCollectAddressesMessagesLastRowID = 0;
    if (count > 0) {
        Range lastRange = mCollectAddressesMessagesRowIDs->allRanges()[count - 1];
        mCollectAddressesMessagesLastRowID = RangeRightBound(lastRange);
    }

    MC_SAFE_RELEASE(mMessagesOp);

    fetchNextRecipients();
}

void IMAPAccountSynchronizer::fetchNextRecipients()
{
    if (mCollectAddressesMessagesRowIDs->count() == 0) {
        saveFetchedRecipients();
        return;
    }

    mFetchRecipientOp = storage()->recipientsForMessagesRowsIDsOperation(mCollectAddressesMessagesRowIDs, 100);
    mFetchRecipientOp->setCallback(this);
    mFetchRecipientOp->retain();
    mFetchRecipientOp->start();
}

void IMAPAccountSynchronizer::fetchNextRecipientsDone()
{
    mFetchedRecipients->addObjectsFromArray(mFetchRecipientOp->recipients());
    MC_SAFE_REPLACE_RETAIN(IndexSet, mCollectAddressesMessagesRowIDs, mFetchRecipientOp->remainingMessagesRowsIDs());
    MC_SAFE_RELEASE(mFetchRecipientOp);

    fetchNextRecipients();
}

void IMAPAccountSynchronizer::saveFetchedRecipients()
{
    if (mRecipients != NULL && mFetchedRecipients->count() == 0) {
        finishedCollectingAddresses();
        return;
    }
    mSaveRecipientsOp = storage()->addToSavedRecipientsOperation(mFetchedRecipients, mCollectAddressesMessagesLastRowID);
    mSaveRecipientsOp->setCallback(this);
    mSaveRecipientsOp->retain();
    mSaveRecipientsOp->start();
}

void IMAPAccountSynchronizer::saveFetchedRecipientsDone()
{
    MC_SAFE_REPLACE_RETAIN(Array, mRecipients, mSaveRecipientsOp->allSavedAddresses());

    MC_SAFE_RELEASE(mSaveRecipientsOp);
    MC_SAFE_RELEASE(mCollectAddressesMessagesRowIDs);
    LOG_ERROR("finished, duration: %g for %s", hermes::currentTime() - mAddressCollectionStartTime, MCUTF8(accountInfo()->email()));
    delegate()->accountSynchronizerHasNewContacts(this);
    finishedCollectingAddresses();
}

void IMAPAccountSynchronizer::finishedCollectingAddresses()
{
    if (mRecipients == NULL) {
        mRecipients = new Array();
    }
    MC_SAFE_RELEASE(mFetchedRecipients);
    mCollectingAddresses = false;

    if (mPendingAddressCollection) {
        mPendingAddressCollection = false;
        scheduleCollectAddresses();
    }
    release();
}

#define COLLECT_ADDRESS_DELAY 30

void IMAPAccountSynchronizer::scheduleCollectAddresses()
{
    if (mCollectingAddresses) {
        mPendingAddressCollection = true;
        return;
    }

    if (mRecipients == NULL) {
        startCollectingAddresses();
    }
    else if (!mScheduledAddressCollection) {
        mScheduledAddressCollection = true;
        performMethodAfterDelay((Object::Method) &IMAPAccountSynchronizer::startCollectingAddresses, NULL, COLLECT_ADDRESS_DELAY);
    }
}

#define TRY_RECONNECT_DELAY (5 * 60)

void IMAPAccountSynchronizer::tryReconnectAfterDelay()
{
    performMethodAfterDelay((Object::Method) &IMAPAccountSynchronizer::tryReconnectNow, NULL, TRY_RECONNECT_DELAY);
}

void IMAPAccountSynchronizer::tryReconnectNow()
{
    LOG_ERROR("try reconnect %s", MCUTF8(accountInfo()->email()));
    if (mSession == NULL) {
        connect();
    }
}

void IMAPAccountSynchronizer::cancelTryReconnectNow()
{
    cancelDelayedPerformMethod((Object::Method) &IMAPAccountSynchronizer::tryReconnectAfterDelay, NULL);
}
