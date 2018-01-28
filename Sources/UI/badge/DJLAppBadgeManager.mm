// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLAppBadgeManager.h"

#import <Cocoa/Cocoa.h>

#include "Hermes.h"

#import "FBKVOController.h"
#import "DJLURLHandler.h"

using namespace mailcore;
using namespace hermes;

@interface DJLAppBadgeManager () <NSSoundDelegate, NSUserNotificationCenterDelegate>

- (void) _accountUnseenChanged;
- (void) _accountNotifyUnreadEmail;
- (void) _accountsChanged;
- (void) _countChanged;
- (void) _notifyMessages:(NSArray *)messages storageView:(MailStorageView *)storageView;
- (void) _operationFinished:(Operation *)op;

@end

class DJLAppBadgeManagerCallback : public mailcore::Object, public AccountManagerObserver,
public MailStorageViewObserver, public AccountObserver, public OperationCallback {

public:
    DJLAppBadgeManagerCallback(DJLAppBadgeManager * manager)
    {
        mManager = manager;
    }

    virtual ~DJLAppBadgeManagerCallback()
    {
    }

    virtual void accountManagerAccountUnseenChanged(AccountManager * manager)
    {
        [mManager _accountUnseenChanged];
    }

    virtual void accountManagerNotifyUnreadEmail(AccountManager * manager, Account * account)
    {
        [mManager _accountNotifyUnreadEmail];
    }

    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mManager _accountsChanged];
    }

    virtual void mailStorageFoldersCountsChanged(MailStorageView * view, mailcore::Array * foldersIDs)
    {
        [mManager _countChanged];
    }

    virtual void mailStorageNotifyMessages(MailStorageView * view, mailcore::Array * notifiedMessages)
    {
        [mManager _notifyMessages:MCO_TO_OBJC(notifiedMessages) storageView:view];
    }

    virtual void accountGotFolders(Account * account)
    {
        [mManager _countChanged];
    }

    virtual void operationFinished(Operation * op)
    {
        [mManager _operationFinished:op];
    }

private:
    __weak DJLAppBadgeManager * mManager;
    
};

@implementation DJLAppBadgeManager {
    DJLAppBadgeManagerCallback * _callback;
    Array * _registeredViews;
    Array * _registeredAccounts;
    FBKVOController * _kvoController;
    BOOL _accountNotifyUnreadEmailScheduled;
    NSMutableDictionary * _messagesToNotify;
    Array * _pendingOps;
    int _pendingOpsCount;
    NSUserNotificationCenter * _userNotificationCenter;
    Account * _account;
    BOOL _pendingNotify;
    NSTimeInterval _lastSoundDate;
    NSStatusItem * _statusItem;
}

#import "DJLSingleton.h"

+ (DJLAppBadgeManager *) sharedManager
{
    DJLSINGLETON(DJLAppBadgeManager);
}

- (id) init
{
    self = [super init];

    _callback = new DJLAppBadgeManagerCallback(self);
    AccountManager::sharedManager()->addObserver(_callback);
    _registeredViews = new Array();
    _registeredAccounts = new Array();
    _messagesToNotify = [[NSMutableDictionary alloc] init];
    _pendingOps = new Array();
    _account = NULL;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DJLShowStatusItem"]) {
        [self _createStatusItem];
    }

    [self _updateBadge];

    _kvoController = [FBKVOController controllerWithObserver:self];
    __weak typeof(self) weakSelf = self;
    [_kvoController observe:[NSUserDefaults standardUserDefaults] keyPath:@"ZenNotifications" options:0 block:^(id observer, id object, NSDictionary * change) {
        [weakSelf _updateBadge];
    }];
    [_kvoController observe:[NSUserDefaults standardUserDefaults] keyPath:@"DJLShowStatusItem" options:0 block:^(id observer, id object, NSDictionary * change) {
        [weakSelf _toggleStatusItem];
    }];

    _userNotificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
    [_userNotificationCenter setDelegate:self];

    return self;
}

- (void) dealloc
{
    MC_SAFE_RELEASE(_account);
    MC_SAFE_RELEASE(_pendingOps);
    MC_SAFE_RELEASE(_registeredAccounts);
    MC_SAFE_RELEASE(_registeredViews);
    AccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (void) _createStatusItem
{
    if (_statusItem) {
        return;
    }
    NSImage * icon = [NSImage imageNamed:@"statusitem"];
    [icon setTemplate:YES];
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.target = self;
    _statusItem.button.action = @selector(_statusItemClicked:);
    _statusItem.highlightMode = NO;
    _statusItem.button.imagePosition = NSImageOnly;
    _statusItem.button.image = icon;
    _statusItem.autosaveName = @"DJLStatusItem";
}

- (void) _destroyStatusItem
{
    if (!_statusItem) {
        return;
    }
    [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
    _statusItem = nil;
}

- (void) _toggleStatusItem
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DJLShowStatusItem"]) {
        [self _createStatusItem];
        [self _updateBadge];
    }
    else {
        [self _destroyStatusItem];
    }
}

