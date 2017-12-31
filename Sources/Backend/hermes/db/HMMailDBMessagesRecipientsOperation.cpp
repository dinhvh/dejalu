// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBMessagesRecipientsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBMessagesRecipientsOperation::MailDBMessagesRecipientsOperation()
{
    mMessagesRowsIDs = NULL;
    mMaxCount = 0;
    mRemainingMessagesRowsIDs = NULL;
    mRecipients = NULL;
}

MailDBMessagesRecipientsOperation::~MailDBMessagesRecipientsOperation()
{
    MC_SAFE_RELEASE(mRecipients);
    MC_SAFE_RELEASE(mMessagesRowsIDs);
    MC_SAFE_RELEASE(mRemainingMessagesRowsIDs);
}

void MailDBMessagesRecipientsOperation::setMessagesRowsIDs(mailcore::IndexSet * messagesRowsIDs)
{
    MC_SAFE_REPLACE_RETAIN(IndexSet, mMessagesRowsIDs, messagesRowsIDs);
}

mailcore::IndexSet * MailDBMessagesRecipientsOperation::messagesRowsIDs()
{
    return mMessagesRowsIDs;
}

void MailDBMessagesRecipientsOperation::setMaxCount(int maxCount)
{
    mMaxCount = maxCount;
}

int MailDBMessagesRecipientsOperation::maxCount()
{
    return mMaxCount;
}

mailcore::Array * MailDBMessagesRecipientsOperation::recipients()
{
    return mRecipients;
}

mailcore::IndexSet * MailDBMessagesRecipientsOperation::remainingMessagesRowsIDs()
{
    return mRemainingMessagesRowsIDs;
}

void MailDBMessagesRecipientsOperation::main()
{
    IndexSet * messagesIndexesToQuery = new IndexSet();
    int remainingCount = mMaxCount;
    for(unsigned int rangeIndex = 0 ; rangeIndex < mMessagesRowsIDs->rangesCount() ; rangeIndex ++) {
        Range * range = &mMessagesRowsIDs->allRanges()[rangeIndex];
        if (range->length < remainingCount) {
            messagesIndexesToQuery->addRange(* range);
            remainingCount -= range->length + 1;
        }
        else if (remainingCount != 0) {
            Range rangeToAdd = RangeMake(range->location, remainingCount - 1);
            messagesIndexesToQuery->addRange(rangeToAdd);
            remainingCount -= remainingCount;
        }
    }
    Array * addresses = syncDB()->recipientsForMessages(messagesIndexesToQuery);
    MC_SAFE_REPLACE_RETAIN(Array, mRecipients, addresses);
    mRemainingMessagesRowsIDs = (IndexSet *) mMessagesRowsIDs->copy();
    mRemainingMessagesRowsIDs->removeIndexSet(messagesIndexesToQuery);
    MC_SAFE_RELEASE(messagesIndexesToQuery);
}

