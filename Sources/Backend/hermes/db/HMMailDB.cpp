// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMMailDB.h"

#include "HMSQLiteKVDB.h"
#include "HMSQLiteSearchIndex.h"
#include "MCXMLDocument.h"
#include "MCXMLElement.h"
#include "MCXMLNode.h"
#include "MCXMLText.h"
#include "HMMailDBChanges.h"
#include "HMMailDBLocalMessagesChanges.h"
#include "HMEndian.h"
#include "DJLLog.h"
#include "HMUtils.h"
#include "HMSerialization.h"
#import "DJLLog.h"

#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/dir.h>
#include <dirent.h>

using namespace hermes;
using namespace mailcore;

#define LOG_SEARCH(...) DJLLogWithID("search", __VA_ARGS__)

static Array * s_notificationHeaders = NULL;
static Array * s_headersToFetch = NULL;
static HashMap * s_senderMapping = NULL;
static HashMap * s_senderSuffixMapping = NULL;
static Array * s_listIDSuffixWhitelist = NULL;
static HashMap * s_dateFormatterWithFormatString = NULL;
static HashMap * s_dateFormatterWithStyle = NULL;
static pthread_mutex_t s_dateFormatterLock = PTHREAD_MUTEX_INITIALIZER;

#define DBVERSION 12
#define DISABLE_PEOPLEVIEW 1

__attribute__((constructor))
static void initialize()
{
    s_notificationHeaders = new Array();
    s_notificationHeaders->addObject(MCSTR("List-ID"));
    s_notificationHeaders->addObject(MCSTR("X-MEETUP-RECIP-ID"));
    s_notificationHeaders->addObject(MCSTR("List-Unsubscribe"));
    s_notificationHeaders->addObject(MCSTR("X-Facebook"));
    s_notificationHeaders->addObject(MCSTR("X-SES-Outgoing"));
    s_notificationHeaders->addObject(MCSTR("X-Roving-ID"));
    s_notificationHeaders->addObject(MCSTR("X-DynectEmail-Msg-Key"));
    s_notificationHeaders->addObject(MCSTR("X-EMV-MemberId"));
    s_notificationHeaders->addObject(MCSTR("X-ICPINFO"));
    s_notificationHeaders->addObject(MCSTR("X-MC-User"));
    s_notificationHeaders->addObject(MCSTR("X-Mailgun-Sid"));
    s_notificationHeaders->addObject(MCSTR("X-Mandrill-User"));
    s_notificationHeaders->addObject(MCSTR("X-MarketoID"));
    s_notificationHeaders->addObject(MCSTR("X-PM-Message-Id"));
    s_notificationHeaders->addObject(MCSTR("X-rext"));
    s_notificationHeaders->addObject(MCSTR("X-SFDC-User"));
    s_notificationHeaders->addObject(MCSTR("X-SG-EID"));
    s_notificationHeaders->addObject(MCSTR("X-SMTPCOM-Tracking-Number"));
    s_notificationHeaders->addObject(MCSTR("X-LinkedIn-Id"));

    s_headersToFetch = new Array();
    s_headersToFetch->addObjectsFromArray(s_notificationHeaders);
    s_headersToFetch->addObject(MCSTR("X-Mailer"));
    s_headersToFetch->addObject(MCSTR("X-DejaLu-Reply"));

    s_senderMapping = new HashMap();
    s_senderMapping->setObjectForKey(MCSTR("hit-reply@linkedin.com"), MCSTR("Linkedin"));
    s_senderMapping->setObjectForKey(MCSTR("member@linkedin.com"), MCSTR("Linkedin"));
    s_senderMapping->setObjectForKey(MCSTR("notify@twitter.com"), MCSTR("Twitter"));
    s_senderMapping->setObjectForKey(MCSTR("auto-confirm@amazon.com"), MCSTR("Amazon"));
    s_senderMapping->setObjectForKey(MCSTR("notifications@basecamp.com"), MCSTR("Basecamp"));
    s_senderMapping->setObjectForKey(MCSTR("noreply@messaging.squareup.com"), MCSTR("Square"));
    s_senderMapping->setObjectForKey(MCSTR("alerts@citibank.com"), MCSTR("Citibank"));
    s_senderMapping->setObjectForKey(MCSTR("no-reply@email.zillow.com"), MCSTR("Zillow"));
    s_senderMapping->setObjectForKey(MCSTR("alerts@notify.wellsfargo.com"), MCSTR("Wells Fargo"));
    s_senderMapping->setObjectForKey(MCSTR("alerts@notify.wellsfargoadvisors.com"), MCSTR("Wells Fargo"));
    s_senderMapping->setObjectForKey(MCSTR("do_not_reply@itunes.com"), MCSTR("iTunes Store"));
    s_senderMapping->setObjectForKey(MCSTR("customerserviceonline@pge.com"), MCSTR("PG&E"));
    s_senderMapping->setObjectForKey(MCSTR("support@github.com"), MCSTR("GitHub"));
    s_senderMapping->setObjectForKey(MCSTR("do-not-reply@stackexchange.com"), MCSTR("Stack Exchange"));
    s_senderMapping->setObjectForKey(MCSTR("calendar-notification@google.com"), MCSTR("Google Calendar"));
    s_senderMapping->setObjectForKey(MCSTR("trackingupdates@fedex.com"), MCSTR("Fedex"));
    s_senderMapping->setObjectForKey(MCSTR("paper@reply.dropboxmail.com"), MCSTR("Dropbox Paper"));
    s_senderMapping->setObjectForKey(MCSTR("paper@dropbox.com"), MCSTR("Dropbox Paper"));
    s_senderMapping->setObjectForKey(MCSTR("auto-reply@usps.com"), MCSTR("USPS"));
    s_senderMapping->setObjectForKey(MCSTR("uspsinformeddelivery@usps.gov"), MCSTR("USPS"));
    s_senderMapping->setObjectForKey(MCSTR("costco@online.costco.com"), MCSTR("Costco"));
    s_senderMapping->setObjectForKey(MCSTR("schwabalerts.myportfolio@schwab.com"), MCSTR("Schwab"));
    s_senderMapping->setObjectForKey(MCSTR("donotreply-comm@schwab.com"), MCSTR("Schwab"));
    s_senderMapping->setObjectForKey(MCSTR("SchwabStockPlanServices@schwab.com"), MCSTR("Schwab"));
    s_senderMapping->setObjectForKey(MCSTR("mcinfo@ups.com"), MCSTR("UPS"));
    s_senderMapping->setObjectForKey(MCSTR("uber.us@uber.com"), MCSTR("Uber"));
    s_senderMapping->setObjectForKey(MCSTR("service@paypal.com"), MCSTR("Paypal"));

    s_senderSuffixMapping = new HashMap();
    s_senderSuffixMapping->setObjectForKey(MCSTR("-noreply@google.com"), MCSTR("Google"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("-noreply@linkedin.com"), MCSTR("Linkedin"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@plus.google.com"), MCSTR("Google"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@emaildl.att-mail.com"), MCSTR("AT&T"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@ordertrack.wireless.att-mail.com"), MCSTR("AT&T"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@emailff.att-mail.com"), MCSTR("AT&T"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@alerts.comcast.net"), MCSTR("Comcast"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@newsletter.voyages-sncf.com"), MCSTR("SNCF"));
    s_senderSuffixMapping->setObjectForKey(MCSTR("@facebookmail.com"), MCSTR("Facebook"));

    s_listIDSuffixWhitelist = new Array();
    s_listIDSuffixWhitelist->addObject(MCSTR(".googlegroups.com"));
    s_listIDSuffixWhitelist->addObject(MCSTR(".github.com"));

    s_dateFormatterWithFormatString = new HashMap();
    s_dateFormatterWithStyle = new HashMap();
}

static DateFormatter * dateFormatterWithStyle(DateFormatStyle dateStyle, DateFormatStyle timeStyle)
{
    String * format = String::stringWithUTF8Format("%i/%i", dateStyle, timeStyle);
    pthread_mutex_lock(&s_dateFormatterLock);
    DateFormatter * formatter = (DateFormatter * ) s_dateFormatterWithStyle->objectForKey(format);
    if (formatter == NULL) {
        formatter = new DateFormatter();
        formatter->setTimeStyle(timeStyle);
        formatter->setDateStyle(dateStyle);
        formatter->prepare();
        s_dateFormatterWithStyle->setObjectForKey(format, formatter);
        formatter->release();
    }
    pthread_mutex_unlock(&s_dateFormatterLock);
    return formatter;
}

static DateFormatter * dateFormatterWithFormatString(String * format)
{
    pthread_mutex_lock(&s_dateFormatterLock);
    DateFormatter * formatter = (DateFormatter *) s_dateFormatterWithFormatString->objectForKey(format);
    if (formatter == NULL) {
        formatter = new DateFormatter();
        formatter->setDateFormat(format);
        formatter->prepare();
        s_dateFormatterWithFormatString->setObjectForKey(format, formatter);
        formatter->release();
    }
    pthread_mutex_unlock(&s_dateFormatterLock);
    return formatter;
}

static bool isImageAttachment(AbstractPart * part)
{
    static Set * supportedImageTypes = NULL;
    if (supportedImageTypes == NULL) {
        supportedImageTypes = new Set();
        supportedImageTypes->addObject(MCSTR("image/png"));
        supportedImageTypes->addObject(MCSTR("image/gif"));
        supportedImageTypes->addObject(MCSTR("image/jpg"));
        supportedImageTypes->addObject(MCSTR("image/jpeg"));
        supportedImageTypes->addObject(MCSTR("image/tiff"));
        supportedImageTypes->addObject(MCSTR("image/tif"));
        supportedImageTypes->addObject(MCSTR("image/pdf"));
        supportedImageTypes->addObject(MCSTR("application/pdf"));
    }
    static Set * supportedImageExtensions = NULL;
    if (supportedImageExtensions == NULL) {
        supportedImageExtensions = new Set();
        supportedImageExtensions->addObject(MCSTR("png"));
        supportedImageExtensions->addObject(MCSTR("gif"));
        supportedImageExtensions->addObject(MCSTR("jpg"));
        supportedImageExtensions->addObject(MCSTR("jpeg"));
        supportedImageExtensions->addObject(MCSTR("pdf"));
        supportedImageExtensions->addObject(MCSTR("tiff"));
        supportedImageExtensions->addObject(MCSTR("tif"));
    }

    if (part->mimeType() != NULL) {
        if (supportedImageTypes->containsObject(part->mimeType()->lowercaseString())) {
            return true;
        }
    }
    String * ext = NULL;
    if (part->filename() != NULL) {
        ext = part->filename()->pathExtension();
        if (ext != NULL) {
            ext = ext->lowercaseString();
            if (supportedImageExtensions->containsObject(ext)) {
                return true;
            }
        }
    }

    return false;
}

static void findImagesInXML(XMLElement * element, Array * result);

static bool isHTMLEmpty(String * html)
{
    Array * images = Array::array();
    html = HTMLCleaner::cleanHTML(html);
    XMLDocument * doc = XMLDocument::documentWithHTMLData(html->dataUsingEncoding());
    findImagesInXML(doc->root(), images);
    if (images->count() > 0) {
        return false;
    }
    String * result = html->flattenHTML()->stripWhitespace();
    if (result->length() > 0) {
        return false;
    }
    return true;
}

namespace hermes {
    class AttachmentRendererHelper : public Object,
    public HTMLRendererTemplateCallback,
    public HTMLRendererIMAPCallback,
    public HTMLRendererRFC822Callback {
    public:
        AttachmentRendererHelper(bool renderImageEnabled)
        {
            mDB = NULL;
            mMessageRowID = -1;
            mRequiredParts = new Array();
            mRenderImageEnabled = renderImageEnabled;
            mMixedTextAndAttachmentsModeEnabled = false;
        }

        virtual ~AttachmentRendererHelper()
        {
            MC_SAFE_RELEASE(mRequiredParts);
            MC_SAFE_RELEASE(mDB);
        }

        virtual void setDB(MailDB * db)
        {
            MC_SAFE_REPLACE_RETAIN(MailDB, mDB, db);
        }

        virtual MailDB * db()
        {
            return mDB;
        }

        virtual void setMessageRowID(int64_t rowID)
        {
            mMessageRowID = rowID;
        }

        virtual int64_t messageRowID()
        {
            return mMessageRowID;
        }

        virtual void setMixedTextAndAttachmentsModeEnabled(bool enabled)
        {
            mMixedTextAndAttachmentsModeEnabled = enabled;
        }

        virtual bool isMixedTextAndAttachmentsModeEnabled()
        {
            return mMixedTextAndAttachmentsModeEnabled;
        }

        virtual bool canPreviewPart(AbstractPart * part)
        {
            if (!mRenderImageEnabled) {
                return false;
            }

            return isImageAttachment(part);
        }

        virtual String * templateForMainHeader(MessageHeader * header)
        {
            return String::string();
        }

        virtual String * templateForImage(AbstractPart * part)
        {
            if (!mMixedTextAndAttachmentsModeEnabled) {
                return MCSTR("");
            }
            String * content = MCSTR("<img src=\"{{URL}}\" x-dejalu-filename=\"{{FILENAME}}\" x-dejalu-unique-id=\"{{UNIQUEID}}\" class=\"-dejalu-image -dejalu-image-attachment\"/>");
            return content;
        }

        virtual HashMap * templateValuesForPart(AbstractPart * part)
        {
            HashMap * result = HTMLRendererTemplateCallback::templateValuesForPart(part);
            mailcore::String * filename = NULL;
            if (part->filename() != NULL) {
                filename = part->filename()->lastPathComponent();
            }
            if (filename != NULL) {
                result->setObjectForKey(MCSTR("FILENAMEEXT"), filename->pathExtension()->htmlEncodedString());
            }
            return result;
        }

        virtual String * templateForAttachment(AbstractPart * part)
        {
            if (!mRenderImageEnabled) {
                return MCSTR("");
            }
            if (!mMixedTextAndAttachmentsModeEnabled) {
                return MCSTR("");
            }
            String * content = MCSTR("<img src=\"x-dejalu-icon:{{FILENAMEEXT}}\" x-dejalu-filename=\"{{FILENAME}}\" x-dejalu-unique-id=\"{{UNIQUEID}}\" class=\"-dejalu-attachment\"/>");
            return content;
        }

        virtual String * templateForAttachmentSeparator()
        {
            if (!mMixedTextAndAttachmentsModeEnabled) {
                return MCSTR("");
            }
            return MCSTR("<div style=\"padding-bottom: 20px;\"></div>");
        }

        virtual String * templateForMessage(AbstractMessage * message)
        {
            if (mMixedTextAndAttachmentsModeEnabled) {
                return MCSTR("<div class=\"-dejalu-mixed-text-and-attachments\">{{BODY}}</div>");
            }
            else {
                return MCSTR("<div>{{BODY}}</div>");
            }
        }

        virtual String * filterHTMLForPart(String * html)
        {
            if (isHTMLEmpty(html)) {
                return MCSTR("");
            }

            String * result = String::string();
            result->appendString(MCSTR("<div class=\"-dejalu-needs-html-filter -dejalu-text-part\">"));
            result->appendString(html);
            result->appendString(MCSTR("</div>"));
            return result;
        }

        virtual mailcore::String * cleanHTMLForPart(mailcore::String * html)
        {
            return html;
        }

        virtual Data * dataForIMAPPart(String * folder, IMAPPart * part)
        {
            Data * result = mDB->retrieveDataForPart(mMessageRowID, part->partID());
            if (result == NULL) {
                mRequiredParts->addObject(part);
            }
            return result;
        }

        virtual Data * dataForRFC822Part(String * folder, Attachment * part)
        {
            Data * result = mDB->retrieveDataForPart(mMessageRowID, part->partID());
            if (result == NULL) {
                mRequiredParts->addObject(part);
            }
            return result;
        }

        virtual Array * requiredParts()
        {
            return mRequiredParts;
        }

        MailDB * mDB;
        int64_t mMessageRowID;
        Array * mRequiredParts;
        bool mRenderImageEnabled;
        bool mMixedTextAndAttachmentsModeEnabled;
    };

    class SummaryHelper : public Object,
    public HTMLRendererTemplateCallback,
    public HTMLRendererIMAPCallback,
    public HTMLRendererRFC822Callback {
    public:
        SummaryHelper()
        {
            mDB = NULL;
            mMessageRowID = -1;
            mRequiredParts = new Array();
        }
        
        virtual ~SummaryHelper()
        {
            MC_SAFE_RELEASE(mRequiredParts);
            MC_SAFE_RELEASE(mDB);
        }
        
        virtual void setDB(MailDB * db)
        {
            MC_SAFE_REPLACE_RETAIN(MailDB, mDB, db);
        }
        
        virtual MailDB * db()
        {
            return mDB;
        }
        
        virtual void setMessageRowID(int64_t rowID)
        {
            mMessageRowID = rowID;
        }
        
        virtual int64_t messageRowID()
        {
            return mMessageRowID;
        }
        
        virtual String * templateForMainHeader(MessageHeader * header)
        {
            return String::string();
        }

        virtual String * templateForImage(AbstractPart * part)
        {
            return String::string();
        }

        virtual String * templateForAttachment(AbstractPart * part)
        {
            return MCSTR("{{#HASSIZE}}\
                         {{#HASFILENAME}}\
                         <div>- {{FILENAME}}, {{SIZE}}</div>\
                         {{/HASFILENAME}}\
                         {{#NOFILENAME}}\
                         <div>- Untitled, {{SIZE}}</div>\
                         {{/NOFILENAME}}\
                         {{/HASSIZE}}\
                         {{#NOSIZE}}\
                         {{#HASFILENAME}}\
                         <div>- {{FILENAME}}</div>\
                         {{/HASFILENAME}}\
                         {{#NOFILENAME}}\
                         <div>- Untitled</div>\
                         {{/NOFILENAME}}\
                         {{/NOSIZE}}\
                         ");
        }

        virtual String * templateForAttachmentSeparator()
        {
            return String::string();
        }
        
        virtual Data * dataForIMAPPart(String * folder, IMAPPart * part)
        {
            Data * result = mDB->retrieveDataForPart(mMessageRowID, part->partID());
            if (result == NULL) {
                mRequiredParts->addObject(part);
            }
            return result;
        }
        
        virtual mailcore::String * cleanHTMLForPart(mailcore::String * html)
        {
            return html;
        }

        virtual Array * requiredParts()
        {
            return mRequiredParts;
        }
        
        virtual Data * dataForRFC822Part(String * folder, Attachment * part)
        {
            Data * data = mDB->retrieveDataForPart(mMessageRowID, part->partID());
            return data;
        }

        MailDB * mDB;
        int64_t mMessageRowID;
        Array * mRequiredParts;
    };
}

MailDB::MailDB()
{
    mSqlite = NULL;
    mPath = NULL;
    mKVDB = NULL;
    mStatementsCache = new HashMap();
    mCreatedRawMessageFolder = false;
    mDebugLastLogDate = (time_t) -1;
    mSerializedMessageCache = new HashMap();
}

MailDB::~MailDB()
{
    MC_SAFE_RELEASE(mSerializedMessageCache);
    MC_SAFE_RELEASE(mStatementsCache);
    MCAssert(mSqlite == NULL);
    MCAssert(mKVDB == NULL);
    MCAssert(mIndex == NULL);
    MC_SAFE_RELEASE(mPath);
}

void MailDB::setPath(String * path)
{
    MC_SAFE_REPLACE_COPY(String, mPath, path);
}

mailcore::String * MailDB::path()
{
    return mPath;
}

void MailDB::sqliteExecuteStatement(const char * statement)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare(statement, &stmt);
    if (r != SQLITE_OK) {
        fprintf(stderr, "failed preparing SQL: %s\n", statement);
        fprintf(stderr, "error: %s\n", sqlite3_errmsg(mSqlite));
        return;
    }
    r = sqlite3_step(stmt);
    if (r != SQLITE_DONE) {
        fprintf(stderr, "failed executing SQL: %s\n", statement);
        if (sqlite3_errmsg(mSqlite) != NULL) {
            if (strstr(sqlite3_errmsg(mSqlite), "cannot start a transaction within a transaction") != NULL) {
                abort();
            }
        }
        fprintf(stderr, "error: %s\n", sqlite3_errmsg(mSqlite));
        return;
    }
    sqliteReset(stmt);
}

int MailDB::sqlitePrepare(const char * statement, sqlite3_stmt ** p_stmt)
{
    int r;
    sqlite3_stmt * stmt = NULL;
    String * statementString = String::stringWithUTF8Characters(statement);
    Value * vStmt = (Value *) mStatementsCache->objectForKey(statementString);
    if (vStmt != NULL) {
        * p_stmt = (sqlite3_stmt *) vStmt->pointerValue();
        return SQLITE_OK;
    }

    r = sqlite3_prepare_v2(mSqlite, statement, -1, &stmt, NULL);
    if (r != SQLITE_OK) {
        fprintf(stderr, "failed preparing SQL: %s\n", statement);
        fprintf(stderr, "error: %s\n", sqlite3_errmsg(mSqlite));
        * p_stmt = stmt;
        return r;
    }
    mStatementsCache->setObjectForKey(statementString, Value::valueWithPointerValue(stmt));
    * p_stmt = stmt;

    return SQLITE_OK;
}

void MailDB::sqliteReset(sqlite3_stmt * stmt)
{
    sqlite3_reset(stmt);
}

bool MailDB::isMetaValid()
{
    String * filename = mPath->stringByAppendingPathComponent(MCSTR("meta.json"));
    Data * data = Data::dataWithContentsOfFile(filename);
    if (data == NULL) {
        return false;
    }
    HashMap * info = (HashMap *) JSON::objectFromJSONData(data);
    Value * version = (Value *) info->objectForKey(MCSTR("version"));
    if (version->intValue() != DBVERSION) {
        return false;
    }

    return true;
}

