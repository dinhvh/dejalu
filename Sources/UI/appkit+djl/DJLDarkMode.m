//
//  DJLDarkMode.m
//  DejaLu
//
//  Created by Hoa Dinh on 12/4/18.
//  Copyright © 2018 Hoa V. DINH. All rights reserved.
//

#import "DJLDarkMode.h"

@implementation DJLDarkMode

+ (BOOL) isDarkModeSupported
{
    NSOperatingSystemVersion version = {10, 14, 0};
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
}

+ (BOOL) isDarkModeForView:(NSView *)view
{
    if (@available(macOS 10.14, *)) {
        NSAppearanceName bestMatch = [[view effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        return [bestMatch isEqualToString:NSAppearanceNameDarkAqua];
    } else {
        return NO;
    }
}

@end

