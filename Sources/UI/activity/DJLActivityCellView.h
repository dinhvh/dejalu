// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#include "Hermes.h"

@interface DJLActivityCellView : NSView

#ifdef __cplusplus
@property (nonatomic, assign) hermes::ActivityItem * activityItem;
#endif

@end
