// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#else
#import <AppKit/AppKit.h>
#endif

#define DJLAVATARMANAGER_UPDATED @"DJLAVATARMANAGER_UPDATED"

@interface DJLAvatarManager : NSObject

- (void) debugNextServiceAvatar;

+ (DJLAvatarManager *) sharedManager;
#if TARGET_OS_IPHONE
- (UIImage *) avatarForEmail:(NSString *)email size:(int)size;
#else
- (NSImage *) avatarForEmail:(NSString *)email size:(int)size;
#endif

@end
