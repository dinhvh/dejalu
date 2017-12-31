// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMIMAPFolderSyncStepDelegate_h
#define dejalu_HMIMAPFolderSyncStepDelegate_h

#ifdef __cplusplus

namespace hermes {
    
    class IMAPFolderSyncStep;
    
    class IMAPFolderSyncStepDelegate {
        
    public:
        virtual void folderSyncStateUpdated(IMAPFolderSyncStep * syncStep) {}
        virtual void folderSyncStepDone(IMAPFolderSyncStep * syncStep) {}
    };
    
}

#endif

#endif
