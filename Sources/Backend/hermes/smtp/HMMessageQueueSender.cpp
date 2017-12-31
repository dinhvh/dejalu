// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMessageQueueSender.h"

#include <sys/stat.h>

#include "HMMessageSender.h"
#include "HMConstants.h"
#include "HMIMAPAccountSynchronizer.h"
#include "HMSMTPAccountInfo.h"
#include "HMMessageSender.h"
#include "HMConstants.h"
#include "HMSMTPAccountSender.h"
#include "HMMessageQueueSenderDelegate.h"
#include "HMUtils.h"
#include "HMReachability.h"
#include "DJLLog.h"

#define RETRY_DELAY (15 * 60)

using namespace hermes;
using namespace mailcore;

MessageQueueSender::MessageQueueSender()
{
    mAccountInfo = NULL;
    mQueueFolder = NULL;
    mPath = NULL;
    mQueue = new Array();
    mIMAPSynchronizer = NULL;
    mSending = false;
    mDeliveryEnabled = false;
    mSender = NULL;
    mSMTPAccountSender = NULL;
    mDelegate = NULL;
    mRetryLaterScheduled = false;
    mProgressCurrentMessageIndex = 0;
    mProgressTotalMessagesCount = 0;
    mCurrentMessageProgress = 0;
    mCurrentMessageProgressMax = 0;
    mCurrentMessageSubject = NULL;
    mLogEnabled = false;
}

MessageQueueSender::~MessageQueueSender()
{
    MC_SAFE_RELEASE(mCurrentMessageSubject);
    MC_SAFE_RELEASE(mSender);
    MC_SAFE_RELEASE(mIMAPSynchronizer);
    MC_SAFE_RELEASE(mQueue);
    MC_SAFE_RELEASE(mPath);
    MC_SAFE_RELEASE(mQueueFolder);
    MC_SAFE_RELEASE(mAccountInfo);
}

void MessageQueueSender::setAccountInfo(SMTPAccountInfo * info)
{
    MC_SAFE_REPLACE_RETAIN(SMTPAccountInfo, mAccountInfo, info);
}

SMTPAccountInfo * MessageQueueSender::accountInfo()
{
    return mAccountInfo;
}

void MessageQueueSender::setIMAPAccountSynchronizer(IMAPAccountSynchronizer * imapSynchronizer)
{
    MC_SAFE_REPLACE_RETAIN(IMAPAccountSynchronizer, mIMAPSynchronizer, imapSynchronizer);
}

IMAPAccountSynchronizer * MessageQueueSender::imapAccountSynchronizer()
{
    return mIMAPSynchronizer;
}

void MessageQueueSender::setPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mPath, path);
}

String * MessageQueueSender::path()
{
    return mPath;
}

void MessageQueueSender::setDeliveryEnabled(bool enabled)
{
    if (mDeliveryEnabled == enabled) {
        return;
    }

    mDeliveryEnabled = enabled;
    if (mDeliveryEnabled) {
        if (mRetryLaterScheduled) {
            cancelRetryLater();
        }
        sendNextMessage();
    }
    else {
        if (mSMTPAccountSender != NULL) {
            mSMTPAccountSender->disconnect();
            MC_SAFE_RELEASE(mSMTPAccountSender);
        }
        cancelRetryLater();
    }
}

bool MessageQueueSender::isSending()
{
    return mSending;
}

unsigned int MessageQueueSender::currentMessageIndex()
{
    return mProgressCurrentMessageIndex;
}

unsigned int MessageQueueSender::totalMessagesCount()
{
    return mProgressTotalMessagesCount;
}

unsigned int MessageQueueSender::currentMessageProgress()
{
    return mCurrentMessageProgress;
}

unsigned int MessageQueueSender::currentMessageProgressMax()
{
    return mCurrentMessageProgressMax;
}

String * MessageQueueSender::currentMessageSubject()
{
    return mCurrentMessageSubject;
}

MessageQueueSenderDelegate * MessageQueueSender::delegate()
{
    return mDelegate;
}

void MessageQueueSender::setDelegate(MessageQueueSenderDelegate * delegate)
{
    mDelegate = delegate;
}

void MessageQueueSender::setLogEnabled(bool enabled)
{
    mLogEnabled = enabled;
}

mailcore::String * MessageQueueSender::queueFilename()
{
    return mQueueFolder->stringByAppendingPathComponent(MCSTR("queue.json"));
}

