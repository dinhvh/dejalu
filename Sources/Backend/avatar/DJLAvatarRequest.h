// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

#ifdef TARGET_OS_IPHONE
#import <ImageIO/ImageIO.h>
#else
#import <ApplicationServices/ApplicationServices.h>
#endif

@protocol DJLAvatarRequestDelegate;

@interface DJLAvatarRequest : NSObject

@property (nonatomic, copy) NSString * email;
@property (nonatomic, assign) int size;
@property (nonatomic, weak) id <DJLAvatarRequestDelegate> delegate;
@property (nonatomic, retain) dispatch_queue_t dispatchQueue;

- (void) start;

@end

@protocol DJLAvatarRequestDelegate

- (void) DJLAvatarRequestUpdate:(DJLAvatarRequest *)request
                          image:(CGImageRef)image;

- (void) DJLAvatarRequestDone:(DJLAvatarRequest *)request;

@end
