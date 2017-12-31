// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBChangeMessagesFlagsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBChangeMessagesFlagsOperation::MailDBChangeMessagesFlagsOperation()
{
    mMessagesRowIDs = NULL;
    mChangeFlagsType = MailDBChangeFlagsTypeMarkRead;
    mDraftsFolderID = -1;
}

MailDBChangeMessagesFlagsOperation::~MailDBChangeMessagesFlagsOperation()
{
    MC_SAFE_RELEASE(mMessagesRowIDs);
}

Array * MailDBChangeMessagesFlagsOperation::messagesRowIDs()
{
    return mMessagesRowIDs;
}

void MailDBChangeMessagesFlagsOperation::setMessagesRowIDs(Array * messagesRowIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mMessagesRowIDs, messagesRowIDs);
}

MailDBChangeFlagsType MailDBChangeMessagesFlagsOperation::changeFlagsType()
{
    return mChangeFlagsType;
}

void MailDBChangeMessagesFlagsOperation::setChangeFlagsType(MailDBChangeFlagsType type)
{
    mChangeFlagsType = type;
}

int64_t MailDBChangeMessagesFlagsOperation::draftsFolderID()
{
    return mDraftsFolderID;
}

void MailDBChangeMessagesFlagsOperation::setDraftsFolderID(int64_t folderID)
{
    mDraftsFolderID = folderID;
}

void MailDBChangeMessagesFlagsOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreacharray(Value, vRowid, mMessagesRowIDs) {
        switch (mChangeFlagsType) {
            case MailDBChangeFlagsTypeMarkRead:
                syncDB()->markMessageAsRead(vRowid->longLongValue(), mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkUnread:
                syncDB()->markMessageAsUnread(vRowid->longLongValue(), mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkFlagged:
                syncDB()->markMessageAsFlagged(vRowid->longLongValue(), mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkUnflagged:
                syncDB()->markMessageAsUnflagged(vRowid->longLongValue(), mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkDeleted:
                syncDB()->markMessageAsDeleted(vRowid->longLongValue(), mDraftsFolderID, changes());
                break;
            case MailDBChangeFlagsTypeMarkArchived:
                // Not implemnented.
                MCAssert(0);
                break;
            case MailDBChangeFlagsTypeRemoveFromFolder:
                // Not implemnented.
                MCAssert(0);
                break;
        }
    }
    syncDB()->commitTransaction(changes());
}

