// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBAddToSavedRecipientsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBAddToSavedRecipientsOperation::MailDBAddToSavedRecipientsOperation()
{
    mAddresses = NULL;
    mRowID = -1;
    mAllSavedAddresses = NULL;
}

MailDBAddToSavedRecipientsOperation::~MailDBAddToSavedRecipientsOperation()
{
    MC_SAFE_RELEASE(mAllSavedAddresses);
    MC_SAFE_RELEASE(mAddresses);
}

void MailDBAddToSavedRecipientsOperation::setAddresses(mailcore::Array * addresses)
{
    MC_SAFE_REPLACE_RETAIN(Array, mAddresses, addresses);
}

mailcore::Array * MailDBAddToSavedRecipientsOperation::addresses()
{
    return mAddresses;
}

void MailDBAddToSavedRecipientsOperation::setRowID(int64_t rowID)
{
    mRowID = rowID;
}

int64_t MailDBAddToSavedRecipientsOperation::rowID()
{
    return mRowID;
}

mailcore::Array * MailDBAddToSavedRecipientsOperation::allSavedAddresses()
{
    return mAllSavedAddresses;
}

// Implements Operation.
void MailDBAddToSavedRecipientsOperation::main()
{
    Array * savedAddresses = syncDB()->addToSavedRecipients(mAddresses, mRowID);
    MC_SAFE_REPLACE_RETAIN(Array, mAllSavedAddresses, savedAddresses);
}

