// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMEmailTemplateManager.h"

#include "HMEmailTemplate.h"

using namespace hermes;
using namespace mailcore;

EmailTemplateManager::EmailTemplateManager()
{
    mTemplates = new Array();
}

EmailTemplateManager::~EmailTemplateManager()
{
    MC_SAFE_RELEASE(mTemplates);
}

EmailTemplateManager * EmailTemplateManager::sharedManager()
{
    static EmailTemplateManager * instance = new EmailTemplateManager();
    return instance;
}

void EmailTemplateManager::addTemplate(EmailTemplate * item)
{
    mTemplates->addObject(item);
}

void EmailTemplateManager::removeTemplateAtIndex(int idx)
{
    mTemplates->removeObjectAtIndex(idx);
}

EmailTemplate * EmailTemplateManager::templateAtIndex(int idx)
{
    return (EmailTemplate *) mTemplates->objectAtIndex(idx);
}

void EmailTemplateManager::replaceTemplateAtIndex(int idx, EmailTemplate * item)
{
    mTemplates->replaceObject(idx, item);
}

