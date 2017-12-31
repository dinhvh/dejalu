// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLProfileRequest.h"

#import "NSDictionary+DJL.h"

@interface DJLProfileRequest () <NSURLSessionDelegate>

@end

@implementation DJLProfileRequest {
    NSString * _token;
    NSURLSession * _session;
    NSURLSessionDataTask * _task;
    NSError * _error;
}

@synthesize token = _token;

- (void) startWithCompletion:(DJLProfileRequestCompletion)completion
{
    if ([[self provider] isEqualToString:@"gmail"]) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                 delegate:self delegateQueue:nil];
        NSDictionary * parameters = @{@"alt": @"json", @"access_token": _token};
        NSString * urlString = [NSString stringWithFormat:@"https://www.googleapis.com/oauth2/v1/userinfo?%@", [parameters djlQueryString]];
        _task = [_session dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error != nil) {
                    completion(nil, error);
                    return;
                }
                if ([(NSHTTPURLResponse *) response statusCode] != 200) {
                    //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    completion(nil, [NSError errorWithDomain:DJLProfileErrorDomain code:DJLProfileErrorAuthentication userInfo:nil]);
                    return;
                }

                NSError * jsonError;
                NSDictionary * result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError != nil) {
                    completion(nil, jsonError);
                    return;
                }
                completion(result, nil);
            });
        }];
        [_task resume];
    }
    else if ([[self provider] isEqualToString:@"outlook"]) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                 delegate:self delegateQueue:nil];
        NSString * urlString = @"https://outlook.office365.com/api/v1.0/me";
        NSURL * url = [NSURL URLWithString:urlString];
        NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:url];
        NSString * value = [NSString stringWithFormat:@"Bearer %@", _token];
        [request addValue:value forHTTPHeaderField:@"Authorization"];
        _task = [_session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error != nil) {
                    completion(nil, error);
                    return;
                }
                if ([(NSHTTPURLResponse *) response statusCode] != 200) {
                    //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    completion(nil, [NSError errorWithDomain:DJLProfileErrorDomain code:DJLProfileErrorAuthentication userInfo:nil]);
                    return;
                }

                NSError * jsonError;
                NSDictionary * result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError != nil) {
                    completion(nil, jsonError);
                    return;
                }
                completion(result, nil);
            });
        }];
        [_task resume];
    }
    else {
        NSAssert(0, @"unsupported provider");
    }
}

+ (void) startWithToken:(NSString *)token
               provider:(NSString *)provider
             completion:(DJLProfileRequestCompletion)completion
{
    DJLProfileRequest * request = [[DJLProfileRequest alloc] init];
    [request setProvider:provider];
    [request setToken:token];
    [request startWithCompletion:completion];
}

@end
