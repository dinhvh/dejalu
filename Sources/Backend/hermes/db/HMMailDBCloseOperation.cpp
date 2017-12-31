// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDBCloseOperation.h"

#include "HMMailDB.h"
#include "HMMailStorage.h"

using namespace hermes;
using namespace mailcore;

MailDBCloseOperation::MailDBCloseOperation()
{
}

MailDBCloseOperation::~MailDBCloseOperation()
{
}

void MailDBCloseOperation::start()
{
    storage()->cancelViews();
    MailDBOperation::start();
}

void MailDBCloseOperation::main()
{
    syncDB()->close();
}
