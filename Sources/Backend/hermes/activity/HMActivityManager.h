// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMActivityManager__
#define __dejalu__HMActivityManager__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    
    class ActivityItem;
    class ActivityManagerObserver;
    
    class ActivityManager : public mailcore::Object {
        
    public:
        static ActivityManager * sharedManager();
        
        ActivityManager();
        virtual ~ActivityManager();
        
        virtual void registerActivity(ActivityItem * item);
        virtual void unregisterActivity(ActivityItem * item);
        
        virtual void addObserver(ActivityManagerObserver * observer);
        virtual void removeObserver(ActivityManagerObserver * observer);
        
        virtual void update();
        
        virtual mailcore::Array * activities();
        
    private:
        mailcore::Array * mActivities;
        carray * mObservers;
    };
    
}

#endif

#endif /* defined(__dejalu__HMActivityManager__) */
