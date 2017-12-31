// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "MCXMLDocument.h"

#include <libxml/tree.h>
#include <libxml/HTMLtree.h>
#include <libxml/HTMLparser.h>

#include "MCXMLElement.h"
#include "MCXMLText.h"

using namespace mailcore;

static xmlNodePtr textToLibXML(XMLText * text);
static xmlDocPtr docToLibXML(XMLDocument * doc);
static xmlNodePtr nodeToLibXML(XMLNode * node);
static XMLNode * nodeFromLibXML(xmlNodePtr node);

static xmlNodePtr elementToLibXML(XMLElement * elt)
{
    xmlNodePtr node = xmlNewNode((xmlNsPtr) NULL,
                                 (const xmlChar *) elt->name()->UTF8Characters());
    mc_foreacharray(String, attributeName, elt->allAttributesNames()) {
        String * attributeValue = elt->attributeForName(attributeName);
        xmlNewProp(node, (const xmlChar *)attributeName->UTF8Characters(),
                   (const xmlChar *) attributeValue->UTF8Characters());
    }
    for(unsigned int i = 0 ; i < elt->childrenCount() ; i ++) {
        XMLNode * eltChild = (XMLElement *) elt->childAtIndex(i);
        xmlNodePtr child = nodeToLibXML(eltChild);
        xmlAddChild(node, child);
    }
    return node;
}

static xmlNodePtr nodeToLibXML(XMLNode * node)
{
    if (node->className()->isEqual(MCSTR("mailcore::XMLText"))) {
        return textToLibXML((XMLText *) node);
    }
    else if (node->className()->isEqual(MCSTR("mailcore::XMLElement"))) {
        return elementToLibXML((XMLElement *) node);
    }
    else {
        MCAssert(0);
        return NULL;
    }
}

static xmlNodePtr textToLibXML(XMLText * text)
{
    return xmlNewText((const xmlChar *) text->value()->UTF8Characters());
}

static xmlDocPtr docToLibXML(XMLDocument * doc)
{
    xmlNodePtr root = elementToLibXML(doc->root());
    xmlDocPtr result = htmlNewDoc(NULL, NULL);
    xmlDocSetRootElement(result, root);
    return result;
}

static XMLElement * elementFromLibXML(xmlNodePtr element)
{
    XMLElement * result = new XMLElement();
    result->setName(String::stringWithUTF8Characters((const char *) element->name));
    
    xmlAttrPtr currentAttr = element->properties;
    while (currentAttr != NULL) {
        if (currentAttr->children != NULL) {
            result->setAttribute(String::stringWithUTF8Characters((const char *) currentAttr->name),
                                 String::stringWithUTF8Characters((const char *) currentAttr->children->content));
        }
        else {
            MCLog("element %s has empty attr %s", element->name, currentAttr->name);
        }
        currentAttr = currentAttr->next;
    }
    xmlNodePtr currentNode = element->children;
    while (currentNode != NULL) {
        XMLNode * node = nodeFromLibXML(currentNode);
        if (node != NULL) {
            result->addChild(node);
        }
        currentNode = currentNode->next;
    }
    result->autorelease();
    return result;
}

static XMLText * textFromLibXML(xmlNodePtr node)
{
    XMLText * result = new XMLText();
    String * content = String::stringWithUTF8Characters((const char *) node->content);
    result->setValue(content);
    result->autorelease();
    return result;
}

static XMLNode * nodeFromLibXML(xmlNodePtr node)
{
    if ((node->type == XML_TEXT_NODE) || (node->type == XML_CDATA_SECTION_NODE)) {
        return textFromLibXML(node);
    }
    else if (node->type == XML_ELEMENT_NODE) {
        return elementFromLibXML(node);
    }
    else if (node->type == XML_COMMENT_NODE) {
        return NULL;
    }
    else {
        // ignore other nodes.
        return NULL;
    }
}

static XMLDocument * docFromLibXML(xmlDocPtr doc)
{
    XMLDocument * xmlDoc = new XMLDocument();
    XMLElement * root = elementFromLibXML(xmlDocGetRootElement(doc));
    xmlDoc->setRoot(root);
    xmlDoc->autorelease();
    return xmlDoc;
}

void XMLDocument::init()
{
    mRoot = NULL;
}

XMLDocument::XMLDocument()
{
    init();
}

XMLDocument * XMLDocument::documentWithData(Data * data)
{
    XMLDocument * result;
    
    xmlDocPtr doc = xmlParseMemory(data->bytes(), data->length());
    result = docFromLibXML(doc);
    xmlFreeDoc(doc);
    return result;
}

XMLDocument * XMLDocument::documentWithHTMLData(Data * data)
{
    XMLDocument * result;
    
    xmlDocPtr doc = htmlReadMemory(data->bytes(), data->length(), NULL,
                                   xmlGetCharEncodingName(XML_CHAR_ENCODING_UTF8),
                                   HTML_PARSE_RECOVER | HTML_PARSE_COMPACT);
    result = docFromLibXML(doc);
    xmlFreeDoc(doc);
    return result;
}

XMLDocument::~XMLDocument()
{
    MC_SAFE_RELEASE(mRoot);
}

void XMLDocument::setRoot(XMLElement * root)
{
    MC_SAFE_REPLACE_RETAIN(XMLElement, mRoot, root);
}

XMLElement * XMLDocument::root()
{
    return mRoot;
}

String * XMLDocument::xmlString(bool pretty)
{
    return xmlData(pretty)->stringWithCharset("utf-8");
}

Data * XMLDocument::xmlData(bool pretty)
{
    xmlChar * cData;
    int size;
    
    xmlDocPtr doc = docToLibXML(this);
    xmlDocDumpMemory(doc, &cData, &size);
    Data * data = Data::dataWithBytes((const char *) cData, size);
    xmlFreeDoc(doc);
    xmlFree(cData);
    return data;
}

String * XMLDocument::htmlString(bool pretty)
{
    return htmlData(pretty)->stringWithCharset("utf-8");
}

Data * XMLDocument::htmlData(bool pretty)
{
    xmlChar * cData;
    int size;
    
    xmlDocPtr doc = docToLibXML(this);
    htmlDocDumpMemory(doc, &cData, &size);
    Data * data = Data::dataWithBytes((const char *) cData, size);
    xmlFreeDoc(doc);
    xmlFree(cData);
    return data;
}

