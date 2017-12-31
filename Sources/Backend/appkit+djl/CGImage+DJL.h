// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#else
#import <AppKit/AppKit.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

CGImageRef DJLCGImageCreateWithData(CFDataRef data, int size);

#ifdef __cplusplus
}
#endif
