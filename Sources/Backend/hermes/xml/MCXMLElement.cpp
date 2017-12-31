// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "MCXMLElement.h"

using namespace mailcore;

void XMLElement::init()
{
    mAttributes = NULL;
    mChildren = NULL;
    mName = NULL;
}

XMLElement::XMLElement()
{
    init();
}

XMLElement::~XMLElement()
{
    MC_SAFE_RELEASE(mName);
    MC_SAFE_RELEASE(mChildren);
    MC_SAFE_RELEASE(mAttributes);
}

void XMLElement::setName(String * name)
{
    if (name != NULL) {
        name = name->lowercaseString();
    }
    MC_SAFE_REPLACE_COPY(String, mName, name);
}

String * XMLElement::name()
{
    return mName;
}

void XMLElement::setAttribute(String * name, String * value)
{
    if (mAttributes == NULL) {
        mAttributes = new HashMap();
    }
    mAttributes->setObjectForKey(name->lowercaseString(), value);
}

void XMLElement::removeAttribute(String * name)
{
    if (mAttributes == NULL)
        return;
    mAttributes->removeObjectForKey(name->lowercaseString());
}

Array * XMLElement::allAttributesNames()
{
    if (mAttributes == NULL)
        return Array::array();
    return mAttributes->allKeys();
}

String * XMLElement::attributeForName(String * name)
{
    if (mAttributes == NULL)
        return NULL;
    return (String *) mAttributes->objectForKey(name->lowercaseString());
}

unsigned int XMLElement::childrenCount()
{
    if (mChildren == NULL)
        return 0;
    return mChildren->count();
}

XMLNode * XMLElement::childAtIndex(unsigned int idx)
{
    if (mChildren == NULL)
        return NULL;
    return (XMLNode *) mChildren->objectAtIndex(idx);
}

void XMLElement::addChild(XMLNode * node)
{
    if (mChildren == NULL)
        mChildren = new Array();
    mChildren->addObject(node);
}

void XMLElement::removeChildAtIndex(unsigned int idx)
{
    if (mChildren == NULL)
        return;
    mChildren->removeObjectAtIndex(idx);
}

