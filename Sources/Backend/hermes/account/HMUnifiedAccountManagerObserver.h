// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMUnifiedAccountManagerObserver_h
#define HMUnifiedAccountManagerObserver_h

#ifdef __cplusplus

namespace hermes {

    class UnifiedAccountManager;

    class UnifiedAccountManagerObserver {
    public:
        virtual void unifiedAccountManagerChanged(UnifiedAccountManager * manager) {}

    };
    
}

#endif

#endif /* HMUnifiedAccountManagerObserver_h */
