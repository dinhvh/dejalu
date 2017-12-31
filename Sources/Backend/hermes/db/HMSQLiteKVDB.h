// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef HMSQLiteKVDB_hpp
#define HMSQLiteKVDB_hpp

#include <MailCore/MailCore.h>

#ifdef __cplusplus

namespace hermes {

    class MailDB;

    class SQLiteKVDB : public mailcore::Object {
    public:
        SQLiteKVDB(MailDB * db);
        virtual ~SQLiteKVDB();

        virtual bool open();
        virtual void close();

        virtual void beginTransaction();
        virtual bool commitTransaction();
        virtual void abortTransaction();

        virtual bool setObjectForKey(mailcore::String * key, mailcore::Data * data);
        virtual mailcore::Data * objectForKey(mailcore::String * key);
        virtual bool removeObjectForKey(mailcore::String * key);

    private:
        MailDB * mDB;
    };
};

#endif

#endif /* HMSQLiteKVDB_hpp */
