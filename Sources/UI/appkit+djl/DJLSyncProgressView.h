// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLSyncProgressView : NSView

@property (nonatomic, assign) double progressValue;
@property (nonatomic, assign) double progressMax;
@property (nonatomic, copy) NSString * text;

@end
