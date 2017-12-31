// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMActivityItem.h"

#include "HMActivityManager.h"

using namespace hermes;

ActivityItem::ActivityItem()
{
    mHasProgress = false;
    mProgressString = NULL;
    mProgressValue = 0;
    mProgressMax = 0;
}

ActivityItem::~ActivityItem()
{
    MC_SAFE_RELEASE(mProgressString);
}

void ActivityItem::setProgressString(mailcore::String * string)
{
    MC_SAFE_REPLACE_COPY(mailcore::String, mProgressString, string);
}

mailcore::String * ActivityItem::progressString()
{
    return mProgressString;
}

void ActivityItem::setHasProgress(bool hasProgress)
{
    mHasProgress = hasProgress;
}

bool ActivityItem::hasProgress()
{
    return mHasProgress;
}

void ActivityItem::setProgressValue(unsigned int value)
{
    mProgressValue = value;
    ActivityManager::sharedManager()->update();
}

unsigned int ActivityItem::progressValue()
{
    return mProgressValue;
}

void ActivityItem::setProgressMax(unsigned int maxValue)
{
    mProgressMax = maxValue;
    ActivityManager::sharedManager()->update();
}

unsigned int ActivityItem::progressMax()
{
    return mProgressMax;
}

void ActivityItem::registerActivity()
{
    ActivityManager::sharedManager()->registerActivity(this);
}

void ActivityItem::unregisterActivity()
{
    ActivityManager::sharedManager()->unregisterActivity(this);
}

