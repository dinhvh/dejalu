// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

#ifdef TARGET_OS_IPHONE
#import <ImageIO/ImageIO.h>
#endif

@protocol DJLGravatarRequestDelegate;

@interface DJLGravatarRequest : NSObject

@property (nonatomic, copy) NSString * email;
@property (nonatomic, assign) int size;
@property (nonatomic, weak) id <DJLGravatarRequestDelegate> delegate;
@property (nonatomic, assign, readonly) CGImageRef cgImage;
@property (nonatomic, retain) dispatch_queue_t dispatchQueue;

- (void) start;

@end

@protocol DJLGravatarRequestDelegate <NSObject>

- (void) DJLGravatarRequestDone:(DJLGravatarRequest *)request;

@end