void MessageQueueSender::loadQueueFromDisk()
{
    String * queueFolder = String::stringWithUTF8Format("%s/%s/Queue", mPath->UTF8Characters(), mAccountInfo->email()->UTF8Characters());
    MC_SAFE_REPLACE_RETAIN(String, mQueueFolder, queueFolder);
    String * folder = String::stringWithUTF8Format("%s/%s", mPath->UTF8Characters(), mAccountInfo->email()->UTF8Characters());
    mkdir(folder->fileSystemRepresentation(), 0700);
    mkdir(mQueueFolder->fileSystemRepresentation(), 0700);

    Data * data = Data::dataWithContentsOfFile(queueFilename());
    if (data != NULL) {
        HashMap * info = (HashMap *) JSON::objectFromJSONData(data);
        Array * queue = (Array *) info->objectForKey(MCSTR("queue"));
        MC_SAFE_REPLACE_RETAIN(Array, mQueue, queue);
    }
    // each item is {filename:"myemail.eml",draftmsgid:"aaaaa-messageid-bbbbb@gmail.com"}
}

void MessageQueueSender::saveQueueToDisk()
{
    HashMap * info = new HashMap();
    info->setObjectForKey(MCSTR("queue"), mQueue);
    Data * data = JSON::objectToJSONData(info);
    data->writeToFile(queueFilename());
}

void MessageQueueSender::addItemToQueue(mailcore::String * draftMessageID, mailcore::Data * messageData)
{
    String * basename = md5String(messageData);
    String * filename = mQueueFolder->stringByAppendingPathComponent(basename)->stringByAppendingString(MCSTR(".eml"));
    messageData->writeToFile(filename);

    HashMap * item = new HashMap();
    item->setObjectForKey(MCSTR("filename"), basename);
    item->setObjectForKey(MCSTR("draftmsgid"), draftMessageID);
    mQueue->addObject(item);
    saveQueueToDisk();
    MC_SAFE_RELEASE(item);
}

void MessageQueueSender::removeItemFromQueue()
{
    HashMap * item = (HashMap *) mQueue->objectAtIndex(0);
    String * basename = (String *) item->objectForKey(MCSTR("filename"));
    String * filename = mQueueFolder->stringByAppendingPathComponent(basename)->stringByAppendingString(MCSTR(".eml"));
    unlink(filename->fileSystemRepresentation());

    mQueue->removeObjectAtIndex(0);
    saveQueueToDisk();
}

void MessageQueueSender::sendMessage(mailcore::String * draftMessageID, mailcore::Data * messageData)
{
    addItemToQueue(draftMessageID, messageData);

    if (!Reachability::sharedManager()->isReachable()) {
        MessageParser * parser = MessageParser::messageParserWithData(messageData);
        delegate()->messageQueueSenderNotifyConnectionError(this, hermes::ErrorNoNetwork, parser);
        return;
    }

    setDeliveryEnabled(true);

    sendNextMessage();

    if (mSending) {
        delegate()->messageQueueSenderSendingStateChanged(this);
    }
}

void MessageQueueSender::removeMessageWithDraftMessageID(mailcore::String * draftMessageID)
{
    int startingIndex = 0;
    if (mSending) {
        startingIndex = 1;
    }

    for(int i = startingIndex ; i < mQueue->count() ; i ++) {
        HashMap * item = (HashMap *) mQueue->objectAtIndex(i);
        String * messageID = (String *) item->objectForKey(MCSTR("draftmsgid"));
        if (messageID->isEqual(draftMessageID)) {
            String * basename = (String *) item->objectForKey(MCSTR("filename"));
            String * filename = mQueueFolder->stringByAppendingPathComponent(basename)->stringByAppendingString(MCSTR(".eml"));
            unlink(filename->fileSystemRepresentation());
            mQueue->removeObjectAtIndex(i);
            saveQueueToDisk();
            break;
        }
    }
}

void MessageQueueSender::sendNextMessage()
{
    if (!mDeliveryEnabled) {
        return;
    }
    if (mQueue->count() == 0) {
        if (mProgressTotalMessagesCount != 0) {
            delegate()->messageQueueSenderSendDone(this);
        }
        MC_SAFE_RELEASE(mCurrentMessageSubject);
        mProgressCurrentMessageIndex = 0;
        mProgressTotalMessagesCount = 0;
        mCurrentMessageProgress = 0;
        mCurrentMessageProgressMax = 0;
        return;
    }

    MessageParser * message = currentParsedMessage();
    MC_SAFE_REPLACE_COPY(String, mCurrentMessageSubject, message->header()->subject());

    mProgressTotalMessagesCount = mProgressCurrentMessageIndex + mQueue->count();
    mCurrentMessageProgress = 0;
    mCurrentMessageProgressMax = 0;
    delegate()->messageQueueSenderProgress(this);

    if (mSending) {
        return;
    }

    retain();

    mSending = true;

    HashMap * item = (HashMap *) mQueue->objectAtIndex(0);
    String * basename = (String *) item->objectForKey(MCSTR("filename"));
    String * filename = mQueueFolder->stringByAppendingPathComponent(basename)->stringByAppendingString(MCSTR(".eml"));

    mSender = new MessageSender();
    mSender->setDelegate(this);
    mSender->setAccountInfo(accountInfo());
    mSender->sendMessage(filename);
}

