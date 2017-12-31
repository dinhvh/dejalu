// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_DJLLog_h
#define dejalu_DJLLog_h

#include <stdio.h>

#define LOG_ERROR(...) DJLLogWithID("error", __VA_ARGS__)
#define LOG_ERROR_STACK(...) DJLLogStackWithID("error", __VA_ARGS__)

#define DJLLog(...) DJLLogInternal("default", NULL, __FILE__, __LINE__, 0, __VA_ARGS__)
#define DJLLogStack(...) DJLLogInternal("default", NULL, __FILE__, __LINE__, 1, __VA_ARGS__)
#define DJLLogWithID(logid, ...) DJLLogInternal(logid, NULL, __FILE__, __LINE__, 0, __VA_ARGS__)
#define DJLLogStackWithID(logid, ...) DJLLogInternal(logid, NULL, __FILE__, __LINE__, 1, __VA_ARGS__)

extern int DJLLogEnabled;

#ifndef __printflike
#define __printflike(a,b)
#endif

#ifdef __cplusplus
extern "C" {
#endif
    void DJLLogInit(void);
    
    void DJLLogEnable(const char * logid);
    
    void DJLLogSetFile(FILE * aLogFile);
    void DJLLogFileClose(void);

    void DJLLogInternal(const char * logid,
                        const char * user,
                        const char * filename,
                        unsigned int line,
                        int dumpStack,
                        const char * format, ...) __printflike(6, 7);

#ifdef __cplusplus
}
#endif

#endif
