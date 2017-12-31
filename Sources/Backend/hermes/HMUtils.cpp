// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMUtils.h"

#include <sys/time.h>
#include <sys/stat.h>
#include <dirent.h>

using namespace hermes;
using namespace mailcore;

bool hermes::isConnectionError(hermes::ErrorCode error)
{
    switch (error) {
        case ErrorConnection:
        case ErrorTLSNotAvailable:
        case ErrorStartTLSNotAvailable:
        case ErrorCertificate:
        case ErrorParse:
        case ErrorGmailExceededBandwidthLimit:
        case ErrorGmailTooManySimultaneousConnections:
        case ErrorNoValidServerFound:
        return true;
        default:
        return false;
    }
}

bool hermes::isFatalError(hermes::ErrorCode error)
{
    switch (error) {
        case ErrorGmailIMAPNotEnabled:
        case ErrorMobileMeMoved:
        case ErrorYahooUnavailable:
        case ErrorNeedsConnectToWebmail:
        case ErrorCompression:
        case ErrorInvalidAccount:
        return true;
        default:
        return false;
    }
}

bool hermes::isAuthenticationError(hermes::ErrorCode error)
{
    return (error == ErrorAuthentication) ||
    (error == ErrorAuthenticationRequired) ||
    (error == ErrorGmailApplicationSpecificPasswordRequired);
}

// should skip message.
bool hermes::isSendError(hermes::ErrorCode error)
{
    //ErrorNonExistantFolder,
    switch (error) {
        case ErrorSendMessageIllegalAttachment:
        case ErrorStorageLimit:
        case ErrorSendMessageNotAllowed:
        case ErrorSendMessage:
        case ErrorFile:
        case ErrorNoSender:
        case ErrorNoRecipient:
        return true;
        default:
        return false;
    }
}

double hermes::currentTime(void)
{
    struct timeval t;
    gettimeofday(&t, NULL);
    return (double) t.tv_sec + (double) t.tv_usec / 1000000.;
}

mailcore::String * hermes::uniquePath(mailcore::String * baseFolder, mailcore::String * baseName)
{
    String * path = NULL;
    int count = 1;
    String * ext = baseName->pathExtension();
    baseName = baseName->stringByDeletingPathExtension();
    while (1) {
        path = String::string();
        path->appendString(baseFolder);
        path->appendString(MCSTR("/"));
        path->appendString(baseName);
        if (count >= 2) {
            path->appendUTF8Format(" %i", count);
        }
        if (ext->length() > 0) {
            path->appendString(MCSTR("."));
            path->appendString(ext);
        }

        const char * cPath = path->fileSystemRepresentation();
        struct stat statbuf;
        int r = stat(cPath, &statbuf);
        if (r < 0) {
            return path;
        }
        count ++;
    }
}

static void removeFileWithType(mailcore::String * filename, int type);

void hermes::removeFile(mailcore::String * filename)
{
    int r;
    struct stat statinfo;

    r = stat(filename->fileSystemRepresentation(), &statinfo);
    if (r < 0)
        return;

    if (S_ISDIR(statinfo.st_mode)) {
        removeFileWithType(filename, DT_DIR);
    }
    else {
        removeFileWithType(filename, DT_REG);
    }
}

static void removeFileWithType(mailcore::String * filename, int type)
{
    if (type == DT_DIR) {
        DIR * dir = opendir(filename->fileSystemRepresentation());
        if (dir == NULL) {
            return;
        }

        struct dirent * ent;
        while ((ent = readdir(dir)) != NULL) {
            if ((strcmp(ent->d_name, ".") == 0) || (strcmp(ent->d_name, "..") == 0)) {
                continue;
            }

            String * subpath = filename->stringByAppendingPathComponent(String::stringWithFileSystemRepresentation(ent->d_name));
            removeFileWithType(subpath, ent->d_type);
        }
        closedir(dir);
        unlink(filename->fileSystemRepresentation());
    }
    else if (type == DT_REG) {
        unlink(filename->fileSystemRepresentation());
    }
}
