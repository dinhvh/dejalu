// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMSearchIndex.h"

using namespace mailcore;
using namespace hermes;

#define KVDB_HAS_TRANSACTION 1

SearchIndex::SearchIndex(mailcore::String * filename)
{
    mIndex = NULL;
    mFilename = (String *) filename->copy();
}

SearchIndex::~SearchIndex()
{
    MC_SAFE_RELEASE(mFilename);
    if (mIndex != NULL) {
        sfts_free(mIndex);
        mIndex = NULL;
    }
}

bool SearchIndex::open()
{
    MCAssert(mIndex == NULL);
    mIndex = sfts_new(mFilename->fileSystemRepresentation());
    int r = sfts_open(mIndex);
    if (r < 0) {
        sfts_free(mIndex);
        mIndex = NULL;
        return false;
    }
    return true;
}

void SearchIndex::close()
{
    MCAssert(mIndex != NULL);
    sfts_close(mIndex);
    sfts_free(mIndex);
    mIndex = NULL;
}

bool SearchIndex::setStringForID(int64_t identifier, mailcore::String * text)
{
    if (text == NULL) {
        return true;
    }
    if (text->length() == 0) {
        return true;
    }
    int r = sfts_u_set(mIndex, identifier, text->unicodeCharacters());
    if (r < 0) {
        return false;
    }
    return true;
}

bool SearchIndex::setStringsForID(int64_t identifier, mailcore::Array * tokens)
{
    if (tokens == NULL) {
        return true;
    }
    if (tokens->count() == 0) {
        return true;
    }
    const UChar ** cTokens = (const UChar **) alloca(sizeof(* cTokens) * tokens->count());
    for(unsigned int i = 0 ; i < tokens->count() ; i ++) {
        cTokens[i] = ((String *) tokens->objectAtIndex(i))->unicodeCharacters();
    }
    int r = sfts_u_set2(mIndex, identifier, cTokens, tokens->count());
    if (r < 0) {
        return false;
    }
    return true;
}

bool SearchIndex::removeID(int64_t identifier)
{
    int r = sfts_remove(mIndex, identifier);
    if (r < 0) {
        return false;
    }
    return true;
}

mailcore::IndexSet * SearchIndex::search(mailcore::String * searchString)
{
    uint64_t * identifiers = NULL;
    size_t count;
    int r = sfts_u_search(mIndex, searchString->unicodeCharacters(), sfts_search_kind_prefix, &identifiers, &count);
    if (r < 0) {
        return IndexSet::indexSet();
    }
    IndexSet * result = IndexSet::indexSet();
    for(unsigned int i = 0 ; i < count ; i ++) {
        result->addIndex(identifiers[i]);
    }
    free(identifiers);
    //fprintf(stderr, "search %s -> %s\n", MCUTF8(searchString), MCUTF8DESC(result));
    return result;
}

void SearchIndex::beginTransaction()
{
#if KVDB_HAS_TRANSACTION
    sfts_transaction_begin(mIndex);
#endif
}

bool SearchIndex::commitTransaction()
{
#if KVDB_HAS_TRANSACTION
    int r = sfts_transaction_commit(mIndex);
#else
    int r = sfts_flush(mIndex);
#endif
    return r == 0;
}

void SearchIndex::abortTransaction()
{
#if KVDB_HAS_TRANSACTION
    sfts_transaction_abort(mIndex);
#endif
}


