// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMessageRenderOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBMessageRenderOperation::MailDBMessageRenderOperation()
{
    mMessageRowID = -1;
    mRenderType = MailDBMessageRenderTypeHTML;
    mRequiredParts = new Array();
    mResult = NULL;
    mHasMessagePart = false;
    mShouldFetchFullMessage = false;
}

MailDBMessageRenderOperation::~MailDBMessageRenderOperation()
{
    MC_SAFE_RELEASE(mResult);
    MC_SAFE_RELEASE(mRequiredParts);
}

int64_t MailDBMessageRenderOperation::messageRowID()
{
    return mMessageRowID;
}

void MailDBMessageRenderOperation::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

MailDBMessageRenderType MailDBMessageRenderOperation::renderType()
{
    return mRenderType;
}

void MailDBMessageRenderOperation::setRenderType(MailDBMessageRenderType type)
{
    mRenderType = type;
}

String * MailDBMessageRenderOperation::result()
{
    return mResult;
}

Array * MailDBMessageRenderOperation::requiredParts()
{
    return mRequiredParts;
}

bool MailDBMessageRenderOperation::hasMessagePart()
{
    return mHasMessagePart;
}

bool MailDBMessageRenderOperation::shouldFetchFullMessage()
{
    return mShouldFetchFullMessage;
}

void MailDBMessageRenderOperation::main()
{
    syncDB()->beginTransaction();
    mResult = syncDB()->renderMessageSummary(mMessageRowID, mRequiredParts, &mHasMessagePart, &mShouldFetchFullMessage);
    syncDB()->commitTransaction(changes());
    MC_SAFE_RETAIN(mResult);
}

