// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLLocalAvatarManager.h"

#import "DJLSingleton.h"
#import "CGImage+DJL.h"

@implementation DJLLocalAvatarManager {
    dispatch_queue_t _dispatchQueue;
}

+ (DJLLocalAvatarManager *) sharedManager
{
    DJLSINGLETON(DJLLocalAvatarManager);
}

- (id) init
{
    self = [super init];
    _dispatchQueue = dispatch_queue_create("DJLLocalAvatarManager", DISPATCH_QUEUE_SERIAL);
    return self;
}

static NSArray * s_matches = nil;
static NSMutableArray * s_regexpArray = nil;
static int s_forceAvatarIndex = -1;

+ (void) debugNextAvatar
{
    s_forceAvatarIndex ++;
    if (s_forceAvatarIndex == [s_matches count]) {
        s_forceAvatarIndex = -1;
    }
}

- (void) loadImageForEmail:(NSString *)email size:(int)size loaded:(void (^)(CGImageRef))loaded
{
    dispatch_async(_dispatchQueue, ^{
        if (s_matches == nil) {
            NSString * filename = [[NSBundle mainBundle] pathForResource:@"avatar" ofType:@"json"];
            NSData * data = [NSData dataWithContentsOfFile:filename];
            s_matches = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            
            s_regexpArray = [NSMutableArray array];
            for(unsigned int i = 0 ; i < [s_matches count] ; i ++) {
                NSDictionary * matchInfo = [s_matches objectAtIndex:i];
                NSArray * regexpStrings = [matchInfo objectForKey:@"email-match"];
                NSMutableArray * compiledArray = [NSMutableArray array];
                for(NSString * regexpString in regexpStrings) {
                    NSRegularExpression * regExp = [NSRegularExpression regularExpressionWithPattern:regexpString options:NSRegularExpressionCaseInsensitive error:NULL];
                    [compiledArray addObject:regExp];
                }
                [s_regexpArray addObject:compiledArray];
            }
        }
        
        for(unsigned int i = 0 ; i < [s_matches count] ; i ++) {
            NSDictionary * matchInfo = [s_matches objectAtIndex:i];
            NSArray * compiledArray = [s_regexpArray objectAtIndex:i];
            BOOL matches = NO;
            for(NSRegularExpression * regexp in compiledArray) {
                if ([regexp numberOfMatchesInString:email options:0 range:NSMakeRange(0, [email length])] > 0) {
                    matches = YES;
                    break;
                }
            }
            if (matches) {
                if (s_forceAvatarIndex != -1) {
                    matchInfo = s_matches[s_forceAvatarIndex];
                }
                NSString * name = [matchInfo objectForKey:@"image"];
                NSString * imageFilename = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
                NSData * imageData = [NSData dataWithContentsOfFile:imageFilename];
                CGImageRef image = NULL;
                if (imageData != nil) {
                    image = DJLCGImageCreateWithData((__bridge CFDataRef) imageData, size);
                }
                if (image != NULL) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        loaded(image);
                        CGImageRelease(image);
                    });
                }
                return;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            loaded(NULL);
        });
    });
}

@end
