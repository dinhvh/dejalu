// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPathManager.h"

#import "DJLAssert.h"

#include <sys/stat.h>

@implementation DJLPathManager {
    dispatch_queue_t _dispatchQueue;
}

+ (instancetype) sharedManager
{
    static DJLPathManager *sharedInstance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        sharedInstance = [[DJLPathManager alloc] init];
    });

    return sharedInstance;
}

- (id) init
{
    self = [super init];
    _dispatchQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    [self _cleanAllLogs];
    return self;
}

- (NSString *) logsFolder
{
    static NSString *logsFolder = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        NSString * folder = [[DJLPathManager sharedManager] applicationDataFolder];
        folder = [folder stringByAppendingPathComponent:@"Logs"];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        logsFolder = folder;
    });

    return logsFolder;
}

- (NSString *) temporaryFolder
{
    NSString * tempDirectoryTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DejaLu.XXXXXX"];
    const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
    char * tempDirectoryNameCString = strdup(tempDirectoryTemplateCString);
    DJLAssert(tempDirectoryNameCString != NULL);
    char *result = mkdtemp(tempDirectoryNameCString);
    DJLAssert(result != NULL);
    NSString *tempDirectoryPath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempDirectoryNameCString
                                                                                              length:strlen(tempDirectoryTemplateCString)];
    free(tempDirectoryNameCString);
    return tempDirectoryPath;
}

- (NSString *) applicationDataFolder
{
    static NSString *applicationDataFolder = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        NSURL * folderURL = nil;
        NSArray * folders = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                   inDomains:NSUserDomainMask];
        if ([folders count] >= 1) {
            folderURL = [folders firstObject];
        }
        DJLAssert(folderURL != nil);
        NSString * folder = [folderURL path];
        folder = [folder stringByAppendingPathComponent:@"DejaLu"];

        applicationDataFolder = folder;
    });
    
    return applicationDataFolder;
}

- (NSString *) accountsFolder
{
    static NSString *accountsFolder = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        NSString * folder = [[DJLPathManager sharedManager] applicationDataFolder];
        folder = [folder stringByAppendingPathComponent:@"Accounts"];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        accountsFolder = folder;
    });
    return accountsFolder;
}

#define CLEAN_PERIOD (2 * 60 * 60)

- (void) _cleanAllLogs
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(_dispatchQueue, ^{
        [weakSelf _cleanAllLogsInQueue];
    });

    [self performSelector:@selector(_cleanAllLogs) withObject:nil afterDelay:CLEAN_PERIOD];
}

#define CLEAN_MIN_DELAY (12 * 60 * 60)
#define ACCOUNTS_LOGS_CLEAN_MIN_DELAY (12 * 60 * 60)

- (void) _cleanAllLogsInQueue
{
    NSString * folder = [self logsFolder];
    [self _cleanLogs:folder minDelay:CLEAN_MIN_DELAY];

    NSArray * names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self accountsFolder] error:NULL];
    for(NSString * name in names) {
        [self _cleanLogs:[[[self accountsFolder] stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"Logs"] minDelay:ACCOUNTS_LOGS_CLEAN_MIN_DELAY];
    }
}

- (void) _cleanLogs:(NSString *)folder minDelay:(time_t)minDelay
{
    time_t currentTime = time(NULL);
    if ([[NSFileManager defaultManager] fileExistsAtPath:folder]) {
        //NSLog(@"cleanLogs: %@", folder);
        NSArray * names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
        for(NSString * name in names) {
            if (![[name pathExtension] isEqualToString:@"log"]) {
                continue;
            }
            NSString * path = [folder stringByAppendingPathComponent:name];
            struct stat statbuf;
            int r = stat([path fileSystemRepresentation], &statbuf);
            if (r < 0) {
                continue;
            }
            if (currentTime - statbuf.st_mtime > minDelay) {
                //NSLog(@"removing %@", path);
                [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            }
        }
    }
}

@end
