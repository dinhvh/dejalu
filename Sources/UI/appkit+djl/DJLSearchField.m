// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLSearchField.h"

@implementation DJLSearchField

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    [self setDrawsBackground:NO];
    return self;
}

- (void)cancelOperation:(id)sender
{
    [(id <DJLSearchFieldDelegate>)[self delegate] djl_searchFieldOperationCancelled:self];
}

@end