MessageParser * MessageQueueSender::currentParsedMessage()
{
    HashMap * item = (HashMap *) mQueue->objectAtIndex(0);
    String * basename = (String *) item->objectForKey(MCSTR("filename"));
    String * filename = mQueueFolder->stringByAppendingPathComponent(basename)->stringByAppendingString(MCSTR(".eml"));
    return MessageParser::messageParserWithContentsOfFile(filename);
}

void MessageQueueSender::messageSenderSendDone(MessageSender * sender)
{
    mSending = false;
    hermes::ErrorCode error = mSender->error();
    MC_SAFE_RELEASE(mSender);

    MessageParser * message = currentParsedMessage();

    if (isConnectionError(error)) {
        LOG_ERROR("%s: MessageQueueSender - connection error %i", MCUTF8(mAccountInfo->email()), error);

        disableAndRetryLater();

        mDelegate->messageQueueSenderNotifyConnectionError(this, error, message);
        release();
        return;
    }
    else if (isFatalError(error)) {
        LOG_ERROR("%s: MessageQueueSender - fatal error %i", MCUTF8(mAccountInfo->email()), error);

        disableAndRetryLater();

        mDelegate->messageQueueSenderNotifyFatalError(this, error, message);
        release();
        return;
    }
    else if (isAuthenticationError(error)) {
        LOG_ERROR("%s: MessageQueueSender - auth error %i", MCUTF8(mAccountInfo->email()), error);

        setDeliveryEnabled(false);

        mDelegate->messageQueueSenderNotifyAuthenticationError(this, error, message);
        release();
        return;
    }
    else if (isSendError(error)) {
        LOG_ERROR("%s: MessageQueueSender - send error %i", MCUTF8(mAccountInfo->email()), error);

        removeItemFromQueue();
        mDelegate->messageQueueSenderNotifySendError(this, error, message);
        release();
        return;
    }
    else if (error != ErrorNone) {
        LOG_ERROR("%s: MessageQueueSender - other error %i", MCUTF8(mAccountInfo->email()), error);
    }

    String * messageID = message->header()->messageID();
    if (mIMAPSynchronizer->sentFolderPath() != NULL) {
        mIMAPSynchronizer->saveMessageToSent(messageID, message->data());
    }
    HashMap * item = (HashMap *) mQueue->objectAtIndex(0);
    String * draftMessageID = (String *) item->objectForKey(MCSTR("draftmsgid"));
    mIMAPSynchronizer->removeDraftForSentMessage(draftMessageID);
    removeItemFromQueue();

    mProgressCurrentMessageIndex ++;
    mProgressTotalMessagesCount = mProgressCurrentMessageIndex + mQueue->count();
    mCurrentMessageProgress = 0;
    mCurrentMessageProgressMax = 0;

    sendNextMessage();

    if (!mSending) {
        delegate()->messageQueueSenderSendingStateChanged(this);
    }
    delegate()->messageQueueSenderSent(this, message);

    release();
}

void MessageQueueSender::messageSenderAccountInfoChanged(MessageSender * sender)
{
    MC_SAFE_REPLACE_RETAIN(SMTPAccountInfo, mAccountInfo, sender->accountInfo());
    MC_SAFE_RELEASE(mSMTPAccountSender);
    delegate()->messageQueueSenderAccountInfoChanged(this);
}

SMTPAccountSender * MessageQueueSender::messageSenderAccountSender(MessageSender * sender)
{
    setupAccountSender();
    return mSMTPAccountSender;
}

void MessageQueueSender::messageSenderProgress(MessageSender * sender,
                                               unsigned int current, unsigned int maximum)
{
    mCurrentMessageProgress = current;
    mCurrentMessageProgressMax = maximum;
    delegate()->messageQueueSenderProgress(this);
}

void MessageQueueSender::setupAccountSender()
{
    if (mSMTPAccountSender != NULL) {
        return;
    }

    mSMTPAccountSender = new SMTPAccountSender();
    mSMTPAccountSender->setAccountInfo(accountInfo());
    mSMTPAccountSender->setPath(mPath);
    mSMTPAccountSender->setLogEnabled(mLogEnabled);
}

void MessageQueueSender::disableAndRetryLater()
{
    setDeliveryEnabled(false);

    mRetryLaterScheduled = true;
    retain();
    performMethodAfterDelay((Object::Method) &MessageQueueSender::retryLater, NULL, RETRY_DELAY);
}

void MessageQueueSender::retryLater(void * context)
{
    mRetryLaterScheduled = false;
    setDeliveryEnabled(true);
    release();
}

void MessageQueueSender::cancelRetryLater()
{
    if (!mRetryLaterScheduled) {
        return;
    }

    mRetryLaterScheduled = false;
    cancelDelayedPerformMethod((Object::Method) &MessageQueueSender::retryLater, NULL);
    release();
}

#pragma mark reachability observer

void MessageQueueSender::reachabilityChanged(Reachability * reachability)
{
    setDeliveryEnabled(reachability->isReachable());
}
