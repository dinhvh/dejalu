// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMMailStorageViewObserver_h
#define dejalu_HMMailStorageViewObserver_h

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    
    class MailStorageView;
    class MailDBChanges;
    
    class MailStorageViewObserver {
    public:
        virtual void mailStorageViewChanged(MailStorageView * view,
                                            mailcore::Array * deleted,
                                            mailcore::Array * moved,
                                            mailcore::Array * added,
                                            mailcore::Array * modified,
                                            mailcore::Array * modifiedIDs) {}
        
        virtual void mailStorageViewModifiedDeletedConversations(MailStorageView * view,
                                                                 mailcore::Array * modified,
                                                                 mailcore::Array * deleted) {}

        virtual void mailStorageViewAddedMessageParts(MailStorageView * view,
                                                      mailcore::Array * /* MailDBMeessagePartInfo */ messageParts) {}

        virtual void mailStorageFoldersCountsChanged(MailStorageView * view, mailcore::Array * foldersIDs) {}

        virtual void mailStorageNotifyMessages(MailStorageView * view, mailcore::Array * notifiedMessages) {}
    };
}

#endif

#endif
