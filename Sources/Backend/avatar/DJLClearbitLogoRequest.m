// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLClearbitLogoRequest.h"

#include <MailCore/MailCore.h>
#import "CGImage+DJL.h"
#import "NSString+DJL.h"

@implementation DJLClearbitLogoRequest {
    NSURLConnection * _connection;
    NSData * _data;
    CGImageRef _cgImage;
    __weak id <DJLClearbitLogoRequestDelegate> _delegate;
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
    NSArray * components = [_email componentsSeparatedByString:@"@"];
    NSString * domain = nil;
    if ([components count] >= 2) {
        domain = [components lastObject];
        domain = [domain lowercaseString];
    }

    __weak typeof(self) weakSelf = self;
    if (domain == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[weakSelf delegate] DJLClearbitLogoRequestDone:self];
        });
        return;
    }

    static NSSet * clearBitBlackList = nil;
    if (clearBitBlackList == nil) {
        clearBitBlackList = [NSSet setWithArray:@[@"gmail.com", @"yahoo.com", @"googlemail.com", @"mac.com", @"me.com", @"icloud.com"]];
    }
    if ([clearBitBlackList containsObject:domain]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[weakSelf delegate] DJLClearbitLogoRequestDone:self];
        });
        return;
    }

    NSString * urlString = [NSString stringWithFormat:@"https://logo.clearbit.com/%@?size=%i", domain, _size];
    NSURL * url = [NSURL URLWithString:urlString];

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
            [[weakSelf delegate] DJLClearbitLogoRequestDone:self];
        });
        return;
    }

    _data = [NSData dataWithContentsOfURL:location];
    
    dispatch_async(_dispatchQueue, ^{
        _cgImage = DJLCGImageCreateWithData((__bridge CFDataRef) _data, _size);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[weakSelf delegate] DJLClearbitLogoRequestDone:self];
        });
    });
}

@end
