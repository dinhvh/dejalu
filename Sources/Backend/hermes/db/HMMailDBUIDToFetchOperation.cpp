// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBUIDToFetchOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBUIDToFetchOperation::MailDBUIDToFetchOperation()
{
    mMessageRowID = -1;
    mUid = 0;
    mPartID = NULL;
    mEncoding = EncodingOther;
    mFilename = NULL;
}

MailDBUIDToFetchOperation::~MailDBUIDToFetchOperation()
{
    MC_SAFE_RELEASE(mFilename);
    MC_SAFE_RELEASE(mPartID);
}

int64_t MailDBUIDToFetchOperation::messageRowID()
{
    return mMessageRowID;
}

void MailDBUIDToFetchOperation::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

mailcore::String * MailDBUIDToFetchOperation::partID()
{
    return mPartID;
}

void MailDBUIDToFetchOperation::setPartID(mailcore::String * partID)
{
    MC_SAFE_REPLACE_COPY(String, mPartID, partID);
}

uint32_t MailDBUIDToFetchOperation::uid()
{
    return mUid;
}

mailcore::Encoding MailDBUIDToFetchOperation::encoding()
{
    return mEncoding;
}

mailcore::String * MailDBUIDToFetchOperation::filename()
{
    return mFilename;
}

void MailDBUIDToFetchOperation::main()
{
    syncDB()->beginTransaction();
    syncDB()->uidToFetch(mMessageRowID, &mUid);
    if (mPartID != NULL) {
        mEncoding = syncDB()->encodingForPart(mMessageRowID, mPartID);
    }
    if (mUid == 0) {
        MC_SAFE_REPLACE_RETAIN(String, mFilename, syncDB()->filenameForRowID(mMessageRowID));
    }
    syncDB()->commitTransaction(changes());
}
