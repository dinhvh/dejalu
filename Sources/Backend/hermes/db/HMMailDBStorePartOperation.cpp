// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBStorePartOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBStorePartOperation::MailDBStorePartOperation()
{
    mPartID = NULL;
    mContent = NULL;
    mMessageRowID = -1;
}

MailDBStorePartOperation::~MailDBStorePartOperation()
{
    MC_SAFE_RELEASE(mContent);
    MC_SAFE_RELEASE(mPartID);
}

int64_t MailDBStorePartOperation::messageRowID()
{
    return mMessageRowID;
}

void MailDBStorePartOperation::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

String * MailDBStorePartOperation::partID()
{
    return mPartID;
}

void MailDBStorePartOperation::setPartID(String * partID)
{
    MC_SAFE_REPLACE_COPY(String, mPartID, partID);
}

Data * MailDBStorePartOperation::content()
{
    return mContent;
}

void MailDBStorePartOperation::setContent(Data * content)
{
    MC_SAFE_REPLACE_RETAIN(Data, mContent, content);
}

void MailDBStorePartOperation::main()
{
    syncDB()->beginTransaction();
    if (mPartID == NULL) {
        // parse message and store all parts.
        syncDB()->parseMessageAndStoreParts(mMessageRowID, mContent, changes());
    }
    else {
        syncDB()->storeDataForPart(mMessageRowID, mPartID, mContent, changes());
    }
    syncDB()->commitTransaction(changes());
}
