// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLOAuth2Request.h"

#import "NSDictionary+DJL.h"
#import "NSData+DJL.h"
#include "DJLLog.h"

@interface DJLOAuth2Request () <NSURLSessionDelegate>

@end

@implementation DJLOAuth2Request {
    NSURL * _tokenURL;
    NSDictionary * _parameters;
    NSURLSession * _session;
    NSURLSessionDataTask * _task;
    NSError * _error;
}

@synthesize tokenURL = _tokenURL;
@synthesize parameters = _parameters;

- (void) startWithCompletion:(DJLOAuth2RequestCompletion)completion
{
    __weak typeof(self) weakSelf = self;

    DJLOAuth2RequestCompletion completionCopy = [completion copy];

    NSURLSessionConfiguration * config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [config setTimeoutIntervalForRequest:30];
    _session = [NSURLSession sessionWithConfiguration:config];

    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[self tokenURL]];
    [request setHTTPMethod:@"POST"];
//    code=4/v6xr77ewYqhvHSyW6UJ1w7jKwAzu&
//    client_id=8819981768.apps.googleusercontent.com&
//    client_secret=your_client_secret&
//    redirect_uri=https://oauth2-login-demo.appspot.com/code&
//    grant_type=authorization_code

//    client_id=8819981768.apps.googleusercontent.com&
//    client_secret=your_client_secret&
//    refresh_token=1/6BMfW9j53gdGImsiyUH5kU5RsR4zwI9lUVX-tqf8JXQ&
//    grant_type=refresh_token
    [request setHTTPBody:[[_parameters djlQueryString] dataUsingEncoding:NSUTF8StringEncoding]];
    _task = [_session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // We use self because self needs to be alive while waiting for the result.
            typeof(self) strongSelf = self;
            if (strongSelf == nil) {
                return;
            }
            strongSelf->_task = nil;
            strongSelf->_session = nil;
            if (error != nil) {
                //NSLog(@"error: %@", error);
                LOG_ERROR("oauth2 error: %s", [[error description] UTF8String]);
                completionCopy(nil, error);
                return;
            }
            if ([(NSHTTPURLResponse *) response statusCode] != 200) {
                //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                LOG_ERROR("oauth2 response error: %.*s", (int) [data length], [data bytes]);
                completionCopy(nil, [NSError errorWithDomain:DJLOAuth2ErrorDomain code:DJLOAuth2ErrorToken userInfo:nil]);
                return;
            }

            NSError * jsonError;
            NSDictionary * result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (result == nil) {
                completionCopy(nil, jsonError);
                return;
            }
            //            {
            //                "access_token":"1/fFAGRNJru1FTz70BzhT3Zg",
            //                "expires_in":3920,
            //                "token_type":"Bearer",
            //                "refresh_token":"1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI"
            //            }

            //            {
            //                "access_token":"1/fFBGRNJru1FQd44AzqT3Zg",
            //                "expires_in":3920,
            //                "token_type":"Bearer"
            //            }
            completionCopy(result, nil);
        });
    }];
    [_task resume];
}

+ (void) startGoogleOAuth2WithParameters:(NSDictionary *)parameters completion:(DJLOAuth2RequestCompletion)completion
{
    DJLOAuth2Request * request = [[DJLOAuth2Request alloc] init];
    [request setTokenURL:[NSURL URLWithString:@"https://www.googleapis.com/oauth2/v3/token"]];
    [request setParameters:parameters];
    [request startWithCompletion:completion];
}

+ (void) startOutlookOAuth2WithParameters:(NSDictionary *)parameters completion:(DJLOAuth2RequestCompletion)completion
{
    DJLOAuth2Request * request = [[DJLOAuth2Request alloc] init];
    [request setTokenURL:[NSURL URLWithString:@"https://login.live.com/oauth20_token.srf"]];
    [request setParameters:parameters];
    [request startWithCompletion:completion];
}

@end
