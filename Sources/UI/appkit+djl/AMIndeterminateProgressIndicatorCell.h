//
//  AMIndeterminateProgressIndicatorCell.h
//  IPICellTest
//
//  Created by Andreas on 23.01.07.
//  Copyright 2007 Andreas Mayer. All rights reserved.
//

// modified for DejaLu

#import <Cocoa/Cocoa.h>


@interface AMIndeterminateProgressIndicatorCell : NSCell {
	double _doubleValue;
	NSTimeInterval _animationDelay;
	BOOL _displayedWhenStopped;
	BOOL _spinning;
	NSColor *_color;
	float _redComponent;
	float _greenComponent;
	float _blueComponent;
}

- (NSColor *)color;
- (void)setColor:(NSColor *)value;

- (double)doubleValue;
- (void)setDoubleValue:(double)value;

- (NSTimeInterval)animationDelay;
- (void)setAnimationDelay:(NSTimeInterval)value;

- (BOOL)isDisplayedWhenStopped;
- (void)setDisplayedWhenStopped:(BOOL)value;

- (BOOL)isSpinning;
- (void)setSpinning:(BOOL)value;


@end
