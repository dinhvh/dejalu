// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPAttachmentDownloader.h"

#include "HMMailDBRetrievePartOperation.h"
#include "HMMailStorage.h"
#include "HMAccount.h"
#include "HMUtils.h"

using namespace mailcore;
using namespace hermes;

IMAPAttachmentDownloader::IMAPAttachmentDownloader()
{
    mMessageRowID = -1;
    mFolderID = -1;
    mPartID = NULL;
    mUniqueID = NULL;
    mDownloadFolder = NULL;
    mCallback = NULL;
    mAccount = NULL;
    mRetrievePartOp = NULL;
    //mSucceeded = false;
    mTriedFetch = false;
    mFilename = NULL;
    mError = ErrorNone;
}

IMAPAttachmentDownloader::~IMAPAttachmentDownloader()
{
    MC_SAFE_RELEASE(mPartID);
    MC_SAFE_RELEASE(mUniqueID);
    MC_SAFE_RELEASE(mDownloadFolder);
    MC_SAFE_RELEASE(mAccount);
    MC_SAFE_RELEASE(mRetrievePartOp);
    MC_SAFE_RELEASE(mFilename);
}

void IMAPAttachmentDownloader::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t IMAPAttachmentDownloader::folderID()
{
    return mFolderID;
}

void IMAPAttachmentDownloader::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

int64_t IMAPAttachmentDownloader::messageRowID()
{
    return mMessageRowID;
}

void IMAPAttachmentDownloader::setUniqueID(mailcore::String * uniqueID)
{
    MC_SAFE_REPLACE_COPY(String, mUniqueID, uniqueID);
}

mailcore::String * IMAPAttachmentDownloader::uniqueID()
{
    return mUniqueID;
}

void IMAPAttachmentDownloader::setDownloadFolder(mailcore::String * downloadFolder)
{
    MC_SAFE_REPLACE_COPY(String, mDownloadFolder, downloadFolder);
}

mailcore::String * IMAPAttachmentDownloader::downloadFolder()
{
    return mDownloadFolder;
}

void IMAPAttachmentDownloader::setAccount(Account * account)
{
    MC_SAFE_REPLACE_RETAIN(Account, mAccount, account);
}

Account * IMAPAttachmentDownloader::account()
{
    return mAccount;
}

void IMAPAttachmentDownloader::setCallback(mailcore::OperationCallback * callback)
{
    mCallback = callback;
}

mailcore::OperationCallback * IMAPAttachmentDownloader::callback()
{
    return mCallback;
}

void IMAPAttachmentDownloader::notifyDownloadFinished(hermes::ErrorCode error)
{
    if (error == ErrorNone) {
        // try again.
        retrievePart();
    }
    else {
        mError = error;
        if (!isCancelled()) {
            mCallback->operationFinished(this);
        }
    }
    mAccount->unregisterPartDownloader(this);
    release();
}

mailcore::String * IMAPAttachmentDownloader::partID()
{
    return mPartID;
}

void IMAPAttachmentDownloader::setFilename(mailcore::String * filename)
{
    MC_SAFE_REPLACE_COPY(String, mFilename, filename);
}

mailcore::String * IMAPAttachmentDownloader::filename()
{
    return mFilename;
}

/*
bool IMAPAttachmentDownloader::succeeded()
{
    return mSucceeded;
}
 */

hermes::ErrorCode IMAPAttachmentDownloader::error()
{
    return mError;
}

void IMAPAttachmentDownloader::start()
{
    mAccount->registerPartDownloader(this);
    retrievePart();
}

void IMAPAttachmentDownloader::retrievePart()
{
    retain();
    MailDBRetrievePartOperation * op = mAccount->dataForPartByUniqueIDOperation(mMessageRowID, mUniqueID);
    op->setRetrieveFilenameEnabled(true);
    op->setCallback(this);
    op->start();
    MC_SAFE_REPLACE_RETAIN(MailDBRetrievePartOperation, mRetrievePartOp, op);
}

void IMAPAttachmentDownloader::retrievePartDone()
{
    if (mRetrievePartOp->content() != NULL) {
        //mSucceeded = true;
        String * filename = MCSTR("Untitled");
        if (mRetrievePartOp->filename() != NULL) {
            filename = mRetrievePartOp->filename();
        }
        String * path = mFilename;
        if (path == NULL) {
            filename = (String *) filename->copy()->autorelease();
            filename->replaceOccurrencesOfString(MCSTR("/"), MCSTR(":"));
            path = hermes::uniquePath(mDownloadFolder, filename);
            MC_SAFE_REPLACE_RETAIN(String, mFilename, path);
        }
        mRetrievePartOp->content()->writeToFile(path);
        MC_SAFE_RELEASE(mRetrievePartOp);
        if (!isCancelled()) {
            mCallback->operationFinished(this);
        }
    }
    else if (!mTriedFetch) {
        mTriedFetch = true;
        MC_SAFE_REPLACE_COPY(String, mPartID, mRetrievePartOp->partID());
        MC_SAFE_RELEASE(mRetrievePartOp);

        if (mPartID == NULL) {
            mError = hermes::ErrorFetch;
            if (!isCancelled()) {
                mCallback->operationFinished(this);
            }
            release();
            return;
        }

        retain();
        mAccount->fetchMessagePart(mFolderID, mMessageRowID, mPartID, true);
    }
    else {
        MC_SAFE_RELEASE(mRetrievePartOp);
        if (!isCancelled()) {
            mCallback->operationFinished(this);
        }
    }
    release();
}

void IMAPAttachmentDownloader::operationFinished(Operation * op)
{
    retrievePartDone();
}
