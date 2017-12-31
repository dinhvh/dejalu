// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBChangePeopleConversationsLabelsOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBChangePeopleConversationsLabelsOperation::MailDBChangePeopleConversationsLabelsOperation()
{
    mConversationsIDs = NULL;
    mRemove = false;
    mFolderID = -1;
    mFolderPath = NULL;
    mTrashFolderID = -1;
}

MailDBChangePeopleConversationsLabelsOperation::~MailDBChangePeopleConversationsLabelsOperation()
{
    MC_SAFE_RELEASE(mConversationsIDs);
    MC_SAFE_RELEASE(mFolderPath);
}

mailcore::Array * MailDBChangePeopleConversationsLabelsOperation::conversationsIDs()
{
    return mConversationsIDs;
}

void MailDBChangePeopleConversationsLabelsOperation::setConversationsIDs(mailcore::Array * conversationsIDs)
{
    MC_SAFE_REPLACE_RETAIN(Array, mConversationsIDs, conversationsIDs);
}

bool MailDBChangePeopleConversationsLabelsOperation::remove()
{
    return mRemove;
}

void MailDBChangePeopleConversationsLabelsOperation::setRemove(bool remove)
{
    mRemove = remove;
}

int64_t MailDBChangePeopleConversationsLabelsOperation::folderID()
{
    return mFolderID;
}

void MailDBChangePeopleConversationsLabelsOperation::setFolderID(int64_t folderID)
{
    mFolderID = folderID;
}

int64_t MailDBChangePeopleConversationsLabelsOperation::trashFolderID()
{
    return mTrashFolderID;
}

void MailDBChangePeopleConversationsLabelsOperation::setTrashFolderID(int64_t trashFolderID)
{
    mTrashFolderID = trashFolderID;
}

mailcore::String * MailDBChangePeopleConversationsLabelsOperation::folderPath()
{
    return mFolderPath;
}

void MailDBChangePeopleConversationsLabelsOperation::setFolderPath(mailcore::String * folderPath)
{
    MC_SAFE_REPLACE_COPY(String, mFolderPath, folderPath);
}

void MailDBChangePeopleConversationsLabelsOperation::main()
{
    syncDB()->beginTransaction();
    mc_foreacharray(Value, vRowid, mConversationsIDs) {
        if (mRemove) {
            syncDB()->removeLabelsForConversation(vRowid->longLongValue(), mFolderID, mTrashFolderID, mFolderPath, changes());
        }
        else {
            syncDB()->addLabelsForConversation(vRowid->longLongValue(), mFolderID, mTrashFolderID, mFolderPath, changes());
        }
    }
    syncDB()->commitTransaction(changes());
}

