// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMMailDBChangePeopleConversationsLabelsOperation_hpp
#define HMMailDBChangePeopleConversationsLabelsOperation_hpp

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"
#include "HMMailDBTypes.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBChangePeopleConversationsLabelsOperation : public MailDBOperation {
    public:
        MailDBChangePeopleConversationsLabelsOperation();
        virtual ~MailDBChangePeopleConversationsLabelsOperation();

        virtual mailcore::Array * conversationsIDs();
        virtual void setConversationsIDs(mailcore::Array * conversationsIDs);

        virtual bool remove();
        virtual void setRemove(bool remove);

        virtual int64_t folderID();
        virtual void setFolderID(int64_t folderID);

        virtual int64_t trashFolderID();
        virtual void setTrashFolderID(int64_t trashFolderID);

        virtual mailcore::String * folderPath();
        virtual void setFolderPath(mailcore::String * folderPath);

        // Implements Operation.
        virtual void main();

    private:
        mailcore::Array * mConversationsIDs;
        bool mRemove;
        mailcore::String * mFolderPath;
        int64_t mTrashFolderID;
        int64_t mFolderID;
    };
    
}

#endif

#endif /* HMMailDBChangePeopleConversationsLabelsOperation_hpp */
