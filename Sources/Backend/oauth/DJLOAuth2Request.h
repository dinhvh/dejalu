// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

#define DJLOAuth2ErrorDomain @"DJLOAuth2ErrorDomain"

enum {
    DJLOAuth2ErrorToken,
};

typedef void (^DJLOAuth2RequestCompletion)(NSDictionary * result, NSError * error);

@interface DJLOAuth2Request : NSObject

@property (nonatomic, copy) NSURL * tokenURL;
@property (nonatomic, retain) NSDictionary * parameters;

- (void) startWithCompletion:(DJLOAuth2RequestCompletion)completion;

+ (void) startGoogleOAuth2WithParameters:(NSDictionary *)parameters completion:(DJLOAuth2RequestCompletion)completion;
+ (void) startOutlookOAuth2WithParameters:(NSDictionary *)parameters completion:(DJLOAuth2RequestCompletion)completion;

@end