void MailDB::resetDB()
{
    String * filename = NULL;
    filename = mPath->stringByAppendingPathComponent(MCSTR("meta.json"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.kvdb"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.kvdb.journal"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.index"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.index.journal"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.sqlite"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("addresses-meta.json"));
    hermes::removeFile(filename);
    filename = mPath->stringByAppendingPathComponent(MCSTR("addresses.json"));
    hermes::removeFile(filename);
    // Don't remove Queue and RawMessage since it could lead to data loss.
}

void MailDB::open()
{
    int r;
    bool dbHasBeenReset = false;
    int tryCount = 0;

retry:

    if (tryCount >= 2) {
        resetDB();
        MCAssert(0);
    }

    tryCount ++;

    if (!isMetaValid()) {
        // reset DB.
        resetDB();
        dbHasBeenReset = true;
    }
    
    mkdir(mPath->fileSystemRepresentation(), 0700);

    String * filename = NULL;
    struct stat statinfo;
    filename = mPath->stringByAppendingPathComponent(MCSTR("meta.json"));
    r = stat(filename->fileSystemRepresentation(), &statinfo);
    if (r < 0) {
        HashMap * info = new HashMap();
        info->setObjectForKey(MCSTR("version"), Value::valueWithIntValue(DBVERSION));
        Data * data = JSON::objectToJSONData(info);
        data->writeToFile(filename);
        MC_SAFE_RELEASE(info);
    }

    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.kvdb"));
    mKVDB = new SQLiteKVDB(this);
    if (!mKVDB->open()) {
        resetDB();
        goto retry;
    }

    filename = mPath->stringByAppendingPathComponent(MCSTR("messages.index"));
    mIndex = new SQLiteSearchIndex(this);
    if (!mIndex->open()) {
        resetDB();
        goto retry;
    }

    String * sqliteFilename = mPath->stringByAppendingPathComponent(MCSTR("messages.sqlite"));
    r = sqlite3_open(sqliteFilename->fileSystemRepresentation(), &mSqlite);
    if (r != SQLITE_OK) {
        resetDB();
        goto retry;
    }

    if (dbHasBeenReset) {
        sqliteExecuteStatement("create table folder(rowid INTEGER PRIMARY KEY AUTOINCREMENT, path text, count number, unread number, starred number, uidvalidity number, lastuid number, lastseenuid number, firstsyncdone number)");

        sqliteExecuteStatement("create table message(rowid INTEGER PRIMARY KEY AUTOINCREMENT, uid number, msgid text, folderid number, date number, convid number, peopleviewid number, original_messageid number, deleted number, starred number, unread number, fetched number, moving number, filename text, attachments_count number, attachment_filename text)");
        sqliteExecuteStatement("create index message_uid on message(uid)");
        sqliteExecuteStatement("create index message_convid on message(convid)");
        sqliteExecuteStatement("create index message_date on message(date)");
        sqliteExecuteStatement("create index message_peopleviewid on message(peopleviewid)");
        sqliteExecuteStatement("create index message_msgid on message(msgid)");

        sqliteExecuteStatement("create table conversation(rowid INTEGER PRIMARY KEY AUTOINCREMENT, recipientmd5 text)");
        sqliteExecuteStatement("create index conversation_recipientmd5 on conversation(recipientmd5)");

        sqliteExecuteStatement("create table peopleview(rowid INTEGER PRIMARY KEY AUTOINCREMENT, recipientmd5 text, date number, starred number, unread number, hasattachment number)");
        sqliteExecuteStatement("create index peopleview_recipientmd5 on peopleview(recipientmd5)");
        sqliteExecuteStatement("create index peopleview_date on peopleview(date)");

        sqliteExecuteStatement("create table peopleviewfolder(peopleviewid number, folderid number, count number)");
        sqliteExecuteStatement("create index peopleviewfolder_peopleviewid on peopleviewfolder(peopleviewid)");

        sqliteExecuteStatement("create table message_local_changes(rowid INTEGER PRIMARY KEY AUTOINCREMENT, messageid number, uid number, folderid number, deleted number, starred number, unread number, addedlabel text, removedlabel text)");

        sqliteExecuteStatement("create table message_copy(original_uid number, original_messageid number, original_folderid, messageid number, folderid number, delete_original number)");

        // use rowid to push in order
        // pushdate is used for expiration: we should remove this message when a sync happened
        //
        // push state:
        //    - 0 no need for push
        //    - 1 need push
        //    - 2 pushed
        sqliteExecuteStatement("create table local_message(messageid number, msgid text, folderid number, pushstate number, pushdate number, date number)");

        // purge state:
        //    - 0 still in draft
        //    - 1 moved to trash
        //    - 2 purged
        sqliteExecuteStatement("create table drafts_message_purge(messageid number, trashuid number, purgestate number)");
        
        sqliteExecuteStatement("create table drafts_message_purge_by_msgid(msgid text, folderid number)");

        // kvdb
        sqliteExecuteStatement("create table kvdb(key text, value blob)");
        sqliteExecuteStatement("create index kvdb_key on kvdb(key)");

        // indexing
        sqliteExecuteStatement("create virtual table search_index using fts4(content="", text)");
    }
}

void MailDB::close()
{
    sqlite3_close(mSqlite);
    mSqlite = NULL;
    mKVDB->close();
    MC_SAFE_RELEASE(mKVDB);
    mIndex->close();
    MC_SAFE_RELEASE(mIndex);
}

void MailDB::sqliteBeginTransaction()
{
    sqliteExecuteStatement("begin");
}

void MailDB::sqliteCommitTransaction()
{
    sqliteExecuteStatement("commit");
}

void MailDB::kv_setObjectForKey(mailcore::String * key, mailcore::Data * data)
{
    int r;
    sqlite3_stmt * stmt;

    kv_removeObjectForKey(key);
    r = sqlitePrepare("insert into kvdb (key, value) values (?, ?)", &stmt);
    sqlite3_bind_text16(stmt, 1, key->unicodeCharacters(), -1, SQLITE_STATIC);
    sqlite3_bind_blob(stmt, 2, data->bytes(), data->length(), SQLITE_STATIC);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

mailcore::Data * MailDB::kv_objectForKey(mailcore::String * key)
{
    int r;
    sqlite3_stmt * stmt;
    Data * result = NULL;

    r = sqlitePrepare("select value from kvdb where key = ?", &stmt);
    sqlite3_bind_text16(stmt, 1, key->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            const void * bytes = sqlite3_column_blob(stmt, 0);
            int length = sqlite3_column_bytes(stmt, 0);
            result = Data::dataWithBytes((const char *) bytes, length);
        }
    }
    sqliteReset(stmt);

    return result;
}

void MailDB::kv_removeObjectForKey(mailcore::String * key)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("delete from kvdb where key = ?", &stmt);
    sqlite3_bind_text16(stmt, 1, key->unicodeCharacters(), -1, SQLITE_STATIC);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

#warning declaration of kv_transliterate()
extern "C" {
    char * kv_transliterate(const UChar * text, int length);
}

void MailDB::index_setStringForID(int64_t identifier, mailcore::String * text)
{
    String * transliteratedResult = String::string();
    const UChar * unichars = text->unicodeCharacters();
    unsigned int len = text->length();
    CFStringRef str = CFStringCreateWithBytes(NULL, (const UInt8 *) unichars, len * sizeof(* unichars), kCFStringEncodingUTF16LE, false);
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(NULL, str, CFRangeMake(0, len), kCFStringTokenizerUnitWord, NULL);
    while (1) {
        CFStringTokenizerTokenType wordKind = CFStringTokenizerAdvanceToNextToken(tokenizer);
        if (wordKind == kCFStringTokenizerTokenNone) {
            break;
        }
        if (wordKind == kCFStringTokenizerTokenHasNonLettersMask) {
            continue;
        }
        CFRange range = CFStringTokenizerGetCurrentTokenRange(tokenizer);
        char * transliterated = kv_transliterate(&unichars[range.location], (int) range.length);
        if (transliterated == NULL) {
            continue;
        }
        if (* transliterated == 0) {
            free(transliterated);
            continue;
        }
        if (transliteratedResult->length() > 0) {
            transliteratedResult->appendUTF8Characters(" ");
        }
        transliteratedResult->appendUTF8Characters(transliterated);
        free(transliterated);
    }
    CFRelease(str);
    CFRelease(tokenizer);

    index_setTransformedStringForID(identifier, transliteratedResult);
}

void MailDB::index_setStringsForID(int64_t identifier, mailcore::Array * tokens)
{
    String * transliteratedResult = String::string();
    mc_foreacharray(String, token, tokens) {
        char * transliterated = kv_transliterate(token->unicodeCharacters(), token->length());
        if (transliterated == NULL) {
            continue;
        }
        if (* transliterated == 0) {
            free(transliterated);
            continue;
        }
        if (transliteratedResult->length() > 0) {
            transliteratedResult->appendUTF8Characters(" ");
        }
        transliteratedResult->appendUTF8Characters(transliterated);
        free(transliterated);
    }
    index_setTransformedStringForID(identifier, transliteratedResult);
}

void MailDB::index_setTransformedStringForID(int64_t identifier, mailcore::String * text)
{
    int r;
    sqlite3_stmt * stmt;

    //fprintf(stderr, "index %i: %s\n", identifier, MCUTF8(text));
    r = sqlitePrepare("insert into search_index (docid, text) values (?, ?)", &stmt);
    sqlite3_bind_int64(stmt, 1, identifier);
    sqlite3_bind_text16(stmt, 2, text->unicodeCharacters(), -1, SQLITE_STATIC);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::index_removeID(int64_t identifier)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("delete from search_index where docid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, identifier);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

mailcore::IndexSet * MailDB::index_search(mailcore::String * searchString)
{
    int r;
    sqlite3_stmt * stmt;
    IndexSet * result = IndexSet::indexSet();

#if 0
    r = sqlitePrepare("select docid from search_index where text match ?", &stmt);
    String * searchStringPrefix = (String *) searchString->copy()->autorelease();
    searchStringPrefix->appendString(MCSTR("*"));
    sqlite3_bind_text16(stmt, 1, searchStringPrefix->unicodeCharacters(), searchStringPrefix->length(), SQLITE_STATIC);
    fprintf(stderr, "matching %s %s\n", MCUTF8(searchStringPrefix), MCUTF8(searchString));
#endif

    String * searchStringPrefix = (String *) searchString->copy()->autorelease();
    searchStringPrefix->replaceOccurrencesOfString(MCSTR("'"), MCSTR("''"));
    searchStringPrefix->appendString(MCSTR("*"));
    String * sqlString = String::stringWithUTF8Format("select docid from search_index where text match ?", searchString->UTF8Characters());
    r = sqlitePrepare(sqlString->UTF8Characters(), &stmt);
    sqlite3_bind_text16(stmt, 1, searchString->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t docid = sqlite3_column_int64(stmt, 0);
            result->addIndex(docid);
        } while (1);
    }
    sqliteReset(stmt);

    //fprintf(stderr, "search: %s\n", MCUTF8(result));

    return result;
}

int64_t MailDB::sqliteAddMessage(uint32_t uid, String * msgid, uint64_t folderID, time_t date,
                                 MessageFlag flags, String * filename,
                                 int attachments_count,
                                 String * attachment_filename,
                                 bool notificationEnabled,
                                 MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("insert into message (uid, msgid, folderid, date, unread, starred, deleted, fetched, convid, peopleviewid, filename, original_messageid, attachments_count, attachment_filename) values (?, ?, ?, ?, ?, ?, ?, 0, -1, -1, ?, -1, ?, ?)", &stmt);
    sqlite3_bind_int64(stmt, 1, uid);
    sqlite3_bind_text16(stmt, 2, msgid->unicodeCharacters(), -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 3, folderID);
    sqlite3_bind_int64(stmt, 4, date);
    sqlite3_bind_int(stmt, 5, !(flags & MessageFlagSeen));
    sqlite3_bind_int(stmt, 6, flags & MessageFlagFlagged);
    sqlite3_bind_int(stmt, 7, flags & MessageFlagDeleted);
    if (filename != NULL) {
        sqlite3_bind_text16(stmt, 8, filename->unicodeCharacters(), -1, SQLITE_STATIC);
    }
    else {
        sqlite3_bind_null(stmt, 8);
    }
    sqlite3_bind_int(stmt, 9, attachments_count);
    if (attachment_filename != NULL) {
        sqlite3_bind_text16(stmt, 10, attachment_filename->unicodeCharacters(), -1, SQLITE_STATIC);
    }
    else {
        sqlite3_bind_null(stmt, 10);
    }
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    int64_t rowid = sqlite3_last_insert_rowid(mSqlite);

    if ((flags & MessageFlagSeen) == 0) {
        if (storeLastUIDForFolder(folderID, uid)) {
            changes->setFolderUnseen(folderID);

            if (notificationEnabled) {
                changes->notifyMessage(folderID, rowid);
            }
        }
    }

    return rowid;
}

int64_t MailDB::sqliteAddConversation()
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("insert into conversation default values", &stmt);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    return sqlite3_last_insert_rowid(mSqlite);
}

void MailDB::sqliteChangeConversationRecipientMD5(int64_t conversationRowID, String * md5)
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("update conversation set recipientmd5 = ? where rowid = ?", &stmt);
    if (md5 == NULL) {
        sqlite3_bind_null(stmt, 1);
    }
    else {
        sqlite3_bind_text16(stmt, 1, md5->unicodeCharacters(), -1, SQLITE_STATIC);
    }
    sqlite3_bind_int64(stmt, 2, conversationRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::sqliteChangeConversationIDForMessageWithRowID(int64_t messageRowID,
                                                           int64_t conversationRowID)
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("update message set convid = ? where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, conversationRowID);
    sqlite3_bind_int64(stmt, 2, messageRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::sqliteChangeConversationIDForMessagesWithConversationID(int64_t oldConversationRowID,
                                                                     int64_t conversationRowID)
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("update message set convid = ? where convid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, conversationRowID);
    sqlite3_bind_int64(stmt, 2, oldConversationRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::sqliteChangePeopleViewIDForMessagesWithConversationID(int64_t conversationRowID,
                                                                   int64_t peopleViewID,
                                                                   MailDBChanges * changes,
                                                                   int64_t peopleViewDate,
                                                                   bool peopleHasAttachment,
                                                                   int64_t draftsFolderID)
{
    int r;
    sqlite3_stmt * stmt;
    Array * foldersIDs = new Array();
    Set * peopleViewIDs = new Set();
    int64_t maxDate = peopleViewDate;
    int64_t maxDateWithDrafts = peopleViewDate;
    bool hasAttachment = false;
    
    // get all old peopleviewid, check if there's still valid
    Array * foldersToRemovePeopleViewIDs = new Array();
    Array * foldersToRemoveFolderIDs = new Array();
    Array * messageRowIDs = new Array();
    r = sqlitePrepare("select peopleviewid, date, folderid, attachments_count from message where convid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, conversationRowID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t peopleViewRowID = sqlite3_column_int64(stmt, 0);
            if (peopleViewRowID != -1) {
                peopleViewIDs->addObject(Value::valueWithLongLongValue(peopleViewRowID));
            }
            int64_t date = sqlite3_column_int64(stmt, 1);
            int64_t folderID = sqlite3_column_int64(stmt, 2);
            if (date > maxDate) {
                if (folderID != draftsFolderID) {
                    maxDate = date;
                }
                else {
                    maxDateWithDrafts = date;
                }
            }
            foldersIDs->addObject(Value::valueWithLongLongValue(folderID));
            
            if (peopleViewRowID != -1) {
                foldersToRemovePeopleViewIDs->addObject(Value::valueWithLongLongValue(peopleViewRowID));
                foldersToRemoveFolderIDs->addObject(Value::valueWithLongLongValue(folderID));
            }

            if (sqlite3_column_int(stmt, 3) > 0) {
                hasAttachment = true;
            }
        } while (1);
    }
    sqliteReset(stmt);

    if (maxDate == -1) {
        maxDate = maxDateWithDrafts;
    }

    hasAttachment = hasAttachment || peopleHasAttachment;

    mc_foreacharray(Value, vRowID, messageRowIDs) {
        searchMetaUpdate(vRowID->longLongValue(), peopleViewID);
    }
    
    for(unsigned int i = 0 ; i < foldersToRemoveFolderIDs->count() ; i ++) {
        Value * vFolderID = (Value *) foldersToRemoveFolderIDs->objectAtIndex(i);
        Value * vPeopleViewID = (Value *) foldersToRemovePeopleViewIDs->objectAtIndex(i);
        sqliteRemoveFolderForPeopleViewID(vPeopleViewID->longLongValue(), vFolderID->longLongValue(), changes);
    }
    MC_SAFE_RELEASE(messageRowIDs);
    MC_SAFE_RELEASE(foldersToRemoveFolderIDs);
    MC_SAFE_RELEASE(foldersToRemovePeopleViewIDs);

    MCAssert(peopleViewID != -1LL);
    // Change people view ID of message
    r = sqlitePrepare("update message set peopleviewid = ? where convid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    sqlite3_bind_int64(stmt, 2, conversationRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    mc_foreacharray(Value, vFolderID, foldersIDs) {
        sqliteAddFolderForPeopleViewID(peopleViewID, vFolderID->longLongValue(), changes);
    }
    
    if ((maxDate != peopleViewDate) || (hasAttachment != peopleHasAttachment)) {
        r = sqlitePrepare("update peopleview set date = ?, hasattachment = ? where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, maxDate);
        sqlite3_bind_int(stmt, 2, hasAttachment);
        sqlite3_bind_int64(stmt, 3, peopleViewID);
        r = sqlite3_step(stmt);
        //sqlite3_finalize(stmt);
        sqliteReset(stmt);
    }
    changes->changePeopleViewCount(peopleViewID);
    changes->modifyPeopleViewID(peopleViewID, maxDate);
    
    mc_foreacharray(Value, vPeopleViewRowID, peopleViewIDs->allObjects()) {
        changes->changePeopleViewCount(vPeopleViewRowID->longLongValue());
        changes->modifyPeopleViewID(vPeopleViewRowID->longLongValue(), -1);
        sqliteCheckRemovePeopleViewID(vPeopleViewRowID->longLongValue(), changes);
    }
    
    MC_SAFE_RELEASE(peopleViewIDs);
    MC_SAFE_RELEASE(foldersIDs);
}

void MailDB::sqliteChangePeopleViewIDForMessage(int64_t messageRowID,
                                                int64_t folderID,
                                                int64_t peopleViewID,
                                                int64_t date,
                                                bool hasAttachment,
                                                MailDBChanges * changes,
                                                int64_t peopleViewDate,
                                                bool peopleHasAttachment,
                                                int64_t draftsFolderID)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t maxDate = peopleViewDate;
    int64_t maxDateWithDrafts = peopleViewDate;
    if (date > maxDate) {
        if (folderID != draftsFolderID) {
            maxDate = date;
        }
        else {
            maxDateWithDrafts = date;
        }
    }
    if (maxDate == -1) {
        maxDate = maxDateWithDrafts;
    }
    hasAttachment = hasAttachment || peopleHasAttachment;

    MCAssert(peopleViewID != -1LL);
    // It's only used when adding the message for the first time. Then we don't need to update peopleview unread and starred count.
    r = sqlitePrepare("update message set peopleviewid = ? where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    sqlite3_bind_int64(stmt, 2, messageRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    if ((maxDate != peopleViewDate) || (peopleHasAttachment != hasAttachment)) {
        peopleViewDate = date;
        r = sqlitePrepare("update peopleview set date = ?, hasattachment = ? where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, date);
        sqlite3_bind_int(stmt, 2, hasAttachment);
        sqlite3_bind_int64(stmt, 3, peopleViewID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }
    
    changes->modifyPeopleViewID(peopleViewID, peopleViewDate);
    
    searchMetaUpdate(messageRowID, peopleViewID);
}

void MailDB::sqliteRemoveConversation(int64_t conversationRowID)
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("delete from conversation where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, conversationRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

int64_t MailDB::sqlitePeopleViewIDForConversationIDWithRecipientMD5(int64_t conversationID, String * recipientMD5,
                                                                    time_t date, bool hasAttachment,
                                                                    bool createIfNeeded,
                                                                    MailDBChanges * changes, int64_t * pPeopleViewDate,
                                                                    bool * pPeopleHasAttachment)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t peopleViewDate = -1;
    bool peopleHasAttachment = false;

    if (recipientMD5 != NULL) {
        // Add to a conversation with 0 or 1 recipient.
        int64_t peopleViewRowID = -1;
        r = sqlitePrepare("select rowid, date from peopleview where recipientmd5 = ?", &stmt);
        sqlite3_bind_text16(stmt, 1, recipientMD5->unicodeCharacters(), -1, SQLITE_STATIC);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                peopleViewRowID = sqlite3_column_int64(stmt, 0);
                peopleViewDate = sqlite3_column_int64(stmt, 1);
                peopleHasAttachment = sqlite3_column_int(stmt, 2);
            }
        }
        sqliteReset(stmt);

        if (peopleViewRowID != -1) {
            * pPeopleViewDate = peopleViewDate;
            * pPeopleHasAttachment = peopleHasAttachment;
            return peopleViewRowID;
        }
    }
    else {
        // Add to a conversation with more than one recipient.
        int64_t peopleViewRowID = -1;
        r = sqlitePrepare("select peopleviewid from message where convid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, conversationID);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                peopleViewRowID = sqlite3_column_int64(stmt, 0);
            }
        }
        sqliteReset(stmt);
        if (peopleViewRowID != -1) {
            bool peopleHasAttachment = false;
            r = sqlitePrepare("select date, hasattachment from peopleview where rowid = ?", &stmt);
            sqlite3_bind_int64(stmt, 1, peopleViewRowID);
            if (r == SQLITE_OK) {
                r = sqlite3_step(stmt);
                if (r == SQLITE_ROW) {
                    peopleViewDate = sqlite3_column_int64(stmt, 0);
                    peopleHasAttachment = sqlite3_column_int(stmt, 1);
                }
            }
            //sqlite3_finalize(stmt);
            sqliteReset(stmt);
            //changes->modifyPeopleViewID(peopleViewRowID);
            * pPeopleViewDate = peopleViewDate;
            * pPeopleHasAttachment = peopleHasAttachment;
            return peopleViewRowID;
        }
    }
    
    if (createIfNeeded) {
        r = sqlitePrepare("insert into peopleview (recipientmd5, date, hasattachment) values (?, ?, ?)", &stmt);
        if (recipientMD5 != NULL) {
            sqlite3_bind_text16(stmt, 1, recipientMD5->unicodeCharacters(), -1, SQLITE_STATIC);
        }
        else {
            sqlite3_bind_null(stmt, 1);
        }
        sqlite3_bind_int64(stmt, 2, date);
        sqlite3_bind_int(stmt, 3, hasAttachment);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);

        int64_t peopleViewRowID = sqlite3_last_insert_rowid(mSqlite);
        changes->addPeopleViewID(peopleViewRowID, date);
        peopleViewDate = date;
        peopleHasAttachment = hasAttachment;
        * pPeopleViewDate = peopleViewDate;
        * pPeopleHasAttachment = peopleHasAttachment;
        return peopleViewRowID;
    }
    else {
        return 0;
    }
}

bool MailDB::sqliteCheckRemoveConversationID(int64_t conversationID)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t count = 0;
    
    r = sqlitePrepare("select count(*) from message where convid = ? limit 1", &stmt);
    sqlite3_bind_int64(stmt, 1, conversationID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            count = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    if (count == 0) {
        sqliteRemoveConversation(conversationID);
        return true;
    }
    
    return false;
}

bool MailDB::sqliteCheckRemovePeopleViewID(int64_t peopleViewID, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t count = 0;
    
    r = sqlitePrepare("select count(*) from message where peopleviewid = ? limit 1", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            count = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    if (count == 0) {
        r = sqlitePrepare("delete from peopleview where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleViewID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
        changes->removePeopleViewID(peopleViewID);
        return true;
    }
    
    return false;
}

void MailDB::sqliteAddFolderForPeopleViewID(int64_t peopleViewID, int64_t folderID, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    unsigned int count;
    int64_t rowID = -1;
    
    count = 0;
    r = sqlitePrepare("select rowid, count from peopleviewfolder where peopleviewid = ? and folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    sqlite3_bind_int64(stmt, 2, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowID = sqlite3_column_int64(stmt, 0);
            count = (unsigned int) sqlite3_column_int64(stmt, 1);
        }
    }
    sqliteReset(stmt);

    if (count == 0) {
        r = sqlitePrepare("insert into peopleviewfolder (peopleviewid, folderid, count) values (?, ?, 1)", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleViewID);
        sqlite3_bind_int64(stmt, 2, folderID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
        count = 1;

        // adding one unread / starred count if it was unread / starred
        r = sqlitePrepare("select unread, starred from peopleview where rowid = ?", &stmt);
        int unread = 0;
        int starred = 0;
        sqlite3_bind_int64(stmt, 1, peopleViewID);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                unread = sqlite3_column_int(stmt, 0);
                starred = sqlite3_column_int(stmt, 1);
            }
        }
        sqliteReset(stmt);

        int starred_count = 0;
        int unread_count = 0;
        int total_count = 0;
        r = sqlitePrepare("select starred, unread, count from folder where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, folderID);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                starred_count = sqlite3_column_int(stmt, 0);
                unread_count = sqlite3_column_int(stmt, 1);
                total_count = sqlite3_column_int(stmt, 2);
            }
        }
        sqliteReset(stmt);

        if (unread) {
            unread_count ++;
        }
        if (starred) {
            starred_count ++;
        }
        total_count ++;

        r = sqlitePrepare("update folder set unread = ?, starred = ?, count = ? where rowid = ?", &stmt);
        sqlite3_bind_int(stmt, 1, unread_count);
        sqlite3_bind_int(stmt, 2, starred_count);
        sqlite3_bind_int(stmt, 3, total_count);
        sqlite3_bind_int64(stmt, 4, folderID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);

        changes->changeCountForFolderID(folderID, unread_count, starred_count, total_count);
    }
    else {
        count ++;
        r = sqlitePrepare("update peopleviewfolder set count = ? where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, count);
        sqlite3_bind_int64(stmt, 2, rowID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }
    
    if (count == 1) {
        changes->addFolderForConversation(peopleViewID, folderID);
    }
}

void MailDB::sqliteRemoveFolderForPeopleViewID(int64_t peopleViewID, int64_t folderID, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    unsigned int count;
    int64_t rowID = -1;
    
    count = 0;
    r = sqlitePrepare("select rowid, count from peopleviewfolder where peopleviewid = ? and folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    sqlite3_bind_int64(stmt, 2, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowID = sqlite3_column_int64(stmt, 0);
            count = (unsigned int) sqlite3_column_int64(stmt, 1);
        }
    }
    else {
        fprintf(stderr, "error: %s\n", sqlite3_errmsg(mSqlite));
    }
    sqliteReset(stmt);

    MCAssert(count > 0);
    
    if (count == 1) {
        count = 0;
        r = sqlitePrepare("delete from peopleviewfolder where peopleviewid = ? and folderid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleViewID);
        sqlite3_bind_int64(stmt, 2, folderID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);

        // remove one unread / starred count if it was unread / starred
        r = sqlitePrepare("select unread, starred from peopleview where rowid = ?", &stmt);
        int unread = 0;
        int starred = 0;
        sqlite3_bind_int64(stmt, 1, peopleViewID);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                unread = sqlite3_column_int(stmt, 0);
                starred = sqlite3_column_int(stmt, 1);
            }
        }
        sqliteReset(stmt);

        int starred_count = 0;
        int unread_count = 0;
        int total_count = 0;
        r = sqlitePrepare("select unread, starred, count from folder where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, folderID);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                unread_count = sqlite3_column_int(stmt, 0);
                starred_count = sqlite3_column_int(stmt, 1);
                total_count = sqlite3_column_int(stmt, 2);
            }
        }
        sqliteReset(stmt);

        if (unread) {
            unread_count --;
        }
        if (starred) {
            starred_count --;
        }
        total_count --;

        r = sqlitePrepare("update folder set unread = ?, starred = ?, count = ? where rowid = ?", &stmt);
        sqlite3_bind_int(stmt, 1, unread_count);
        sqlite3_bind_int(stmt, 2, starred_count);
        sqlite3_bind_int(stmt, 3, total_count);
        sqlite3_bind_int64(stmt, 4, folderID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);

        changes->changeCountForFolderID(folderID, unread_count, starred_count, total_count);
    }
    else {
        count --;
        r = sqlitePrepare("update peopleviewfolder set count = ? where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, count);
        sqlite3_bind_int64(stmt, 2, rowID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }
    
    if (count == 0) {
        changes->removeFolderFromConversation(peopleViewID, folderID);
    }
}

static int64_t int64FromData(Data * data)
{
    char * str = (char *) malloc(data->length() + 1);
    memcpy(str, data->bytes(), data->length());
    str[data->length()] = 0;
    int64_t result = strtoll(str, NULL, 10);
    free(str);
    return result;
}

static Data * dataFromInt64(int64_t value)
{
    String * str = String::stringWithUTF8Format("%lld", (long long) value);
    return str->dataUsingEncoding("utf-8");
}

static int compareString(void * a , void * b, void * ctx)
{
    String * sa = (String *) a;
    String * sb = (String *) b;
    return sa->compare(sb);
}

/*
 push state:
 - 0 no need for push
 - 1 need push
 - 2 pushed
*/

int64_t MailDB::addPendingMessageWithData(int64_t folderID, mailcore::Data * data,
                                          bool needsToBeSentToServer,
                                          bool hasBeenPushed,
                                          String * parsedMessageID,
                                          int64_t draftsFolderID,
                                          MailDBChanges * changes)
{
    String * basename = md5String(data);
    String * filename = localMessageFilenameWithBasename(basename);
    mailcore::ErrorCode code = data->writeToFile(filename);
    if (code != mailcore::ErrorNone) {
        LOG_ERROR("could not write file %s", MCUTF8(filename));
    }
    MessageParser * msg = MessageParser::messageParserWithData(data);
    if (parsedMessageID != NULL) {
        parsedMessageID->setString(msg->header()->messageID());
    }

    sqlite3_stmt * stmt;
    IndexSet * messageRowsIDs = IndexSet::indexSet();
    IndexSet * rowsIDs = IndexSet::indexSet();
    int r = sqlitePrepare("select rowid, messageid from local_message where folderid = ? and msgid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    sqlite3_bind_text16(stmt, 2, msg->header()->messageID()->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t rowID = sqlite3_column_int64(stmt, 0);
            int64_t messageRowID = sqlite3_column_int64(stmt, 1);
            rowsIDs->addIndex(rowID);
            messageRowsIDs->addIndex(messageRowID);
        }
        while (1);
    }
    sqliteReset(stmt);

    int64_t rowid = addMessage(folderID, 0, msg, MessageFlagSeen, basename, false, draftsFolderID, changes);

    int pushState = 0;
    if (needsToBeSentToServer) {
        if (hasBeenPushed) {
            pushState = 2;
        }
        else {
            pushState = 1;
        }
    }
    else {
        pushState = 0;
    }

    // add the message.
    r = sqlitePrepare("insert into local_message (messageid, msgid, folderid, pushstate, pushdate, date) values (?, ?, ?, ?, ?, ?)", &stmt);
    sqlite3_bind_int64(stmt, 1, rowid);
    sqlite3_bind_text16(stmt, 2, msg->header()->messageID()->unicodeCharacters(), -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 3, folderID);
    sqlite3_bind_int(stmt, 4, pushState);
    sqlite3_bind_int64(stmt, 5, time(NULL));
    sqlite3_bind_int64(stmt, 6, msg->header()->date());
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    {
        mc_foreachindexset(rowID, rowsIDs) {
            r = sqlitePrepare("delete from local_message where rowid = ?", &stmt);
            sqlite3_bind_int64(stmt, 1, rowID);
            r = sqlite3_step(stmt);
            sqliteReset(stmt);
        }
    }
    {
        mc_foreachindexset(messageRowID, messageRowsIDs) {
            removeMessage(messageRowID, changes);
        }
    }

    return rowid;
}

void MailDB::setLocalMessagePushed(int64_t messageRowID)
{
    sqlite3_stmt * stmt;
    int r = sqlitePrepare("update local_message set pushstate = 2, pushdate = ? where messageid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, time(NULL));
    sqlite3_bind_int64(stmt, 2, messageRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::removeMatchingPendingCopyMessage(int64_t folderID, mailcore::String * messageID, int64_t date, MailDBChanges * changes)
{
    sqlite3_stmt * stmt;
    IndexSet * rowids = IndexSet::indexSet();
    int r = sqlitePrepare("select rowid from message where msgid = ? and date = ? and uid = 0", &stmt);
    sqlite3_bind_text16(stmt, 1, messageID->unicodeCharacters(), -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 2, date);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t messageRowID = sqlite3_column_int64(stmt, 0);
            rowids->addIndex(messageRowID);
        } while (1);
    }
    sqliteReset(stmt);

    mc_foreachindexset(messageRowID, rowids) {
        removeMessage(messageRowID, changes);
    }
}

void MailDB::removeMatchingLocalMessage(int64_t folderID, mailcore::String * messageID, time_t date, MailDBChanges * changes)
{
    sqlite3_stmt * stmt;
    int64_t messageRowID = -1;
    int64_t rowID = -1;
    int r = sqlitePrepare("select rowid, messageid from local_message where folderid = ? and msgid = ? and date = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    sqlite3_bind_text16(stmt, 2, messageID->unicodeCharacters(), -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 3, date);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowID = sqlite3_column_int64(stmt, 0);
            messageRowID = sqlite3_column_int64(stmt, 1);
        }
    }
    sqliteReset(stmt);

    if (rowID == -1) {
        return;
    }

    r = sqlitePrepare("delete from local_message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, rowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    removeMessage(messageRowID, changes);
}

void MailDB::removeExpiredLocalMessage(int64_t folderID, MailDBChanges * changes)
{
    sqlite3_stmt * stmt;
    int64_t messageRowID = -1;
    int64_t rowID = -1;
    int r = sqlitePrepare("select rowid, messageid from local_message where folderid = ? and pushstate = 2 and pushdate < ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    time_t date = time(NULL) - 12 * 60 * 60;
    sqlite3_bind_int64(stmt, 2, date);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowID = sqlite3_column_int64(stmt, 0);
            messageRowID = sqlite3_column_int64(stmt, 1);
        }
    }
    sqliteReset(stmt);

    if (rowID == -1) {
        return;
    }

    r = sqlitePrepare("delete from local_message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, rowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    removeMessage(messageRowID, changes);
}

mailcore::HashMap * MailDB::nextMessageToPush(int64_t folderID, bool draftBehaviorEnabled)
{
    sqlite3_stmt * stmt;
    int64_t messageRowID = -1;
    String * messageID = NULL;
    int r = sqlitePrepare("select messageid, msgid from local_message where folderid = ? and pushstate = 1 order by rowid limit 1", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            messageRowID = sqlite3_column_int64(stmt, 0);
            const void * messageIDUnichars = sqlite3_column_text16(stmt, 1);
            messageID = String::stringWithCharacters((const UChar *) messageIDUnichars);
        }
    }
    sqliteReset(stmt);

    if (messageRowID == -1) {
        return NULL;
    }

    String * filename = filenameForRowID(messageRowID);
    if (filename == NULL) {
        return NULL;
    }

    IndexSet * messagesRowIDsToDelete = NULL;
    if (draftBehaviorEnabled) {
        messagesRowIDsToDelete = IndexSet::indexSet();
        r = sqlitePrepare("select rowid from message where msgid = ?", &stmt);
        sqlite3_bind_text16(stmt, 1, messageID->unicodeCharacters(), -1, SQLITE_STATIC);
        if (r == SQLITE_OK) {
            do {
                r = sqlite3_step(stmt);
                if (r != SQLITE_ROW) {
                    break;
                }
                int64_t otherMessageRowID = sqlite3_column_int64(stmt, 0);
                messagesRowIDsToDelete->addIndex(otherMessageRowID);
            } while (1);
        }
        sqliteReset(stmt);
    }

    HashMap * result = HashMap::hashMap();
    result->setObjectForKey(MCSTR("filename"), filename);
    result->setObjectForKey(MCSTR("rowid"), Value::valueWithLongLongValue(messageRowID));
    if (messagesRowIDsToDelete != NULL) {
        result->setObjectForKey(MCSTR("old"), messagesRowIDsToDelete);
    }
    return result;
}

int64_t MailDB::addIMAPMessage(int64_t folderID, mailcore::IMAPMessage * msg,
                               bool notificationEnabled,
                               int64_t draftsFolderID,
                               MailDBChanges * changes)
{
    removeMatchingPendingCopyMessage(folderID, msg->header()->messageID(), msg->header()->date(), changes);
    removeMatchingLocalMessage(folderID, msg->header()->messageID(), msg->header()->date(), changes);
    int64_t rowID = addMessage(folderID, msg->uid(), msg, msg->flags(), NULL, notificationEnabled, draftsFolderID, changes);
    if (msg->gmailLabels() != NULL) {
        storeLabelsForMessage(rowID, msg->gmailLabels());
    }
    return rowID;
}

bool MailDB::isMessageWithoutBodystructure(mailcore::AbstractMessage * msg)
{
    bool result = false;
    if (msg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
        if (((IMAPMessage *) msg)->mainPart() == NULL) {
            result = true;
        }
    }
    return result;
}

mailcore::HashMap * MailDB::computeAttachment(mailcore::AbstractMessage * msg)
{
    bool hasAttachment = false;
    int attachmentsCount = 0;
    String * attachmentFilename = NULL;
    bool skipAttachmentsInfo = isMessageWithoutBodystructure(msg);
    if (!skipAttachmentsInfo) {
        if ((msg->attachments()->count() > 0) || (msg->htmlInlineAttachments()->count() > 0)) {
            hasAttachment = true;
            attachmentsCount = msg->attachments()->count() + msg->htmlInlineAttachments()->count();
            if (attachmentFilename == NULL) {
                mc_foreacharray(AbstractPart, currentAttachment, msg->attachments()) {
                    if (currentAttachment->filename() != NULL) {
                        MC_SAFE_REPLACE_COPY(String, attachmentFilename, currentAttachment->filename());
                        break;
                    }
                }
            }
            if (attachmentFilename == NULL) {
                mc_foreacharray(AbstractPart, currentAttachment, msg->htmlInlineAttachments()) {
                    if (currentAttachment->filename() != NULL) {
                        MC_SAFE_REPLACE_COPY(String, attachmentFilename, currentAttachment->filename());
                        break;
                    }
                }
            }
        }
    }
    HashMap * result = HashMap::hashMap();
    if (attachmentFilename != NULL) {
        result->setObjectForKey(MCSTR("filename"), attachmentFilename->lastPathComponent());
    }
    result->setObjectForKey(MCSTR("count"), Value::valueWithIntValue(attachmentsCount));
    return result;
}

int64_t MailDB::addMessage(int64_t folderID, uint32_t msgUid,
                           mailcore::AbstractMessage * msg,
                           mailcore::MessageFlag flags,
                           String * filename,
                           bool notificationEnabled,
                           int64_t draftsFolderID,
                           MailDBChanges * changes)
{
    // add new message
    HashMap * attachmentInfo = computeAttachment(msg);
    String * attachmentFilename = (String *) attachmentInfo->objectForKey(MCSTR("filename"));
    int attachmentsCount = ((Value *) attachmentInfo->objectForKey(MCSTR("count")))->intValue();

    int64_t messageRowID = sqliteAddMessage(msgUid, msg->header()->messageID(), folderID, msg->header()->date(), flags, filename,
                                            attachmentsCount,
                                            attachmentFilename,
                                            notificationEnabled, changes);
    if ((flags & MessageFlagDeleted) != 0)
        return messageRowID;
    
    internalAddMessage(folderID, messageRowID, msg, flags, draftsFolderID, changes);
    
    String * key = String::stringWithUTF8Format("msg-%lld", (long long) messageRowID);
    mSerializedMessageCache->setObjectForKey(Value::valueWithLongLongValue((long long) messageRowID), msg);
    mKVDB->setObjectForKey(key, hermes::fastSerializedData(msg));
    if (filename != NULL) {
        storeFilenameForMessageParser(messageRowID, filename);
    }
    indexAddMessageHeaders(messageRowID, msg);
    
    return messageRowID;
}

void MailDB::internalAddMessage(int64_t folderID, int64_t messageRowID,
                                mailcore::AbstractMessage * msg, MessageFlag flags,
                                int64_t draftsFolderID,
                                MailDBChanges * changes)
{
    bool hasAttachment = false;
    bool skipAttachmentsInfo = isMessageWithoutBodystructure(msg);
    if (!skipAttachmentsInfo) {
        if ((msg->attachments()->count() > 0) || (msg->htmlInlineAttachments()->count() > 0)) {
            hasAttachment = true;
        }
    }

    String * msgid = msg->header()->messageID();

    Set * referencesSet = new Set();
    referencesSet->addObject(msgid);
    referencesSet->addObjectsFromArray(msg->header()->references());
    referencesSet->addObjectsFromArray(msg->header()->inReplyTo());
    Array * references = referencesSet->allObjects();
    referencesSet->release();
    
    String * subject = msg->header()->extractedSubject();
    if (subject == NULL) {
        subject = String::string();
    }
    String * subjectMD5 = md5String(subject->lowercaseString()->dataUsingEncoding("utf-8"));
    
    Set * msgIDToChange = new Set();
    Set * emptyMsgID = new Set();
    Set * conversationsToMerge = new Set();
    Data * foundValue = NULL;
    for(unsigned int i = 0 ; i < references->count() ; i ++) {
        String * curMsgID = (String *) references->objectAtIndex(i);
        String * key = new String();
        key->appendUTF8Characters("relationmsgid-");
        key->appendString(curMsgID);
        key->appendUTF8Characters("-");
        key->appendString(subjectMD5);
        Data * value = mKVDB->objectForKey(key);
        if (value != NULL) {
            if (foundValue == NULL) {
                foundValue = value;
            }
            else if (!value->isEqual(foundValue)) {
                msgIDToChange->addObject(key);
                conversationsToMerge->addObject(value);
            }
        }
        else {
            emptyMsgID->addObject(key);
        }
        key->release();
    }
    
    Set * recipientSet = new Set();
    Array * recipient = new Array();
    if (msg->header()->from() != NULL) {
        if (!recipientSet->containsObject(msg->header()->from()->mailbox()->lowercaseString())) {
            recipientSet->addObject(msg->header()->from()->mailbox()->lowercaseString());
            recipient->addObject(msg->header()->from());
        }
    }
    else if (msg->header()->sender() != NULL) {
        if (!recipientSet->containsObject(msg->header()->sender()->mailbox()->lowercaseString())) {
            recipientSet->addObject(msg->header()->sender()->mailbox()->lowercaseString());
            recipient->addObject(msg->header()->sender());
        }
    }
    if (msg->header()->to() != NULL) {
        mc_foreacharray(Address, address, msg->header()->to()) {
            if (!recipientSet->containsObject(address->mailbox()->lowercaseString())) {
                recipientSet->addObject(address->mailbox()->lowercaseString());
                recipient->addObject(address);
            }
        }
    }
    if (msg->header()->cc() != NULL) {
        mc_foreacharray(Address, address2, msg->header()->cc()) {
            if (!recipientSet->containsObject(address2->mailbox()->lowercaseString())) {
                recipientSet->addObject(address2->mailbox()->lowercaseString());
                recipient->addObject(address2);
            }
        }
    }
    Array * recipientArray = recipientSet->allObjects();
    recipientArray->sortArray(compareString, NULL);

    if (foundValue == NULL) {
        Data * lastSubjectData = mKVDB->objectForKey(MCSTR("last-msg-subject"));
        Data * lastRecipientData = mKVDB->objectForKey(MCSTR("last-msg-recipient"));
        String * lastSubject = String::string();
        if (lastSubjectData != NULL) {
            lastSubject = lastSubjectData->stringWithCharset("utf-8");
        }
        Array * lastRecipient = Array::array();
        if (lastRecipientData != NULL) {
            //lastRecipient = (Array *) JSON::objectFromJSONData(lastRecipientData);
            lastRecipient = (Array *) hermes::objectWithFastSerializedData(lastRecipientData);
        }
        if (lastRecipient != NULL) {
            if (lastSubject->isEqual(subject) && lastRecipient->isEqual(recipientArray)) {
                foundValue = mKVDB->objectForKey(MCSTR("last-msg-peopleviewid"));
            }
        }
    }

    int64_t conversationRowID;
    if (foundValue == NULL) {
        // add a new conversation
        conversationRowID = sqliteAddConversation();
        foundValue = dataFromInt64(conversationRowID);
    }
    else {
        conversationRowID = int64FromData(foundValue);
    }

#if !DISABLE_PEOPLEVIEW
    unsigned int recipientInitialCount = 0;
    String * initialRecipientMD5 = NULL;
    String * peopleKey = new String();
    peopleKey->appendString(MCSTR("people-"));
    peopleKey->appendUTF8Format("%lld", (long long) conversationRowID);
    Data * peopleData = mKVDB->objectForKey(peopleKey);
    if (peopleData != NULL) {
        Array * peopleArray = (Array *) JSON::objectFromJSONData(peopleData);
        recipientSet->addObjectsFromArray(peopleArray);
        recipientInitialCount = peopleArray->count();
        initialRecipientMD5 = md5String(peopleData);
    }
#endif

    // set converationID on message, also change conversation date if needed
    sqliteChangeConversationIDForMessageWithRowID(messageRowID, conversationRowID);
    
    bool needsChangePeopleViewForWholeConversation = false;
    Array * conversationsIDs = conversationsToMerge->allObjects();
    for(unsigned int i = 0 ; i < conversationsIDs->count() ; i ++) {
        Data * otherConvRowIDData = (Data *) conversationsIDs->objectAtIndex(i);
        int64_t otherConversationRowID = int64FromData(otherConvRowIDData);
        
        // find all message with convID == otherConversationRowID, set conversationRowID
        // also change conversation date if needed
        sqliteChangeConversationIDForMessagesWithConversationID(otherConversationRowID, conversationRowID);
        needsChangePeopleViewForWholeConversation = true;

        sqliteRemoveConversation(otherConversationRowID);

#if !DISABLE_PEOPLEVIEW
        String * key = new String();
        key->appendString(MCSTR("people-"));
        key->appendUTF8Format("%lld", (long long) otherConversationRowID);
        
        peopleData = mKVDB->objectForKey(key);
        if (peopleData != NULL) {
            Array * peopleArray = (Array *) JSON::objectFromJSONData(peopleData);
            recipientSet->addObjectsFromArray(peopleArray);
            mKVDB->removeObjectForKey(key);
        }
        key->release();
#endif
    }
    
    for(unsigned int i = 0 ; i < references->count() ; i ++) {
        String * curMsgID = (String *) references->objectAtIndex(i);
        String * key = new String();
        key->appendUTF8Characters("relationmsgid-");
        key->appendString(curMsgID);
        key->appendUTF8Characters("-");
        key->appendString(subjectMD5);
        if (msgIDToChange->containsObject(key) || emptyMsgID->containsObject(key)) {
            mKVDB->setObjectForKey(key, foundValue);
        }
        key->release();
    }
    
#if !DISABLE_PEOPLEVIEW
    Array * recipientArray = recipientSet->allObjects();
    recipientArray = recipientArray->sortedArray(compareString, NULL);
    Data * recipientData = JSON::objectToJSONData(recipientArray);
    String * recipientMD5 = md5String(recipientData);
    String * listID = msg->header()->extraHeaderValueForName(MCSTR("List-ID"));
    if (listID != NULL) {
        recipientMD5 = md5String(listID->dataUsingEncoding("utf-8"));
    }
#else
    String * recipientMD5 = NULL;
#endif

    int64_t peopleViewDate = -1;
    bool peopleHasAttachment = false;
    int64_t peopleViewID = sqlitePeopleViewIDForConversationIDWithRecipientMD5(conversationRowID, recipientMD5, msg->header()->receivedDate(), hasAttachment, true, changes, &peopleViewDate, &peopleHasAttachment);

#if !DISABLE_PEOPLEVIEW
    if (recipientInitialCount != recipientSet->count()) {
        sqliteChangeConversationRecipientMD5(conversationRowID, recipientMD5);
        bool sameRecipient = false;
        if ((recipientMD5 == NULL) && (initialRecipientMD5 == NULL)) {
            sameRecipient = true;
        }
        else if (recipientMD5 != NULL) {
            sameRecipient = recipientMD5->isEqual(initialRecipientMD5);
        }
        else /* initialRecipientMD5 != NULL */ {
            sameRecipient = initialRecipientMD5->isEqual(recipientMD5);
        }
        
        if (!sameRecipient) {
            needsChangePeopleViewForWholeConversation = true;
        }
        mKVDB->setObjectForKey(peopleKey, recipientData);
    }
#endif

    MCAssert(peopleViewID != -1LL);
    if (needsChangePeopleViewForWholeConversation) {
        sqliteChangePeopleViewIDForMessagesWithConversationID(conversationRowID, peopleViewID,
                                                              changes, peopleViewDate, peopleHasAttachment,
                                                              draftsFolderID);
    }
    else {
        sqliteChangePeopleViewIDForMessage(messageRowID, folderID,
                                           peopleViewID, msg->header()->receivedDate(),
                                           hasAttachment,
                                           changes, peopleViewDate, peopleHasAttachment,
                                           draftsFolderID);
        sqliteAddFolderForPeopleViewID(peopleViewID, folderID, changes);
    }

    String * key = String::stringWithUTF8Format("conv-%lld", (long long) peopleViewID);
    Data * data = mKVDB->objectForKey(key);
    HashMap * convCacheInfo;
    if (data == NULL) {
        convCacheInfo = HashMap::hashMap();
    }
    else {
        convCacheInfo = (HashMap *) hermes::objectWithFastSerializedData(data);
    }
    Array * convRecipient = (Array *) convCacheInfo->objectForKey(MCSTR("recipients"));
    if (convRecipient == NULL) {
        convRecipient = Array::array();
        convCacheInfo->setObjectForKey(MCSTR("recipients"), convRecipient);
    }
    Set * existingRecipient = Set::set();
    {
        mc_foreacharray(Address, address, convRecipient) {
            existingRecipient->addObject(address->mailbox()->lowercaseString());
        }
    }
    {
        mc_foreacharray(Address, address, recipient) {
            if (!existingRecipient->containsObject(address->mailbox()->lowercaseString())) {
                convRecipient->addObject(address);
                existingRecipient->addObject(address->mailbox()->lowercaseString());
            }
        }
    }
    Array * senders = (Array *) convCacheInfo->objectForKey(MCSTR("senders"));
    if (senders == NULL) {
        senders = Array::array();
        convCacheInfo->setObjectForKey(MCSTR("senders"), senders);
    }
    Set * existing = Set::set();
    mc_foreacharray(Address, sender, senders) {
        existing->addObject(sender->mailbox()->lowercaseString());
    }
    Address * from = NULL;
    if (msg->header()->from() != NULL) {
        from = msg->header()->from();
    }
    else if (msg->header()->sender() != NULL) {
        from = msg->header()->sender();
    }
    if (from != NULL && from->mailbox() != NULL) {
        if (!existing->containsObject(from->mailbox()->lowercaseString())) {
            senders->addObject(from);
        }
        if (!existingRecipient->containsObject(from->mailbox()->lowercaseString())) {
            convRecipient->addObject(from);
        }
    }
    mKVDB->setObjectForKey(key, hermes::fastSerializedData(convCacheInfo));

#if !DISABLE_PEOPLEVIEW
    peopleKey->release();
#endif
    emptyMsgID->release();
    msgIDToChange->release();
    conversationsToMerge->release();
    
    mKVDB->setObjectForKey(MCSTR("last-msg-subject"), subject->dataUsingEncoding("utf-8"));
    mKVDB->setObjectForKey(MCSTR("last-msg-peopleviewid"), dataFromInt64(conversationRowID));
    mKVDB->setObjectForKey(MCSTR("last-msg-recipient"), hermes::fastSerializedData(recipientArray));

    MC_SAFE_RELEASE(recipient);
    MC_SAFE_RELEASE(recipientSet);

    changeMessageCommon(folderID, messageRowID, peopleViewID, MessageFlagSeen, flags, MessageFlagMaskAll, false, false, true,
                        draftsFolderID, changes);
}

void MailDB::changeMessageWithUID(int64_t folderID, uint32_t uid, MessageFlag flags, MessageFlag mask,
                                  int64_t draftsFolderID,
                                  MailDBChanges * changes, int64_t * pRowID, int64_t * pPeopleViewID)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t rowid = -1;
    int current_unread = 0;
    int current_starred = 0;
    int current_deleted = 0;
    int64_t peopleViewID = -1;
    bool moving = false;

    * pRowID = -1;

    r = sqlitePrepare("select rowid, unread, starred, deleted, peopleviewid, moving from message where folderid = ? and uid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    sqlite3_bind_int64(stmt, 2, uid);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowid = sqlite3_column_int64(stmt, 0);
            current_unread = sqlite3_column_int(stmt, 1);
            current_starred = sqlite3_column_int(stmt, 2);
            current_deleted = sqlite3_column_int(stmt, 3);
            peopleViewID = sqlite3_column_int64(stmt, 4);
            moving = (bool) sqlite3_column_int(stmt, 5);
        }
    }
    MessageFlag currentFlags = (MessageFlag) 0;
    if (!current_unread) {
        currentFlags = (MessageFlag) (currentFlags | MessageFlagSeen);
    }
    if (current_starred) {
        currentFlags = (MessageFlag) (currentFlags | MessageFlagFlagged);
    }
    if (current_deleted) {
        currentFlags = (MessageFlag) (currentFlags | MessageFlagDeleted);
    }
    sqliteReset(stmt);

    if (rowid == -1) {
        return;
    }

    * pRowID = rowid;
    * pPeopleViewID = peopleViewID;
    changeMessageCommon(folderID, rowid, peopleViewID, currentFlags, flags, mask, moving, moving, false, draftsFolderID, changes);
}

void MailDB::changeMessageLabelsWithUID(int64_t messageRowID, int64_t peopleViewID, mailcore::Array * labels, MailDBChanges * changes)
{
    Array * currentLabels = labelsForMessage(messageRowID);
    if (currentLabels != NULL) {
        if (currentLabels->isEqual(labels)) {
            return;
        }
    }

    storeLabelsForMessage(messageRowID, labels);

    int r;
    sqlite3_stmt * stmt;
    int64_t date = -1;
    r = sqlitePrepare("select date from peopleview where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            date = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);
    changes->modifyPeopleViewID(peopleViewID, date);
}

bool MailDB::changeMessageToMoving(int64_t folderID,
                                   int64_t rowID,
                                   MessageFlag flags,
                                   bool currentMoving,
                                   bool moving,
                                   int64_t draftsFolderID,
                                   MailDBChanges * changes)
{
    bool currentDeleted = (flags & MessageFlagDeleted) != 0;
    bool current_hidden = currentDeleted || currentMoving;
    bool hidden = currentDeleted || moving;

    if (currentMoving != moving) {
        sqlite3_stmt * stmt;
        int r;

        r = sqlitePrepare("update message set moving = ? where rowid = ?", &stmt);
        sqlite3_bind_int(stmt, 1, moving);
        sqlite3_bind_int64(stmt, 2, rowID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }

    if (hidden != current_hidden) {
        if (hidden) {
            internalRemoveMessage(rowID, changes, false);
        }
        else {
            // should crash if it fails since it's queries in the callers this method.
            AbstractMessage * storedMsg = messageForRowID(rowID);
            internalAddMessage(folderID, rowID, storedMsg, flags, draftsFolderID, changes);
        }
        return true;
    }
    else {
        return false;
    }
}

bool MailDB::changeMessageCommon(int64_t folderID,
                                 int64_t rowID,
                                 int64_t peopleViewID,
                                 MessageFlag currentFlags,
                                 MessageFlag flags,
                                 MessageFlag mask,
                                 bool currentMoving,
                                 bool moving,
                                 bool adding,
                                 int64_t draftsFolderID,
                                 MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    int current_unread = 0;
    int current_starred = 0;
    int current_deleted = 0;
    int unread = 0;
    int starred = 0;
    int deleted = 0;
    
    current_unread = (currentFlags & MessageFlagSeen) == 0;
    current_starred = (currentFlags & MessageFlagFlagged) != 0;
    current_deleted = (currentFlags & MessageFlagDeleted) != 0;
    
    unread = current_unread;
    starred = current_starred;
    deleted = current_deleted;
    if ((mask & MessageFlagSeen) != 0) {
        unread = (flags & MessageFlagSeen) == 0;
    }
    if ((mask & MessageFlagFlagged) != 0) {
        starred = (flags & MessageFlagFlagged) != 0;
    }
    if ((mask & MessageFlagDeleted) != 0) {
        deleted = (flags & MessageFlagDeleted) != 0;
    }
    if (deleted) {
        starred = 0;
        unread = 0;
        flags = (MessageFlag) (flags & ~MessageFlagFlagged);
        flags = (MessageFlag) (flags & ~MessageFlagSeen);
    }

    bool changed = false;
    if ((starred != current_starred) || (unread != current_unread) || (deleted != current_deleted)) {
        changed = true;
    }
    
    if (!changed) {
        return false;
    }

    r = sqlitePrepare("update message set unread = ?, starred = ?, deleted = ? where rowid = ?", &stmt);
    sqlite3_bind_int(stmt, 1, unread);
    sqlite3_bind_int(stmt, 2, starred);
    sqlite3_bind_int(stmt, 3, deleted);
    sqlite3_bind_int64(stmt, 4, rowID);
    r = sqlite3_step(stmt);
    //sqlite3_finalize(stmt);
    sqliteReset(stmt);

    int64_t date = -1;
    r = sqlitePrepare("select date from peopleview where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            date = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);
    changes->modifyPeopleViewID(peopleViewID, date);
    changes->changePeopleViewCount(peopleViewID);

    // TODO: changeMessageCommon() should assume moving == currentMoving and reflects all the callers.
    MCAssert(currentMoving == moving);

    bool current_hidden = current_deleted || currentMoving;
    bool hidden = deleted || moving;

    if (hidden != current_hidden) {
        if (hidden) {
            internalRemoveMessage(rowID, changes, false);
        }
        else {
            // Should crash if rowID is not valid since rowID should be valid at this point.
            AbstractMessage * storedMsg = messageForRowID(rowID);
            if (!adding) {
                internalAddMessage(folderID, rowID, storedMsg, flags, draftsFolderID, changes);
            }
        }
    }
    
    return true;
}

bool MailDB::changeMessageLabel(int64_t messageRowID, int64_t peopleViewID, mailcore::String * label, bool remove, MailDBChanges * changes)
{
    int64_t date = -1;
    sqlite3_stmt * stmt;
    int r;
    r = sqlitePrepare("select date from peopleview where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            date = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);
    changes->modifyPeopleViewID(peopleViewID, date);

    Array * labels = labelsForMessage(messageRowID);
    if (labels != NULL) {
        if (remove) {
            labels->removeObject(label);
        }
        else {
            labels->addObject(label);
        }
        storeLabelsForMessage(messageRowID, labels);
    }

    return true;
}

IndexSet * MailDB::uids(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;
    IndexSet * result = IndexSet::indexSet();
    
    r = sqlitePrepare("select uid from message where folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t uid = sqlite3_column_int64(stmt, 0);
            if (uid == 0) {
                continue;
            }
            result->addIndex(uid);
        } while (1);
    }
    sqliteReset(stmt);

    return result;
}

Array * MailDB::peopleConversations(bool isStarred)
{
    int r;
    sqlite3_stmt * stmt;
    Array * result = Array::array();
    const char * sqlExpression;
    
    if (isStarred) {
        sqlExpression = "select rowid, date, unread from peopleview where starred != 0 order by date desc";
    }
    else {
        sqlExpression = "select rowid, date, unread from peopleview order by date desc";
    }
    r = sqlitePrepare(sqlExpression, &stmt);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t peopleViewRowID = sqlite3_column_int64(stmt, 0);
            int64_t date = sqlite3_column_int64(stmt, 1);
            int unread = sqlite3_column_int(stmt, 2);
            HashMap * conversation = new HashMap();
            conversation->setObjectForKey(MCSTR("id"), Value::valueWithLongLongValue(peopleViewRowID));
            conversation->setObjectForKey(MCSTR("date"), Value::valueWithLongLongValue(date));
            conversation->setObjectForKey(MCSTR("unread"), Value::valueWithBoolValue(unread));
            result->addObject(conversation);
            MC_SAFE_RELEASE(conversation);
        } while (1);
    }
    sqliteReset(stmt);

    MCLog("conversations: %i", result->count());
    
    return result;
}

Array * MailDB::peopleConversationsForFolder(int64_t folderID, bool isUnread)
{
    Array * sortedConversations = peopleConversations(isUnread);
    Array * result = Array::array();
    
    int r;
    sqlite3_stmt * stmt;
    Set * existing = new Set();
    
    r = sqlitePrepare("select peopleviewid from peopleviewfolder where folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t peopleViewRowID = sqlite3_column_int64(stmt, 0);
            existing->addObject(Value::valueWithLongLongValue(peopleViewRowID));
        } while (1);
    }
    sqliteReset(stmt);

    mc_foreacharray(HashMap, conversation, sortedConversations) {
        if (existing->containsObject(conversation->objectForKey(MCSTR("id")))) {
            result->addObject(conversation);
        }
    }
    
    MC_SAFE_RELEASE(existing);
    
    return result;
}

static int compareDisplayName(void * a, void * b, void * context)
{
    String * sa = (String *) a;
    String * sb = (String *) b;
    return sa->lowercaseString()->compare(sb->lowercaseString());
}

static int compareDate(void * a, void * b, void * context)
{
    Array * itemA = (Array *) a;
    Array * itemB = (Array *) b;
    Value * dateA = (Value *) itemA->objectAtIndex(5);
    Value * dateB = (Value *) itemB->objectAtIndex(5);
    if (dateB->longLongValue() < dateA->longLongValue()) {
        return -1;
    }
    else if (dateB->longLongValue() > dateA->longLongValue()) {
        return 1;
    }
    else {
        return 0;
    }
}

static String * veryShortDisplayString(Set * emailSet, Address * address)
{
    if (emailSet->containsObject(address->mailbox()->lowercaseString())) {
        return MCSTR("me");
    }
    else {
        return AddressDisplay::veryShortDisplayStringForAddress(address);
    }
}

static int compareLabels(void * a, void * b, void * context)
{
    String * strA = (String *) a;
    String * strB = (String *) b;
    return strA->lowercaseString()->compare(strB->lowercaseString());
}

static String * cleanMailboxPlus(String * mailbox)
{
    Array * components = mailbox->componentsSeparatedByString(MCSTR("@"));
    if (components->count() != 2) {
        return mailbox;
    }
    String * left = (String *) components->objectAtIndex(0);
    String * right = (String *) components->objectAtIndex(1);
    components = left->componentsSeparatedByString(MCSTR("+"));
    if (components->count() >= 1) {
        left = (String *) components->objectAtIndex(0);
    }
    return left->stringByAppendingUTF8Characters("@")->stringByAppendingString(right);
}

HashMap * MailDB::peopleConversationInfo(int64_t peopleConversationID,
                                         mailcore::HashMap * foldersScores,
                                         int64_t inboxFolderID,
                                         mailcore::Set * emailSet,
                                         mailcore::Set * folderIDToExcludeFromUnread,
                                         MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    HashMap * result = HashMap::hashMap();
    
    result->setObjectForKey(MCSTR("id"), Value::valueWithLongLongValue(peopleConversationID));
    
    AutoreleasePool * pool = new AutoreleasePool();
    
    r = sqlitePrepare("select date, hasattachment from peopleview where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleConversationID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            time_t date = (time_t) sqlite3_column_int64(stmt, 0);
            bool hasAttachment = sqlite3_column_int(stmt, 1);
            time_t currentDate = time(NULL);
            struct tm gmDate;
            struct tm gmCurrentDate;
            gmtime_r(&date, &gmDate);
            gmtime_r(&currentDate, &gmCurrentDate);
            if (gmDate.tm_year == gmCurrentDate.tm_year) {
                DateFormatter * formatter = dateFormatterWithFormatString(MCSTR("M/d"));
                String * dateStr = formatter->stringFromDate(date);
                if (dateStr != NULL) {
                    result->setObjectForKey(MCSTR("datestr"), dateStr);
                }
            }
            else {
                DateFormatter * formatter = dateFormatterWithStyle(DateFormatStyleShort, DateFormatStyleNone);
                String * dateStr = formatter->stringFromDate(date);
                if (dateStr != NULL) {
                    result->setObjectForKey(MCSTR("datestr"), dateStr);
                }
            }
            result->setObjectForKey(MCSTR("timestamp"), Value::valueWithLongLongValue((long long) date));
            result->setObjectForKey(MCSTR("hasattachment"), Value::valueWithBoolValue(hasAttachment));
        }
    }
    sqliteReset(stmt);

    //int count = 0;
    String * listID = NULL;
    bool listIDDisplayName = false;
    String * conversationSubject = NULL;
    String * senderMD5ForGravatar = NULL;
    String * fallbackSenderMD5ForGravatar = NULL;
    String * senderEmail = NULL;
    String * fallbackSenderEmail = NULL;
    Address * mainSender = NULL;
    Address * mainFallbackSender = NULL;
    bool isNotification = false;

    Array * items = Array::array();
    Set * ignoredMessageUniqueIDs = Set::set();

    // Retrieve items for database.
    r = sqlitePrepare("select rowid, unread, starred, folderid, msgid, date, attachments_count, attachment_filename from message where peopleviewid = ? order by date desc", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleConversationID);
    if (r == SQLITE_OK) {
        do {
            AutoreleasePool * pool = new AutoreleasePool();

            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                pool->release();
                break;
            }

            int64_t rowID = sqlite3_column_int64(stmt, 0);
            Value * nbRowID = Value::valueWithLongLongValue(rowID);
            int unread = sqlite3_column_int(stmt, 1);
            Value * nbUnread = Value::valueWithBoolValue(unread);
            int starred = sqlite3_column_int(stmt, 2);
            Value * nbStarred = Value::valueWithBoolValue(starred);
            int64_t folderID = sqlite3_column_int64(stmt, 3);
            Value * nbFolderID = Value::valueWithLongLongValue(folderID);
            const void * cMsgid = sqlite3_column_text16(stmt, 4);
            String * messageID = String::stringWithCharacters((const UChar *) cMsgid);
            int64_t date = sqlite3_column_int64(stmt, 5);
            Value * nbDate = Value::valueWithLongLongValue(date);
            int attachmentsCount = sqlite3_column_int(stmt, 6);
            Value * nbAttachmentsCount = Value::valueWithIntValue(attachmentsCount);
            const void * cAttachmentFilename = sqlite3_column_text16(stmt, 7);
            String * attachmentFilename = String::stringWithCharacters((const UChar *) cAttachmentFilename);

            String * uniqueID = String::string();
            uniqueID->appendString(messageID);
            uniqueID->appendUTF8Format("-%llu", (long long unsigned) date);

            Value * nbScore = (Value *) foldersScores->objectForKey(nbFolderID);
            int score = nbScore == NULL ? 0 : nbScore->intValue();
            if (score < 0) {
                ignoredMessageUniqueIDs->addObject(uniqueID);
            }

            Array * item = Array::array();
            item->addObject(nbRowID);
            item->addObject(nbUnread);
            item->addObject(nbStarred);
            item->addObject(nbFolderID);
            item->addObject(messageID);
            item->addObject(nbDate);
            item->addObject(nbAttachmentsCount);
            if (attachmentFilename == NULL) {
                item->addObject(Null::null());
            }
            else {
                item->addObject(attachmentFilename);
            }

            items->addObject(item);

            pool->release();
        } while (1);
    }
    sqliteReset(stmt);

    // Items to show.
    HashMap * itemsHash = new HashMap();
    for(unsigned int i = 0 ; i < items->count() ; i ++) {
        AutoreleasePool * pool = new AutoreleasePool();

        Array * item = (Array *) items->objectAtIndex(i);

        Value * nbFolderID = (Value *) item->objectAtIndex(3);
        String * messageID = (String *) item->objectAtIndex(4);
        Value * nbDate = (Value *) item->objectAtIndex(5);

        String * uniqueID = String::string();
        uniqueID->appendString(messageID);
        uniqueID->appendUTF8Format("-%llu", (long long unsigned) nbDate->longLongValue());

        // skipped ignored message.
        if (ignoredMessageUniqueIDs->containsObject(uniqueID)) {
            pool->release();
            continue;
        }

        Array * otherItem = (Array *) itemsHash->objectForKey(uniqueID);
        if (otherItem != NULL) {
            Value * vScore = (Value *) foldersScores->objectForKey(nbFolderID);
            int score = vScore == NULL ? 0 : vScore->intValue();

            Value * nbOtherItemFolderID = (Value *) otherItem->objectAtIndex(3);
            Value * vOtherScore = (Value *) foldersScores->objectForKey(nbOtherItemFolderID);
            int otherScore = vOtherScore == NULL ? 0 : vOtherScore->intValue();
            if (score > otherScore) {
                itemsHash->setObjectForKey(uniqueID, item);
            }
        }
        else {
            itemsHash->setObjectForKey(uniqueID, item);
        }

        pool->release();
    }
    Array * itemsToShow = itemsHash->allValues();
    MC_SAFE_RELEASE(itemsHash);

    itemsToShow->sortArray(compareDate, NULL);

    HashMap * msgInfo = nil;

    Set * recipientSet = new Set();
    Array * recipients = new Array();
    Set * senderSet = new Set();
    Array * senders = new Array();
    Array * recipientsEmails = new Array();

    Set * conversationLabelsSet = new Set();
    Set * foldersIDs = new Set();

    String * msgInfoAttachmentFilename = NULL;
    int totalAttachmentsCount = 0;

    int starred = 0;
    int unread = 0;
    for(unsigned int i = 0 ; i < itemsToShow->count() ; i ++) {
        AutoreleasePool * pool = new AutoreleasePool();

        Array * item = (Array *) itemsToShow->objectAtIndex(i);

        Value * nbRowID = (Value *) item->objectAtIndex(0);
        Value * nbUnread = (Value *) item->objectAtIndex(1);
        Value * nbStarred = (Value *) item->objectAtIndex(2);
        Value * nbFolderID = (Value *) item->objectAtIndex(3);
        String * messageID = (String *) item->objectAtIndex(4);
        Value * nbDate = (Value *) item->objectAtIndex(5);
        Value * nbAttachmentsCount = (Value *) item->objectAtIndex(6);
        String * attachmentFilename = (String *) item->objectAtIndex(7);
        if (attachmentFilename == (String *) Null::null()) {
            attachmentFilename = NULL;
        }

        foldersIDs->addObject(nbFolderID);

        String * uniqueID = String::string();
        uniqueID->appendString(messageID);
        uniqueID->appendUTF8Format("-%llu", (long long unsigned) nbDate->longLongValue());

        if (!folderIDToExcludeFromUnread->containsObject(nbFolderID)) {
            // has unread?
            if (nbUnread->boolValue()) {
                unread = 1;
            }
        }

        // has starred?
        if (nbStarred->boolValue()) {
            starred = 1;
        }

        int64_t messageRowID = nbRowID->longLongValue();

        bool includeMsg = true;

        totalAttachmentsCount += nbAttachmentsCount->intValue();
        if (msgInfo != NULL) {
            includeMsg = false;

            if (msgInfoAttachmentFilename == NULL) {
                msgInfoAttachmentFilename = attachmentFilename;
            }
        }
        else {
            msgInfoAttachmentFilename = attachmentFilename;

            msgInfo = new HashMap();
            msgInfo->setObjectForKey(MCSTR("id"), nbRowID);
            msgInfo->setObjectForKey(MCSTR("folder"), nbFolderID);
            msgInfo->setObjectForKey(MCSTR("uniqueid"), uniqueID);
        }

        // Should crash if messageRowID is not valid since it should be valid at this point.
        AbstractMessage * message = messageForRowID(messageRowID);
        mc_foreacharray(String, headerName, s_notificationHeaders) {
            if (message->header()->extraHeaderValueForName(headerName) != NULL) {
                isNotification = true;
                break;
            }
        }

        Array * msgLabels = labelsForMessage(messageRowID);
        conversationLabelsSet->addObjectsFromArray(msgLabels);

        // Collect recipient and senders.
        if (message->header()->from() != NULL) {
            String * mailbox = message->header()->from()->mailbox()->lowercaseString();
            if (!recipientSet->containsObject(mailbox)) {
                recipientSet->addObject(mailbox);
                recipients->addObject(veryShortDisplayString(emailSet, message->header()->from()));
                recipientsEmails->addObject(mailbox);
            }
            if (!senderSet->containsObject(mailbox)) {
                senderSet->addObject(mailbox);
                senders->addObject(veryShortDisplayString(emailSet, message->header()->from()));
            }
        }
        else if (message->header()->sender() != NULL) {
            String * mailbox = message->header()->sender()->mailbox()->lowercaseString();
            if (!recipientSet->containsObject(mailbox)) {
                recipientSet->addObject(mailbox);
                recipients->addObject(veryShortDisplayString(emailSet, message->header()->sender()));
                recipientsEmails->addObject(mailbox);
            }
            if (!senderSet->containsObject(mailbox)) {
                senderSet->addObject(mailbox);
                senders->addObject(veryShortDisplayString(emailSet, message->header()->sender()));
            }
        }
        if (message->header()->to() != NULL) {
            mc_foreacharray(Address, address, message->header()->to()) {
                String * mailbox = address->mailbox()->lowercaseString();
                if (!recipientSet->containsObject(mailbox)) {
                    recipientSet->addObject(mailbox);
                    recipients->addObject(veryShortDisplayString(emailSet, address));
                    recipientsEmails->addObject(mailbox);
                }
            }
        }
        if (message->header()->cc() != NULL) {
            mc_foreacharray(Address, address, message->header()->cc()) {
                if (!recipientSet->containsObject(address->mailbox()->lowercaseString())) {
                    recipientSet->addObject(address->mailbox()->lowercaseString());
                    recipients->addObject(veryShortDisplayString(emailSet, address));
                    recipientsEmails->addObject(address->mailbox()->lowercaseString());
                }
            }
        }

        String * sender = NULL;
        Address * senderMailbox = NULL;
        if (message->header()->from() != NULL) {
            senderMailbox = message->header()->from();
        }
        else if (message->header()->sender() != NULL) {
            senderMailbox = message->header()->sender();
        }
        if (senderMailbox != NULL) {
            sender = AddressDisplay::veryShortDisplayStringForAddress(senderMailbox);
            if (senderMD5ForGravatar == NULL) {
                if (senderMailbox->mailbox() != NULL) {
                    if (!emailSet->containsObject(senderMailbox->mailbox())) {
                        senderMD5ForGravatar = md5String(senderMailbox->mailbox()->lowercaseString()->dataUsingEncoding("utf-8"));
                        senderMD5ForGravatar->retain();
                        senderEmail = senderMailbox->mailbox();
                        senderEmail->retain();
                        mainSender = senderMailbox;
                        mainSender->retain();
                    }
                }
            }
            if (fallbackSenderMD5ForGravatar == NULL) {
                fallbackSenderMD5ForGravatar = md5String(senderMailbox->mailbox()->lowercaseString()->dataUsingEncoding("utf-8"));
                fallbackSenderMD5ForGravatar->retain();
                fallbackSenderEmail = senderMailbox->mailbox();
                fallbackSenderEmail->retain();
                mainFallbackSender = senderMailbox;
                mainFallbackSender->retain();
            }
        }
        else {
            MCLog("WARNING: from and sender are null %s", MCUTF8DESC(message));
        }

        if (!includeMsg) {
            pool->release();
            continue;
        }

        if (conversationSubject == NULL) {
            String * subject = message->header()->partialExtractedSubject();
            conversationSubject = subject;
            if (conversationSubject != NULL) {
                conversationSubject = (String *) conversationSubject->copy()->autorelease();
                conversationSubject->replaceOccurrencesOfString(MCSTR("\n"), MCSTR(" "));
                while (conversationSubject->replaceOccurrencesOfString(MCSTR("  "), MCSTR(" ")) > 0) {
                    // do nothing
                }
                result->setObjectForKey(MCSTR("subject"), conversationSubject);
            }
        }

        if (listID == NULL) {
            String * currentListID = message->header()->extraHeaderValueForName(MCSTR("List-ID"));
            if (currentListID != NULL) {
                Address * address = Address::addressWithRFC822String(currentListID);
                if ((address != NULL) && (address->mailbox() != NULL)) {
                    mc_foreacharray(String, suffix, s_listIDSuffixWhitelist) {
                        if (address->mailbox()->hasSuffix(suffix)) {
                            listID = currentListID;
                            break;
                        }
                    }
                }
            }
        }
        if (listID == NULL) {
            if (message->header()->from() != NULL) {
                String * mailbox = message->header()->from()->mailbox()->lowercaseString();
                mailbox = cleanMailboxPlus(mailbox);
                listID = (String *) s_senderMapping->objectForKey(mailbox);
                if (listID != NULL) {
                    listIDDisplayName = true;
                }
                else {
                    mc_foreachhashmapKeyAndValue(String, key, String, value, s_senderSuffixMapping) {
                        if (mailbox->hasSuffix(key)) {
                            listID = value;
                            listIDDisplayName = true;
                        }
                    }
                }
                if (listID == NULL) {
                    if (mailbox->hasPrefix(MCSTR("noreply@")) || mailbox->hasPrefix(MCSTR("no-reply@")) || mailbox->hasPrefix(MCSTR("no_reply@"))) {
                        isNotification = true;
                    }
                    mc_foreacharray(Address, replyToAddress, message->header()->replyTo()) {
                        String * replyMailbox = replyToAddress->mailbox()->lowercaseString();
                        if (replyMailbox->hasPrefix(MCSTR("noreply@")) || replyMailbox->hasPrefix(MCSTR("no-reply@")) || replyMailbox->hasPrefix(MCSTR("no_reply@"))) {
                            isNotification = true;
                        }
                    }
                }
            }
        }
        if (listID != NULL) {
            isNotification = true;
        }
        if (message->header()->extraHeaderValueForName(MCSTR("X-MC-User")) != NULL) {
            listID = NULL;
        }

        if (sender != NULL) {
            if (emailSet->containsObject(senderMailbox->mailbox())) {
                msgInfo->setObjectForKey(MCSTR("sender"), MCSTR("me"));
            }
            else {
                msgInfo->setObjectForKey(MCSTR("sender"), sender);
            }
        }

        String * snippet = renderMessageSummary(messageRowID, NULL, NULL, NULL);
        if (snippet != NULL) {
            if (snippet->length() > 256) {
                snippet = snippet->substringToIndex(256);
            }
            msgInfo->setObjectForKey(MCSTR("snippet"), snippet);
        }

        pool->release();
    }

    if (msgInfoAttachmentFilename != NULL) {
        result->setObjectForKey(MCSTR("attachment-filename"), msgInfoAttachmentFilename);
    }
    result->setObjectForKey(MCSTR("attachments-count"), Value::valueWithIntValue(totalAttachmentsCount));

    result->setObjectForKey(MCSTR("folders"), foldersIDs->allObjects());
    MC_SAFE_RELEASE(foldersIDs);

    Array * conversationLabels = conversationLabelsSet->allObjects()->sortedArray(compareLabels, NULL);
    result->setObjectForKey(MCSTR("labels"), conversationLabels);
    MC_SAFE_RELEASE(conversationLabelsSet);

    result->setObjectForKey(MCSTR("unread"), Value::valueWithBoolValue(unread));
    result->setObjectForKey(MCSTR("starred"), Value::valueWithBoolValue(starred));

    if (senderMD5ForGravatar != NULL) {
        result->setObjectForKey(MCSTR("sender-md5"), senderMD5ForGravatar);
        result->setObjectForKey(MCSTR("sender"), senderEmail);
        String * singleRecipient = AddressDisplay::shortDisplayStringForAddress(mainSender);
        result->setObjectForKey(MCSTR("single-recipient"), singleRecipient);
    }
    else if (fallbackSenderMD5ForGravatar != NULL) {
        result->setObjectForKey(MCSTR("sender-md5"), fallbackSenderMD5ForGravatar);
        result->setObjectForKey(MCSTR("sender"), fallbackSenderEmail);
        String * singleRecipient = AddressDisplay::shortDisplayStringForAddress(mainFallbackSender);
        result->setObjectForKey(MCSTR("single-recipient"), singleRecipient);
    }

    // sort recipients and recipientsEmails but not senders.
    recipients->sortArray(compareDisplayName, NULL);
    recipientsEmails->sortArray(compareDisplayName, NULL);
    String * recipientMD5 = md5String(hermes::fastSerializedData(recipientsEmails));

    result->setObjectForKey(MCSTR("senders"), senders);
    result->setObjectForKey(MCSTR("recipients"), recipients);
    result->setObjectForKey(MCSTR("recipients-md5"), recipientMD5);

    MC_SAFE_RELEASE(senders);
    MC_SAFE_RELEASE(senderSet);
    MC_SAFE_RELEASE(recipients);
    MC_SAFE_RELEASE(recipientSet);
    MC_SAFE_RELEASE(recipientsEmails);

    if (listID != NULL) {
        if (listIDDisplayName) {
            result->setObjectForKey(MCSTR("listid"), listID);
        }
        else {
            Address * address = Address::addressWithRFC822String(listID);
            String * simplifiedListID = (String *) address->mailbox()->copy();
            int location = simplifiedListID->locationOfString(MCSTR("."));
            if (location != -1) {
                simplifiedListID->deleteCharactersInRange(RangeMake(location, UINT64_MAX));
            }
            result->setObjectForKey(MCSTR("listid"), simplifiedListID);
            MC_SAFE_RELEASE(simplifiedListID);
        }
    }
    result->setObjectForKey(MCSTR("notification"), Value::valueWithBoolValue(isNotification));
    if (msgInfo != NULL) {
        Array * messages = Array::arrayWithObject(msgInfo);
        result->setObjectForKey(MCSTR("messages"), messages);
        MC_SAFE_RELEASE(msgInfo);
    }
    else {
        result->setObjectForKey(MCSTR("messages"), Array::array());
    }

    MC_SAFE_RELEASE(senderMD5ForGravatar);
    MC_SAFE_RELEASE(fallbackSenderMD5ForGravatar);
    MC_SAFE_RELEASE(mainSender);
    MC_SAFE_RELEASE(mainFallbackSender);
    MC_SAFE_RELEASE(senderEmail);
    MC_SAFE_RELEASE(fallbackSenderEmail);
    
    pool->release();
    
    return result;
}

