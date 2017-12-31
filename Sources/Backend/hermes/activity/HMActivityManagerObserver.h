// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMActivityManagerObserver_h
#define dejalu_HMActivityManagerObserver_h

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    
    class ActivityManagerObserver {
    public:
        virtual void activityManagerUpdated(ActivityManager * manager) {}
    };
    
}

#endif

#endif
