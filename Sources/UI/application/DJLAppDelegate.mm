// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAppDelegate.h"

#import "DJLMainWindowController.h"
#import "DJLAddressBookManager.h"
#import "DJLConversationStatusView.h"
#import "DJLPreferencesWindowController.h"
#import "DJLAddAccountWindowController.h"
#import "DJLAppBadgeManager.h"
#import "DJLPathManager.h"
#import "DJLAvatarManager.h"
#include "Hermes.h"
#include "DJLLog.h"
#include "DJLLogUtils.h"
#include "FBKVOController.h"

#include <MailCore/MailCore.h>
#import <Sparkle/Sparkle.h>
#import <HockeySDK/HockeySDK.h>
#import <GoogleAnalyticsTracker/GoogleAnalyticsTracker.h>
#import "PFMoveApplication.h"
#include "DJLKeys.h"

using namespace mailcore;
using namespace hermes;

@interface DJLAppDelegate () <DJLMainWindowControllerDelegate, DJLAddAccountWindowControllerDelegate, BITHockeyManagerDelegate>

- (void) _accountClosed;

@end

class DJLAppDelegateCallback : public Object, public AccountObserver {
public:
    DJLAppDelegateCallback(DJLAppDelegate * appDelegate)
    {
        mAppDelegate = appDelegate;
    }

    virtual void accountClosed(Account * account) {
        [mAppDelegate _accountClosed];
    }

private:
    __weak DJLAppDelegate * mAppDelegate;
};

@implementation DJLAppDelegate {
    DJLMainWindowController * _mainWindowController;
    DJLPreferencesWindowController * _prefsWindowController;
    NSMutableArray * _retainWindow;
    NSMutableArray * _updatingAccountControllers;
    DJLAddAccountWindowController * _mainAddAccountController;
    int _closePendingCount;
    DJLAppDelegateCallback * _callback;
    FBKVOController * _kvoController;
}

- (id) init
{
    self = [super init];
    [self _applyLogEnabled];
    [self _setupAutoUpdate];
    AccountManager::sharedManager();
    _updatingAccountControllers = [[NSMutableArray alloc] init];
    _callback = new DJLAppDelegateCallback(self);
    _kvoController = [FBKVOController controllerWithObserver:self];
    [_kvoController observe:[NSUserDefaults standardUserDefaults] keyPath:@"DJLLogEnabled" options:0 block:^(id observer, id object, NSDictionary *change) {
        [self _applyLogEnabled];
    }];
    [self _applyQuickSyncEnabled];
    [_kvoController observe:[NSUserDefaults standardUserDefaults] keyPath:@"DJLLQuickSync" options:0 block:^(id observer, id object, NSDictionary *change) {
        [self _applyQuickSyncEnabled];
    }];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(_receiveWakeNote)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object: nil];

    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_callback);
}

- (void) _receiveWakeNote
{
    [[SUUpdater sharedUpdater] checkForUpdatesInBackground];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
#if !DEBUG
    PFMoveToApplicationsFolderIfNecessary();
#endif
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Hockeyapp
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:BITHOCKEYMANAGER_APP_ID delegate:self];
    [[BITHockeyManager sharedHockeyManager] setDelegate:self];
    [[[BITHockeyManager sharedHockeyManager] crashManager] setAutoSubmitCrashReport:YES];
    [[BITHockeyManager sharedHockeyManager] startManager];

    // Google Analytics
    MPAnalyticsConfiguration *configuration = [[MPAnalyticsConfiguration alloc] initWithAnalyticsIdentifier:DJL_GOOGLE_ANALYTICS_ID];
    [MPGoogleAnalyticsTracker activateConfiguration:configuration];

    [self _setupDebugMenu];

    _retainWindow = [[NSMutableArray alloc] init];
    
    NSArray * apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    if ([apps count] >= 2) {
        [self _showAlertAlreadyRunning];
        return;
    }

    //MCLogEnabled = true;

    NSInteger cleanLaunchCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"DJLCleanLaunch"];
    NSTimeInterval cleanLaunchDate = [[NSUserDefaults standardUserDefaults] doubleForKey:@"DJLCleanLaunchDate"];
    // within the same 2 minute.
    if ([NSDate timeIntervalSinceReferenceDate] - cleanLaunchDate < 2 * 60.0) {
        cleanLaunchCount ++;
    }
    else {
        cleanLaunchCount = 1;
    }

    BOOL cleanDB = NO;
    if (cleanLaunchCount >= 3) {
        cleanLaunchCount = 1;
        cleanDB = YES;
    }

    [[NSUserDefaults standardUserDefaults] setInteger:cleanLaunchCount forKey:@"DJLCleanLaunch"];
    [[NSUserDefaults standardUserDefaults] setDouble:[NSDate timeIntervalSinceReferenceDate] forKey:@"DJLCleanLaunchDate"];

    if (([NSEvent modifierFlags] & (NSShiftKeyMask | NSAlternateKeyMask)) != 0) {
        cleanDB = YES;
    }
    if (cleanDB) {
        NSLog(@"The application crashed too often. Resetting email database.");
        AccountManager::sharedManager()->setResetDB();
    }

    [self performSelector:@selector(_markLaunchAsClean) withObject:nil afterDelay:5];

    [DJLAppBadgeManager sharedManager];
    [MCOMailProvidersManager sharedManager];
    [DJLAddressBookManager sharedManager];

    _mainWindowController = [[DJLMainWindowController alloc] init];
    [_mainWindowController setDelegate:self];

    [self _open];
}