Array * MailDB::messagesForPeopleConversation(int64_t peopleConversationID,
                                              HashMap * foldersScores)
{
    int r;
    sqlite3_stmt * stmt;
    HashMap * uniqueIDs = new HashMap();

    Array * items = Array::array();
    Set * ignoredMessageUniqueIDs = Set::set();

    r = sqlitePrepare("select rowid, unread, starred, uid, folderid, msgid, date from message where peopleviewid = ? order by date desc", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleConversationID);
    if (r == SQLITE_OK) {
        do {
            AutoreleasePool * pool = new AutoreleasePool();

            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                pool->release();
                break;
            }

            int64_t rowID = sqlite3_column_int64(stmt, 0);
            Value * nbRowID = Value::valueWithLongLongValue(rowID);
            int unread = sqlite3_column_int(stmt, 1);
            Value * nbUnread = Value::valueWithBoolValue(unread);
            int starred = sqlite3_column_int(stmt, 2);
            Value * nbStarred = Value::valueWithBoolValue(starred);
            int64_t uid = sqlite3_column_int64(stmt, 3);
            Value * nbUid = Value::valueWithLongLongValue(uid);
            int64_t folderID = sqlite3_column_int64(stmt, 4);
            Value * nbFolderID = Value::valueWithLongLongValue(folderID);
            const void * cMsgid = sqlite3_column_text16(stmt, 5);
            String * messageID = String::stringWithCharacters((const UChar *) cMsgid);
            int64_t date = sqlite3_column_int64(stmt, 6);
            Value * nbDate = Value::valueWithLongLongValue(date);

            String * uniqueID = String::string();
            uniqueID->appendString(messageID);
            uniqueID->appendUTF8Format("-%llu", (long long unsigned) date);

            Value * nbScore = NULL;
            if (foldersScores != NULL) {
                nbScore = (Value *) foldersScores->objectForKey(nbFolderID);
                if (nbScore == NULL) {
                    nbScore = (Value *) foldersScores->objectForKey(Value::valueWithLongLongValue(-1));
                }
            }
            int score = nbScore == NULL ? 0 : nbScore->intValue();
            if (score < 0) {
                ignoredMessageUniqueIDs->addObject(uniqueID);
            }

            Array * item = Array::array();
            item->addObject(nbRowID);
            item->addObject(nbUnread);
            item->addObject(nbStarred);
            item->addObject(nbUid);
            item->addObject(nbFolderID);
            item->addObject(messageID);
            item->addObject(nbDate);

            items->addObject(item);

            pool->release();
        } while (1);
    }
    sqliteReset(stmt);

    Array * result = Array::array();

    for(unsigned int i = 0 ; i < items->count() ; i ++) {
        AutoreleasePool * pool = new AutoreleasePool();

        Array * item = (Array *) items->objectAtIndex(i);

        Value * nbRowID = (Value *) item->objectAtIndex(0);
        Value * nbUnread = (Value *) item->objectAtIndex(1);
        Value * nbStarred = (Value *) item->objectAtIndex(2);
        Value * nbUid = (Value *) item->objectAtIndex(3);
        Value * nbFolderID = (Value *) item->objectAtIndex(4);
        String * messageID = (String *) item->objectAtIndex(5);
        Value * nbDate = (Value *) item->objectAtIndex(6);

        Value * nbScore = NULL;
        if (foldersScores != NULL) {
            nbScore = (Value *) foldersScores->objectForKey(nbFolderID);
            if (nbScore == NULL) {
                nbScore = (Value *) foldersScores->objectForKey(Value::valueWithLongLongValue(-1));
            }
        }
        int score = nbScore == NULL ? 0 : nbScore->intValue();

        String * uniqueID = String::string();
        uniqueID->appendString(messageID);
        uniqueID->appendUTF8Format("-%llu", (long long unsigned) nbDate->longLongValue());

        if (ignoredMessageUniqueIDs->containsObject(uniqueID)) {
            pool->release();
            continue;
        }

        bool skip = false;

        Value * vIdx = (Value *) uniqueIDs->objectForKey(uniqueID);
        if (vIdx != NULL) {
            unsigned int idx = vIdx->unsignedIntValue();
            HashMap * existingInfo = (HashMap *) result->objectAtIndex(idx);
            if (existingInfo != NULL) {
                Value * vExistingFolderID = (Value *) existingInfo->objectForKey(MCSTR("folderid"));
                Value * vExistingScore = (Value *) foldersScores->objectForKey(vExistingFolderID);
                int existingScore = vExistingScore == NULL ? 0 : vExistingScore->intValue();
                if (score > existingScore) {
                    skip = true;
                    existingInfo->setObjectForKey(MCSTR("rowid"), nbRowID);
                    existingInfo->setObjectForKey(MCSTR("unread"), nbUnread);
                    existingInfo->setObjectForKey(MCSTR("starred"), nbStarred);
                    existingInfo->setObjectForKey(MCSTR("uid"), nbUid);
                    existingInfo->setObjectForKey(MCSTR("folderid"), nbFolderID);
                }
                else {
                    skip = true;
                }
            }
        }

        if (skip) {
            pool->release();
            continue;
        }

        HashMap * info = HashMap::hashMap();
        info->setObjectForKey(MCSTR("rowid"), nbRowID);
        info->setObjectForKey(MCSTR("unread"), nbUnread);
        info->setObjectForKey(MCSTR("starred"), nbStarred);
        info->setObjectForKey(MCSTR("uid"), nbUid);
        info->setObjectForKey(MCSTR("folderid"), nbFolderID);
        info->setObjectForKey(MCSTR("msgid"), messageID);
        info->setObjectForKey(MCSTR("date"), nbDate);
        result->addObject(info);

        uniqueIDs->setObjectForKey(uniqueID, Value::valueWithUnsignedIntValue(result->count() - 1));

        pool->release();
    }

    MC_SAFE_RELEASE(uniqueIDs);
    
    return result;
}

