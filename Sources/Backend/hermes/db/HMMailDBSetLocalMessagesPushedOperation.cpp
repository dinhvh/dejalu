// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBSetLocalMessagesPushedOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBSetLocalMessagesPushedOperation::MailDBSetLocalMessagesPushedOperation()
{
    mMessagesRowsIDs = NULL;
}

MailDBSetLocalMessagesPushedOperation::~MailDBSetLocalMessagesPushedOperation()
{
    MC_SAFE_RELEASE(mMessagesRowsIDs);
}

mailcore::IndexSet * MailDBSetLocalMessagesPushedOperation::messagesRowsIDs()
{
    return mMessagesRowsIDs;
}

void MailDBSetLocalMessagesPushedOperation::setMessagesRowsIDs(mailcore::IndexSet * messagesRowsIDs)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mMessagesRowsIDs, messagesRowsIDs);
}

void MailDBSetLocalMessagesPushedOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreachindexset(idx, mMessagesRowsIDs) {
        syncDB()->setLocalMessagePushed(idx);
    }
    syncDB()->commitTransaction(changes());
}

