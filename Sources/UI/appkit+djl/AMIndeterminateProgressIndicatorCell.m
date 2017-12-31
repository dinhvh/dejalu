//
//  AMIndeterminateProgressIndicatorCell.m
//  IPICellTest
//
//  Created by Andreas on 23.01.07.
//  Copyright 2007 Andreas Mayer. All rights reserved.
//

//	2007-03-10	Andreas Mayer
//	- removed -keyEquivalent and -keyEquivalentModifierMask methods
//		(I thought those were required by NSTableView/Column. They are not.
//		Instead I was using NSButtons as a container for the cells in the demo project.
//		Replacing those with plain NSControls did fix the problem.)
//	2007-03-24	Andreas Mayer
//	- will now spin in the same direction in flipped and not flipped views
//	2008-09-03	Andreas Mayer
//	- restore default settings for NSBezierPath after drawing
//	- instead of the saturation, we now modify the lines' opacity; does look better on colored
//		backgrounds

// modified for DejaLu

#import "AMIndeterminateProgressIndicatorCell.h"

#define ConvertAngle(a) (fmod((90.0-(a)), 360.0))

#define DEG2RAD  0.017453292519943295

@implementation AMIndeterminateProgressIndicatorCell

- (id)init
{
	if (self = [super initImageCell:nil]) {
		[self setAnimationDelay:5.0/60.0];
		[self setDisplayedWhenStopped:YES];
		[self setDoubleValue:0.0];
		[self setColor:[NSColor blackColor]];
	}
	return self;
}

- (NSColor *)color
{
	return _color;
}

- (void)setColor:(NSColor *)value
{
	float alphaComponent;
	if (_color != value) {
        _color = value;
        
        NSColor * color;
        color = [_color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        
        CGFloat components[4];
        
        [color getComponents:components];
        _redComponent = components[0];
        _greenComponent = components[1];
        _blueComponent = components[2];
        alphaComponent = components[3];
        
		NSAssert((alphaComponent > 0.999), @"color must be opaque");
	}
}

- (double)doubleValue
{
	return _doubleValue;
}

- (void)setDoubleValue:(double)value
{
	if (_doubleValue != value) {
		_doubleValue = value;
		if (_doubleValue > 1.0) {
			_doubleValue = 1.0;
		} else if (_doubleValue < 0.0) {
			_doubleValue = 0.0;
		}
	}
}

- (NSTimeInterval)animationDelay
{
	return _animationDelay;
}

- (void)setAnimationDelay:(NSTimeInterval)value
{
    _animationDelay = value;
}

- (BOOL)isDisplayedWhenStopped
{
	return _displayedWhenStopped;
}

- (void)setDisplayedWhenStopped:(BOOL)value
{
	if (_displayedWhenStopped != value) {
		_displayedWhenStopped = value;
	}
}

- (BOOL)isSpinning
{
	return _spinning;
}

- (void)setSpinning:(BOOL)value
{
    _spinning = value;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// cell has no border
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if ([self isSpinning] || [self isDisplayedWhenStopped]) {
		float flipFactor = ([controlView isFlipped] ? 1.0 : -1.0);
		int step = round([self doubleValue]/(5.0/60.0));
		float cellSize = MIN(cellFrame.size.width, cellFrame.size.height);
		NSPoint center = cellFrame.origin;
		center.x += cellSize/2.0;
		center.y += cellFrame.size.height/2.0;
		float outerRadius;
		float innerRadius;
		float strokeWidth = cellSize*0.08;
		if (cellSize >= 32.0) {
			outerRadius = cellSize*0.38;
			innerRadius = cellSize*0.23;
		} else {
			outerRadius = cellSize*0.48;
			innerRadius = cellSize*0.27;
		}
		float a; // angle
		NSPoint inner;
		NSPoint outer;
		// remember defaults
		NSLineCapStyle previousLineCapStyle = [NSBezierPath defaultLineCapStyle];
		float previousLineWidth = [NSBezierPath defaultLineWidth]; 
		// new defaults for our loop
		[NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
		[NSBezierPath setDefaultLineWidth:strokeWidth];
		if ([self isSpinning]) {
			a = (270+(step* 30))*DEG2RAD;
		} else {
			a = 270*DEG2RAD;
		}
		a = flipFactor*a;
		int i;
		for (i = 0; i < 12; i++) {
			[[NSColor colorWithCalibratedRed:_redComponent green:_greenComponent blue:_blueComponent alpha:1.0-sqrt(i)*0.25] set];
			outer = NSMakePoint(center.x+cos(a)*outerRadius, center.y+sin(a)*outerRadius);
			inner = NSMakePoint(center.x+cos(a)*innerRadius, center.y+sin(a)*innerRadius);
			[NSBezierPath strokeLineFromPoint:inner toPoint:outer];
			a -= flipFactor*30*DEG2RAD;
		}
		// restore previous defaults
		[NSBezierPath setDefaultLineCapStyle:previousLineCapStyle];
		[NSBezierPath setDefaultLineWidth:previousLineWidth];
	}
}

- (void)setObjectValue:(id)value
{
	if ([value respondsToSelector:@selector(boolValue)]) {
		[self setSpinning:[value boolValue]];
	} else {
		[self setSpinning:NO];
	}
}


@end
