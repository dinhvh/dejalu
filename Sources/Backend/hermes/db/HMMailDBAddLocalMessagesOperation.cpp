// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBAddLocalMessagesOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBAddLocalMessagesOperation::MailDBAddLocalMessagesOperation()
{
    mMessageIDs = NULL;
    mMessagesRowsIDs = NULL;
    mMessagesData = NULL;
    mFolderID = -1;
    mNeedsToBeSentToServer = false;
    mHasBeenPushed = false;
    mDraftsFolderID = -1;
}

MailDBAddLocalMessagesOperation::~MailDBAddLocalMessagesOperation()
{
    MC_SAFE_RELEASE(mMessageIDs);
    MC_SAFE_RELEASE(mMessagesRowsIDs);
    MC_SAFE_RELEASE(mMessagesData);
}

mailcore::Array * MailDBAddLocalMessagesOperation::messagesData()
{
    return mMessagesData;
}

void MailDBAddLocalMessagesOperation::setMessagesData(mailcore::Array * /* Data */ msgsData)
{
    MC_SAFE_REPLACE_RETAIN(Array, mMessagesData, msgsData);
}

int64_t MailDBAddLocalMessagesOperation::folderID()
{
    return mFolderID;
}

void MailDBAddLocalMessagesOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

void MailDBAddLocalMessagesOperation::setNeedsToBeSentToServer(bool enabled)
{
    mNeedsToBeSentToServer = enabled;
}

bool MailDBAddLocalMessagesOperation::needsToBeSentToServer()
{
    return mNeedsToBeSentToServer;
}

void MailDBAddLocalMessagesOperation::setHasBeenPushed(bool enabled)
{
    mHasBeenPushed = enabled;
}

bool MailDBAddLocalMessagesOperation::hasBeenPushed()
{
    return mHasBeenPushed;
}

int64_t MailDBAddLocalMessagesOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBAddLocalMessagesOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

Array * MailDBAddLocalMessagesOperation::messageIDs()
{
    return mMessageIDs;
}

mailcore::Array * MailDBAddLocalMessagesOperation::messagesRowsIDs()
{
    return mMessagesRowsIDs;
}

void MailDBAddLocalMessagesOperation::main()
{
    mMessagesRowsIDs = new Array();
    mMessageIDs = new Array();
    syncDB()->beginTransaction();
    mc_foreacharray(Data, messageData, mMessagesData) {
        String * messageID = new String();
        int64_t rowid = syncDB()->addPendingMessageWithData(mFolderID, messageData, mNeedsToBeSentToServer, mHasBeenPushed, messageID,
                                                            mDraftsFolderID, changes());
        mMessagesRowsIDs->addObject(Value::valueWithLongLongValue(rowid));
        mMessageIDs->addObject(messageID);
        MC_SAFE_RELEASE(messageID);
    }
    syncDB()->commitTransaction(changes());
}
