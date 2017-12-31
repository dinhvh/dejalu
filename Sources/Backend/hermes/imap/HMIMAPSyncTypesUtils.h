// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMIMAPSyncTypesUtils_hpp
#define HMIMAPSyncTypesUtils_hpp

#include "HMIMAPSyncTypes.h"

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    bool supportsBodystructure(IMAPSyncType syncType);
    IMAPSyncType syncTypeWithProviderIdentifier(mailcore::String * providerIdentifier);

}

#endif

#endif /* HMIMAPSyncTypesUtils_hpp */