void MailDB::removeMessage(int64_t messageRowID, MailDBChanges * changes)
{
    internalRemoveMessage(messageRowID, changes, true);
}

void MailDB::removeMessageUid(int64_t folderID, uint32_t uid, MailDBChanges * changes)
{
    internalRemoveMessageUid(folderID, uid, changes, true);
}

void MailDB::internalRemoveMessageUid(int64_t folderID, uint32_t uid, MailDBChanges * changes, bool removeEntry)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t conversationRowID = -1;
    int64_t peopleViewRowID = -1;
    int64_t messageRowID = -1;
    String * basename = NULL;

    r = sqlitePrepare("select rowid, convid, peopleviewid, filename from message where uid = ? and folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, uid);
    sqlite3_bind_int64(stmt, 2, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            const void * basenameUnichars = NULL;
            messageRowID = sqlite3_column_int64(stmt, 0);
            conversationRowID = sqlite3_column_int64(stmt, 1);
            peopleViewRowID = sqlite3_column_int64(stmt, 2);
            basenameUnichars = sqlite3_column_text16(stmt, 3);
            basename = String::stringWithCharacters((const UChar *) basenameUnichars);
            if (basename != NULL) {
                if (basename->length() == 0) {
                    basename = NULL;
                }
            }
        }
    }
    sqliteReset(stmt);

    internalCommonRemoveMessage(messageRowID, folderID, uid, peopleViewRowID, conversationRowID, changes, removeEntry, basename);
}

