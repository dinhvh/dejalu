// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAvatarRequest.h"

#import <MailCore/MailCore.h>

#import "DJLAddressBookManager.h"
#import "NSString+DJL.h"
#import "DJLGravatarRequest.h"
#import "CGImage+DJL.h"
#import "DJLLocalAvatarManager.h"
#import "DJLClearbitLogoRequest.h"

// step1: cache, continue if found
// step2: address book, stop if found
// step3: gmail, stop if found
// step4: gravatar, stop if found

@interface DJLAvatarRequest () <DJLGravatarRequestDelegate, DJLClearbitLogoRequestDelegate>

@end

@implementation DJLAvatarRequest {
    int _step;
    NSString * _email;
    int _size;
    __weak id <DJLAvatarRequestDelegate> _delegate;
    DJLGravatarRequest * _gravatarRequest;
    DJLClearbitLogoRequest * _clearbitLogoRequest;
    dispatch_queue_t _dispatchQueue;
    BOOL _found;
}

@synthesize email = _email;
@synthesize size = _size;
@synthesize delegate = _delegate;
@synthesize dispatchQueue = _dispatchQueue;

// notification
// cache
// address book
// gmail
// gravatar

- (void) start
{
    _found = NO;
    _step = 0;
    [self _requestNext];
}

- (void) _requestNext
{
    // TODO: cache avatar in memory
    switch (_step) {
        case 0:
            [self _requestLocalAvatar];
            break;
            
        case 1:
            [self _requestAddressBook];
            break;
            
        case 2:
            [self _requestGravatar];
            break;

        case 3:
            [self _requestClearbit];
            break;

        case 4:
            [self _fail];
    }
}

- (void) _requestLocalAvatar
{
    [[DJLLocalAvatarManager sharedManager] loadImageForEmail:_email size:_size * 2 loaded:^(CGImageRef image) {
        if (image != NULL) {
            _found = YES;
            [[self delegate] DJLAvatarRequestUpdate:self image:image];
        }
        _step ++;
        [self _requestNext];
    }];
}

- (void) _requestAddressBook
{
#if !TARGET_OS_IPHONE
    [[DJLAddressBookManager sharedManager] loadImageForEmail:_email size:_size * 2 loaded:^(CGImageRef image) {
        if (image != NULL) {
            _found = YES;
            [[self delegate] DJLAvatarRequestUpdate:self image:image];
            [[self delegate] DJLAvatarRequestDone:self];
            return;
        }
        
        _step ++;
        [self _requestNext];
    }];
#endif
}

- (void) _requestGravatar
{
    _gravatarRequest = [[DJLGravatarRequest alloc] init];
    [_gravatarRequest setDispatchQueue:_dispatchQueue];
    [_gravatarRequest setEmail:_email];
    [_gravatarRequest setSize:_size * 2];
    [_gravatarRequest setDelegate:self];
    [_gravatarRequest start];
}

- (void) DJLGravatarRequestDone:(DJLGravatarRequest *)request
{
    if ([_gravatarRequest cgImage] != NULL) {
        _found = YES;
        [[self delegate] DJLAvatarRequestUpdate:self image:[_gravatarRequest cgImage]];
        [[self delegate] DJLAvatarRequestDone:self];
        _gravatarRequest = nil;
        return;
    }
    _gravatarRequest = nil;
    _step ++;
    [self _requestNext];
}

- (void) _requestClearbit
{
    if (_found) {
        // skip
        _step ++;
        [self _requestNext];
        return;
    }

    _clearbitLogoRequest = [[DJLClearbitLogoRequest alloc] init];
    [_clearbitLogoRequest setDispatchQueue:_dispatchQueue];
    [_clearbitLogoRequest setEmail:_email];
    [_clearbitLogoRequest setSize:_size * 2];
    [_clearbitLogoRequest setDelegate:self];
    [_clearbitLogoRequest start];
}

- (void) DJLClearbitLogoRequestDone:(DJLClearbitLogoRequest *)request;
{
    if ([_clearbitLogoRequest cgImage] != NULL) {
        _found = YES;
        [[self delegate] DJLAvatarRequestUpdate:self image:[_clearbitLogoRequest cgImage]];
        [[self delegate] DJLAvatarRequestDone:self];
        _clearbitLogoRequest = nil;
        return;
    }
    _clearbitLogoRequest = nil;
    _step ++;
    [self _requestNext];
}

- (void) _fail
{
    [[self delegate] DJLAvatarRequestDone:self];
}

@end
