// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

typedef void (^DJLProfileRequestCompletion)(NSDictionary * result, NSError * error);

#define DJLProfileErrorDomain @"DJLOAuth2ErrorDomain"

enum {
    DJLProfileErrorAuthentication,
};

@interface DJLProfileRequest : NSObject

@property (nonatomic, copy) NSString * token;
@property (nonatomic, copy) NSString * provider;

- (void) startWithCompletion:(DJLProfileRequestCompletion)completion;

+ (void) startWithToken:(NSString *)token
               provider:(NSString *)provider
             completion:(DJLProfileRequestCompletion)completion;

@end
