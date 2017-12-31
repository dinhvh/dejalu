// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMSQLiteSearchIndex_hpp
#define HMSQLiteSearchIndex_hpp

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class MailDB;

    class SQLiteSearchIndex : public mailcore::Object {
    public:
        SQLiteSearchIndex(MailDB * db);
        virtual ~SQLiteSearchIndex();

        virtual bool open();
        virtual void close();

        virtual bool setStringForID(int64_t identifier, mailcore::String * text);
        virtual bool setStringsForID(int64_t identifier, mailcore::Array * tokens);
        virtual bool removeID(int64_t identifier);
        virtual mailcore::IndexSet * search(mailcore::String * searchString);

        virtual void beginTransaction();
        virtual bool commitTransaction();
        virtual void abortTransaction();

    private:
        MailDB * mDB;
    };
};

#endif

#endif /* HMSQLiteSearchIndex_hpp */
