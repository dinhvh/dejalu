// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMActivityManager.h"

#include <libetpan/libetpan.h>

#include "HMActivityItem.h"
#include "HMActivityManagerObserver.h"

using namespace mailcore;
using namespace hermes;

ActivityManager * ActivityManager::sharedManager()
{
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    static ActivityManager * singleton = NULL;
    pthread_mutex_lock(&lock);
    if (singleton == NULL) {
        singleton = new ActivityManager();
    }
    pthread_mutex_unlock(&lock);
    return singleton;
}

ActivityManager::ActivityManager()
{
    mActivities = new Array();
    mObservers = carray_new(4);
}

ActivityManager::~ActivityManager()
{
    carray_free(mObservers);
    MC_SAFE_RELEASE(mActivities);
}

void ActivityManager::registerActivity(ActivityItem * item)
{
    mActivities->addObject(item);
    update();
}

void ActivityManager::unregisterActivity(ActivityItem * item)
{
    mActivities->removeObject(item);
    update();
}

void ActivityManager::addObserver(ActivityManagerObserver * observer)
{
    carray_add(mObservers, (void *) observer, NULL);
}

void ActivityManager::removeObserver(ActivityManagerObserver * observer)
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        if (carray_get(mObservers, i) == observer) {
            carray_delete(mObservers, i);
            break;
        }
    }
}

void ActivityManager::update()
{
    for(unsigned int i = 0 ; i < carray_count(mObservers) ; i ++) {
        ActivityManagerObserver * observer = (ActivityManagerObserver *) carray_get(mObservers, i);
        observer->activityManagerUpdated(this);
    }
}

mailcore::Array * ActivityManager::activities()
{
    return mActivities;
}
