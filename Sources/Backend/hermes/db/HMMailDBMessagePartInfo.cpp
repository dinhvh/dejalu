// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMessagePartInfo.h"

using namespace hermes;
using namespace mailcore;

MailDBMessagePartInfo::MailDBMessagePartInfo()
{
    mMessageRowID = -1;
    mPartID = NULL;
}

MailDBMessagePartInfo::~MailDBMessagePartInfo()
{
    MC_SAFE_RELEASE(mPartID);
}

int64_t MailDBMessagePartInfo::messageRowID()
{
    return mMessageRowID;
}

void MailDBMessagePartInfo::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

mailcore::String * MailDBMessagePartInfo::partID()
{
    return mPartID;
}

void MailDBMessagePartInfo::setPartID(mailcore::String * partID)
{
    MC_SAFE_REPLACE_COPY(String, mPartID, partID);
}
