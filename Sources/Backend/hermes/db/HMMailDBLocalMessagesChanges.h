// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBMessagesFlagsChanges__
#define __dejalu__HMMailDBMessagesFlagsChanges__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    class MailDBLocalMessagesChanges : public mailcore::Object {
        
    public:
        MailDBLocalMessagesChanges();
        virtual ~MailDBLocalMessagesChanges();
        
        virtual void setFlagsChangeForMessage(int64_t changeRowID, int64_t messageRowID, uint32_t uid, int deleted, int starred, int unread);
        virtual void addMessageLabel(int64_t changeRowID, int64_t messageRowID, uint32_t uid, mailcore::String * label);
        virtual void removeMessageLabel(int64_t changeRowID, int64_t messageRowID, uint32_t uid, mailcore::String * label);
        
        virtual mailcore::IndexSet * messagesWithAddedDeletedFlag();
        virtual mailcore::IndexSet * messagesWithRemovedDeletedFlag();
        virtual mailcore::IndexSet * messagesWithAddedFlaggedFlag();
        virtual mailcore::IndexSet * messagesWithRemovedFlaggedFlag();
        virtual mailcore::IndexSet * messagesWithAddedSeenFlag();
        virtual mailcore::IndexSet * messagesWithRemovedSeenFlag();
        
        // returns msg rowid -> array of labels.
        virtual mailcore::HashMap * labelsRemoval();
        // returns msg rowid -> array of labels.
        virtual mailcore::HashMap * labelsAdditions();
        
        virtual mailcore::IndexSet * rowIDs();
        
    private:
        mailcore::IndexSet * mAddedDeleted;
        mailcore::IndexSet * mRemovedDeleted;
        mailcore::IndexSet * mAddedFlagged;
        mailcore::IndexSet * mRemovedFlagged;
        mailcore::IndexSet * mAddedSeen;
        mailcore::IndexSet * mRemovedSeen;
        mailcore::IndexSet * mRowIDs;
        mailcore::HashMap * mLabelsAddition;
        mailcore::HashMap * mLabelsRemoval;
    };
}

#endif

#endif /* defined(__dejalu__HMMessagesFlagsChanges__) */
