// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMMailDBConversationMessagesOperation__
#define __dejalu__HMMailDBConversationMessagesOperation__

#include <MailCore/MailCore.h>
#include "HMMailDBOperation.h"

#ifdef __cplusplus

namespace hermes {
    class MailDBConversationMessagesOperation : public MailDBOperation {
    public:
        MailDBConversationMessagesOperation();
        virtual ~MailDBConversationMessagesOperation();
        
        virtual int64_t conversationID();
        virtual void setConversationID(int64_t conversationID);
        
        virtual mailcore::HashMap * foldersScores();
        virtual void setFoldersScores(mailcore::HashMap * foldersScores);
        
        virtual mailcore::Array * messages();
        
        // Implements Operation.
        virtual void main();
        
    private:
        int64_t mConversationID;
        mailcore::Array * mMessages;
        mailcore::HashMap * mFoldersScores;
    };
    
}

#endif

#endif /* defined(__dejalu__HMMailDBConversationMessagesOperation__) */
