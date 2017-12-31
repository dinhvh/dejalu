// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMEmailTemplateManager_hpp
#define HMEmailTemplateManager_hpp

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class EmailTemplate;

    class EmailTemplateManager : public mailcore::Object {

    public:
        static EmailTemplateManager * sharedManager();

        virtual void addTemplate(EmailTemplate * item);
        virtual void removeTemplateAtIndex(int idx);
        virtual EmailTemplate * templateAtIndex(int idx);
        virtual void replaceTemplateAtIndex(int idx, EmailTemplate * item);

    private:
        EmailTemplateManager();
        ~EmailTemplateManager();

    private:
        mailcore::Array * mTemplates;
    };
}

#endif

#endif /* DJLEmailTemplateManager_hpp */