void MailDB::internalRemoveMessage(int64_t messageRowID, MailDBChanges * changes, bool removeEntry)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t conversationRowID = -1;
    int64_t peopleViewRowID = -1;
    int64_t folderID = -1;
    int32_t uid = 0;
    String * basename = NULL;

    indexRemoveMessage(messageRowID);
    removeLabelsForMessage(messageRowID);
    removeSearchMetaForMessage(messageRowID);
    removePartsForMessage(messageRowID);

    time_t currentTime = time(NULL);
    if ((mDebugLastLogDate == (time_t) -1) || ((currentTime - mDebugLastLogDate) >= 1)) {
        LOG_ERROR("remove internal message %lli %i", messageRowID, removeEntry);
        mDebugLastLogDate = currentTime;
    }

    r = sqlitePrepare("select uid, convid, peopleviewid, folderid, filename from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            const void * basenameUnichars = NULL;
            uid = (uint32_t) sqlite3_column_int64(stmt, 0);
            conversationRowID = sqlite3_column_int64(stmt, 1);
            peopleViewRowID = sqlite3_column_int64(stmt, 2);
            folderID = sqlite3_column_int64(stmt, 3);
            basenameUnichars = sqlite3_column_text16(stmt, 4);
            basename = String::stringWithCharacters((const UChar *) basenameUnichars);
            if (basename != NULL) {
                if (basename->length() == 0) {
                    basename = NULL;
                }
            }
        }
    }
    sqliteReset(stmt);

    internalCommonRemoveMessage(messageRowID, folderID, uid, peopleViewRowID, conversationRowID, changes, removeEntry, basename);
}

void MailDB::internalCommonRemoveMessage(int64_t messageRowID, int64_t folderID, uint32_t uid,
                                         int64_t peopleViewRowID, int64_t conversationRowID,
                                         MailDBChanges * changes, bool removeEntry,
                                         String * basename)
{
    sqlite3_stmt * stmt;
    int r;
    
    if (removeEntry) {
        r = sqlitePrepare("delete from message where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, messageRowID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);

        String * key = String::stringWithUTF8Format("msg-%lld", (long long) messageRowID);
        mKVDB->removeObjectForKey(key);
        key = String::stringWithUTF8Format("msg-%lld-p", (long long) messageRowID);
        mKVDB->removeObjectForKey(key);
        mSerializedMessageCache->removeObjectForKey(Value::valueWithLongLongValue((long long) messageRowID));

        if (basename != NULL) {
            String * filename = localMessageFilenameWithBasename(basename);
            unlink(filename->fileSystemRepresentation());
        }
    }
    else {
        // change people view ID of message
        r = sqlitePrepare("update message set convid = -1, peopleviewid = -1 where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, messageRowID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }

    if (peopleViewRowID != -1) {
        changes->changePeopleViewCount(peopleViewRowID);
        changes->modifyPeopleViewID(peopleViewRowID, -1);
        sqliteRemoveFolderForPeopleViewID(peopleViewRowID, folderID, changes);
    }
    
    sqliteCheckRemoveConversationID(conversationRowID);
    sqliteCheckRemovePeopleViewID(peopleViewRowID, changes);
}

int64_t MailDB::addFolder(mailcore::String * folderPath)
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("insert into folder (path) values (?)", &stmt);
    sqlite3_bind_text16(stmt, 1, folderPath->unicodeCharacters(), -1, SQLITE_STATIC);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    return sqlite3_last_insert_rowid(mSqlite);
}

void MailDB::validateFolder(mailcore::String * folderPath, uint32_t uidValidity, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    bool changed = false;
    int64_t folderID = -1;
    uint32_t storedUidValidity = 0;

    r = sqlitePrepare("select rowid, uidvalidity from folder where path = ?", &stmt);
    sqlite3_bind_text16(stmt, 1, folderPath->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            folderID = sqlite3_column_int64(stmt, 0);
            storedUidValidity = (uint32_t) sqlite3_column_int64(stmt, 1);
            if (storedUidValidity != uidValidity) {
                changed = true;
            }
        }
    }
    sqliteReset(stmt);

    if (!changed) {
        return;
    }

    LOG_ERROR("uid validity changed: new: %llu vs old: %llu", (unsigned long long) uidValidity, (unsigned long long) storedUidValidity);
    r = sqlitePrepare("update folder set uidvalidity = ? where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, uidValidity);
    sqlite3_bind_int64(stmt, 2, folderID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    // reset zen notification
    r = sqlitePrepare("update folder set lastseenuid = 0 where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    Array * messageRowIDs;

    messageRowIDs = new Array();
    r = sqlitePrepare("select rowid from message where folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t rowID = sqlite3_column_int64(stmt, 0);
            messageRowIDs->addObject(Value::valueWithLongLongValue(rowID));
        } while (1);
    }
    sqliteReset(stmt);

    mc_foreacharray(Value, vRowID, messageRowIDs) {
        removeMessage(vRowID->longLongValue(), changes);
    }

    MC_SAFE_RELEASE(messageRowIDs);
}

void MailDB::removeFolder(mailcore::String * folderPath, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    Array * messageRowIDs;

    messageRowIDs = new Array();
    r = sqlitePrepare("select rowid from folder where path = ?", &stmt);
    sqlite3_bind_text16(stmt, 1, folderPath->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t rowID = sqlite3_column_int64(stmt, 0);
            messageRowIDs->addObject(Value::valueWithLongLongValue(rowID));
        } while (1);
    }
    sqliteReset(stmt);

    mc_foreacharray(Value, vRowID, messageRowIDs) {
        removeMessage(vRowID->longLongValue(), changes);
    }

    r = sqlitePrepare("delete from folder where path = ?", &stmt);
    sqlite3_bind_text16(stmt, 1, folderPath->unicodeCharacters(), -1, SQLITE_STATIC);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    MC_SAFE_RELEASE(messageRowIDs);
}

HashMap * MailDB::folders()
{
    int r;
    sqlite3_stmt * stmt;
    HashMap * result = HashMap::hashMap();
    
    r = sqlitePrepare("select rowid, path from folder", &stmt);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t folderID = sqlite3_column_int64(stmt, 0);
            const UChar * folderPathCharacters = (UChar *) sqlite3_column_text16(stmt, 1);
            String * folderPath = String::stringWithCharacters(folderPathCharacters);
            result->setObjectForKey(folderPath, Value::valueWithLongLongValue(folderID));
        } while (1);
    }
    sqliteReset(stmt);

    return result;
}

void MailDB::storeValueForKey(String * key, Data * value)
{
    mKVDB->setObjectForKey(key, value);
}

Data * MailDB::retrieveValueForKey(String * key)
{
    return mKVDB->objectForKey(key);
}

void MailDB::removeValueForKey(String * key)
{
    mKVDB->removeObjectForKey(key);
}

String * MailDB::folderPathForFolderID(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;
    String * folderPath = NULL;
    
    r = sqlitePrepare("select path from folder where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            const UChar * folderPathCharacters = (UChar *) sqlite3_column_text16(stmt, 0);
            folderPath = String::stringWithCharacters(folderPathCharacters);
        }
    }
    sqliteReset(stmt);

    return folderPath;
}

int64_t MailDB::rowIDForMessage(int64_t folderID, uint32_t uid)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t rowID = -1;
    
    r = sqlitePrepare("select rowid from message where uid = ? and folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, uid);
    sqlite3_bind_int64(stmt, 2, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowID = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    return rowID;
}

mailcore::Data * MailDB::retrieveDataForLocalPartWithUniqueID(int64_t messageRowID, mailcore::String * uniqueID)
{
    String * filename = filenameForRowID(messageRowID);
    if (filename == NULL) {
        return NULL;
    }
    MessageParser * parser = MessageParser::messageParserWithContentsOfFile(filename);
    Attachment * part = (Attachment *) parser->partForUniqueID(uniqueID);
    Data * result = part->data();
    MC_SAFE_RETAIN(result);
    result->autorelease();
    return result;
}

Data * MailDB::retrieveDataForPart(int64_t messageRowID, mailcore::String * partID)
{
    String * key = String::stringWithUTF8Format("part-%lld-%s", (long long) messageRowID, MCUTF8(partID));
    return (Data *) mKVDB->objectForKey(key);
}

void MailDB::storeDataForPart(int64_t messageRowID,
                              String * partID, Data * data,
                              MailDBChanges * changes)
{
    AutoreleasePool * pool = new AutoreleasePool();
    String * dataKey = String::stringWithUTF8Format("part-%lld-%s", (long long) messageRowID, MCUTF8(partID));
    mKVDB->setObjectForKey(dataKey, data);
    String * key = String::stringWithUTF8Format("part-%lld", (long long) messageRowID);
    Data * encodedInfo = mKVDB->objectForKey(key);
    Array * info;
    if (encodedInfo != NULL) {
        info = (Array *) hermes::objectWithFastSerializedData(encodedInfo);
    }
    else {
        info = Array::array();
    }
    info->addObject(dataKey);
    mKVDB->setObjectForKey(key, hermes::fastSerializedData(info));
    changes->addMessagePart(messageRowID, partID);
    pool->release();
}

void MailDB::removePartsForMessage(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("part-%lld", (long long) messageRowID);
    Data * encodedInfo = mKVDB->objectForKey(key);
    if (encodedInfo == NULL) {
        return;
    }
    Array * info = (Array *) hermes::objectWithFastSerializedData(encodedInfo);
    mc_foreacharray(String, partKey, info) {
        mKVDB->removeObjectForKey(partKey);
    }
    mKVDB->removeObjectForKey(key);
    
}

int64_t MailDB::originalMessageRowID(int64_t messageRowID)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t originalRowID = -1;

    r = sqlitePrepare("select original_messageid from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            originalRowID = (int64_t) sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    if (originalRowID == -1) {
        originalRowID = messageRowID;
    }

    return originalRowID;
}


static bool hasMessagePartForIMAPMultipart(IMAPMultipart * part);
static bool hasMessagePartForIMAPMessagePart(IMAPMessagePart * part);

static bool hasMessagePart(AbstractPart * part)
{
    if (part->className()->isEqual(MCSTR("mailcore::IMAPMultipart"))) {
        return hasMessagePartForIMAPMultipart((IMAPMultipart *) part);
    }
    else if (part->className()->isEqual(MCSTR("mailcore::IMAPMessagePart"))) {
        return hasMessagePartForIMAPMessagePart((IMAPMessagePart *) part);
    }
    else {
        return false;
    }
}

static bool hasMessagePartForIMAPMultipart(IMAPMultipart * part)
{
    bool result = false;
    mc_foreacharray(AbstractPart, child, part->parts()) {
        if (hasMessagePart(child)) {
            result = true;
            break;
        }
    }
    return result;
}

static bool hasMessagePartForIMAPMessagePart(IMAPMessagePart * part)
{
    return true;
}

String * MailDB::renderMessageSummary(int64_t messageRowID,
                                      Array * requiredParts,
                                      bool * p_hasMessagePart,
                                      bool * p_shouldFetchFullMessage)
{
    String * key = new String();
    key->appendUTF8Characters("msg-preview-");
    key->appendUTF8Format("%lld", (long long) messageRowID);
    Data * data = mKVDB->objectForKey(key);
    key->release();
    if (data != NULL) {
        if (p_hasMessagePart != NULL) {
            * p_hasMessagePart = false;
        }
        if (p_shouldFetchFullMessage != NULL) {
            * p_shouldFetchFullMessage = false;
        }
        return data->stringWithCharset("utf-8");
    }
    
    SummaryHelper * helper = new SummaryHelper();
    helper->setDB(this);
    helper->setMessageRowID(originalMessageRowID(messageRowID));

    // Should NOT crash if messageRowID is not valid since rendering could be asynchronous.
    AbstractMessage * storedMsg = messageForRowIDNoAssert(messageRowID);

    bool resultHasMessagePart = false;
    bool shouldFetchFullMessage = false;
    String * html = NULL;
    if (storedMsg != NULL) {
        if (storedMsg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
            if (isMessageWithoutBodystructure(storedMsg)) {
                MessageParser * parsedMsg = storedParsedMessage(messageRowID);
                if (parsedMsg != NULL) {
                    html = parsedMsg->htmlRenderingWithDataCallback(helper, helper);
                }
                else {
                    html = NULL;
                    shouldFetchFullMessage = true;
                }
                resultHasMessagePart = false;
            }
            else {
                MessageParser * parsedMsg = storedParsedMessage(messageRowID);
                if (parsedMsg != NULL) {
                    html = parsedMsg->htmlRenderingWithDataCallback(helper, helper);
                }
                else {
                    html = ((IMAPMessage *) storedMsg)->htmlRendering(NULL, helper, helper);
                    resultHasMessagePart = hasMessagePart(((IMAPMessage *) storedMsg)->mainPart());
                }
            }
        }
        else {
            MessageParser * parser = messageParserForRowID(messageRowID);
            html = parser->htmlRenderingWithDataCallback(helper, helper);
        }
    }
    if (requiredParts != NULL) {
        requiredParts->addObjectsFromArray(helper->requiredParts());
    }
    String * result = NULL;
    if (html != NULL) {
        result = html->flattenHTMLAndShowBlockquoteAndLink(false, false);
        result = result->stripWhitespace();
        result = result->substringToIndex(256);

        // Store.
        key = new String();
        key->appendUTF8Characters("msg-preview-");
        key->appendUTF8Format("%lld", (long long) messageRowID);
        mKVDB->setObjectForKey(key, result->dataUsingEncoding("utf-8"));
        key->release();
        
        String * contentToIndex = html->flattenHTMLAndShowBlockquoteAndLink(true, true);
        indexSetMessageSummary(messageRowID, storedMsg, contentToIndex);
    }
    
    MC_SAFE_RELEASE(helper);
    
    if (p_hasMessagePart != NULL) {
        * p_hasMessagePart = resultHasMessagePart;
    }
    if (p_shouldFetchFullMessage != NULL) {
        * p_shouldFetchFullMessage = shouldFetchFullMessage;
    }

    return result;
}

HashMap * MailDB::addressToHashMap(Address * address)
{
    if (address == NULL) {
        return NULL;
    }

    HashMap * result = HashMap::hashMap();
    if (address->displayName() != NULL) {
        result->setObjectForKey(MCSTR("display-name"), AddressDisplay::sanitizeDisplayName(address->displayName()));
    }
    if (address->mailbox() != NULL) {
        result->setObjectForKey(MCSTR("mailbox"), address->mailbox());
    }
    return result;
}

Array * MailDB::addressesToHashMaps(Array * /* HashMap */ addresses)
{
    if (addresses == NULL) {
        return NULL;
    }
    if (addresses->count() == 0) {
        return NULL;
    }

    Array * result = Array::array();
    mc_foreacharray(Address, address, addresses) {
        result->addObject(addressToHashMap(address));
    }
    return result;
}

