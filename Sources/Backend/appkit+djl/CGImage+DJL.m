// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "CGImage+DJL.h"

CGImageRef DJLCGImageCreateWithData(CFDataRef data, int size)
{
    CGImageRef image = NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, (__bridge CFDictionaryRef) @{});
    if (CGImageSourceGetCount(source) > 0) {
        NSMutableDictionary * info;
        info = [NSMutableDictionary dictionary];
        [info setObject:(id) kCFBooleanTrue forKey:(__bridge NSString *) kCGImageSourceCreateThumbnailWithTransform];
        [info setObject:(id) kCFBooleanTrue forKey:(__bridge NSString *) kCGImageSourceCreateThumbnailFromImageAlways];
        [info setObject:[NSNumber numberWithFloat:size] forKey:(__bridge NSString *) kCGImageSourceThumbnailMaxPixelSize];
        image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef) info);
    }
    CFRelease(source);
    CGDataProviderRelease(provider);
    return image;
}
