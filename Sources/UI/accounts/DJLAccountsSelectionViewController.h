// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>

#include "Hermes.h"

@protocol DJLAccountsSelectionViewControllerDelegate;

@interface DJLAccountsSelectionViewController : NSViewController

@property (nonatomic, assign) id<DJLAccountsSelectionViewControllerDelegate> delegate;

- (void) reloadData;
- (void) makeFirstResponder;
- (void) prepareSize;

@end

@protocol DJLAccountsSelectionViewControllerDelegate <NSObject>

- (void) DJLAccountsSelectionViewController:(DJLAccountsSelectionViewController *)controller accountSelected:(hermes::Account *)account emailAlias:(NSString *)emailAlias;
- (void) DJLAccountsSelectionViewController:(DJLAccountsSelectionViewController *)controller hasHeight:(CGFloat)height;

@end
