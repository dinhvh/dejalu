// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMReachability.h"

#include <libetpan/libetpan.h>
#import <AppKit/AppKit.h>

#import "NPReachability.h"
#include "HMReachabilityObserver.h"
#include "DJLLog.h"

using namespace hermes;
using namespace mailcore;

@interface HMReachabilityNotificationHandler : NSObject

- (void) _reachabilityChanged;
- (void) _receiveWakeNote;

@end

@implementation HMReachabilityNotificationHandler

- (void) _reachabilityChanged
{
    LOG_ERROR("HMReachabilityNotificationHandler / _reachabilityChanged");
    Reachability::sharedManager()->reachabilityChanged();
}

- (void) _receiveWakeNote
{
    LOG_ERROR("HMReachabilityNotificationHandler / _receiveWakeNote");
    Reachability::sharedManager()->reachabilityChanged();
}

@end


Reachability * Reachability::sharedManager()
{
    static Reachability * instance = new Reachability();
    return instance;
}

Reachability::Reachability()
{
    mObservers = carray_new(4);
    static HMReachabilityNotificationHandler * s_reachabilityNotificationHandler = [[HMReachabilityNotificationHandler alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:s_reachabilityNotificationHandler selector:@selector(_reachabilityChanged) name:NPReachabilityChangedNotification object:[NPReachability sharedInstance]];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:s_reachabilityNotificationHandler
                                                           selector:@selector(_receiveWakeNote)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object: nil];
}

Reachability::~Reachability()
{
    carray_free(mObservers);
}

bool Reachability::isReachable()
{
    return [[NPReachability sharedInstance] isCurrentlyReachable];
}

void Reachability::addObserver(ReachabilityObserver * observer)
{
    carray_add(mObservers, (void *) observer, NULL);
}

void Reachability::removeObserver(ReachabilityObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            break;
        }
    }
}

void Reachability::reachabilityChanged()
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        ReachabilityObserver * observer = (ReachabilityObserver *) carray_get(mObservers, i);
        observer->reachabilityChanged(this);
    }
}
