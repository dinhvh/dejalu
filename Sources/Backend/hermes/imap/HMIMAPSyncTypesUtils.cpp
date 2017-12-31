// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMIMAPSyncTypesUtils.h"

using namespace hermes;

bool hermes::supportsBodystructure(IMAPSyncType syncType)
{
    switch (syncType) {
        case IMAPSyncTypeConformant:
        default:
            return true;
        case IMAPSyncTypeOther:
        case IMAPSyncTypeQQ:
        case IMAPSyncTypeDomino:
            return false;
    }
}

hermes::IMAPSyncType hermes::syncTypeWithProviderIdentifier(mailcore::String * providerIdentifier)
{
    IMAPSyncType syncType = IMAPSyncTypeConformant;
    if (providerIdentifier == NULL) {
        return syncType;
    }

    if (providerIdentifier->isEqual(MCSTR("gmail"))) {
        syncType = IMAPSyncTypeGmail;
    }
    else if (providerIdentifier->isEqual(MCSTR("mobileme"))) {
        syncType = IMAPSyncTypeICloud;
    }
    else if (providerIdentifier->isEqual(MCSTR("fastmail"))) {
        syncType = IMAPSyncTypeFastmail;
    }
    else if (providerIdentifier->isEqual(MCSTR("yahoo"))) {
        syncType = IMAPSyncTypeYahoo;
    }
    else if (providerIdentifier->isEqual(MCSTR("apple")) ||
             providerIdentifier->isEqual(MCSTR("euro-apple")) ||
             providerIdentifier->isEqual(MCSTR("asia-apple"))) {
        syncType = IMAPSyncTypeApple;
    }
    else if (providerIdentifier->isEqual(MCSTR("gmx"))) {
        syncType = IMAPSyncTypeGMX;
    }
    else if (providerIdentifier->isEqual(MCSTR("zimbra"))) {
        syncType = IMAPSyncTypeZimbra;
    }
    else if (providerIdentifier->isEqual(MCSTR("ovh"))) {
        syncType = IMAPSyncTypeOVH;
    }
    else if (providerIdentifier->isEqual(MCSTR("outlook"))) {
        syncType = IMAPSyncTypeOutlook;
    }
    else if (providerIdentifier->isEqual(MCSTR("office365"))) {
        syncType = IMAPSyncTypeOffice365;
    }
    else if (providerIdentifier->isEqual(MCSTR("qq"))) {
        syncType = IMAPSyncTypeQQ;
    }
    else if (providerIdentifier->isEqual(MCSTR("domino"))) {
        syncType = IMAPSyncTypeDomino;
    }

    return syncType;
}
