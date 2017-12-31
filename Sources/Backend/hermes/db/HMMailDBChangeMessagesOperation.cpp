// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBChangeMessagesOperation.h"

#include "HMMailDB.h"
#include "HMMailDBChanges.h"

using namespace hermes;
using namespace mailcore;

MailDBChangeMessagesOperation::MailDBChangeMessagesOperation()
{
    mMessages = NULL;
    mFolderID = -1;
    mDraftsFolderID = -1;
}

MailDBChangeMessagesOperation::~MailDBChangeMessagesOperation()
{
    MC_SAFE_RELEASE(mMessages);
}

Array * MailDBChangeMessagesOperation::messages()
{
    return mMessages;
}

void MailDBChangeMessagesOperation::setMessages(Array * msgs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mMessages, msgs);
}

int64_t MailDBChangeMessagesOperation::folderID()
{
    return mFolderID;
}

void MailDBChangeMessagesOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBChangeMessagesOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBChangeMessagesOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

void MailDBChangeMessagesOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreacharray(IMAPMessage, msg, mMessages) {
        int64_t rowid;
        int64_t peopleViewID;
        syncDB()->changeMessageWithUID(mFolderID, msg->uid(), msg->flags(), MessageFlagMaskAll, mDraftsFolderID,
                                       changes(), &rowid, &peopleViewID);
        if ((rowid != -1) && (msg->gmailLabels() != NULL)) {
            syncDB()->changeMessageLabelsWithUID(rowid, peopleViewID, msg->gmailLabels(), changes());
        }
    }
    syncDB()->commitTransaction(changes());
}