- (void) _statusItemClicked:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp arrangeInFront:self];
    for (NSWindow * window in NSApp.orderedWindows) {
        if ([window.identifier isEqualToString:@"DejaLu Main Window"]) {
            [window makeKeyAndOrderFront:self];
            break;
        }
    }
}

- (void) _accountUnseenChanged
{
    [self _updateBadge];
}

- (void) _accountNotifyUnreadEmail
{
#if 0
    if (_accountNotifyUnreadEmailScheduled) {
        return;
    }
    _accountNotifyUnreadEmailScheduled = YES;
    [self performSelector:@selector(_accountNotifyUnreadEmailAfterDelay) withObject:0 afterDelay:0.5];
#endif
}

#if 0
- (void) _accountNotifyUnreadEmailAfterDelay
{
    [self _playSound];
}
#endif

- (void) _playSound
{
    if ([NSDate timeIntervalSinceReferenceDate] - _lastSoundDate < 0.5) {
        NSLog(@"sound played recently");
        return;
    }
    _lastSoundDate = [NSDate timeIntervalSinceReferenceDate];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SoundEnabled"]) {
        NSSound * sound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"newmail" ofType:@"m4a"] byReference:YES];
        [sound setDelegate:self];
        [sound play];
    }
}

- (void) sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying
{
    _accountNotifyUnreadEmailScheduled = NO;
}

- (void) _accountsChanged
{
    {
        for(unsigned int i = 0 ; i  < _registeredAccounts->count() ; i ++) {
            MailStorageView * view = (MailStorageView *) _registeredViews->objectAtIndex(i);
            Account * account = (Account *) _registeredAccounts->objectAtIndex(i);
            account->removeObserver(_callback);
            view->removeObserver(_callback);
            account->closeViewForCounters(view);
        }
    }
    _registeredViews->removeAllObjects();
    _registeredAccounts->removeAllObjects();
    {
        mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
            MailStorageView * view = account->viewForCounters();
            view->addObserver(_callback);
            account->addObserver(_callback);
            _registeredViews->addObject(view);
            _registeredAccounts->addObject(account);
        }
    }
    [self _countChanged];
}

- (void) _countChanged
{
    [self _updateBadge];
}

- (void) _updateBadge
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ZenNotifications"]) {
        [self _updateNewEmailsBadge];
    }
    else {
        [self _updateUnreadEmailsBadge];
    }
}

- (void) _updateNewEmailsBadge
{
    BOOL showStatusItem = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLShowStatusItem"];
    BOOL hasUnseen = NO;
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        if (account->isFolderUnseen(account->folderIDForPath(account->inboxFolderPath()))) {
            hasUnseen = YES;
        }
    }
    if (hasUnseen) {
        [[NSApp dockTile] setBadgeLabel:@" "];
        if (showStatusItem) {
            _statusItem.button.imagePosition = NSImageLeft;
            _statusItem.button.title = @"!";
        }
    }
    else {
        [[NSApp dockTile] setBadgeLabel:nil];
        if (showStatusItem) {
            _statusItem.button.imagePosition = NSImageOnly;
            _statusItem.button.title = @"";
        }
    }
}

- (void) _updateUnreadEmailsBadge
{
    BOOL showStatusItem = [[NSUserDefaults standardUserDefaults] boolForKey:@"DJLShowStatusItem"];
    int total = 0;
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {
        if (account->inboxFolderPath() != NULL) {
            total += account->unreadCountForFolderID(account->folderIDForPath(account->inboxFolderPath()));
        }
    }
    if (total < 0) {
        total = 0;
    }
    if (total == 0) {
        [[NSApp dockTile] setBadgeLabel:nil];
        if (showStatusItem) {
            _statusItem.button.imagePosition = NSImageOnly;
            _statusItem.button.title = @"";
        }
    }
    else {
        NSString * label = [NSString stringWithFormat:@"%u", total];
        [[NSApp dockTile] setBadgeLabel:label];
        if (showStatusItem) {
            _statusItem.button.imagePosition = NSImageLeft;
            _statusItem.button.title = label;
        }
    }
}

