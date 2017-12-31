// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMessageInfoOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBMessageInfoOperation::MailDBMessageInfoOperation()
{
    mMessageRowID = -1;
    mMessageInfo = NULL;
    mEmailSet = NULL;
    mRenderImageEnabled = false;
}

MailDBMessageInfoOperation::~MailDBMessageInfoOperation()
{
    MC_SAFE_RELEASE(mEmailSet);
    MC_SAFE_RELEASE(mMessageInfo);
}

int64_t MailDBMessageInfoOperation::messageRowID()
{
    return mMessageRowID;
}

void MailDBMessageInfoOperation::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

mailcore::Set * MailDBMessageInfoOperation::emailSet()
{
    return mEmailSet;
}

void MailDBMessageInfoOperation::setEmailSet(mailcore::Set * emailSet)
{
    MC_SAFE_REPLACE_RETAIN(mailcore::Set, mEmailSet, emailSet);
}

bool MailDBMessageInfoOperation::renderImageEnabled()
{
    return mRenderImageEnabled;
}

void MailDBMessageInfoOperation::setRenderImageEnabled(bool enabled)
{
    mRenderImageEnabled = enabled;
}

HashMap * MailDBMessageInfoOperation::messageInfo()
{
    return mMessageInfo;
}

void MailDBMessageInfoOperation::main()
{
    syncDB()->beginTransaction();
    mMessageInfo = syncDB()->messageInfo(mMessageRowID, NULL, mEmailSet, mRenderImageEnabled);
    syncDB()->commitTransaction(changes());
    MC_SAFE_RETAIN(mMessageInfo);
}
