// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBPeopleViewIDOperation.h"

#include "HMMailDB.h"

using namespace mailcore;
using namespace hermes;

MailDBPeopleViewIDOperation::MailDBPeopleViewIDOperation()
{
    mMessageID = NULL;
    mPeopleViewID = -1;
}

MailDBPeopleViewIDOperation::~MailDBPeopleViewIDOperation()
{
    MC_SAFE_RELEASE(mMessageID);
}

void MailDBPeopleViewIDOperation::setMessageID(mailcore::String * messageID)
{
    MC_SAFE_REPLACE_COPY(String, mMessageID, messageID);
}

mailcore::String * MailDBPeopleViewIDOperation::messageID()
{
    return mMessageID;
}

int64_t MailDBPeopleViewIDOperation::peopleViewID()
{
    return mPeopleViewID;
}

void MailDBPeopleViewIDOperation::main()
{
    mPeopleViewID = syncDB()->peopleViewIDForMessageID(mMessageID);
}
