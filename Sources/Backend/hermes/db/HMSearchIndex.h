// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef __dejalu__HMSearchIndex__
#define __dejalu__HMSearchIndex__

#include <MailCore/MailCore.h>
#include <kvdb/sfts.h>

#ifdef __cplusplus

namespace hermes {
    class SearchIndex : public mailcore::Object {
    public:
        SearchIndex(mailcore::String * filename);
        virtual ~SearchIndex();
        
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
        sfts * mIndex;
        mailcore::String * mFilename;
    };
};

#endif

#endif /* defined(__dejalu__HMSearchIndex__) */