- (void) _markLaunchAsClean
{
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"DJLCleanLaunch"];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"DJLCleanLaunch"];

    if (_closePendingCount > 0) {
        return NSTerminateLater;
    }

    _closePendingCount += AccountManager::sharedManager()->accounts()->count();
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        account->addObserver(_callback);
        account->close();
    }
    if (_closePendingCount == 0) {
        return NSTerminateNow;
    }
    else {
        return NSTerminateLater;
    }
}

- (void) _accountClosed
{
    _closePendingCount --;
    if (_closePendingCount == 0) {
        [NSApp replyToApplicationShouldTerminate:YES];
    }
}

- (void) _open
{
    if (AccountManager::sharedManager()->accounts()->count() == 0) {
        [self addAccount];
    }
    else {
        [_mainWindowController showWindow:nil];
    }
}

- (void) _showAlertAlreadyRunning
{
    NSAlert * alert = [[NSAlert alloc] init];
    NSString * messageText = [NSString stringWithFormat:@"%@ is already running", [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *) kCFBundleNameKey]];
    NSString * informativeText = @"An other instance of the application is already running. Please close the other instance of the application.";
    [alert setMessageText:messageText];
    [alert setInformativeText:informativeText];
    [alert runModal];
    [NSApp terminate:nil];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [[_mainWindowController window] setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [self _open];
    return YES;
}

- (void)applicationWillResignActive:(NSNotification *)aNotification
{
    [DJLConversationStatusView setInteractionEnabled:NO];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    [self performSelector:@selector(_allowStatusClickAfterDelay) withObject:nil afterDelay:0.5];
}

- (void) _allowStatusClickAfterDelay
{
    [DJLConversationStatusView setInteractionEnabled:YES];
}

- (IBAction) openPreferences:(id)sender
{
    if (_prefsWindowController == nil) {
        _prefsWindowController = [[DJLPreferencesWindowController alloc] init];
    }
    [_prefsWindowController showWindow:nil];
}

- (void) DJLMainWindowController:(DJLMainWindowController *)controller openLabelsPrefsForAccount:(hermes::Account *)account
{
    [self openPreferences:nil];
    [_prefsWindowController showLabelsForAccount:account];
}

- (void) DJLMainWindowController:(DJLMainWindowController *)controller openAccountPrefs:(hermes::Account *)account
{
    DJLAddAccountWindowController * accountController = [[DJLAddAccountWindowController alloc] init];
    if (account->accountInfo()->providerIdentifier() != NULL) {
        if (account->accountInfo()->providerIdentifier()->isEqual(MCSTR("gmail")) || account->accountInfo()->providerIdentifier()->isEqual(MCSTR("outlook"))) {
            [accountController setHintProviderIdentifier:MCO_TO_OBJC(account->accountInfo()->providerIdentifier())];
            [accountController setHintEmail:MCO_TO_OBJC(account->accountInfo()->email())];
        }
        else {
            [accountController setHintProviderIdentifier:MCO_TO_OBJC(account->accountInfo()->providerIdentifier())];
            [accountController setHintEmail:MCO_TO_OBJC(account->accountInfo()->email())];
        }
    }
    else {
        [accountController setHintEmail:MCO_TO_OBJC(account->accountInfo()->email())];
        NSMutableDictionary * properties = [[NSMutableDictionary alloc] init];

        NSString * imapHostname = MCO_TO_OBJC(account->accountInfo()->imapInfo()->hostname());
        if ((account->accountInfo()->imapInfo()->port() != 993) &&
            (account->accountInfo()->imapInfo()->port() != 143)) {
            imapHostname = [imapHostname stringByAppendingFormat:@":%i", account->accountInfo()->imapInfo()->port()];
        }
        properties[@"imap-hostname"] = imapHostname;
        properties[@"imap-login"] = MCO_TO_OBJC(account->accountInfo()->imapInfo()->username());
        properties[@"imap-password"] = MCO_TO_OBJC(account->accountInfo()->imapInfo()->password());

        NSString * smtpHostname = MCO_TO_OBJC(account->accountInfo()->smtpInfo()->hostname());
        if ((account->accountInfo()->smtpInfo()->port() != 465) &&
            (account->accountInfo()->smtpInfo()->port() != 25) &&
            (account->accountInfo()->smtpInfo()->port() != 587)) {
            smtpHostname = [smtpHostname stringByAppendingFormat:@":%i", account->accountInfo()->smtpInfo()->port()];
        }
        properties[@"smtp-hostname"] = smtpHostname;
        properties[@"smtp-login"] = MCO_TO_OBJC(account->accountInfo()->smtpInfo()->username());
        properties[@"smtp-password"] = MCO_TO_OBJC(account->accountInfo()->smtpInfo()->password());

        [accountController setAccountProperties:properties];
    }
    [accountController setDelegate:self];
    [accountController showWindow:nil];
    [_updatingAccountControllers addObject:accountController];
}

