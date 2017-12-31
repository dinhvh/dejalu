// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMUnifiedMailStorageViewObserver_hpp
#define HMUnifiedMailStorageViewObserver_hpp

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class UnifiedMailStorageView;
    class MailDBChanges;

    class UnifiedMailStorageViewObserver {
    public:
        virtual void mailStorageViewChanged(UnifiedMailStorageView * view,
                                            mailcore::Array * deleted,
                                            mailcore::Array * moved,
                                            mailcore::Array * added,
                                            mailcore::Array * modified) {}
    };
}

#endif

#endif /* HMUnifiedMailStorageViewObserver_hpp */