static void findImagesInXML(XMLElement * element, Array * result)
{
    if (element->name()->isEqual(MCSTR("img"))) {
        result->addObject(element);
    }
    for(unsigned int i = 0 ; i < element->childrenCount() ; i ++) {
        XMLNode * node = element->childAtIndex(i);
        if (node->className()->isEqual(MCSTR("mailcore::XMLElement"))) {
            XMLElement * subElement = (XMLElement *) node;
            findImagesInXML(subElement, result);
        }
    }
}

static Array * contentIDURLStringsForCID(String * contentID)
{
    Array * result = Array::array();
    result->addObject(MCSTR("cid:")->stringByAppendingString(contentID));
    result->addObject(MCSTR("cid:")->stringByAppendingString(contentID->urlEncodedString()));

    Array * components;
    components = contentID->componentsSeparatedByString(MCSTR("/"));
    if (components->count() >= 2) {
        Array * resultComponents;

        resultComponents = Array::array();
        mc_foreacharray(String, component, components) {
            resultComponents->addObject(component->urlEncodedString());
        }
        result->addObject(MCSTR("cid:")->stringByAppendingString(resultComponents->componentsJoinedByString(MCSTR("/"))));
    }

    return result;
}

static HashMap * imageAttachmentsForMessage(AbstractMessage * storedMsg, String * htmlContent)
{
    Array * images = Array::array();
    if (htmlContent != NULL) {
        htmlContent = HTMLCleaner::cleanHTML(htmlContent);
        XMLDocument * doc = XMLDocument::documentWithHTMLData(htmlContent->dataUsingEncoding());
        findImagesInXML(doc->root(), images);
    }
    Set * urlSet = Set::set();
    mc_foreacharray(XMLElement, imageElement, images) {
        String * src = imageElement->attributeForName(MCSTR("src"));
        if (src != NULL) {
            if (src->hasPrefix(MCSTR("cid:"))) {
                urlSet->addObject(src);
            }
        }
    }
    HashMap * result = HashMap::hashMap();
    Array * cidImageParts = Array::array();
    HashMap * cidPartsMapping = HashMap::hashMap();
    Array * attachments = storedMsg->attachments();
    {
        mc_foreacharray(AbstractPart, part, attachments) {
            if (part->contentID() != NULL) {
                bool isInBody = false;
                Array * possibleURLs = contentIDURLStringsForCID(part->contentID());
                mc_foreacharray(String, url, possibleURLs) {
                    if (urlSet->containsObject(url)) {
                        isInBody = true;
                        HashMap * partBasicInfo = HashMap::hashMap();
                        partBasicInfo->setObjectForKey(MCSTR("uniqueID"), part->uniqueID());
                        if (part->filename() != NULL) {
                            partBasicInfo->setObjectForKey(MCSTR("filename"), part->filename());
                        }
                        cidPartsMapping->setObjectForKey(url, partBasicInfo);
                    }
                }
                if (isInBody) {
                    continue;
                }
            }
            if (isImageAttachment(part)) {
                cidImageParts->addObject(part);
            }
        }
    }
    {
        mc_foreacharray(AbstractPart, part, storedMsg->htmlInlineAttachments()) {
            if (part->contentID() != NULL) {
                Array * possibleURLs = contentIDURLStringsForCID(part->contentID());
                mc_foreacharray(String, url, possibleURLs) {
                    if (urlSet->containsObject(url)) {
                        HashMap * partBasicInfo = HashMap::hashMap();
                        partBasicInfo->setObjectForKey(MCSTR("uniqueID"), part->uniqueID());
                        if (part->filename() != NULL) {
                            partBasicInfo->setObjectForKey(MCSTR("filename"), part->filename());
                        }
                        cidPartsMapping->setObjectForKey(url, partBasicInfo);
                    }
                }
            }
        }
    }
    result->setObjectForKey(MCSTR("cidImageParts"), cidImageParts);
    result->setObjectForKey(MCSTR("cidPartsMapping"), cidPartsMapping);
    return result;
}

static Array * otherAttachmentsForMessage(AbstractMessage * storedMsg)
{
    Array * result = Array::array();
    Array * attachments = storedMsg->attachments();
    mc_foreacharray(AbstractPart, part, attachments) {
        if (!isImageAttachment(part)) {
            result->addObject(part);
        }
    }
    return result;
}

HashMap * MailDB::messageInfo(int64_t messageRowID,
                              Array * requiredParts,
                              Set * emailSet,
                              bool renderImageEnabled)
{
    HashMap * info = HashMap::hashMap();

    AttachmentRendererHelper * helper = new AttachmentRendererHelper(renderImageEnabled);
    helper->setDB(this);
    helper->setMessageRowID(originalMessageRowID(messageRowID));

    // Should not crash since retrieving can be asynchronous.
    AbstractMessage * storedMsg = messageForRowIDNoAssert(messageRowID);
    if (storedMsg == NULL) {
        MC_SAFE_RELEASE(helper);
        return NULL;
    }
    AbstractMessage * originalMsg = storedMsg;

    String * result = NULL;
    if (storedMsg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
        if (isMessageWithoutBodystructure(storedMsg)) {
            MessageParser * parsedMsg = storedParsedMessage(messageRowID);
            if (parsedMsg != NULL) {
                result = parsedMsg->htmlRenderingWithDataCallback(helper, helper);
                storedMsg = parsedMsg;
            }
            else {
                result = NULL;
            }
        }
        else {
            MessageParser * parsedMsg = storedParsedMessage(messageRowID);
            if (parsedMsg != NULL) {
                result = parsedMsg->htmlRenderingWithDataCallback(helper, helper);
                storedMsg = parsedMsg;
            }
            else {
                result = ((IMAPMessage *) storedMsg)->htmlRendering(NULL, helper, helper);
            }
        }
    }
    else {
        storedMsg = messageParserForRowID(messageRowID);
        result = ((MessageParser *) storedMsg)->htmlRenderingWithDataCallback(helper, helper);
    }

    HashMap * imageAttachments = imageAttachmentsForMessage(storedMsg, result);
    Array * images = (Array *) imageAttachments->objectForKey(MCSTR("cidImageParts"));
    Array * imageAttachmentsResult = Array::array();
    {
        mc_foreacharray(AbstractPart, part, images) {
            imageAttachmentsResult->addObject(part->serializable());
        }
    }
    Array * otherAttachments = otherAttachmentsForMessage(storedMsg);
    Array * otherAttachmentsResult = Array::array();
    {
        mc_foreacharray(AbstractPart, part, otherAttachments) {
            HashMap * partInfo = part->serializable();
            if (part->filename() != NULL) {
                partInfo->setObjectForKey(MCSTR("filenameext"), part->filename()->pathExtension());
            }
            otherAttachmentsResult->addObject(partInfo);
        }
    }
    Array * allAttachments = Array::array();
    {
        mc_foreacharray(AbstractPart, part, storedMsg->attachments()) {
            HashMap * info = HashMap::hashMap();
            info->setObjectForKey(MCSTR("uniqueID"), part->uniqueID());
            if (part->filename() != NULL) {
                info->setObjectForKey(MCSTR("filename"), part->filename());
            }
            allAttachments->addObject(info);
        }
        mc_foreacharray(AbstractPart, inlinePart, storedMsg->htmlInlineAttachments()) {
            HashMap * info = HashMap::hashMap();
            info->setObjectForKey(MCSTR("uniqueID"), inlinePart->uniqueID());
            if (inlinePart->filename() != NULL) {
                info->setObjectForKey(MCSTR("filename"), inlinePart->filename());
            }
            allAttachments->addObject(info);
        }
    }

    if (requiredParts != NULL) {
        requiredParts->addObjectsFromArray(helper->requiredParts());
    }
    bool mixedTextAndAttachmentsModeEnabled = helper->isMixedTextAndAttachmentsModeEnabled();
    MC_SAFE_RELEASE(helper);

    String * subject = storedMsg->header()->extractedSubject();
    if (subject != NULL) {
        info->setObjectForKey(MCSTR("subject"), subject);
    }
    if (storedMsg->header()->subject() != NULL) {
        info->setObjectForKey(MCSTR("original-subject"), storedMsg->header()->subject());
    }
    String * sender = NULL;
    Address * senderMailbox = NULL;
    if (storedMsg->header()->from() != NULL) {
        senderMailbox = storedMsg->header()->from();
    }
    else if (storedMsg->header()->sender() != NULL) {
        senderMailbox = storedMsg->header()->sender();
    }
    bool isMe = false;
    if (senderMailbox != NULL) {
        if (emailSet != NULL) {
            if (emailSet->containsObject(senderMailbox->mailbox())) {
                info->setObjectForKey(MCSTR("me"), Value::valueWithBoolValue(true));
                isMe = true;
            }
        }
        sender = AddressDisplay::shortDisplayStringForAddress(senderMailbox);
    }
    if (sender != NULL) {
        info->setObjectForKey(MCSTR("sender"), sender);
    }
    time_t date = storedMsg->header()->date();
    if (time(NULL) - date < 12 * 60 * 60) {
        DateFormatter * formatter = dateFormatterWithStyle(DateFormatStyleNone, DateFormatStyleShort);
        String * dateStr = formatter->stringFromDate(date);
        if (dateStr != NULL) {
            info->setObjectForKey(MCSTR("date"), dateStr);
        }
    }
    else {
        DateFormatter * formatter = dateFormatterWithStyle(DateFormatStyleShort, DateFormatStyleNone);
        String * dateStr = formatter->stringFromDate(date);
        if (dateStr != NULL) {
            info->setObjectForKey(MCSTR("date"), dateStr);
        }
    }
    if (result != NULL) {
        info->setObjectForKey(MCSTR("content"), result);
        info->setObjectForKey(MCSTR("all-attachments"), allAttachments);
        info->setObjectForKey(MCSTR("image-attachments"), imageAttachmentsResult);
        info->setObjectForKey(MCSTR("other-attachments"), otherAttachmentsResult);
        info->setObjectForKey(MCSTR("mixed-text-attachments"), mixedTextAndAttachmentsModeEnabled ? MCSTR("1") : MCSTR("0"));
        info->setObjectForKey(MCSTR("cid-mapping"), imageAttachments->objectForKey(MCSTR("cidPartsMapping")));
    }

    if (originalMsg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
        info->setObjectForKey(MCSTR("type"), MCSTR("imap"));
    }
    info->setObjectForKey(MCSTR("msg"), storedMsg->serializable());

    {
        DateFormatter * formatter = dateFormatterWithStyle(DateFormatStyleMedium, DateFormatStyleMedium);
        String * dateStr = formatter->stringFromDate(date);
        if (dateStr != NULL) {
            info->setObjectForKey(MCSTR("header-date"), dateStr);
        }

        bool hasReplyTo = false;
        if (storedMsg->header()->replyTo() != NULL) {
            if (storedMsg->header()->replyTo()->count() >= 2) {
                hasReplyTo = true;
            }
            else if (storedMsg->header()->replyTo()->count() == 1) {
                Address * address = (Address *) storedMsg->header()->replyTo()->objectAtIndex(0);
                if (address->mailbox() != NULL) {
                    if (!address->mailbox()->isEqual(storedMsg->header()->from()->mailbox())) {
                        hasReplyTo = true;
                    }
                }
            }
        }
        if (hasReplyTo) {
            Array * replyToArray = addressesToHashMaps(storedMsg->header()->replyTo());
            if (replyToArray != NULL) {
                info->setObjectForKey(MCSTR("header-replyto"), replyToArray);
            }
        }
        if (storedMsg->header()->from() != NULL) {
            HashMap * fromHash = addressToHashMap(storedMsg->header()->from());
            info->setObjectForKey(MCSTR("header-from"), fromHash);
        }
        Array * toArray = addressesToHashMaps(storedMsg->header()->to());
        if (toArray != NULL) {
            info->setObjectForKey(MCSTR("header-to"), toArray);
        }
        Array * ccArray = addressesToHashMaps(storedMsg->header()->cc());
        if (ccArray != NULL) {
            info->setObjectForKey(MCSTR("header-cc"), ccArray);
        }
        Array * bccArray = addressesToHashMaps(storedMsg->header()->bcc());
        if (bccArray) {
            info->setObjectForKey(MCSTR("header-bcc"), bccArray);
        }
    }

    String * recipientMD5 = MCSTR("");
    Array * recipient = Array::array();
    {
        Set * recipientSet = Set::set();
        if (storedMsg->header()->from() != NULL) {
            recipientSet->addObject(storedMsg->header()->from()->mailbox()->lowercaseString());
        }
        {
            mc_foreacharray(Address, address, storedMsg->header()->to()) {
                if (!recipientSet->containsObject(address->mailbox()->lowercaseString())) {
                    recipientSet->addObject(address->mailbox()->lowercaseString());
                    if (isMe) {
                        if (!emailSet->containsObject(address->mailbox()->lowercaseString())) {
                            recipient->addObject(AddressDisplay::veryShortDisplayStringForAddress(address));
                        }
                    }
                    else {
                        recipient->addObject(AddressDisplay::veryShortDisplayStringForAddress(address));
                    }
                }
            }
        }
        {
            mc_foreacharray(Address, address, storedMsg->header()->cc()) {
                if (!recipientSet->containsObject(address->mailbox()->lowercaseString())) {
                    recipientSet->addObject(address->mailbox()->lowercaseString());
                    if (isMe) {
                        if (!emailSet->containsObject(address->mailbox()->lowercaseString())) {
                            recipient->addObject(AddressDisplay::veryShortDisplayStringForAddress(address));
                        }
                    }
                    else {
                        recipient->addObject(AddressDisplay::veryShortDisplayStringForAddress(address));
                    }
                }
            }
        }
        Array * recipientEmails = recipientSet->allObjects();
        recipientEmails->sortArray(compareDisplayName, NULL);
        recipientMD5 = md5String(hermes::fastSerializedData(recipientEmails));
        recipient->sortArray(compareDisplayName, NULL);
    }
    info->setObjectForKey(MCSTR("recipients-md5"), recipientMD5);
    info->setObjectForKey(MCSTR("recipients"), recipient);
    String * listID = storedMsg->header()->extraHeaderValueForName(MCSTR("List-ID"));
    if (listID != NULL) {
        info->setObjectForKey(MCSTR("listid"), listID);
    }

    return info;
}

mailcore::Array * MailDB::recipientsForMessages(mailcore::IndexSet * messagesRowIDs)
{
    Set * recipients = new Set();
    mc_foreachindexset(messageRowID, messagesRowIDs) {
        // Should not crash since it's asynchronous.
        AbstractMessage * storedMsg = messageForRowIDNoAssert(messageRowID);
        if (storedMsg == NULL) {
            continue;
        }
        recipients->addObjectsFromArray(storedMsg->header()->to());
        recipients->addObjectsFromArray(storedMsg->header()->cc());
        recipients->addObjectsFromArray(storedMsg->header()->bcc());
    }
    Array * result = recipients->allObjects();
    MC_SAFE_RELEASE(recipients);
    return result;
}

mailcore::Array * MailDB::addToSavedRecipients(mailcore::Array * addresses, int64_t rowID)
{
    String * filename = mPath->stringByAppendingPathComponent(MCSTR("addresses.json"));
    Data * data = Data::dataWithContentsOfFile(filename);
    Array * existingAddresses = NULL;
    if (data != NULL) {
        HashMap * info = (HashMap *) hermes::objectWithFastSerializedData(data);
        existingAddresses = (Array *) info->objectForKey(MCSTR("addresses"));
    }
    if (existingAddresses == NULL) {
        existingAddresses = Array::array();
    }
    Set * addressesSet = Set::setWithArray(existingAddresses);
    addressesSet->addObjectsFromArray(addresses);

    Array * allSavedAddresses = addressesSet->allObjects();
    HashMap * infoToWrite = HashMap::hashMap();
    infoToWrite->setObjectForKey(MCSTR("addresses"), allSavedAddresses);
    data = hermes::fastSerializedData(infoToWrite);
    data->writeToFile(filename);

    if (rowID != 0) {
        filename = mPath->stringByAppendingPathComponent(MCSTR("addresses-meta.json"));
        infoToWrite = HashMap::hashMap();
        infoToWrite->setObjectForKey(MCSTR("rowid"), Value::valueWithUnsignedLongLongValue(rowID));
        data = JSON::objectToJSONData(infoToWrite);
        data->writeToFile(filename);
    }

    return allSavedAddresses;
}

mailcore::Array * MailDB::savedRecipients()
{
    String * filename = mPath->stringByAppendingPathComponent(MCSTR("addresses.json"));
    Data * data = Data::dataWithContentsOfFile(filename);
    if (data != NULL) {
        HashMap * info = (HashMap *) hermes::objectWithFastSerializedData(data);
        return (Array *) info->objectForKey(MCSTR("addresses"));
    }
    return Array::array();
}

int64_t MailDB::lastUidForSavedRecipients()
{
    String * filename = mPath->stringByAppendingPathComponent(MCSTR("addresses-meta.json"));
    Data * data = Data::dataWithContentsOfFile(filename);
    if (data != NULL) {
        HashMap * info = (HashMap *) JSON::objectFromJSONData(data);
        if (info != NULL) {
            return ((Value *) info->objectForKey(MCSTR("rowid")))->longLongValue();
        }
    }
    return 0;
}

void MailDB::nextUidToFetch(int64_t folderID, uint32_t maxUid, uint32_t * pUid, int64_t * pMessageRowID)
{
    int r;
    sqlite3_stmt * stmt;
    int64_t rowID = -1;
    uint32_t uid = 0;
    
    if (maxUid == 0) {
        r = sqlitePrepare("select rowid, uid from message where folderid = ? and fetched = 0 order by uid desc limit 1", &stmt);
        sqlite3_bind_int64(stmt, 1, folderID);
    }
    else {
        r = sqlitePrepare("select rowid, uid from message where folderid = ? and fetched = 0 and uid <= ? order by uid desc limit 1", &stmt);
        sqlite3_bind_int64(stmt, 1, folderID);
        sqlite3_bind_int64(stmt, 2, maxUid);
    }
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            rowID = sqlite3_column_int64(stmt, 0);
            uid = (uint32_t) sqlite3_column_int64(stmt, 1);
        }
    }
    sqliteReset(stmt);

    if (uid == 0) {
        rowID = -1;
    }

    * pMessageRowID = rowID;
    * pUid = uid;
}

void MailDB::uidToFetch(int64_t messageRowID, uint32_t * pUid)
{
    int r;
    sqlite3_stmt * stmt;
    uint32_t uid = 0;
    
    r = sqlitePrepare("select uid from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            uid = (uint32_t) sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    * pUid = uid;
}

Encoding MailDB::encodingForPart(int64_t messageRowID, String * partID)
{
    // Should not crash since it's asynchronous.
    IMAPMessage * msg = (IMAPMessage *) messageForRowIDNoAssert(messageRowID);
    if (msg == NULL) {
        return EncodingOther;
    }
    if (!msg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
        // XXX - handle weird situation.
        return EncodingOther;
    }
    MCAssert(msg->className()->isEqual(MCSTR("mailcore::IMAPMessage")));
    IMAPPart * part = (IMAPPart *) msg->partForPartID(partID);
    if (part == NULL) {
        return EncodingOther;
    }
    return part->encoding();
}

void MailDB::markAsFetched(int64_t messageRowID, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;
    
    r = sqlitePrepare("update message set fetched = 1 where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    // Rendered. Marked as modified.
    int64_t peopleViewID = -1;
    r = sqlitePrepare("select peopleviewid from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            peopleViewID = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    int64_t date = -1;
    r = sqlitePrepare("select date from peopleview where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            date = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    if ((peopleViewID != -1) && (changes != NULL)) {
        changes->modifyPeopleViewID(peopleViewID, date);
    }
}

void MailDB::beginTransaction()
{
    sqliteBeginTransaction();
    mKVDB->beginTransaction();
    mIndex->beginTransaction();
}

void MailDB::commitTransaction(MailDBChanges * changes)
{
    computePeopleViewCounts(changes);
    mIndex->commitTransaction();
    mKVDB->commitTransaction();
    sqliteCommitTransaction();
    mSerializedMessageCache->removeAllObjects();
}

void MailDB::mutateMessageFlag(int64_t messageRowID, mailcore::MessageFlag mask, bool remove, int64_t draftsFolderID,
                               MailDBChanges * changes, bool mutateOther)
{
    mutateMessageFlagAndLabel(messageRowID, mask, NULL, remove, draftsFolderID, changes, mutateOther);
}

void MailDB::mutateMessageLabel(int64_t messageRowID, mailcore::String * label, bool remove,
                                MailDBChanges * changes, bool mutateOther)
{
    mutateMessageFlagAndLabel(messageRowID, (MessageFlag) 0, label, remove, -1, changes, mutateOther);
}

void MailDB::mutateMessageFlagAndLabel(int64_t messageRowID, mailcore::MessageFlag mask, mailcore::String * label, bool remove,
                                       int64_t draftsFolderID,
                                       MailDBChanges * changes, bool mutateOther)
{
    int r;
    sqlite3_stmt * stmt;
    int current_unread = 0;
    int current_starred = 0;
    int current_deleted = 0;
    int64_t peopleViewID = -1;
    int64_t folderID = -1;
    uint32_t uid = 0;
    String * msgid = NULL;
    bool moving = false;

    r = sqlitePrepare("select uid, msgid, folderid, unread, starred, deleted, peopleviewid, moving from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            uid = (uint32_t) sqlite3_column_int64(stmt, 0);
            const char * utf8msgid = (const char *) sqlite3_column_text(stmt, 1);
            msgid = String::stringWithUTF8Characters(utf8msgid);
            folderID = sqlite3_column_int64(stmt, 2);
            current_unread = sqlite3_column_int(stmt, 3);
            current_starred = sqlite3_column_int(stmt, 4);
            current_deleted = sqlite3_column_int(stmt, 5);
            peopleViewID = sqlite3_column_int64(stmt, 6);
            moving = (bool) sqlite3_column_int(stmt, 7);
        }
    }
    sqliteReset(stmt);

    if (peopleViewID == -1) {
        // not found.
        return;
    }

    if (mutateOther) {
        Array * otherMessageRowIDs = rowsForMessageID(msgid, peopleViewID);
        mc_foreacharray(Value, otherMessageRowID, otherMessageRowIDs) {
            mutateMessageFlagAndLabel(otherMessageRowID->longLongValue(), mask, label, remove, draftsFolderID, changes, false);
        }
        return;
    }

    MessageFlag currentFlags = (MessageFlag) 0;
    if (!current_unread) {
        currentFlags = (MessageFlag) (currentFlags | MessageFlagSeen);
    }
    if (current_starred) {
        currentFlags = (MessageFlag) (currentFlags | MessageFlagFlagged);
    }
    if (current_deleted) {
        currentFlags = (MessageFlag) (currentFlags | MessageFlagDeleted);
    }
    
    MessageFlag flags = (MessageFlag) 0;
    if (!remove) {
        flags = mask;
    }
    if (label != NULL) {
        if (!changeMessageLabel(messageRowID, peopleViewID, label, remove, changes)) {
            return;
        }

        const char * sqlString = NULL;
        if (remove) {
            sqlString = "insert into message_local_changes (messageid, uid, folderid, removedlabel) values (?, ?, ?, ?)";
        }
        else {
            sqlString = "insert into message_local_changes (messageid, uid, folderid, addedlabel) values (?, ?, ?, ?)";
        }
        r = sqlitePrepare(sqlString, &stmt);
        sqlite3_bind_int64(stmt, 1, messageRowID);
        sqlite3_bind_int64(stmt, 2, uid);
        sqlite3_bind_int64(stmt, 3, folderID);
        sqlite3_bind_text16(stmt, 4, label->unicodeCharacters(), -1, SQLITE_STATIC);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }
    else if (changeMessageCommon(folderID, messageRowID, peopleViewID, currentFlags, flags, mask, moving, moving, false,
                                 draftsFolderID, changes)) {
        const char * sqlString = NULL;
        switch (mask) {
            case MessageFlagDeleted:
                sqlString = "insert into message_local_changes (messageid, uid, folderid, deleted) values (?, ?, ?, ?)";
                break;
            case MessageFlagFlagged:
                sqlString = "insert into message_local_changes (messageid, uid, folderid, starred) values (?, ?, ?, ?)";
                break;
            case MessageFlagSeen:
                sqlString = "insert into message_local_changes (messageid, uid, folderid, unread) values (?, ?, ?, ?)";
                remove = !remove;
                break;
            default:
                MCAssert(0);
                break;
        }
        r = sqlitePrepare(sqlString, &stmt);
        sqlite3_bind_int64(stmt, 1, messageRowID);
        sqlite3_bind_int64(stmt, 2, uid);
        sqlite3_bind_int64(stmt, 3, folderID);
        if (remove) {
            sqlite3_bind_int(stmt, 4, -1);
        }
        else {
            sqlite3_bind_int(stmt, 4, 1);
        }
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }

    changes->setFolderNeedsPushFlags(folderID);
}

void MailDB::markMessageAsRead(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes)
{
    mutateMessageFlag(messageRowID, MessageFlagSeen, false, draftsFolderID, changes);
}

void MailDB::markMessageAsUnread(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes)
{
    mutateMessageFlag(messageRowID, MessageFlagSeen, true, draftsFolderID, changes);
}

void MailDB::markMessageAsFlagged(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes)
{
    mutateMessageFlag(messageRowID, MessageFlagFlagged, false, draftsFolderID, changes);
}

void MailDB::markMessageAsUnflagged(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes)
{
    mutateMessageFlag(messageRowID, MessageFlagFlagged, true, draftsFolderID, changes);
}

void MailDB::markMessageAsDeleted(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes)
{
    mutateMessageFlag(messageRowID, MessageFlagDeleted, false, draftsFolderID, changes, false);
}

Array * MailDB::messagesRowIDsForPeopleViewID(int64_t peopleViewID, int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;
    Array * result;
    
    result = Array::array();
    if (folderID == -1) {
        r = sqlitePrepare("select rowid from message where peopleviewid = ? order by date desc", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleViewID);
    }
    else {
        r = sqlitePrepare("select rowid from message where peopleviewid = ? and folderid = ? order by date desc", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleViewID);
        sqlite3_bind_int64(stmt, 2, folderID);
    }
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            
            int64_t rowID = sqlite3_column_int64(stmt, 0);
            result->addObject(Value::valueWithLongLongValue(rowID));
        } while (1);
    }
    //sqlite3_finalize(stmt);
    sqliteReset(stmt);
    return result;
}

