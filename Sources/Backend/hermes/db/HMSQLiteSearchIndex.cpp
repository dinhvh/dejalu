// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMSQLiteSearchIndex.h"

#include "HMMailDB.h"

using namespace hermes;

SQLiteSearchIndex::SQLiteSearchIndex(MailDB * db)
{
    mDB = db;
    MC_SAFE_RETAIN(mDB);
}

SQLiteSearchIndex::~SQLiteSearchIndex()
{
    MC_SAFE_RELEASE(mDB);
}

bool SQLiteSearchIndex::open()
{
    return true;
}

void SQLiteSearchIndex::close()
{
}

bool SQLiteSearchIndex::setStringForID(int64_t identifier, mailcore::String * text)
{
    mDB->index_setStringForID(identifier, text);
    return true;
}

bool SQLiteSearchIndex::setStringsForID(int64_t identifier, mailcore::Array * tokens)
{
    mDB->index_setStringsForID(identifier, tokens);
    return true;
}

bool SQLiteSearchIndex::removeID(int64_t identifier)
{
    mDB->index_removeID(identifier);
    return true;
}

mailcore::IndexSet * SQLiteSearchIndex::search(mailcore::String * searchString)
{
    return mDB->index_search(searchString);
}

void SQLiteSearchIndex::beginTransaction()
{
}

bool SQLiteSearchIndex::commitTransaction()
{
    return true;
}

void SQLiteSearchIndex::abortTransaction()
{
}
