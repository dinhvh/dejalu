// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAvatarManager.h"

#import "DJLAvatarRequest.h"
#import "DJLSingleton.h"
#import "DJLAddressBookManager.h"
#import "DJLLocalAvatarManager.h"

@interface DJLAvatarManager () <DJLAvatarRequestDelegate>

@end

@implementation DJLAvatarManager {
    NSCache * _cache;
    int _cacheGeneration;
    DJLAvatarRequest * _currentRequest;
    dispatch_queue_t _dispatchQueue;
    NSMutableArray * _requests;
    NSMutableSet * _pending;
}

+ (DJLAvatarManager *) sharedManager
{
    DJLSINGLETON(DJLAvatarManager);
}

- (id) init
{
    self = [super init];
    
    _requests = [NSMutableArray array];
    _pending = [NSMutableSet set];
    _dispatchQueue = dispatch_queue_create("DJLAvatarManager", DISPATCH_QUEUE_SERIAL);
    _cache = [[NSCache alloc] init];
    [_cache setCountLimit:200];
    _cacheGeneration = 0;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_addressBookLoaded) name:DJLADDRESSBOOKMANAGER_LOADED object:nil];
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#if TARGET_OS_IPHONE
- (UIImage *) avatarForEmail:(NSString *)email size:(int)size
#else
- (NSImage *) avatarForEmail:(NSString *)email size:(int)size
#endif
{
    NSString * key = [NSString stringWithFormat:@"%@-%i", email, size];
    NSDictionary * cacheItem = [_cache objectForKey:key];
#if TARGET_OS_IPHONE
    UIImage * image;
#else
    NSImage * image;
#endif
    image = [cacheItem objectForKey:@"image"];
    NSDate * date = [cacheItem objectForKey:@"date"];
    int cacheGeneration = [(NSNumber *) [cacheItem objectForKey:@"generation"] intValue];
    
    if (image == nil) {
        date = [NSDate distantPast];
    }
    if ((cacheGeneration != _cacheGeneration) || (- [date timeIntervalSinceNow] > 60 * 60 * 24)) { // 1 day
        if (![_pending containsObject:key]) {
            DJLAvatarRequest * request = [[DJLAvatarRequest alloc] init];
            [request setDispatchQueue:_dispatchQueue];
            [request setEmail:email];
            [request setSize:size];
            [request setDelegate:self];
            [request start];
            [_requests addObject:request];
            [_pending addObject:key];
        }
    }

    if (image == (NSImage *) [NSNull null]) {
        return nil;
    }
    return image;
}

- (void) DJLAvatarRequestUpdate:(DJLAvatarRequest *)request
                          image:(CGImageRef)cgImage
{
    NSString * key = [NSString stringWithFormat:@"%@-%i", [request email], [request size]];
    NSMutableDictionary * cacheItem = [NSMutableDictionary dictionary];
#if TARGET_OS_IPHONE
    // TODO: Check scale of the the image created from the CGImageRef.
    UIImage * image = [[UIImage alloc] initWithCGImage:cgImage];
#else
    NSSize size = NSMakeSize([request size], [request size]);
    NSImage * image = [[NSImage alloc] initWithCGImage:cgImage size:size];
#endif
    [cacheItem setObject:image forKey:@"image"];
    [cacheItem setObject:[NSDate date] forKey:@"date"];
    [cacheItem setObject:[NSNumber numberWithInt:_cacheGeneration] forKey:@"generation"];
    [_cache setObject:cacheItem forKey:key];
    
    // send notification for image, size
    NSMutableDictionary * info = [NSMutableDictionary dictionary];
    [info setObject:[request email] forKey:@"email"];
    [info setObject:[NSNumber numberWithInt:[request size]] forKey:@"size"];
    [[NSNotificationCenter defaultCenter] postNotificationName:DJLAVATARMANAGER_UPDATED object:self userInfo:info];
}

- (void) DJLAvatarRequestDone:(DJLAvatarRequest *)request
{
    NSString * key = [NSString stringWithFormat:@"%@-%i", [request email], [request size]];
    if ([_cache objectForKey:key] == nil) {
        NSMutableDictionary * cacheItem = [NSMutableDictionary dictionary];
        [cacheItem setObject:[NSNull null] forKey:@"image"];
        [cacheItem setObject:[NSDate date] forKey:@"date"];
        [cacheItem setObject:[NSNumber numberWithInt:_cacheGeneration] forKey:@"generation"];
        [_cache setObject:cacheItem forKey:key];
    }
    [_pending removeObject:key];
    [_requests removeObject:request];
}

- (void) _addressBookLoaded
{
    _cacheGeneration ++;
    [[NSNotificationCenter defaultCenter] postNotificationName:DJLAVATARMANAGER_UPDATED object:self userInfo:nil];
}

- (void) debugNextServiceAvatar
{
    [DJLLocalAvatarManager debugNextAvatar];
    [_cache removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:DJLAVATARMANAGER_UPDATED object:self userInfo:nil];
}

@end
