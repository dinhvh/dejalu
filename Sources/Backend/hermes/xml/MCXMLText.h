// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __hermes__MCXMLText__
#define __hermes__MCXMLText__

#include <MailCore/MailCore.h>
#include "MCXMLNode.h"

#ifdef __cplusplus

namespace mailcore {
    class XMLText : public XMLNode {
    public:
        XMLText();
        virtual ~XMLText();
        
        virtual void setValue(String * value);
        virtual String * value();
        
    private:
        String * mValue;
        void init();
    };
}

#endif

#endif /* defined(__hermes__MCXMLText__) */
