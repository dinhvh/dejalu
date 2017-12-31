// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMEmailTemplate.h"

using namespace hermes;
using namespace mailcore;

EmailTemplate::EmailTemplate()
{
    mName = NULL;
    mTemplateString = NULL;
}

EmailTemplate::~EmailTemplate()
{
    MC_SAFE_RELEASE(mName);
    MC_SAFE_RELEASE(mTemplateString);
}

void EmailTemplate::setName(mailcore::String * name)
{
    MC_SAFE_REPLACE_COPY(String, mName, name);
}

mailcore::String * EmailTemplate::name()
{
    return mName;
}

void EmailTemplate::setTemplateString(mailcore::String * templateString)
{
    MC_SAFE_REPLACE_COPY(String, mTemplateString, templateString);
}

mailcore::String * EmailTemplate::templateString()
{
    return mTemplateString;
}

