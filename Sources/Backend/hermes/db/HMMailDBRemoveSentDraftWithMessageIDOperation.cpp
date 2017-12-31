// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRemoveSentDraftWithMessageIDOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBRemoveSentDraftWithMessageIDOperation::MailDBRemoveSentDraftWithMessageIDOperation()
{
    mMessageID = NULL;
    mFolderID = -1;
}

MailDBRemoveSentDraftWithMessageIDOperation::~MailDBRemoveSentDraftWithMessageIDOperation()
{
    MC_SAFE_RELEASE(mMessageID);
}

void MailDBRemoveSentDraftWithMessageIDOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBRemoveSentDraftWithMessageIDOperation::folderID()
{
    return mFolderID;
}

void MailDBRemoveSentDraftWithMessageIDOperation::setMessageID(mailcore::String * messageID)
{
    MC_SAFE_REPLACE_COPY(String, mMessageID, messageID);
}

mailcore::String * MailDBRemoveSentDraftWithMessageIDOperation::messageID()
{
    return mMessageID;
}

void MailDBRemoveSentDraftWithMessageIDOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->removeSentDraftWithMessageID(folderID(), messageID());
    syncDB()->commitTransaction(changes());
}

