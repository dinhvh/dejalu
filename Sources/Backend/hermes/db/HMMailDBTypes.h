// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMMailDBTypes_h
#define dejalu_HMMailDBTypes_h

#ifdef __cplusplus

namespace hermes {
    
    enum MailDBMessageRenderType {
        MailDBMessageRenderTypeHTML,
        MailDBMessageRenderTypeSummary,
    };
    
    enum MailDBChangeFlagsType {
        MailDBChangeFlagsTypeMarkRead,
        MailDBChangeFlagsTypeMarkUnread,
        MailDBChangeFlagsTypeMarkFlagged,
        MailDBChangeFlagsTypeMarkUnflagged,
        MailDBChangeFlagsTypeMarkDeleted,
        MailDBChangeFlagsTypeMarkArchived,
        MailDBChangeFlagsTypeRemoveFromFolder,
    };
}

#endif

#endif
