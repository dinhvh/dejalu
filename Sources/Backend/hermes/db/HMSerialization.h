// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMSerialization_hpp
#define HMSerialization_hpp

#include <MailCore/MailCore.h>

namespace hermes {

    mailcore::Data * fastSerializedData(mailcore::Object * object);
    mailcore::Object * objectWithFastSerializedData(mailcore::Data * data);

}

#endif /* HMSerialization_hpp */
