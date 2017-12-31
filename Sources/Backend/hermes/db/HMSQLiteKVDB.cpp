// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMSQLiteKVDB.h"

#include "HMMailDB.h"

using namespace hermes;
using namespace mailcore;

SQLiteKVDB::SQLiteKVDB(MailDB * db)
{
    mDB = db;
    MC_SAFE_RETAIN(mDB);
}

SQLiteKVDB::~SQLiteKVDB()
{
    MC_SAFE_RELEASE(mDB);
}

bool SQLiteKVDB::open()
{
    return true;
}

void SQLiteKVDB::close()
{
}

void SQLiteKVDB::beginTransaction()
{
    // do nothing.
}

bool SQLiteKVDB::commitTransaction()
{
    // do nothing.
    return true;
}

void SQLiteKVDB::abortTransaction()
{
    // do nothing.
}

bool SQLiteKVDB::setObjectForKey(String * key, Data * data)
{
    mDB->kv_setObjectForKey(key, data);
    return true;
}

Data * SQLiteKVDB::objectForKey(String * key)
{
    return mDB->kv_objectForKey(key);
}

bool SQLiteKVDB::removeObjectForKey(String * key)
{
    mDB->kv_removeObjectForKey(key);
    return true;
}
