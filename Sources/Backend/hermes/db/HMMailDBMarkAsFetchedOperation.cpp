// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMarkAsFetchedOperation.h"

#include "HMMailDB.h"
#include "HMMailDBChanges.h"

using namespace hermes;
using namespace mailcore;

MailDBMarkAsFetchedOperation::MailDBMarkAsFetchedOperation()
{
    mMessageRowID = -1;
}

MailDBMarkAsFetchedOperation::~MailDBMarkAsFetchedOperation()
{
}

int64_t MailDBMarkAsFetchedOperation::messageRowID()
{
    return mMessageRowID;
}

void MailDBMarkAsFetchedOperation::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

void MailDBMarkAsFetchedOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->markAsFetched(mMessageRowID, changes());
    syncDB()->commitTransaction(changes());
}
