// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBStoreKeyValueOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBStoreKeyValueOperation::MailDBStoreKeyValueOperation()
{
    mKey = NULL;
    mValue = NULL;
}

MailDBStoreKeyValueOperation::~MailDBStoreKeyValueOperation()
{
    MC_SAFE_RELEASE(mValue);
    MC_SAFE_RELEASE(mKey);
}

String * MailDBStoreKeyValueOperation::key()
{
    return mKey;
}

void MailDBStoreKeyValueOperation::setKey(String * key)
{
    MC_SAFE_REPLACE_COPY(String, mKey, key);
}

Data * MailDBStoreKeyValueOperation::value()
{
    return mValue;
}

void MailDBStoreKeyValueOperation::setValue(Data * value)
{
    MC_SAFE_REPLACE_RETAIN(Data, mValue, value);
}

void MailDBStoreKeyValueOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->storeValueForKey(mKey, mValue);
    syncDB()->commitTransaction(changes());
}
