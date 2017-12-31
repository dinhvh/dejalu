// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <ImageIO/ImageIO.h>
#endif

@interface DJLLocalAvatarManager : NSObject

+ (void) debugNextAvatar;

+ (DJLLocalAvatarManager *) sharedManager;
- (void) loadImageForEmail:(NSString *)email size:(int)size loaded:(void (^)(CGImageRef))loaded;

@end
