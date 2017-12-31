// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#pragma once

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Create and return the log folder located in the application data directory.
//NSString* LogDirectory();

// Returns the next available log file full path name.
NSString* NextAvailableLogFilePath(NSString* logDirectory);

// Remove log files from |logDirectory| until total log file size is less then
// |maxSize| bytes. Oldest files will be removed first.
//void PurgeLogDirectoryForMaxSizeInByte(NSString* logDirectory, int64_t maxSize);

#ifdef __cplusplus
}
#endif
