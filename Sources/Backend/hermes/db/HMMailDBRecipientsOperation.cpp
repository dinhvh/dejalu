// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRecipientsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBRecipientsOperation::MailDBRecipientsOperation()
{
    mAddresses = NULL;
}

MailDBRecipientsOperation::~MailDBRecipientsOperation()
{
    MC_SAFE_RELEASE(mAddresses);
}

// result
mailcore::Array * MailDBRecipientsOperation::addresses()
{
    return mAddresses;
}

// Implements Operation.
void MailDBRecipientsOperation::main()
{
    MC_SAFE_REPLACE_RETAIN(Array, mAddresses, syncDB()->savedRecipients());
}

