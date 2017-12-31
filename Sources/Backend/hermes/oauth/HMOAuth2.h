// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMAuth2_h
#define dejalu_HMAuth2_h

#include <MailCore/MailCore.h>

#include "DJLKeys.h"
#include "HMConstants.h"

#ifdef __cplusplus

namespace hermes {
    void OAuth2GetToken(mailcore::String * refreshToken,
                        mailcore::String * providerIdentifier,
                        void (* gotTokenCallback)(hermes::ErrorCode code, mailcore::String * OAuth2Token, void * data),
                        void * data);
}

#endif

#endif
