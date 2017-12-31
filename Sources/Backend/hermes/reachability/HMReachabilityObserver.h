// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_ReachabilityObserver_h
#define dejalu_ReachabilityObserver_h

#ifdef __cplusplus

namespace hermes {

    class Reachability;

    class ReachabilityObserver {
    public:
        virtual void reachabilityChanged(Reachability * reachability) {}
        
    };

}

#endif

#endif