- (void) _notifyMessages:(NSArray *)messages storageView:(MailStorageView *)storageView
{
    int idx = -1;
    for(unsigned int i = 0 ; i < _registeredViews->count() ; i ++) {
        if (_registeredViews->objectAtIndex(i) == storageView) {
            idx = i;
        }
    }
    MCAssert(idx != -1);

    //NSLog(@"notify %@", messages);
    MCOIndexSet * messagesToNotify = [MCOIndexSet indexSet];
    Account * account = (Account *) _registeredAccounts->objectAtIndex(idx);
    int64_t inboxFolderID = account->folderIDForPath(account->inboxFolderPath());
    for(NSDictionary * msgInfo in messages) {
        NSNumber * nbFolderID = msgInfo[@"folderid"];
        if ([nbFolderID longLongValue] == inboxFolderID) {
            int64_t rowID = [(NSNumber *) msgInfo[@"rowid"] longLongValue];
            account->fetchMessageSummary(inboxFolderID, rowID, false);
            [messagesToNotify addIndex:rowID];
        }
    }

    if ([messagesToNotify count] == 0) {
        return;
    }

    NSString * email = MCO_TO_OBJC(account->accountInfo()->email());
    MCOIndexSet * allMessagesToNotify = _messagesToNotify[email];
    if (allMessagesToNotify == nil) {
        allMessagesToNotify = [[MCOIndexSet alloc] init];
        _messagesToNotify[email] = allMessagesToNotify;
    }
    [allMessagesToNotify addIndexSet:messagesToNotify];
    //NSLog(@"notify %@", _messagesToNotify);

    [self _tryNotifyAfterDelay];
}

- (void) _tryNotifyAfterDelay
{
    if (_pendingOpsCount > 0) {
        return;
    }

    if (_pendingNotify) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_notifyAfterDelay) object:nil];
    }
    _pendingNotify = YES;
    [self performSelector:@selector(_notifyAfterDelay) withObject:nil afterDelay:2.0];
}

- (void) _notifyAfterDelay
{
    _pendingNotify = NO;
    //NSLog(@"notify after delay %@", _messagesToNotify);
    Array * accounts = AccountManager::sharedManager()->accounts();
    for(unsigned int i = 0 ; i < accounts->count() ; i ++) {
        Account * account = (Account *) accounts->objectAtIndex(i);
        if (account == NULL) {
            continue;
        }
        NSString * email = MCO_TO_OBJC(account->accountInfo()->email());
        MCOIndexSet * allMessagesToNotify = _messagesToNotify[email];
        if ([allMessagesToNotify count] == 0) {
            [_messagesToNotify removeObjectForKey:email];
            continue;
        }
        MC_SAFE_REPLACE_RETAIN(Account, _account, account);

        if ([allMessagesToNotify count] >= 4) {
            [self _showMultipleMessagesNotification:[allMessagesToNotify count]];
        }
        else {
            _pendingOpsCount += [allMessagesToNotify count];
            [allMessagesToNotify enumerateIndexes:^(uint64_t idx) {
                MailDBMessageInfoOperation * op = account->messageInfoOperation(idx);
                _pendingOps->addObject(op);
                op->setCallback(_callback);
                op->start();
            }];
        }
        [_messagesToNotify removeObjectForKey:email];
        break;
    }
}

- (void) _operationFinished:(Operation *)op
{
    _pendingOpsCount --;
    if (_pendingOpsCount == 0) {
        [self _allFetched];
        _pendingOps->removeAllObjects();
    }

}

- (void) _allFetched
{
    [self _playSound];
    mc_foreacharray(MailDBMessageInfoOperation, op, _pendingOps) {
        NSDictionary * info = MCO_TO_OBJC(op->messageInfo());
        NSString * sender = info[@"sender"];
        NSString * subject = info[@"subject"];
        NSString * content = info[@"content"];
        content = [content mco_flattenHTMLAndShowBlockquote:NO showLink:NO];
        //NSLog(@"notify %@", info);
        NSUserNotification * notification = [[NSUserNotification alloc] init];
        [notification setTitle:sender];
        if ([subject length] != 0) {
            [notification setSubtitle:subject];
        }
        if ([content length] != 0) {
            [notification setInformativeText:content];
        }
        NSDictionary * msgDict = info[@"msg"];
        NSDictionary * headerDict = msgDict[@"header"];
        NSString * messageID = headerDict[@"messageID"];
        NSDictionary * userInfo = nil;
        if (messageID != nil) {
            userInfo = @{@"messageID": messageID, @"email": MCO_TO_OBJC(_account->accountInfo()->email())};
        }
        [notification setUserInfo:userInfo];
        [_userNotificationCenter deliverNotification:notification];
    }
    MC_SAFE_RELEASE(_account);
    [self _tryNotifyAfterDelay];
}

- (void) _showMultipleMessagesNotification:(int)count
{
    [self _playSound];
    NSString * email = MCO_TO_OBJC(_account->accountInfo()->email());
    NSUserNotification * notification = [[NSUserNotification alloc] init];
    [notification setTitle:@"New Messages Received"];
    [notification setInformativeText:[NSString stringWithFormat:@"%@ | %u messages", email, count]];
    [_userNotificationCenter deliverNotification:notification];
    MC_SAFE_RELEASE(_account);
    [self _tryNotifyAfterDelay];
}

#pragma mark user notification center delegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    NSString * messageID = [notification userInfo][@"messageID"];
    if (messageID != nil) {
        NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"message:%@", messageID]];
        [[DJLURLHandler sharedManager] openURL:url];
    }
}

@end
