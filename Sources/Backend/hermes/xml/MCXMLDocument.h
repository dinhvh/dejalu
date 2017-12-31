// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __hermes__MCXMLDocument__
#define __hermes__MCXMLDocument__

#include <MailCore/MCBaseTypes.h>

#ifdef __cplusplus

namespace mailcore {
    class XMLNode;
    class XMLElement;
    
    class XMLDocument : public Object {
    public:
        // create empty document.
        XMLDocument();
        
        // parse data.
        static XMLDocument * documentWithData(Data * data);
        static XMLDocument * documentWithHTMLData(Data * data);
        
        virtual ~XMLDocument();
        
        virtual void setRoot(XMLElement * root);
        virtual XMLElement * root();
        
        virtual String * xmlString(bool pretty);
        virtual Data * xmlData(bool pretty);
        virtual String * htmlString(bool pretty);
        virtual Data * htmlData(bool pretty);
        
    private:
        XMLElement * mRoot;
        void init();
    };
}

#endif

#endif /* defined(__hermes__MCXMLDocument__) */
