// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBOperation.h"

#include "HMMailDB.h"
#include "HMMailStorage.h"
#include "HMMailDBChanges.h"
#include "DJLLog.h"

using namespace hermes;
using namespace mailcore;

MailDBOperation::MailDBOperation()
{
    mSyncDB = NULL;
    mStorage = NULL;
    mQueue = NULL;
    mChanges = new MailDBChanges();
    setShouldRunWhenCancelled(true);
}

MailDBOperation::~MailDBOperation()
{
    MC_SAFE_RELEASE(mChanges);
    MC_SAFE_RELEASE(mQueue);
    MC_SAFE_RELEASE(mStorage);
    MC_SAFE_RELEASE(mSyncDB);
}

void MailDBOperation::setSyncDB(MailDB * syncDB)
{
    MC_SAFE_REPLACE_RETAIN(MailDB, mSyncDB, syncDB);
}

MailDB * MailDBOperation::syncDB()
{
    return mSyncDB;
}

void MailDBOperation::setStorage(MailStorage * storage)
{
    MC_SAFE_REPLACE_RETAIN(MailStorage, mStorage, storage);
}

MailStorage * MailDBOperation::storage()
{
    return mStorage;
}

void MailDBOperation::setOperationQueue(OperationQueue * queue)
{
    MC_SAFE_REPLACE_RETAIN(OperationQueue, mQueue, queue);
}

OperationQueue * MailDBOperation::operationQueue()
{
    return mQueue;
}

MailDBChanges * MailDBOperation::changes()
{
    return mChanges;
}

void MailDBOperation::afterMain()
{
    mStorage->notifyStorageOperationFinished(this);
}

void MailDBOperation::start()
{
    if (mStorage->isTerminated() && !className()->isEqual(MCSTR("hermes::MailDBCloseOperation"))) {
        fprintf(stderr, "operation starting while storage is closed %s - cancelled: %i\n", MCUTF8(this), isCancelled());
        LOG_ERROR("operation starting while storage is closed %s - cancelled: %i", MCUTF8(this), isCancelled());
        return;
    }
    mQueue->addOperation(this);
}