mailcore::IndexSet * MailDB::messagesForFolderID(int64_t folderID, int64_t minimumRowID)
{
    IndexSet * result = IndexSet::indexSet();
    sqlite3_stmt * stmt;
    int r = sqlitePrepare("select rowid from message where folderid = ? and rowid >= ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    sqlite3_bind_int64(stmt, 2, minimumRowID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }

            int64_t rowID = sqlite3_column_int64(stmt, 0);
            result->addIndex(rowID);
        } while (1);
    }
    sqliteReset(stmt);
    return result;
}

Array * MailDB::mainMessagesRowIDsForPeopleViewID(int64_t peopleViewID, int64_t inboxFolderID, int64_t sentFolderID)
{
    Array * messages = messagesForPeopleConversation(peopleViewID, HashMap::hashMap());
    if (messages->count() == 0) {
        return Array::array();
    }
    HashMap * foundInfo = NULL;
    {
        mc_foreacharray(HashMap, info, messages) {
            if (((Value *) info->objectForKey(MCSTR("folderid")))->longLongValue() == inboxFolderID) {
                foundInfo = info;
                break;
            }
        }
    }
    if (foundInfo == NULL) {
        AutoreleasePool * pool = new AutoreleasePool();
        mc_foreacharray(HashMap, info, messages) {
            if (((Value *) info->objectForKey(MCSTR("folderid")))->longLongValue() != sentFolderID) {
                int64_t rowID = ((Value *) info->objectForKey(MCSTR("rowid")))->longLongValue();
                bool isSent = false;
                // Should crash since it's been queries earlier.
                AbstractMessage * msg = messageForRowID(rowID);
                if (msg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
                    // Gmail message in not in label folder but has label \Sent
                    mc_foreacharray(String, label, ((IMAPMessage *) msg)->gmailLabels()) {
                        if (label->isEqual(MCSTR("\\Sent"))) {
                            isSent = true;
                        }
                    }
                }
                if (!isSent) {
                    foundInfo = info;
                    break;
                }
                break;
            }
        }
        pool->release();
    }

    HashMap * info = foundInfo;
    if (info == NULL) {
        info = (HashMap *) messages->objectAtIndex(0);
    }
    String * mainMessageID = (String *) info->objectForKey(MCSTR("msgid"));
    Value * vMainDate = (Value *) info->objectForKey(MCSTR("date"));
    time_t mainDate = vMainDate->unsignedLongLongValue();

    Array * result = Array::array();
    int r;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("select rowid from message where peopleviewid = ? order by date desc", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            
            int64_t rowID = sqlite3_column_int64(stmt, 0);

            // Should crash since it's been queries earlier.
            AbstractMessage * message = messageForRowID(rowID);
            
            if (message->header()->messageID()->isEqual(mainMessageID) && message->header()->date() == mainDate) {
                result->addObject(Value::valueWithLongLongValue(rowID));
            }
        } while (1);
    }
    sqliteReset(stmt);

    return result;
}

void MailDB::markPeopleViewAsRead(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID, MailDBChanges * changes)
{
    Array * messages = messagesRowIDsForPeopleViewID(peopleViewID, folderID);
    mc_foreacharray(Value, vMessageRowID, messages) {
        int64_t messageRowID = vMessageRowID->longLongValue();
        markMessageAsRead(messageRowID, draftsFolderID, changes);
    }
}

void MailDB::markPeopleViewAsUnread(int64_t peopleViewID, int64_t folderID,
                                    int64_t inboxFolderID, int64_t sentFolderID, int64_t draftsFolderID,
                                    MailDBChanges * changes)
{
    Array * messages = mainMessagesRowIDsForPeopleViewID(peopleViewID, inboxFolderID, sentFolderID);
    mc_foreacharray(Value, vMessageRowID, messages) {
        int64_t messageRowID = vMessageRowID->longLongValue();
        markMessageAsUnread(messageRowID, draftsFolderID, changes);
    }
}

void MailDB::markPeopleViewAsFlagged(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID,
                                     MailDBChanges * changes)
{
    Array * messages = mainMessagesRowIDsForPeopleViewID(peopleViewID, -1, -1);
    mc_foreacharray(Value, vMessageRowID, messages) {
        int64_t messageRowID = vMessageRowID->longLongValue();
        markMessageAsFlagged(messageRowID, draftsFolderID, changes);
    }
}

void MailDB::markPeopleViewAsUnflagged(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID,
                                       MailDBChanges * changes)
{
    Array * messages = messagesRowIDsForPeopleViewID(peopleViewID, folderID);
    mc_foreacharray(Value, vMessageRowID, messages) {
        int64_t messageRowID = vMessageRowID->longLongValue();
        markMessageAsUnflagged(messageRowID, draftsFolderID, changes);
    }
}

void MailDB::markPeopleViewAsDeleted(int64_t peopleViewID, int64_t folderID, int64_t draftsFolderID,
                                     MailDBChanges * changes)
{
    Array * messages = messagesRowIDsForPeopleViewID(peopleViewID, folderID);
    mc_foreacharray(Value, vMessageRowID, messages) {
        int64_t messageRowID = vMessageRowID->longLongValue();
        markMessageAsDeleted(messageRowID, draftsFolderID, changes);
    }
}

MailDBLocalMessagesChanges * MailDB::localMessagesChanges(int64_t folderID)
{
    MailDBLocalMessagesChanges * result = new MailDBLocalMessagesChanges();
    int r;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("select rowid, messageid, uid, deleted, starred, unread, addedlabel, removedlabel from message_local_changes where folderid = ? order by rowid asc", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }

            int64_t rowid = sqlite3_column_int64(stmt, 0);
            int64_t messageRowID = sqlite3_column_int64(stmt, 1);
            uint32_t uid = (uint32_t) sqlite3_column_int64(stmt, 2);
            int deleted = sqlite3_column_int(stmt, 3);
            int starred = sqlite3_column_int(stmt, 4);
            int unread = sqlite3_column_int(stmt, 5);
            const UChar * addedLabelCharacters = (UChar *) sqlite3_column_text16(stmt, 6);
            String * addedLabel = NULL;
            if (addedLabelCharacters != NULL && * addedLabelCharacters != 0) {
                addedLabel = String::stringWithCharacters(addedLabelCharacters);
            }
            const UChar * removedLabelCharacters = (UChar *) sqlite3_column_text16(stmt, 7);
            String * removedLabel = NULL;
            if (removedLabelCharacters != NULL && * removedLabelCharacters != 0) {
                removedLabel = String::stringWithCharacters(removedLabelCharacters);
            }

            if (addedLabel != NULL) {
                result->addMessageLabel(rowid, messageRowID, uid, addedLabel);
            }
            else if (removedLabel != NULL) {
                result->removeMessageLabel(rowid, messageRowID, uid, removedLabel);
            }
            else {
                result->setFlagsChangeForMessage(rowid, messageRowID, uid, deleted, starred, unread);
            }
        } while (1);
    }
    sqliteReset(stmt);

    result->autorelease();
    return result;
}

void MailDB::removeLocalMessagesChanges(IndexSet * rowsIDs)
{
    mc_foreachindexset(rowID, rowsIDs) {
        sqlite3_stmt * stmt;
        int r;
        
        r = sqlitePrepare("delete from message_local_changes where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, rowID);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }
}

//////////////////
// Index
// 0: from
// 1: from-mailbox
// 2: to
// 3: to-mailbox
// 4: subject
// 5: attachments names
// 6: content

void MailDB::indexSetMessageSummary(int64_t messageRowID, AbstractMessage * msg, String * summary)
{
    if (0) {
        fprintf(stderr, "%s\n", MCUTF8DESC(msg));
        fprintf(stderr, "%s\n", MCUTF8(summary));
        Array * keywords = Array::array();
        keywords->addObject(MCSTR(""));
        IndexSet * result = messagesRowsIDsForKeywords(keywords);
        fprintf(stderr, "index result -> %i\n", result->containsIndex(messageRowID));
    }
    mIndex->setStringForID((messageRowID << 4) + 6, summary);
}

void MailDB::indexAddMessageHeaders(int64_t messageRowID, AbstractMessage * msg)
{
    Address * from = msg->header()->from();
    if (from != NULL) {
        if (from->displayName() != NULL) {
            mIndex->setStringForID((messageRowID << 4) + 0, from->displayName());
        }
        if (from->mailbox() != NULL) {
            mIndex->setStringsForID((messageRowID << 4) + 1, Array::arrayWithObject(from->mailbox()));
        }
    }
    Array * recipient = Array::array();
    recipient->addObjectsFromArray(msg->header()->to());
    recipient->addObjectsFromArray(msg->header()->cc());
    recipient->addObjectsFromArray(msg->header()->bcc());
    {
        String * stringToIndex = String::string();
        Array * mailboxToIndex = Array::array();
        mc_foreacharray(Address, address, recipient) {
            if (address->displayName() != NULL) {
                stringToIndex->appendString(address->displayName());
                stringToIndex->appendString(MCSTR(" "));
            }
            if (address->mailbox() != NULL) {
                mailboxToIndex->addObject(address->mailbox());
            }
        }
        mIndex->setStringForID((messageRowID << 4) + 2, stringToIndex);
        mIndex->setStringsForID((messageRowID << 4) + 3, mailboxToIndex);
    }
    String * subject = msg->header()->subject();
    if (subject != NULL) {
        mIndex->setStringForID((messageRowID << 4) + 4, subject);
    }
    bool skipIndexAttachments = isMessageWithoutBodystructure(msg);
    if (!skipIndexAttachments) {
        indexAddMessageAttachments(messageRowID, msg);
    }
}

void MailDB::indexAddMessageAttachments(int64_t messageRowID, mailcore::AbstractMessage * msg)
{
    Array * attachments = msg->attachments();
    if (attachments != NULL) {
        String * stringToIndex = String::string();
        mc_foreacharray(IMAPPart, part, attachments) {
            if (part->filename() != NULL) {
                stringToIndex->appendString(part->filename());
                stringToIndex->appendString(MCSTR(" "));
            }
        }
        mIndex->setStringForID((messageRowID << 4) + 5, stringToIndex);
    }
}

void MailDB::indexRemoveMessage(int64_t messageRowID)
{
    mIndex->removeID((messageRowID << 4) + 0);
    mIndex->removeID((messageRowID << 4) + 1);
    mIndex->removeID((messageRowID << 4) + 2);
    mIndex->removeID((messageRowID << 4) + 3);
    mIndex->removeID((messageRowID << 4) + 4);
}

IndexSet * MailDB::messagesRowsIDsForKeywords(Array * keywords)
{
    IndexSet * result = NULL;
    mc_foreacharray(String, keyword, keywords) {
        IndexSet * keywordResult = mIndex->search(keyword);
        IndexSet * messageKeywordResult = IndexSet::indexSet();
        mc_foreachindexset(value, keywordResult) {
            messageKeywordResult->addIndex(value >> 4);
        }
        if (result == NULL) {
            result = messageKeywordResult;
        }
        else {
            result->intersectsIndexSet(messageKeywordResult);
        }
    }
    if (result == NULL) {
        result = IndexSet::indexSet();
    }
    return result;
}

IndexSet * MailDB::peopleViewIDsForKeywords(Array * keywords)
{
    IndexSet * result = IndexSet::indexSet();
    LOG_SEARCH("%p: search for matching messages", this);
    IndexSet * resultMessagesRowsIDs = messagesRowsIDsForKeywords(keywords);
    LOG_SEARCH("%p: search for matching messages done", this);
    LOG_SEARCH("%p: matching conversations", this);
    mc_foreachindexset(messageRowID, resultMessagesRowsIDs) {
        int64_t peopleViewID = searchMetaPeopleViewID(messageRowID);
        if (peopleViewID == -1) {
            continue;
        }
        result->addIndex(peopleViewID);
    }
    LOG_SEARCH("%p: matching conversations done", this);
    return result;
}

Array * MailDB::peopleConversationsForKeywords(Array * keywords)
{
    LOG_SEARCH("%p: request conversations", this);
    Array * conversations = peopleConversations();
    LOG_SEARCH("%p: request conversations done", this);
    LOG_SEARCH("%p: search for matching conversations", this);
    IndexSet * matchingPeopleViewIDs = peopleViewIDsForKeywords(keywords);
    LOG_SEARCH("%p: search for matching conversations done", this);
    
    Array * result = Array::array();
    mc_foreacharray(HashMap, conversation, conversations) {
        Value * vID = (Value *) conversation->objectForKey(MCSTR("id"));
        if (matchingPeopleViewIDs->containsIndex(vID->longLongValue())) {
            result->addObject(conversation);
        }
    }
    
    return result;
}

void MailDB::searchMetaUpdate(int64_t messageRowID, int64_t peopleViewID)
{
    String * key = String::stringWithUTF8Format("search-%lli", messageRowID);
    peopleViewID = hermes::hton64(peopleViewID);
    Data * data = Data::dataWithBytes((const char *) &peopleViewID, sizeof(int64_t));
    storeValueForKey(key, data);
}

int64_t MailDB::searchMetaPeopleViewID(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("search-%lli", messageRowID);
    Data * data = retrieveValueForKey(key);
    if (data == NULL)
        return -1;
    int64_t result;
    memcpy((void *) &result, (const void *) data->bytes(), sizeof(result));
    result = hermes::ntoh64(result);
    return result;
}

void MailDB::removeSearchMetaForMessage(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("search-%lli", messageRowID);
    removeValueForKey(key);
}

AbstractMessage * MailDB::messageForRowIDNoAssert(int64_t messageRowID)
{
    AbstractMessage * message = (AbstractMessage *) mSerializedMessageCache->objectForKey(Value::valueWithLongLongValue((long long) messageRowID));
    if (message != NULL) {
        return message;
    }
    AutoreleasePool * pool = new AutoreleasePool();
    String * key = String::stringWithUTF8Format("msg-%lld", (long long) messageRowID);
    Data * data = mKVDB->objectForKey(key);
    if (data == NULL) {
        pool->release();
        return NULL;
    }

    message = (AbstractMessage *) hermes::objectWithFastSerializedData(data);
    if (message == NULL) {
        pool->release();
        return NULL;
    }
    message->retain();
    pool->release();

    message->autorelease();

    mSerializedMessageCache->setObjectForKey(Value::valueWithLongLongValue((long long) messageRowID), message);

    return message;
}

bool MailDB::isMessageStoredInDatabase(int64_t messageRowID)
{
    bool exists = false;
    sqlite3_stmt * stmt;
    int r = sqlitePrepare("select rowid from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            exists = true;
        }
    }
    sqliteReset(stmt);
    return exists;
}

void MailDB::checkMessageIsStoredInDatabase(int64_t messageRowID)
{
    MCAssert(isMessageStoredInDatabase(messageRowID));
}

AbstractMessage * MailDB::messageForRowID(int64_t messageRowID)
{
    AbstractMessage * message = (AbstractMessage *) mSerializedMessageCache->objectForKey(Value::valueWithLongLongValue((long long) messageRowID));
    if (message != NULL) {
        return message;
    }
    AutoreleasePool * pool = new AutoreleasePool();
    String * key = String::stringWithUTF8Format("msg-%lld", (long long) messageRowID);
    Data * data = mKVDB->objectForKey(key);
    if (data == NULL) {

        fprintf(stderr, "Message %lli is nil. Database %s is corrupted.\n", messageRowID, MCUTF8(path()));
        LOG_ERROR("Message %lli is nil. Database %s is corrupted.", messageRowID, MCUTF8(path()));
        String * filename = mPath->stringByAppendingPathComponent(MCSTR("meta.json"));
        hermes::removeFile(filename);

        checkMessageIsStoredInDatabase(messageRowID);

        abort();
        return NULL;
    }

    message = (AbstractMessage *) hermes::objectWithFastSerializedData(data);
    if (message == NULL) {
        fprintf(stderr, "msg serialized: %s\n", MCUTF8(data));
        LOG_ERROR("Message %lli could not be deserialized. Database %s is corrupted.", messageRowID, MCUTF8(path()));
        fprintf(stderr, "Message %lli could not be deserialized. Database %s is corrupted.\n", messageRowID, MCUTF8(path()));
        String * filename = mPath->stringByAppendingPathComponent(MCSTR("meta.json"));
        hermes::removeFile(filename);
        abort();
    }
    message->retain();
    pool->release();

    message->autorelease();

    mSerializedMessageCache->setObjectForKey(Value::valueWithLongLongValue((long long) messageRowID), message);

    return message;
}

int64_t MailDB::peopleViewIDForMessageID(mailcore::String * messageID)
{
    int r;
    int64_t peopleViewID = -1;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("select peopleviewid from message where msgid = ?", &stmt);
    sqlite3_bind_text16(stmt, 1, messageID->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            peopleViewID = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    return peopleViewID;
}

String * MailDB::localMessageFilenameWithBasename(String * basename)
{
    String * folder = mPath->stringByAppendingPathComponent(MCSTR("RawMessage"));
    if (!mCreatedRawMessageFolder) {
        mkdir(folder->fileSystemRepresentation(), 0700);
    }
    String * emlFilename = basename->stringByAppendingString(MCSTR(".eml"));
    return folder->stringByAppendingPathComponent(emlFilename);
}

void MailDB::storeFilenameForMessageParser(int64_t messageRowID, mailcore::String * filename)
{
    String * key = String::stringWithUTF8Format("msg-fn-%lld", (long long) messageRowID);
    mKVDB->setObjectForKey(key, filename->dataUsingEncoding());
}

MessageParser * MailDB::messageParserForRowID(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("msg-fn-%lld", (long long) messageRowID);
    Data * filenameData = mKVDB->objectForKey(key);
    if (filenameData == NULL) {
        return NULL;
    }
    String * filename = localMessageFilenameWithBasename(filenameData->stringWithCharset("utf-8"));
    return MessageParser::messageParserWithContentsOfFile(filename);
}

mailcore::Data * MailDB::dataForMessageParser(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("msg-fn-%lld", (long long) messageRowID);
    Data * filenameData = mKVDB->objectForKey(key);
    if (filenameData == NULL) {
        return NULL;
    }
    String * filename = localMessageFilenameWithBasename(filenameData->stringWithCharset("utf-8"));
    if (filename == NULL) {
        return NULL;
    }
    return Data::dataWithContentsOfFile(filename);
}

void MailDB::removeMessageParserForRowID(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("msg-fn-%lld", (long long) messageRowID);
    Data * filenameData = mKVDB->objectForKey(key);
    if (filenameData == NULL) {
        return;
    }
    String * filename = localMessageFilenameWithBasename(filenameData->stringWithCharset("utf-8"));
    if (filename == NULL) {
        return;
    }
    unlink(filename->fileSystemRepresentation());
    removeValueForKey(key);
}

Array * MailDB::notificationHeaders()
{
    return s_notificationHeaders;
}

Array * MailDB::headersToFetch()
{
    return s_headersToFetch;
}

mailcore::Array * MailDB::rowsForMessageID(mailcore::String * msgid, int64_t peopleViewID)
{
    mailcore::Array * result = new Array();
    int r;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("select rowid from message where peopleviewid = ? and msgid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    sqlite3_bind_text16(stmt, 2, msgid->unicodeCharacters(), -1, SQLITE_STATIC);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }

            int64_t messageRowID = sqlite3_column_int64(stmt, 0);
            result->addObject(Value::valueWithLongLongValue(messageRowID));
        } while (1);
    }
    sqliteReset(stmt);

    result->autorelease();
    return result;
}

void MailDB::copyMessageToFolderCommon(int64_t messageRowID, int64_t otherFolderID, int deleteOriginal, IndexSet * foldersIDs, int64_t draftsFolderID, MailDBChanges * changes)
{
    // Should not crash since it's asynchronous.
    AbstractMessage * msg = messageForRowIDNoAssert(messageRowID);
    if (msg == NULL) {
        return;
    }
    if (deleteOriginal == 2) {
        changes->removeMessageIDFromSendQueue(msg->header()->messageID());
    }
    if (msg->className()->isEqual(MCSTR("mailcore::IMAPMessage"))) {
        // copy IMAP message.
        IMAPMessage * imapMsg = (IMAPMessage *) msg;
        MessageFlag currentFlags = (MessageFlag) 0;
        bool currentMoving = false;

        // add original message id.
        int r;
        sqlite3_stmt * stmt;

        int64_t folderID = -1;
        int64_t uid = -1;
        int64_t originalMessageRowID = -1;
        r = sqlitePrepare("select folderid, uid, original_messageid, moving, unread, starred, deleted from message where rowid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, messageRowID);
        if (r == SQLITE_OK) {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                folderID = sqlite3_column_int64(stmt, 0);
                uid = sqlite3_column_int64(stmt, 1);
                originalMessageRowID = sqlite3_column_int64(stmt, 2);
                currentMoving = sqlite3_column_int(stmt, 3);
                int currentUnread = sqlite3_column_int(stmt, 4);
                int currentStarred = sqlite3_column_int(stmt, 5);
                int currentDeleted = sqlite3_column_int(stmt, 6);
                if (!currentUnread) {
                    currentFlags = (MessageFlag) (currentFlags | MessageFlagSeen);
                }
                if (currentStarred) {
                    currentFlags = (MessageFlag) (currentFlags | MessageFlagFlagged);
                }
                if (currentDeleted) {
                    currentFlags = (MessageFlag) (currentFlags | MessageFlagFlagged);
                }
            }
        }
        sqliteReset(stmt);

        if (folderID == otherFolderID) {
            return;
        }

        foldersIDs->addIndex(folderID);

        int64_t copyMessageRowID = -1;
        if (deleteOriginal != 2) {
            copyMessageRowID = addMessage(otherFolderID, 0, imapMsg, currentFlags, NULL, false, draftsFolderID, changes);

            if (originalMessageRowID != -1) {
                messageRowID = originalMessageRowID;
            }

            r = sqlitePrepare("update message set original_messageid = ? where rowid = ?", &stmt);
            sqlite3_bind_int64(stmt, 1, messageRowID);
            sqlite3_bind_int64(stmt, 2, copyMessageRowID);
            r = sqlite3_step(stmt);
            sqliteReset(stmt);
        }
        if (deleteOriginal) {
            changeMessageToMoving(folderID,
                                  messageRowID,
                                  currentFlags,
                                  currentMoving,
                                  true,
                                  draftsFolderID,
                                  changes);
        }

        // add copy to pending operations.
        r = sqlitePrepare("insert into message_copy (original_uid, original_messageid, original_folderid, messageid, folderid, delete_original) values (?, ?, ?, ?, ?, ?)", &stmt);
        sqlite3_bind_int64(stmt, 1, uid);
        sqlite3_bind_int64(stmt, 2, messageRowID);
        sqlite3_bind_int64(stmt, 3, folderID);
        sqlite3_bind_int64(stmt, 4, copyMessageRowID);
        sqlite3_bind_int64(stmt, 5, otherFolderID);
        sqlite3_bind_int(stmt, 6, deleteOriginal);
        r = sqlite3_step(stmt);
        sqliteReset(stmt);
    }
    else {
        if (deleteOriginal != 2) {
            // copy local message.
            Data * data = dataForMessageParser(messageRowID);
            // workaround issue when the message file might not exist.
            if (data != NULL) {
                addPendingMessageWithData(otherFolderID, data, true, false, NULL, draftsFolderID, changes);
            }
        }

        if (deleteOriginal) {
            removeMessage(messageRowID, changes);
        }
    }
}

void MailDB::copyMessageToFolder(int64_t messageRowID, int64_t otherFolderID, IndexSet * foldersIDs,
                                 int64_t draftsFolderID, MailDBChanges * changes)
{
    copyMessageToFolderCommon(messageRowID, otherFolderID, 0, foldersIDs, draftsFolderID, changes);
}

void MailDB::copyPeopleViewToFolder(int64_t peopleViewID, int64_t otherFolderID, mailcore::HashMap * foldersScores, IndexSet * foldersIDs,
                                    int64_t draftsFolderID, MailDBChanges * changes)
{
    Array * messages = messagesForPeopleConversation(peopleViewID, foldersScores);
    mc_foreacharray(HashMap, msgInfo, messages) {
        Value * vMessageRowID = (Value *) msgInfo->objectForKey(MCSTR("rowid"));
        int64_t messageRowID = vMessageRowID->longLongValue();
        copyMessageToFolder(messageRowID, otherFolderID, foldersIDs, draftsFolderID, changes);
    }
}

void MailDB::moveMessageToFolder(int64_t messageRowID, int64_t otherFolderID, IndexSet * foldersIDs,
                                 int64_t draftsFolderID, MailDBChanges * changes)
{
    copyMessageToFolderCommon(messageRowID, otherFolderID, 1, foldersIDs, draftsFolderID, changes);
}

void MailDB::movePeopleViewToFolder(int64_t peopleViewID, int64_t otherFolderID, mailcore::HashMap * foldersScores, IndexSet * foldersIDs,
                                    int64_t draftsFolderID, MailDBChanges * changes)
{
    Array * messages = messagesForPeopleConversation(peopleViewID, foldersScores);
    mc_foreacharray(HashMap, msgInfo, messages) {
        Value * vMessageRowID = (Value *) msgInfo->objectForKey(MCSTR("rowid"));
        int64_t messageRowID = vMessageRowID->longLongValue();
        moveMessageToFolder(messageRowID, otherFolderID, foldersIDs, draftsFolderID, changes);
    }
}

void MailDB::purgeMessageToFolder(int64_t messageRowID, int64_t trashFolderID, IndexSet * foldersIDs,
                                  int64_t draftsFolderID, MailDBChanges * changes)
{
    copyMessageToFolderCommon(messageRowID, trashFolderID, 2, foldersIDs, draftsFolderID, changes);
}

void MailDB::purgePeopleViewToFolder(int64_t peopleViewID, int64_t folderID,
                                     int64_t trashFolderID, IndexSet * foldersIDs,
                                     int64_t draftsFolderID, MailDBChanges * changes)
{
    Array * messages = messagesRowIDsForPeopleViewID(peopleViewID, folderID);
    mc_foreacharray(Value, vMessageRowID, messages) {
        int64_t messageRowID = vMessageRowID->longLongValue();
        purgeMessageToFolder(messageRowID, trashFolderID, foldersIDs, draftsFolderID, changes);
    }
}

mailcore::Array * MailDB::messagesUidsToCopyCommon(int64_t folderID, int deleteOriginal)
{
    sqlite3_stmt * stmt;
    int r;
    Array * result = Array::array();

    r = sqlitePrepare("select rowid, original_uid, folderid, messageid from message_copy where original_folderid = ? and delete_original = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    sqlite3_bind_int(stmt, 2, deleteOriginal);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }

            int64_t rowID = sqlite3_column_int64(stmt, 0);
            uint32_t uid = (uint32_t) sqlite3_column_int64(stmt, 1);
            int64_t folderID = sqlite3_column_int64(stmt, 2);
            int64_t messageRowID = sqlite3_column_int64(stmt, 3);
            HashMap * info = HashMap::hashMap();
            info->setObjectForKey(MCSTR("rowid"), Value::valueWithLongLongValue(rowID));
            info->setObjectForKey(MCSTR("uid"), Value::valueWithLongLongValue(uid));
            info->setObjectForKey(MCSTR("dest"), Value::valueWithLongLongValue(folderID));
            info->setObjectForKey(MCSTR("messagerowid"), Value::valueWithLongLongValue(messageRowID));
            result->addObject(info);
        } while (1);
    }
    sqliteReset(stmt);
    return result;
}

