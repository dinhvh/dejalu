// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGravatarRequest.h"

#include <MailCore/MailCore.h>
#import "CGImage+DJL.h"
#import "NSString+DJL.h"

@implementation DJLGravatarRequest {
    NSURLConnection * _connection;
    NSData * _data;
    CGImageRef _cgImage;
    __weak id <DJLGravatarRequestDelegate> _delegate;
    int _size;
    NSString * _email;
    dispatch_queue_t _dispatchQueue;
    BOOL _failed;
}

@synthesize email = _email;
@synthesize size = _size;
@synthesize delegate = _delegate;
@synthesize cgImage = _cgImage;
@synthesize dispatchQueue = _dispatchQueue;

- (void) dealloc
{
    if (_cgImage != NULL) {
        CGImageRelease(_cgImage);
    }
}

- (void) start
{
    _data = [NSMutableData data];
    _email = [_email lowercaseString];
    mailcore::String * md5String = mailcore::md5String((mailcore::Data *) [[_email dataUsingEncoding:NSUTF8StringEncoding] mco_mcObject]);
    NSString * urlString = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%s?s=%i&d=404", md5String->UTF8Characters(), _size];
    NSURL * url = [NSURL URLWithString:urlString];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDownloadTask * task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL * location, NSURLResponse * response, NSError * error) {
        [weakSelf _downloadFinishedWithLocation:location response:response error:error];
    }];
    [task resume];
}

- (void) _downloadFinishedWithLocation:(NSURL *)location response:(NSURLResponse *)response error:(NSError *)error
{
    __weak typeof(self) weakSelf = self;

    if (error != nil) {
        _failed = YES;
    }
    else {
        NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            _failed = YES;
        }
    }

    if (_failed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[weakSelf delegate] DJLGravatarRequestDone:self];
        });
        return;
    }

    _data = [NSData dataWithContentsOfURL:location];
    
    dispatch_async(_dispatchQueue, ^{
        _cgImage = DJLCGImageCreateWithData((__bridge CFDataRef) _data, _size);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[weakSelf delegate] DJLGravatarRequestDone:self];
        });
    });
}

@end
