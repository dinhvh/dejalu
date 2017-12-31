// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include <stdio.h>

#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#if __APPLE__
#include <execinfo.h>
#endif
#include <libetpan/libetpan.h>

static pid_t sPid = -1;
int DJLLogEnabled = 0;

__attribute__((constructor))
static void initialize()
{
    sPid = getpid();
}

static void logInternalv(FILE * file,
                         const char * user, const char * filename, unsigned int line,
                         int dumpStack, const char * format, va_list argp);

static chash * enabledHash = NULL;

void DJLLogInit(void)
{
    enabledHash = chash_new(CHASH_DEFAULTSIZE, CHASH_COPYKEY);
}

void DJLLogEnable(const char * logid)
{
    chashdatum key;
    chashdatum value;
    key.data = (void *) logid;
    key.len = (unsigned int) strlen(logid);
    value.data = NULL;
    value.len = 0;
    chash_set(enabledHash, &key, &value, NULL);
}

static int isEnabled(const char * logid)
{
    int r;
    chashdatum key;
    chashdatum value;
    key.data = (void *) logid;
    key.len = (unsigned int) strlen(logid);
    r = chash_get(enabledHash, &key, &value);
    if (r < 0)
        return 0;
    return 1;
}

static FILE * logFile = NULL;
static pthread_mutex_t logFileLock = PTHREAD_MUTEX_INITIALIZER;

static void lock()
{
    pthread_mutex_lock(&logFileLock);
}

static void unlock()
{
    pthread_mutex_unlock(&logFileLock);
}

void DJLLogSetFile(FILE * aLogFile)
{
    lock();
    if (aLogFile != logFile) {
        logFile = aLogFile;
    }
    unlock();
}

void DJLLogFileClose(void)
{
    lock();
    if (logFile != NULL) {
        fclose(logFile);
        logFile = NULL;
    }
    unlock();
}

void DJLLogInternal(const char * logid, const char * user,
                    const char * filename,
                    unsigned int line,
                    int dumpStack,
                    const char * format, ...)
{
    va_list argp;
    
    va_start(argp, format);
    if (isEnabled(logid)) {
        lock();
        if (logFile == NULL) {
            logFile = stderr;
        }
        logInternalv(logFile, user, filename, line, dumpStack, format, argp);
        unlock();
    }
    va_end(argp);
}

static void logInternalv(FILE * file,
                         const char * user, const char * filename, unsigned int line,
                         int dumpStack, const char * format, va_list argp)
{
    if (!DJLLogEnabled)
        return;
    
    while (1) {
        const char * p = filename;
        
        p = strchr(filename, '/');
        if (p == NULL) {
            break;
        }
        filename = p + 1;
    }
    
    struct timeval tv;
    struct tm tm_value;
    pthread_t thread_id = pthread_self();
    
    gettimeofday(&tv, NULL);
    localtime_r(&tv.tv_sec, &tm_value);
    fprintf(file, "%04u-%02u-%02u %02u:%02u:%02u.%03u ", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min, tm_value.tm_sec, (int) (tv.tv_usec / 1000));
    
#ifdef __MACH__
    if (pthread_main_np()) {
#else
    if (0) {
#endif
        fprintf(file, "[%i:main] %s:%i: ", sPid, filename, line);
    }
    else {
        unsigned long threadValue;
#ifdef _MACH_PORT_T
        threadValue = pthread_mach_thread_np(thread_id);
#else
        threadValue = (unsigned long) thread_id;
#endif
        fprintf(file, "[%i:%lx] %s:%i: ", sPid, threadValue, filename, line);
    }
    vfprintf(file, format, argp);
    fprintf(file, "\n");
    
    if (dumpStack) {
#if __APPLE__
        void * frame[128];
        char ** frameSymbols;
        int frameCount;
        int i;
            
        fprintf(file, "    ");
        frameCount = backtrace(frame, 128);
        frameSymbols = backtrace_symbols(frame, frameCount);
        for(i = 0 ; i < frameCount ; i ++) {
            fprintf(file, " %p %s", frame[i], frameSymbols[i]);
        }
        fprintf(file, "\n");
        free(frameSymbols);
#endif
        // TODO: other platforms implemented needed.
    }
        
    fflush(file);
}
