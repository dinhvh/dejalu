// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_DJLSingleton_h
#define dejalu_DJLSingleton_h

#define DJLSINGLETON(className) \
  static className * singleton = nil; \
  static dispatch_once_t onceToken; \
  dispatch_once(&onceToken, ^{ \
    singleton = [[className alloc] init]; \
  }); \
  return singleton;

#endif
