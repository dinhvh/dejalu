// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMUtils__
#define __dejalu__HMUtils__

#include "HMConstants.h"
#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    bool isConnectionError(hermes::ErrorCode error);
    bool isFatalError(hermes::ErrorCode error);
    bool isAuthenticationError(hermes::ErrorCode error);
    bool isSendError(hermes::ErrorCode error);

    double currentTime(void);

    mailcore::String * uniquePath(mailcore::String * baseFolder, mailcore::String * baseName);
    void removeFile(mailcore::String * filename);
}

#endif

#endif /* defined(__dejalu__HMUtils__) */
