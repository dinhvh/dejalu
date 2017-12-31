// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBRetrievePartOperation.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

MailDBRetrievePartOperation::MailDBRetrievePartOperation()
{
    mMessageRowID = -1;
    mPartID = NULL;
    mContent = NULL;
    mUniqueID = NULL;
    mFilename = NULL;
    mRetrieveFilenameEnabled = false;
}

MailDBRetrievePartOperation::~MailDBRetrievePartOperation()
{
    MC_SAFE_RELEASE(mUniqueID);
    MC_SAFE_RELEASE(mPartID);
    MC_SAFE_RELEASE(mContent);
    MC_SAFE_RELEASE(mFilename);
}

int64_t MailDBRetrievePartOperation::messageRowID()
{
    return mMessageRowID;
}

void MailDBRetrievePartOperation::setMessageRowID(int64_t messageRowID)
{
    mMessageRowID = messageRowID;
}

String * MailDBRetrievePartOperation::partID()
{
    return mPartID;
}

void MailDBRetrievePartOperation::setPartID(String * partID)
{
    MC_SAFE_REPLACE_COPY(String, mPartID, partID);
}

mailcore::String * MailDBRetrievePartOperation::uniqueID()
{
    return mUniqueID;
}

void MailDBRetrievePartOperation::setUniqueID(mailcore::String * uniqueID)
{
    MC_SAFE_REPLACE_COPY(String, mUniqueID, uniqueID);
}

mailcore::String * MailDBRetrievePartOperation::filename()
{
    return mFilename;
}

void MailDBRetrievePartOperation::setFilename(mailcore::String * filename)
{
    MC_SAFE_REPLACE_COPY(String, mFilename, filename);
}

void MailDBRetrievePartOperation::setRetrieveFilenameEnabled(bool enabled)
{
    mRetrieveFilenameEnabled = enabled;
}

bool MailDBRetrievePartOperation::retrieveFilenameEnabled()
{
    return mRetrieveFilenameEnabled;
}

Data * MailDBRetrievePartOperation::content()
{
    return mContent;
}

static bool isMessageWithoutBodystructure(mailcore::AbstractMessage * msg)
{
    bool result = false;
    if (msg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
        if (((IMAPMessage *) msg)->mainPart() == NULL) {
            result = true;
        }
    }
    return result;
}

void MailDBRetrievePartOperation::main()
{
    syncDB()->beginTransaction();
    if (mRetrieveFilenameEnabled) {
        AbstractMessage * storedMsg = syncDB()->messageForRowIDNoAssert(mMessageRowID);
        if (storedMsg == NULL) {
            goto err;
        }
        AbstractPart * part = NULL;
        if (mPartID != NULL) {
            part = ((IMAPMessage *) storedMsg)->partForPartID(mPartID);
        }
        else {
            if (isMessageWithoutBodystructure(storedMsg)) {
                storedMsg = syncDB()->storedParsedMessage(mMessageRowID);
            }
            part = storedMsg->partForUniqueID(mUniqueID);
            //if (storedMsg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
                if (mPartID == NULL) {
                    if (part->className()->isEqual(MCSTR("mailcore::IMAPPart"))) {
                        MC_SAFE_REPLACE_COPY(String, mPartID, ((IMAPPart *) part)->partID());
                    }
                    else if (part->className()->isEqual(MCSTR("mailcore::Attachment"))) {
                        MC_SAFE_REPLACE_COPY(String, mPartID, ((Attachment *) part)->partID());
                    }
                }
            //}
        }
        MC_SAFE_REPLACE_COPY(String, mFilename, part->filename());
    }
    if (mPartID != NULL) {
        mContent = syncDB()->retrieveDataForPart(mMessageRowID, mPartID);
    }
    else if (mUniqueID != NULL) {
        mContent = syncDB()->retrieveDataForLocalPartWithUniqueID(mMessageRowID, mUniqueID);
    }
    MC_SAFE_RETAIN(mContent);
err:
    syncDB()->commitTransaction(changes());
}
