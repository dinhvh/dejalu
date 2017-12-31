// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMEmailTemplate_hpp
#define HMEmailTemplate_hpp

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class EmailTemplate : public mailcore::Object {

    public:

        EmailTemplate();
        virtual ~EmailTemplate();

        virtual void setName(mailcore::String * name);
        virtual mailcore::String * name();

        virtual void setTemplateString(mailcore::String * templateString);
        virtual mailcore::String * templateString();

    private:
        mailcore::String * mName;
        mailcore::String * mTemplateString;
    };
}

#endif

#endif /* HMEmailTemplate_hpp */
