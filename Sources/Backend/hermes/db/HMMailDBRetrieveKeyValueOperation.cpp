// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRetrieveKeyValueOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBRetrieveKeyValueOperation::MailDBRetrieveKeyValueOperation()
{
    mKey = NULL;
    mValue = NULL;
}

MailDBRetrieveKeyValueOperation::~MailDBRetrieveKeyValueOperation()
{
    MC_SAFE_RELEASE(mValue);
    MC_SAFE_RELEASE(mKey);
}

String * MailDBRetrieveKeyValueOperation::key()
{
    return mKey;
}

void MailDBRetrieveKeyValueOperation::setKey(String * key)
{
    MC_SAFE_REPLACE_COPY(String, mKey, key);
}

Data * MailDBRetrieveKeyValueOperation::value()
{
    return mValue;
}

void MailDBRetrieveKeyValueOperation::main()
{
    syncDB()->beginTransaction();
    mValue = syncDB()->retrieveValueForKey(mKey);
    MC_SAFE_RETAIN(mValue);
    syncDB()->commitTransaction(changes());
}
