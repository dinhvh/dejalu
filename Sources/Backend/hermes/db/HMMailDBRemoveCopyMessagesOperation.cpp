// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRemoveCopyMessagesOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBRemoveCopyMessagesOperation::MailDBRemoveCopyMessagesOperation()
{
    mRowsIDs = NULL;
    mMessagesRowsIDs = NULL;
    mClearMoving = false;
    mDraftsFolderID = -1;
}

MailDBRemoveCopyMessagesOperation::~MailDBRemoveCopyMessagesOperation()
{
    MC_SAFE_RELEASE(mRowsIDs);
    MC_SAFE_RELEASE(mMessagesRowsIDs);
}

void MailDBRemoveCopyMessagesOperation::setRowsIDs(mailcore::IndexSet * rowsIDs)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mRowsIDs, rowsIDs);
}

mailcore::IndexSet * MailDBRemoveCopyMessagesOperation::rowsIDs()
{
    return mRowsIDs;
}

void MailDBRemoveCopyMessagesOperation::setMessagesRowIDs(mailcore::IndexSet * messagesRowIDs)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mMessagesRowsIDs, messagesRowIDs);
}

mailcore::IndexSet * MailDBRemoveCopyMessagesOperation::messagesRowIDs()
{
    return mMessagesRowsIDs;
}

void MailDBRemoveCopyMessagesOperation::setClearMoving(bool clearMoving)
{
    mClearMoving = clearMoving;
}

bool MailDBRemoveCopyMessagesOperation::clearMoving()
{
    return mClearMoving;
}

int64_t MailDBRemoveCopyMessagesOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBRemoveCopyMessagesOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

void MailDBRemoveCopyMessagesOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreachindexset(rowid, mRowsIDs) {
        syncDB()->removeCopyMessage(rowid);
    }
    if (mClearMoving) {
        mc_foreachindexset(messageRowID, mMessagesRowsIDs) {
            syncDB()->clearMovingForMessage(messageRowID, mDraftsFolderID, changes());
        }
    }
    syncDB()->commitTransaction(changes());
}
