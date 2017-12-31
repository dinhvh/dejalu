// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMActivityItem__
#define __dejalu__HMActivityItem__

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {
    
    class ActivityItem : public mailcore::Object {
    public:
        ActivityItem();
        virtual ~ActivityItem();
        
        virtual void setProgressString(mailcore::String * string);
        virtual mailcore::String * progressString();
        
        virtual void setHasProgress(bool hasProgress);
        virtual bool hasProgress();
        
        virtual void setProgressValue(unsigned int value);
        virtual unsigned int progressValue();
        
        virtual void setProgressMax(unsigned int maxValue);
        virtual unsigned int progressMax();
        
        virtual void registerActivity();
        virtual void unregisterActivity();
        
    private:
        bool mHasProgress;
        mailcore::String * mProgressString;
        unsigned int mProgressValue;
        unsigned int mProgressMax;
    };
    
}

#endif

#endif /* defined(__dejalu__HMActivityItem__) */