mailcore::Array * MailDB::messagesUidsToPurge(int64_t folderID)
{
    return messagesUidsToCopyCommon(folderID, 2);
}

mailcore::Array * MailDB::messagesUidsToMove(int64_t folderID)
{
    return messagesUidsToCopyCommon(folderID, 1);
}

mailcore::Array * MailDB::messagesUidsToCopy(int64_t folderID)
{
    return messagesUidsToCopyCommon(folderID, 0);
}

void MailDB::removeCopyMessage(int64_t rowID)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("delete from message_copy where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, rowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::clearMovingForMessage(int64_t messageRowID, int64_t draftsFolderID, MailDBChanges * changes)
{
    int r;
    sqlite3_stmt * stmt;

    int64_t folderID = -1;
    int64_t uid = -1;
    MessageFlag currentFlags = MessageFlagNone;
    bool currentMoving = false;

    r = sqlitePrepare("select folderid, uid, moving, deleted, starred, unread from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            folderID = sqlite3_column_int64(stmt, 0);
            uid = sqlite3_column_int64(stmt, 1);
            currentMoving = sqlite3_column_int(stmt, 2);
            int currentUnread = sqlite3_column_int(stmt, 3);
            int currentStarred = sqlite3_column_int(stmt, 4);
            int currentDeleted = sqlite3_column_int(stmt, 5);
            if (!currentUnread) {
                currentFlags = (MessageFlag) (currentFlags | MessageFlagSeen);
            }
            if (currentStarred) {
                currentFlags = (MessageFlag) (currentFlags | MessageFlagFlagged);
            }
            if (currentDeleted) {
                currentFlags = (MessageFlag) (currentFlags | MessageFlagFlagged);
            }
        }
    }
    sqliteReset(stmt);
    if (uid == -1) {
        return;
    }

    changeMessageToMoving(folderID,
                          messageRowID,
                          currentFlags,
                          currentMoving,
                          false,
                          draftsFolderID,
                          changes);
}

void MailDB::removeSentDraftWithMessageID(int64_t folderID, mailcore::String * messageID)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("insert into drafts_message_purge_by_msgid (folderid, msgid) values (?, ?)", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    sqlite3_bind_text16(stmt, 2, messageID->unicodeCharacters(), -1, SQLITE_STATIC);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

mailcore::IndexSet * MailDB::sentDraftsToRemoveWithMessageID(int64_t folderID)
{
    sqlite3_stmt * stmt;
    int r;
    Array * messageIDs = Array::array();

    r = sqlitePrepare("select msgid from drafts_message_purge_by_msgid where folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            const void * messageIDUnichars = sqlite3_column_text16(stmt, 0);
            String * messageID = String::stringWithCharacters((const UChar *) messageIDUnichars);
            messageIDs->addObject(messageID);
        }
        while (1);
    }
    sqliteReset(stmt);

    IndexSet * messagesRowIDs = IndexSet::indexSet();
    mc_foreacharray(String, messageID, messageIDs) {
        r = sqlitePrepare("select rowid from message where msgid = ? and folderid = ?", &stmt);
        sqlite3_bind_text16(stmt, 1, messageID->unicodeCharacters(), -1, SQLITE_STATIC);
        sqlite3_bind_int64(stmt, 2, folderID);
        if (r == SQLITE_OK) {
            do {
                r = sqlite3_step(stmt);
                if (r != SQLITE_ROW) {
                    break;
                }
                int64_t rowID = sqlite3_column_int64(stmt, 0);
                messagesRowIDs->addIndex(rowID);
            }
            while (1);
        }
        sqliteReset(stmt);
    }
    return messagesRowIDs;
}

void MailDB::removeSentDraftRemove(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("delete from drafts_message_purge_by_msgid where folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::storeLabelsForMessage(int64_t messageRowID, mailcore::Array * labels)
{
    String * key = String::stringWithUTF8Format("labels-%lli", messageRowID);
    Data * data = hermes::fastSerializedData(labels);
    storeValueForKey(key, data);
}

mailcore::Array * MailDB::labelsForMessage(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("labels-%lli", messageRowID);
    Data * data = retrieveValueForKey(key);
    if (data == NULL)
        return NULL;
    return (mailcore::Array *) hermes::objectWithFastSerializedData(data);
}

void MailDB::removeLabelsForMessage(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("labels-%lli", messageRowID);
    removeValueForKey(key);
}

mailcore::Array * MailDB::messageForConversationNoTrash(int64_t peopleConversationID, int64_t folderID, int64_t trashFolderID)
{
    Array * result = Array::array();
    int r;
    sqlite3_stmt * stmt;

    if (folderID == -1) {
        r = sqlitePrepare("select rowid, folderid from message where peopleviewid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleConversationID);
    }
    else {
        r = sqlitePrepare("select rowid, folderid from message where peopleviewid = ? and folderid = ?", &stmt);
        sqlite3_bind_int64(stmt, 1, peopleConversationID);
        sqlite3_bind_int64(stmt, 2, folderID);
    }
    if (r == SQLITE_OK) {
        do {
            AutoreleasePool * pool = new AutoreleasePool();

            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                pool->release();
                break;
            }

            int64_t folderID = sqlite3_column_int64(stmt, 1);
            if (folderID == trashFolderID) {
                continue;
            }

            int64_t rowID = sqlite3_column_int64(stmt, 0);
            Value * nbRowID = Value::valueWithLongLongValue(rowID);
            result->addObject(nbRowID);

            pool->release();
        } while (1);
    }
    sqliteReset(stmt);

    return result;
}

void MailDB::removeLabelsForConversation(int64_t conversationRowID, int64_t folderID, int64_t trashFolderID, mailcore::String * folderName, MailDBChanges * changes)
{
    Array * msgs = NULL;
    if ((trashFolderID != -1) && (folderID == trashFolderID)) {
        msgs = messageForConversationNoTrash(conversationRowID, folderID, -1);
    }
    else {
        msgs = messageForConversationNoTrash(conversationRowID, -1, trashFolderID);
    }
    mc_foreacharray(Value, vMsgRowID, msgs) {
        int64_t msgRowID = vMsgRowID->longLongValue();
        mutateMessageLabel(msgRowID, folderName, true, changes);
    }
}

void MailDB::addLabelsForConversation(int64_t conversationRowID, int64_t folderID, int64_t trashFolderID, mailcore::String * folderName, MailDBChanges * changes)
{
    Array * msgs = NULL;
    if ((trashFolderID != -1) && (folderID == trashFolderID)) {
        msgs = messageForConversationNoTrash(conversationRowID, folderID, -1);
    }
    else {
        msgs = messageForConversationNoTrash(conversationRowID, -1, trashFolderID);
    }
    mc_foreacharray(Value, vMsgRowID, msgs) {
        int64_t msgRowID = vMsgRowID->longLongValue();
        mutateMessageLabel(msgRowID, folderName, false, changes);
    }
}

bool MailDB::storeLastUIDForFolder(int64_t folderID, int64_t uid)
{
    int r;
    sqlite3_stmt * stmt;

    int64_t lastUID = 0;
    r = sqlitePrepare("select lastuid from folder where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r != SQLITE_ROW) {
            sqliteReset(stmt);
            return false;
        }
        lastUID = sqlite3_column_int64(stmt, 0);
    }
    sqliteReset(stmt);

    if (uid <= lastUID) {
        return false;
    }

    r = sqlitePrepare("update folder set lastuid = ? where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, uid);
    sqlite3_bind_int64(stmt, 2, folderID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

    return true;
}

void MailDB::storeLastSeenUIDForFolder(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;

    int64_t lastUID = 0;
    r = sqlitePrepare("select lastuid from folder where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r != SQLITE_ROW) {
            sqliteReset(stmt);
            return;
        }
        lastUID = sqlite3_column_int64(stmt, 0);
    }
    sqliteReset(stmt);

    r = sqlitePrepare("update folder set lastseenuid = ? where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, lastUID);
    sqlite3_bind_int64(stmt, 2, folderID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

bool MailDB::isFolderUnseen(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;

    int64_t lastUID = 0;
    int64_t lastSeenUID = 0;
    r = sqlitePrepare("select lastuid, lastseenuid from folder where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r != SQLITE_ROW) {
            return false;
        }
        lastUID = sqlite3_column_int64(stmt, 0);
        lastSeenUID = sqlite3_column_int64(stmt, 1);
    }
    sqliteReset(stmt);

    return (lastUID > lastSeenUID);
}

void MailDB::storeDefaultNamespace(mailcore::IMAPNamespace * ns)
{
    storeValueForKey(MCSTR("default-namespace"), hermes::fastSerializedData(ns));
}

mailcore::IMAPNamespace * MailDB::defaultNamespace()
{
    Data * data = retrieveValueForKey(MCSTR("default-namespace"));
    if (data == NULL) {
        return NULL;
    }
    return (IMAPNamespace *) hermes::objectWithFastSerializedData(data);
}

mailcore::HashMap * MailDB::foldersCounts()
{
    int r;
    sqlite3_stmt * stmt;
    HashMap * result = HashMap::hashMap();

    r = sqlitePrepare("select rowid, unread, starred, count from folder", &stmt);
    if (r == SQLITE_OK) {
        do {
            r = sqlite3_step(stmt);
            if (r != SQLITE_ROW) {
                break;
            }
            int64_t folderID = sqlite3_column_int64(stmt, 0);
            int unreadCount = sqlite3_column_int(stmt, 1);
            int starredCount = sqlite3_column_int(stmt, 2);
            int totalCount = sqlite3_column_int(stmt, 3);
            HashMap * item = HashMap::hashMap();
            item->setObjectForKey(MCSTR("unread"),  Value::valueWithIntValue(unreadCount));
            item->setObjectForKey(MCSTR("starred"),  Value::valueWithIntValue(starredCount));
            item->setObjectForKey(MCSTR("count"),  Value::valueWithIntValue(totalCount));
            result->setObjectForKey(Value::valueWithLongLongValue(folderID), item);
        } while (1);
    }
    sqliteReset(stmt);

    return result;
}

mailcore::String * MailDB::filenameForRowID(int64_t messageRowID)
{
    int r;
    sqlite3_stmt * stmt;
    String * basename = NULL;

    r = sqlitePrepare("select filename from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        const void * basenameUnichars = NULL;
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            basenameUnichars = sqlite3_column_text16(stmt, 0);
            basename = String::stringWithCharacters((const UChar *) basenameUnichars);
            if (basename != NULL) {
                if (basename->length() == 0) {
                    basename = NULL;
                }
            }
        }
    }
    sqliteReset(stmt);

    if (basename == NULL) {
        return NULL;
    }

    return localMessageFilenameWithBasename(basename);
}

int64_t MailDB::peopleViewIDForMessageRowID(int64_t messageRowID)
{
    int r;
    int64_t peopleViewID = -1;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("select peopleviewid from message where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, messageRowID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            peopleViewID = sqlite3_column_int64(stmt, 0);
        }
    }
    sqliteReset(stmt);

    return peopleViewID;
}

bool MailDB::peopleViewHasAttachment(int64_t peopleViewID)
{
    int r;
    bool result = 0;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("select hasattachment from peopleview where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, peopleViewID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r == SQLITE_ROW) {
            result = sqlite3_column_int(stmt, 0);
        }
    }
    sqliteReset(stmt);

    return result;
}

void MailDB::storeParsedMessage(int64_t messageRowID, MessageParser * message)
{
    String * key = String::stringWithUTF8Format("msg-%lld-p", (long long) messageRowID);
    mKVDB->setObjectForKey(key, hermes::fastSerializedData(message));

    indexAddMessageAttachments(messageRowID, message);

    int64_t peopleViewID = peopleViewIDForMessageRowID(messageRowID);
    bool peopleHasAttachment = peopleViewHasAttachment(peopleViewID);
    HashMap * attachmentInfo = computeAttachment(message);
    String * attachmentFilename = (String *) attachmentInfo->objectForKey(MCSTR("filename"));
    int attachmentsCount = ((Value *) attachmentInfo->objectForKey(MCSTR("count")))->intValue();
    bool hasAttachment = (attachmentsCount > 0);

    peopleHasAttachment = peopleHasAttachment || hasAttachment;

    int r;
    sqlite3_stmt * stmt;
    r = sqlitePrepare("update message set attachments_count = ?, attachment_filename = ? where rowid = ?", &stmt);
    sqlite3_bind_int(stmt, 1, hasAttachment);
    if (attachmentFilename != NULL) {
        sqlite3_bind_text16(stmt, 2, attachmentFilename->unicodeCharacters(), -1, SQLITE_STATIC);
    }
    else {
        sqlite3_bind_null(stmt, 2);
    }
    sqlite3_bind_int64(stmt, 3, messageRowID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
    r = sqlitePrepare("update peopleview set hasattachment = ? where rowid = ?", &stmt);
    sqlite3_bind_int(stmt, 1, peopleHasAttachment);
    sqlite3_bind_int64(stmt, 2, peopleViewID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);

}

mailcore::MessageParser * MailDB::storedParsedMessage(int64_t messageRowID)
{
    String * key = String::stringWithUTF8Format("msg-%lld-p", (long long) messageRowID);
    Data * data = mKVDB->objectForKey(key);
    if (data == NULL) {
        return NULL;
    }
    MessageParser * message = (MessageParser *) hermes::objectWithFastSerializedData(data);
    return message;
}

void MailDB::parseMessageAndStoreParts(int64_t messageRowID,
                                       mailcore::Data * data,
                                       MailDBChanges * changes)
{
    MessageParser * message = MessageParser::messageParserWithData(data);
    recursiveStorePart(messageRowID, message->mainPart(), changes);

    // Also store MessageParser result.
    storeParsedMessage(messageRowID, message);
}

void MailDB::recursiveStorePart(int64_t messageRowID,
                                mailcore::AbstractPart * part,
                                MailDBChanges * changes)
{
    switch (part->partType()) {
        case PartTypeSingle:
        {
            return recursiveStoreSinglePart(messageRowID, (Attachment *) part, changes);
        }
        case PartTypeMessage:
        {
            return recursiveStoreMessagePart(messageRowID, (MessagePart *) part, changes);
        }
        case PartTypeMultipartMixed:
        case PartTypeMultipartRelated:
        case PartTypeMultipartAlternative:
        case PartTypeMultipartSigned:
            return recursiveStoreMultipart(messageRowID, (Multipart *) part, changes);
        default:
            MCAssert(0);
    }
}

void MailDB::recursiveStoreSinglePart(int64_t messageRowID,
                                      mailcore::Attachment * part,
                                      MailDBChanges * changes)
{
    storeDataForPart(messageRowID, part->partID(), part->data(), changes);
}

void MailDB::recursiveStoreMessagePart(int64_t messageRowID,
                                       mailcore::MessagePart * part,
                                       MailDBChanges * changes)
{
    recursiveStorePart(messageRowID, part->mainPart(), changes);
}

void MailDB::recursiveStoreMultipart(int64_t messageRowID,
                                     mailcore::Multipart * part,
                                     MailDBChanges * changes)
{
    mc_foreacharrayIndex(idx, AbstractPart, subpart, part->parts()) {
        recursiveStorePart(messageRowID, subpart, changes);
    }
}

bool MailDB::checkFolderSeen(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;

    int64_t lastUID = 0;
    r = sqlitePrepare("select lastuid from folder where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r != SQLITE_ROW) {
            sqliteReset(stmt);
            return false;
        }
        lastUID = sqlite3_column_int64(stmt, 0);
    }
    sqliteReset(stmt);
    if (lastUID == 0) {
        return false;
    }

    int folderSeen = 0;
    r = sqlitePrepare("select unread from message where uid = ? and folderid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, lastUID);
    sqlite3_bind_int64(stmt, 2, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r != SQLITE_ROW) {
            // Message has been deleted -> it's been seen.
            folderSeen = true;
        }
        else {
            int unread = sqlite3_column_int(stmt, 0);
            folderSeen = (unread == 0);
        }
    }
    sqliteReset(stmt);

    if (folderSeen) {
        storeLastSeenUIDForFolder(folderID);
    }

    return folderSeen;
}

bool MailDB::isFirstSyncDone(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;
    int firstSyncDone = 0;

    r = sqlitePrepare("select firstsyncdone from folder where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    if (r == SQLITE_OK) {
        r = sqlite3_step(stmt);
        if (r != SQLITE_ROW) {
            sqliteReset(stmt);
            return false;
        }
        firstSyncDone = sqlite3_column_int(stmt, 0);
    }
    sqliteReset(stmt);
    return firstSyncDone != 0;
}

void MailDB::markFirstSyncDone(int64_t folderID)
{
    int r;
    sqlite3_stmt * stmt;

    r = sqlitePrepare("update folder set firstsyncdone = 1 where rowid = ?", &stmt);
    sqlite3_bind_int64(stmt, 1, folderID);
    r = sqlite3_step(stmt);
    sqliteReset(stmt);
}

void MailDB::computePeopleViewCounts(MailDBChanges * changes)
{
    if (changes->changedCountPeopleViewIDs()->count() == 0) {
        return;
    }
    Array * peopleViewIDs = Array::array();
    peopleViewIDs->addObjectsFromArray(changes->addedPeopleViewIDs());
    peopleViewIDs->addObjectsFromArray(changes->modifiedPeopleViewIDs());
    IndexSet * modifiedPeopleViewIDs = new IndexSet();
    mc_foreacharray(Value, vPeopleViewID, peopleViewIDs) {
        modifiedPeopleViewIDs->addIndex(vPeopleViewID->longLongValue());
    }

    IndexSet * changedPeopleView = (IndexSet *) changes->changedCountPeopleViewIDs()->copy();
    changedPeopleView->intersectsIndexSet(modifiedPeopleViewIDs);
    MC_SAFE_RELEASE(modifiedPeopleViewIDs);

    {
        mc_foreachindexset(peopleViewID, changedPeopleView) {
            int current_unread_count = 0;
            int current_starred_count = 0;
            int r;
            sqlite3_stmt * stmt;
            int64_t date = -1;
            r = sqlitePrepare("select unread, starred, date from peopleview where rowid = ?", &stmt);
            sqlite3_bind_int64(stmt, 1, peopleViewID);
            if (r == SQLITE_OK) {
                r = sqlite3_step(stmt);
                if (r == SQLITE_ROW) {
                    current_unread_count = sqlite3_column_int(stmt, 0);
                    current_starred_count = sqlite3_column_int(stmt, 1);
                    date = sqlite3_column_int64(stmt, 2);
                }
            }
            sqliteReset(stmt);

            int unread_count = 0;
            int starred_count = 0;
            r = sqlitePrepare("select sum(unread), sum(starred) from message where peopleviewid = ?", &stmt);
            sqlite3_bind_int64(stmt, 1, peopleViewID);
            if (r == SQLITE_OK) {
                r = sqlite3_step(stmt);
                if (r == SQLITE_ROW) {
                    unread_count = sqlite3_column_int(stmt, 0);
                    starred_count = sqlite3_column_int(stmt, 1);
                }
            }
            sqliteReset(stmt);

            if ((unread_count != current_unread_count) || (starred_count != current_starred_count)) {
                r = sqlitePrepare("update peopleview set starred = ?, unread = ? where rowid = ?", &stmt);
                sqlite3_bind_int(stmt, 1, starred_count);
                sqlite3_bind_int(stmt, 2, unread_count);
                sqlite3_bind_int64(stmt, 3, peopleViewID);
                r = sqlite3_step(stmt);
                sqliteReset(stmt);

                IndexSet * folderIDs = new IndexSet();
                r = sqlitePrepare("select folderid from peopleviewfolder where peopleviewid = ?", &stmt);
                sqlite3_bind_int64(stmt, 1, peopleViewID);
                if (r == SQLITE_OK) {
                    do {
                        r = sqlite3_step(stmt);
                        if (r != SQLITE_ROW) {
                            break;
                        }
                        int64_t folderID = sqlite3_column_int(stmt, 0);
                        folderIDs->addIndex(folderID);
                    } while (1);
                }
                sqliteReset(stmt);

                unread_count = unread_count > 0 ? 1 : 0;
                starred_count = starred_count > 0 ? 1 : 0;
                current_unread_count = current_unread_count > 0 ? 1 : 0;
                current_starred_count = current_starred_count > 0 ? 1 : 0;
                if ((unread_count != current_unread_count) || (starred_count != current_starred_count)) {
                    mc_foreachindexset(folderID, folderIDs) {
                        int folder_unread_count = 0;
                        int folder_starred_count = 0;
                        int folder_count = 0;

                        r = sqlitePrepare("select unread, starred, count from folder where rowid = ?", &stmt);
                        sqlite3_bind_int64(stmt, 1, folderID);
                        if (r == SQLITE_OK) {
                            r = sqlite3_step(stmt);
                            if (r == SQLITE_ROW) {
                                folder_unread_count = sqlite3_column_int(stmt, 0);
                                folder_starred_count = sqlite3_column_int(stmt, 1);
                                folder_count = sqlite3_column_int(stmt, 2);
                            }
                        }
                        sqliteReset(stmt);

                        if (unread_count && !current_unread_count) {
                            folder_unread_count ++;
                        }
                        if (!unread_count && current_unread_count) {
                            folder_unread_count --;
                        }
                        if (starred_count && !current_starred_count) {
                            folder_starred_count ++;
                        }
                        if (!starred_count && current_starred_count) {
                            folder_starred_count --;
                        }

                        r = sqlitePrepare("update folder set unread = ?, starred = ? where rowid = ?", &stmt);
                        sqlite3_bind_int(stmt, 1, folder_unread_count);
                        sqlite3_bind_int(stmt, 2, folder_starred_count);
                        sqlite3_bind_int64(stmt, 3, folderID);
                        r = sqlite3_step(stmt);
                        sqliteReset(stmt);

                        changes->changeCountForFolderID(folderID, folder_unread_count, folder_starred_count, folder_count);
                    }
                }

                MC_SAFE_RELEASE(folderIDs);
            }
            changes->modifyPeopleViewID(peopleViewID, date);
        }
    }
    MC_SAFE_RELEASE(changedPeopleView);
}
