// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "MCXMLText.h"

using namespace mailcore;

XMLText::XMLText()
{
    init();
}

XMLText::~XMLText()
{
    MC_SAFE_RELEASE(mValue);
}

void XMLText::setValue(String * value)
{
    MC_SAFE_REPLACE_COPY(String, mValue, value);
}

String * XMLText::value()
{
    return mValue;
}

void XMLText::init()
{
    mValue = NULL;
}

