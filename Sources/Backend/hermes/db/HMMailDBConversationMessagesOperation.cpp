// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBConversationMessagesOperation.h"

#include "HMMailDB.h"
#include "HMMailDBChanges.h"

using namespace hermes;
using namespace mailcore;

MailDBConversationMessagesOperation::MailDBConversationMessagesOperation()
{
    mConversationID = -1;
    mMessages = NULL;
    mFoldersScores = NULL;
}

MailDBConversationMessagesOperation::~MailDBConversationMessagesOperation()
{
    MC_SAFE_RELEASE(mFoldersScores);
    MC_SAFE_RELEASE(mMessages);
}

int64_t MailDBConversationMessagesOperation::conversationID()
{
    return mConversationID;
}

void MailDBConversationMessagesOperation::setConversationID(int64_t conversationID)
{
    mConversationID = conversationID;
}

mailcore::HashMap * MailDBConversationMessagesOperation::foldersScores()
{
    return mFoldersScores;
}

void MailDBConversationMessagesOperation::setFoldersScores(mailcore::HashMap * foldersScores)
{
    MC_SAFE_REPLACE_RETAIN(HashMap, mFoldersScores, foldersScores);
}

Array * MailDBConversationMessagesOperation::messages()
{
    return mMessages;
}

void MailDBConversationMessagesOperation::main()
{
    syncDB()->beginTransaction();
    mMessages = syncDB()->messagesForPeopleConversation(mConversationID, mFoldersScores);
    syncDB()->commitTransaction(changes());
    mMessages->retain();
}
