// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMUnifiedMailStorageView_hpp
#define HMUnifiedMailStorageView_hpp

#include <MailCore/MailCore.h>

#include "HMMailStorageViewObserver.h"

#ifdef __cplusplus

namespace hermes {

    class MailStorage;
    class MailStorageViewObserver;
    class MailDBChanges;
    class MailDBConversationMessagesOperation;
    class UnifiedMailStorageViewObserver;
    class MailStorageView;

    class UnifiedMailStorageView : public mailcore::Object, public hermes::MailStorageViewObserver {
    public:
        UnifiedMailStorageView();
        virtual ~UnifiedMailStorageView();

        virtual void setStorageViews(mailcore::Array * /* MailStorageView */ views);
        virtual mailcore::Array * storageViews();

        virtual void addObserver(UnifiedMailStorageViewObserver * observer);
        virtual void removeObserver(UnifiedMailStorageViewObserver * observer);

        virtual unsigned int conversationsCount();
        virtual mailcore::HashMap * conversationsInfoAtIndex(unsigned int idx);
        virtual mailcore::HashMap * conversationsInfoForConversationID(unsigned int accountIndex,
                                                                       int64_t conversationID);

        virtual bool isLoading();

    public: // HMMailStorageView observer
        virtual void mailStorageViewChanged(MailStorageView * view,
                                            mailcore::Array * deleted,
                                            mailcore::Array * moved,
                                            mailcore::Array * added,
                                            mailcore::Array * modified,
                                            mailcore::Array * modifiedIDs);

    private:
        mailcore::Array * mViews;
        int mOpenCount;
        mailcore::Array * mConversations;
        carray * mObservers;
        double mLastUpdateTimestamp;
        mailcore::Set * mModifiedConversationsIDs;
        bool mScheduledUpdate;

        void notifyChangesToObserver(mailcore::Array * deleted, mailcore::Array * moved, mailcore::Array * added,
                                     mailcore::Array * modified);
        void scheduleUpdate(double currentTime);
        void updateNow();
    };
    
}

#endif

#endif /* HMUnifiedMailStorageView_hpp */
