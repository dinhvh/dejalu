// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <MailCore/MailCore.h>

#import "DJLLogUtils.h"
#include "DJLLog.h"
#import "DJLPathManager.h"

int main(int argc, const char * argv[])
{
    NSDictionary * defaultSettings = @{@"DJLMainWindowHasConversationView": @YES,
                                       @"DJLFolderWidth": @150,
                                       @"DJLConversationListWidth": @250,
                                       @"DJLConversationViewWidth": @600,
                                       @"DJLMainWindowHasFolderView": @NO,
                                       @"DJLMainWindowHasConversationView": @YES,
                                       @"SoundEnabled": @YES,
                                       @"DJLEnableVibrancy": @YES};
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultSettings];

    DJLLogInit();
    DJLLogEnabled = 1;
    MCLogEnabled = 0;

    DJLLogEnable("main");
    DJLLogEnable("error");
    DJLLogEnable("cleanup");
    return NSApplicationMain(argc, argv);
}
