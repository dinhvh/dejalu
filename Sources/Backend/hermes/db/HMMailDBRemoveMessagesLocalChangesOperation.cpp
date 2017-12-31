// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRemoveMessagesLocalChangesOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBRemoveMessagesLocalChangesOperation::MailDBRemoveMessagesLocalChangesOperation()
{
    mRowsIDs = NULL;
}

MailDBRemoveMessagesLocalChangesOperation::~MailDBRemoveMessagesLocalChangesOperation()
{
    MC_SAFE_RELEASE(mRowsIDs);
}

IndexSet * MailDBRemoveMessagesLocalChangesOperation::rowsIDs()
{
    return mRowsIDs;
}

void MailDBRemoveMessagesLocalChangesOperation::setRowsIDs(IndexSet * rowsIDs)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mRowsIDs, rowsIDs);
}

void MailDBRemoveMessagesLocalChangesOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->removeLocalMessagesChanges(mRowsIDs);
    syncDB()->commitTransaction(changes());
}

