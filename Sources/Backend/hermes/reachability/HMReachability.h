// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMReachability__
#define __dejalu__HMReachability__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class ReachabilityObserver;

    class Reachability : public mailcore::Object {

    public:
        static Reachability * sharedManager();

        virtual bool isReachable();

        virtual void addObserver(ReachabilityObserver * observer);
        virtual void removeObserver(ReachabilityObserver * observer);

    public: // private
        virtual void reachabilityChanged();

    private:
        Reachability();
        ~Reachability();

        carray * mObservers;
    };

}

#endif

#endif /* defined(__dejalu__HMReachability__) */
