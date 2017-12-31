// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLLogUtils.h"

#import "DJLPathManager.h"
#include <sys/time.h>
#include <sys/stat.h>
#include <stdlib.h>

NSString* NextAvailableLogFilePath(NSString* folder) {
  struct timeval tv;
  struct tm tm_value;
  
  gettimeofday(&tv, NULL);
  localtime_r(&tv.tv_sec, &tm_value);
  char * dateBuffer = NULL;
  asprintf(&dateBuffer, "%04u-%02u-%02u--%02u:%02u", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min);
  
  NSString * path = nil;
  int count = 0;
  while (1) {
      struct stat statInfo;
      if (count == 0) {
          path = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.log", dateBuffer]];
      }
      else {
          path = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%s-%i.log", dateBuffer, count]];
      }
      if (stat([path fileSystemRepresentation], &statInfo) < 0) {
          break;
      }
      count ++;
  }
  free(dateBuffer);
  return path;
}
