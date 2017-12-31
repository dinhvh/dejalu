// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface DJLSearchField : NSSearchField

@end

@protocol DJLSearchFieldDelegate <NSObject>

- (void) djl_searchFieldOperationCancelled:(DJLSearchField *)searchField;

@end
