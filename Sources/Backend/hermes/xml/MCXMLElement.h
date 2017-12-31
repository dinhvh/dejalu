// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __hermes__MCXMLElement__
#define __hermes__MCXMLElement__

#include <MailCore/MailCore.h>
#include "MCXMLNode.h"

#ifdef __cplusplus

namespace mailcore {
    class XMLElement : public XMLNode {
    public:
        XMLElement();
        virtual ~XMLElement();
        
        virtual void setName(String * name);
        virtual String * name();
        
        virtual void setAttribute(String * name, String * value);
        virtual void removeAttribute(String * name);
        virtual Array * allAttributesNames();
        virtual String * attributeForName(String * name);
        
        virtual unsigned int childrenCount();
        virtual XMLNode * childAtIndex(unsigned int idx);
        virtual void addChild(XMLNode * node);
        virtual void removeChildAtIndex(unsigned int idx);
        
    private:
        HashMap * mAttributes;
        Array * mChildren;
        String * mName;
        void init();
    };
}

#endif

#endif /* defined(__hermes__MCXMLElement__) */