- (void) DJLAddAccountWindowControllerClosed:(DJLAddAccountWindowController *)controller
{
    if (controller == _mainAddAccountController) {
        if (AccountManager::sharedManager()->accounts()->count() > 0) {
            [_mainWindowController showWindow:nil];
        }
        _mainAddAccountController = nil;
    }
    else {
        [_updatingAccountControllers removeObject:controller];
    }
}

- (void) composeMessage:(id)sender
{
    [_mainWindowController composeMessage];
}

- (IBAction) debugOpenAccountFolder:(id)sender
{
    [_mainWindowController debugOpenAccountFolder];
}

- (IBAction) debugActivity:(id)sender
{
    [_mainWindowController debugActivity];
}

- (void) refresh:(id)sender
{
    [_mainWindowController refresh];
}

- (void) _setupAutoUpdate
{
#if DJL_PRODUCTION
    [SUUpdater sharedUpdater];
    [[SUUpdater sharedUpdater] setAutomaticallyDownloadsUpdates:YES];
    [[SUUpdater sharedUpdater] checkForUpdatesInBackground];
#endif
}

- (IBAction) checkForUpdates:(id)sender
{
    [[SUUpdater sharedUpdater] checkForUpdates:nil];
}

- (IBAction) debugCrash:(id)sender
{
    abort();
}

- (IBAction) debugCell:(id)sender
{
}

- (IBAction) debugEnableWellKnownIMAP:(id)sender
{
}

- (IBAction) debugEnableCustomIMAP:(id)sender
{
}

- (IBAction) showHelp:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://dejalu.me/help"]];
}

- (IBAction) debugNextAvatarIcon:(id)sender
{
    [[DJLAvatarManager sharedManager] debugNextServiceAvatar];
}

- (void) _applyLogEnabled
{
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLLogEnabled"];
    if (enabled) {
        NSString * folder = [[DJLPathManager sharedManager] logsFolder];
        FILE * f = fopen([NextAvailableLogFilePath(folder) fileSystemRepresentation], "wb");
        DJLLogSetFile(f);

        NSString * shortVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
        NSString * name = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
        NSString * build = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleVersionKey];
        NSString * logString = [NSString stringWithFormat:@"%@ %@ (build %@)", name, shortVersion, build];
        DJLLogWithID("main", "%s", [logString UTF8String]);
    }
    else {
        DJLLogFileClose();
    }

    AccountManager::sharedManager()->setLogEnabled(enabled);
}

- (void) _applyQuickSyncEnabled
{
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLQuickSync"];
    AccountManager::sharedManager()->setQuickSyncEnabled(enabled);
}

- (void) _setupDebugMenu
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
        return;
    }

    for(NSMenuItem * item in [_helpMenu itemArray]) {
        if ([NSStringFromSelector([item action]) hasPrefix:@"debug"]) {
            [item setHidden:YES];
        }
    }
}

#pragma mark -
#pragma mark menu validation

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    SEL aSelector = [item action];
    if (aSelector == @selector(composeMessage:)) {
        return AccountManager::sharedManager()->accounts()->count() > 0;
    }
    else if (aSelector == @selector(refresh:)) {
        return AccountManager::sharedManager()->accounts()->count() > 0;
    }
    else {
        return YES;
    }
}

- (void) addAccount
{
    if (_mainAddAccountController == nil) {
        _mainAddAccountController = [[DJLAddAccountWindowController alloc] init];
        [_mainAddAccountController setDelegate:self];
    }
    [_mainAddAccountController showWindow:nil];
}

+ (void) addAccount
{
    [(DJLAppDelegate *) [NSApp delegate] addAccount];
}

#pragma hockeyapp delegate

- (void)crashManagerWillSendCrashReport:(BITCrashManager *)crashManager
{
    [MPGoogleAnalyticsTracker trackEventOfCategory:@"App" action:@"Crash" label:@"The app crashed. A report is being sent" value:@(0)];
}

- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager
{
    if (AccountManager::sharedManager()->accounts()->count() > 0) {
        Account * account = (Account *) AccountManager::sharedManager()->accounts()->objectAtIndex(0);
        return MCO_TO_OBJC(account->accountInfo()->email());
    }
    else {
        return nil;
    }
}

@end
