// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Foundation/Foundation.h>

@interface DJLPathManager : NSObject

+ (instancetype) sharedManager;
- (NSString *) applicationDataFolder;
- (NSString *) temporaryFolder;
- (NSString *) accountsFolder;
- (NSString *) logsFolder;

@end
