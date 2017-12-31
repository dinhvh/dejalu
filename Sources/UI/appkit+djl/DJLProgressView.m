// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLProgressView.h"
#import <QuartzCore/QuartzCore.h>

@implementation DJLProgressView {
    CAShapeLayer * _layer;
    CGFloat _progressValue;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    
    _layer = [CAShapeLayer layer];
    [[self layer] addSublayer:_layer];
    
    return self;
}

- (void) setProgressValue:(CGFloat)progressValue {
    _progressValue = progressValue;
}

- (CGFloat) progressValue {
    return _progressValue;
}

@end
