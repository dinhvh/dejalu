// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLPrefsSignatureViewController.h"

#import <WebKit/WebKit.h>

#import "DJLColoredView.h"
#import "DJLCreateLinkWindowController.h"
#import "NSString+DJL.h"
#import "NSData+DJL.h"
#import "DJLComposerWebView.h"
#import "DJLPathManager.h"
#import "WebResource+DJL.h"

using namespace mailcore;
using namespace hermes;

@interface DJLPrefsSignatureViewController () <NSTextViewDelegate, WebEditingDelegate,
WebFrameLoadDelegate, DJLCreateLinkWindowControllerDelegate, WebPolicyDelegate, WebUIDelegate>

- (void) _updateAccounts;

@end

class DJLPrefsSignatureViewControllerCallback : public mailcore::Object, public AccountObserver, public AccountManagerObserver {
public:
    DJLPrefsSignatureViewControllerCallback(DJLPrefsSignatureViewController * controller)
    {
        mController = controller;
    }

    virtual void accountManagerChanged(AccountManager * manager)
    {
        [mController _updateAccounts];
    }

private:
    __weak DJLPrefsSignatureViewController * mController;
};

@implementation DJLPrefsSignatureViewController {
    DJLPrefsSignatureViewControllerCallback * _callback;
    NSPopUpButton * _popupButton;
    DJLColoredView * _borderView;
    DJLComposerWebView * _webView;
    Array * _accounts;
    NSMutableArray * _emails;
    Account * _account;
    NSString * _email;
    BOOL _scheduledSave;
    NSButton * _checkBox;
    DJLColoredView * _overlay;
    DJLCreateLinkWindowController * _createLinkController;
    NSString * _temporaryFolder;
    BOOL _webViewReady;
    BOOL _hasChanges;
    NSTextField * _placeholder;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _callback = new DJLPrefsSignatureViewControllerCallback(self);
    AccountManager::sharedManager()->addObserver(_callback);
    _accounts = new Array();
    _emails = [[NSMutableArray alloc] init];
    return self;
}

- (void) dealloc
{
    [self _unsetup];
    MC_SAFE_RELEASE(_accounts);
    MC_SAFE_RELEASE(_account);
    AccountManager::sharedManager()->removeObserver(_callback);
    MC_SAFE_RELEASE(_callback);
}

- (NSImage *) icon
{
    return [NSImage imageNamed:@"DejaLu_Signature_Light_32"];
}

- (NSString *) title
{
    return @"Signature";
}

- (CGFloat) height
{
    return 300;
}

- (void) loadView
{
    NSView * view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
    [self setView:view];

    NSView * contentView = [self view];

    NSRect frame = [contentView bounds];

    _popupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, frame.size.height - 40, 300, 30)];
    [_popupButton setTarget:self];
    [_popupButton setAction:@selector(_accountSelected)];
    [_popupButton setAutoresizingMask:NSViewMinYMargin];
    [contentView addSubview:_popupButton];

    _checkBox = [[NSButton alloc] initWithFrame:NSMakeRect(20, frame.size.height - 70, 300, 30)];
    [_checkBox setButtonType:NSSwitchButton];
    [_checkBox setTitle:@"Use custom alias signature"];
    [_checkBox setAutoresizingMask:NSViewMinYMargin];
    [_checkBox setTarget:self];
    [_checkBox setAction:@selector(_checkboxChanged:)];
    [contentView addSubview:_checkBox];

    frame = [contentView bounds];
    frame = NSInsetRect(frame, 19, 19);
    frame.size.height -= 25 + 30;
    _borderView = [[DJLColoredView alloc] initWithFrame:frame];
    [_borderView setBackgroundColor:[NSColor colorWithWhite:0.95 alpha:1.0]];
    [_borderView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [contentView addSubview:_borderView];

    frame = [contentView bounds];
    frame = NSInsetRect(frame, 20, 20);
    frame.size.height -= 25 + 30;
    _webView = [[DJLComposerWebView alloc] initWithFrame:frame frameName:nil groupName:nil];
    [_webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    //[_webView setEditable:YES];
    [_webView setEditingDelegate:self];
    [_webView setFrameLoadDelegate:self];
    [_webView setPolicyDelegate:self];
    [_webView setUIDelegate:self];
    [[_webView preferences] setStandardFontFamily:@"Helvetica Neue"];
    [[_webView preferences] setDefaultFontSize:16];
    [contentView addSubview:_webView];
    NSString * filename = [[NSBundle mainBundle] pathForResource:@"signature" ofType:@"html"];
    NSString * htmlString = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    [[_webView mainFrame] loadHTMLString:htmlString baseURL:[[NSBundle mainBundle] resourceURL]];

    _overlay = [[DJLColoredView alloc] initWithFrame:frame];
    [_overlay setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.75]];
    [_overlay setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [contentView addSubview:_overlay];

    frame = [contentView bounds];
    frame = NSInsetRect(frame, 20, 20);
    frame.size.height -= 25 + 30;
    _placeholder = [[NSTextField alloc] initWithFrame:frame];
    [_placeholder setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_placeholder setEditable:NO];
    [_placeholder setBezeled:NO];
    [_placeholder setDrawsBackground:NO];
    [_placeholder setTextColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];
    [_placeholder setStringValue:@"You need to add an account before setting the signature on it"];
    [_placeholder setAlignment:NSCenterTextAlignment];
    [_placeholder setFont:[NSFont systemFontOfSize:30]];
    [_placeholder sizeToFit];
    [_placeholder setHidden:YES];
    [contentView addSubview:_placeholder];

    [self _updateView];
}

- (void) _unsetup
{
    [_webView setEditingDelegate:nil];
    [_webView setFrameLoadDelegate:nil];
    [_webView setPolicyDelegate:nil];
    [_webView setUIDelegate:nil];
}

- (BOOL) _isSelectionEmpty
{
    return ([_webView selectedDOMRange] == nil) || [[_webView selectedDOMRange] collapsed];
}

- (void) _updateView
{
    [_popupButton removeAllItems];
    [_emails removeAllObjects];
    _accounts->removeAllObjects();
    mc_foreacharray(Account, account, AccountManager::sharedManager()->accounts()) {

        NSMutableArray * emails = [[NSMutableArray alloc] init];
        [emails addObject:MCO_TO_OBJC(account->accountInfo()->email())];
        mc_foreacharray(Address, address, account->accountInfo()->aliases()) {
            [emails addObject:MCO_TO_OBJC(address->mailbox())];
        }
        [emails sortedArrayUsingSelector:@selector(compare:)];

        for(NSString * email in emails) {
            [_popupButton addItemWithTitle:email];
            [_emails addObject:email];
            _accounts->addObject(account);
        }

    }
    [self _accountSelected];
}

- (void) _accountSelected
{
    [self _save];

    int selectedIndex = (int) [_popupButton indexOfSelectedItem];
    if (selectedIndex >= _accounts->count()) {
        if (_accounts->count() == 0) {
            selectedIndex = -1;
        }
        else {
            selectedIndex = 0;
        }
    }

    if (selectedIndex == -1) {
        NSRect frame = [[self view] bounds];
        frame = NSInsetRect(frame, 19, 19);
        frame.size.height -= 25;
        [_borderView setFrame:frame];

        frame = [[self view] bounds];
        frame = NSInsetRect(frame, 20, 20);
        frame.size.height -= 25;
        [_webView setFrame:frame];

        frame = [_webView frame];
        frame.size.height -= 25;
        [_placeholder setFrame:frame];
        [_placeholder setHidden:NO];

        [self _setEditable:YES];
        [_checkBox setState:NSOffState];
        [_checkBox setEnabled:NO];
        [self _loadSignatureForEmail:nil enabled:NO];
        return;
    }

    [_placeholder setHidden:YES];

    Account * account = (Account *) _accounts->objectAtIndex(selectedIndex);
    MC_SAFE_REPLACE_RETAIN(Account, _account, account);
    _email = _emails[selectedIndex];

    BOOL isAlias = NO;
    if (_account->accountInfo()->email()->isEqual(MCO_FROM_OBJC(String, _email))) {
        NSRect frame = [[self view] bounds];
        frame = NSInsetRect(frame, 19, 19);
        frame.size.height -= 25;
        [_borderView setFrame:frame];

        frame = [[self view] bounds];
        frame = NSInsetRect(frame, 20, 20);
        frame.size.height -= 25;
        [_webView setFrame:frame];
    }
    else {
        NSRect frame = [[self view] bounds];
        frame = NSInsetRect(frame, 19, 19);
        frame.size.height -= 25 + 30;
        [_borderView setFrame:frame];

        frame = [[self view] bounds];
        frame = NSInsetRect(frame, 20, 20);
        frame.size.height -= 25 + 30;
        [_webView setFrame:frame];
        isAlias = YES;
    }

    [_checkBox setEnabled:YES];
    Data * data = (Data *) _account->accountInfo()->signatureForEmail(MCO_FROM_OBJC(String, _email));
    if (!isAlias) {
        [_checkBox setEnabled:NSOffState];
        [self _loadSignatureForEmail:_email enabled:YES];
        [self _setEditable:YES];
    }
    else {
        if (data != NULL) {
            [_checkBox setState:NSOnState];
            [self _loadSignatureForEmail:_email enabled:YES];
            [self _setEditable:YES];
        }
        else {
            [_checkBox setState:NSOffState];
            [self _loadSignatureForEmail:MCO_TO_OBJC(_account->accountInfo()->email()) enabled:NO];
            [self _setEditable:NO];
        }
    }
}

- (void) _setEditable:(BOOL)editable
{
    [_overlay setFrame:[_webView frame]];
    [_overlay setHidden:editable];
}

- (void) _loadSignatureForEmail:(NSString *)email enabled:(BOOL)enabled
{
    if (!_webViewReady) {
        return;
    }

    if (email == nil) {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcClearContent" withArguments:@[]];
        [[_webView windowScriptObject] callWebScriptMethod:@"objcDisable" withArguments:nil];
        return;
    }

    Data * data = (Data *) _account->accountInfo()->signatureForEmail(MCO_FROM_OBJC(String, email));
    WebArchive * archive = nil;
    if (data != NULL) {
        @try {
            archive = [[WebArchive alloc] initWithData:MCO_TO_OBJC(data)];
        }
        @catch (id e) {
            // do nothing
        }
        @finally {
        }
    }
    if (archive == nil) {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcClearContent" withArguments:@[]];
    }
    else {
        for(WebResource * resource in [archive subresources]) {
            [[[_webView mainFrame] dataSource] addSubresource:resource];
        }
        NSString * content = [[archive mainResource] djlString];
        [[_webView windowScriptObject] callWebScriptMethod:@"objcSetContent" withArguments:@[content]];
    }
    if (enabled) {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcFocus" withArguments:nil];
    }
    else {
        [[_webView windowScriptObject] callWebScriptMethod:@"objcDisable" withArguments:nil];
    }
}

- (void) _checkboxChanged:(id)sender
{
    BOOL isAlias = !_account->accountInfo()->email()->isEqual(MCO_FROM_OBJC(String, _email));
    if (isAlias && [_checkBox state] == NSOffState) {
        [self _loadSignatureForEmail:MCO_TO_OBJC(_account->accountInfo()->email()) enabled:NO];
        [self _setEditable:NO];
    }
    else {
        [self _loadSignatureForEmail:MCO_TO_OBJC(_account->accountInfo()->email()) enabled:YES];
        [self _setEditable:YES];
    }
    [self _saveAfterDelay];
}

- (void) _save
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_save) object:nil];
    _scheduledSave = NO;

    if (!_hasChanges) {
        return;
    }

    if (_account == NULL) {
        return;
    }

    BOOL isAlias = !_account->accountInfo()->email()->isEqual(MCO_FROM_OBJC(String, _email));
    if (isAlias && [_checkBox state] == NSOffState) {
        _account->accountInfo()->setEmailSignature(MCO_FROM_OBJC(String, _email), NULL);
    }
    else {
        NSString * jsonContent = [[_webView windowScriptObject] callWebScriptMethod:@"objcContent" withArguments:nil];
        NSDictionary * content = [NSJSONSerialization JSONObjectWithData:[jsonContent dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];

        NSArray * urls = content[@"urls"];
        NSString * html = content[@"html"];

        WebResource * mainResource = [[WebResource alloc] initWithData:[html dataUsingEncoding:NSUTF8StringEncoding]
                                                                   URL:[NSURL fileURLWithPath:@"/"]
                                                              MIMEType:@"text/html"
                                                      textEncodingName:@"utf-8"
                                                             frameName:nil];
        NSMutableArray * resources = [[NSMutableArray alloc] init];
        for(NSString * urlString in urls) {
            WebResource * resource = [[[_webView mainFrame] dataSource] subresourceForURL:[NSURL URLWithString:urlString]];
            [resources addObject:resource];
        }
        WebArchive * archive = [[WebArchive alloc] initWithMainResource:mainResource subresources:resources subframeArchives:nil];

        Data * data = MCO_FROM_OBJC(Data, [archive data]);
        _account->accountInfo()->setEmailSignature(MCO_FROM_OBJC(String, _email), data);
    }
    _account->save();
    _hasChanges = NO;
}

- (void) _saveAfterDelay
{
    _hasChanges = YES;

    if (_scheduledSave) {
        return;
    }

    _scheduledSave = YES;
    [self performSelector:@selector(_save) withObject:nil afterDelay:0.5];
}

- (void) _updateAccounts
{
    [self _updateView];
}

- (NSURL *) _baseURL
{
    return [[NSBundle bundleForClass:[self class]] resourceURL];
}

- (void) viewDidHide
{
    [self _save];
}

#pragma mark Create links

- (IBAction) createLink:(id)sender
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcSelectCurrentLink" withArguments:nil];
    NSString * value = [[_webView windowScriptObject] callWebScriptMethod:@"objcLinkFromSelection" withArguments:nil];
    NSURL * url = [value djlURL];
    _createLinkController = [[DJLCreateLinkWindowController alloc] init];
    [_createLinkController setDelegate:self];
    [_createLinkController beginSheetWithWindow:[[self view] window] url:url];
}

- (void) DJLCreateLinkWindowController:(DJLCreateLinkWindowController *)controller createLink:(NSURL *)url
{
    [[_webView windowScriptObject] callWebScriptMethod:@"objcAddLinkToSelection" withArguments:@[[url absoluteString]]];
    [self webViewDidChange:nil];
    _createLinkController = nil;
}

- (void) DJLCreateLinkWindowControllerCancelled:(DJLCreateLinkWindowController *)controller
{
    _createLinkController = nil;
}


#pragma mark -
#pragma mark WebView delegate

- (void) webViewDidChange:(NSNotification *)notification
{
    [self _saveAfterDelay];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    _webViewReady = YES;
    [self _accountSelected];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
    NSInteger modifierKeys = [[actionInformation objectForKey:WebActionModifierFlagsKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            [listener ignore];
            break;

        case WebNavigationTypeOther:
        default:
            [listener use];
            break;
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)newFrameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    WebNavigationType navType = (WebNavigationType) [(NSNumber *) [actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
    NSInteger modifierKeys = [[actionInformation objectForKey:WebActionModifierFlagsKey] intValue];

    switch(navType) {
        case WebNavigationTypeLinkClicked:
            [listener ignore];
            break;

        case WebNavigationTypeOther:
        default:
            [listener use];
            break;
    }
}

#pragma mark -
#pragma mark drag and drop management for WebView

#warning TODO: factorize code

- (NSBitmapImageRep*) _mmGenerateBitmapRepForImage:(NSImage *)image
{
    CGImageRef cgImage;

    cgImage =  [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage != NULL) {
        return [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    }

    NSSize size = [image size];

    int rowBytes = ((int)(ceil(size.width)) * 4 + 0x0000000F) & ~0x0000000F; // 16-byte aligned

    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                         pixelsWide:size.width
                                                                         pixelsHigh:size.height
                                                                      bitsPerSample:8
                                                                    samplesPerPixel:4
                                                                           hasAlpha:YES
                                                                           isPlanar:NO
                                                                     colorSpaceName:NSCalibratedRGBColorSpace
                                                                       bitmapFormat:0
                                                                        bytesPerRow:rowBytes
                                                                       bitsPerPixel:32];

    if ( imageRep == nil )
        return nil;

    NSGraphicsContext* imageContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:imageContext];

    [image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

    [NSGraphicsContext restoreGraphicsState];
    // returns a 32-bit bitmap rep of the receiver, whatever its original format. The image rep is not added to the image.

    return imageRep;
}

- (CGImageRef) _cgImageForImage:(NSImage *)image
{
    NSImage * imageCopy = [image copy];

    for(NSImageRep * rep in [imageCopy representations]) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            NSBitmapImageRep * bitmapRep;

            bitmapRep = (NSBitmapImageRep *) rep;

            return [bitmapRep CGImage];
        }
    }

    [imageCopy addRepresentation:[self _mmGenerateBitmapRepForImage:imageCopy]];
    CGImageRef result = [(NSBitmapImageRep *) [[imageCopy representations] lastObject] CGImage];
    
    return result;
}

- (NSSize) _imageSizeWithFilename:(NSString *)filename
{
    NSImage * image;
    CGImageRef cgImage;
    NSSize size;

    image = [[NSImage alloc] initWithContentsOfFile:filename];
    cgImage = [self _cgImageForImage:image];
    size.width = CGImageGetWidth(cgImage);
    size.height = CGImageGetHeight(cgImage);

    return size;
}

- (NSSize) _fitImageSizeWithFilename:(NSString *)filename
{
    NSSize size;
    CGFloat height;
    CGFloat width;

    size = [self _imageSizeWithFilename:filename];
    width = 460;
    if (size.width < width) {
        width = size.width;
    }
    height = width * size.height / size.width;

    return NSMakeSize(width, height);
}

- (NSString *) _temporaryFolder
{
    if (_temporaryFolder != nil) {
        return _temporaryFolder;
    }

    _temporaryFolder = [[DJLPathManager sharedManager] temporaryFolder];
    return _temporaryFolder;
}

- (NSString *) _pngFilenameFromFilename:(NSString *)filename
{
    NSString * tmpDir = [self _temporaryFolder];
    NSImage * image = [[NSImage alloc] initWithContentsOfFile:filename];

    NSString * basename = [filename lastPathComponent];
    basename = [basename stringByDeletingPathExtension];
    NSString * tmpFilename = [tmpDir stringByAppendingPathComponent:basename];
    tmpFilename = [tmpFilename stringByAppendingPathExtension:@"png"];

    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];

    NSURL * fileURL = [[NSURL alloc] initFileURLWithPath:tmpFilename];
    CGImageDestinationRef destinationRef = CGImageDestinationCreateWithURL((CFURLRef)fileURL, (CFStringRef)@"public.png" , 1, NULL);
#warning TODO: there's probably a more efficient way to convert an image
    CGImageDestinationAddImage(destinationRef, [self _cgImageForImage:image], NULL);
    CGImageDestinationFinalize(destinationRef);
    CFRelease(destinationRef);

    return tmpFilename;
}

- (NSString *) _markupStringForImages:(NSArray *)imagesFilenames
{
    NSMutableArray * filenames;
    NSMutableArray * imageFilenames;
    NSMutableDictionary * contentIDs;
    NSMutableArray * tiffToPngFilenames;
    NSMutableArray * filenamesToRemove;

    filenames = [NSMutableArray arrayWithArray:imagesFilenames];
    imageFilenames = [NSMutableArray array];

    contentIDs = [[NSMutableDictionary alloc] init];

    tiffToPngFilenames = [NSMutableArray array];
    filenamesToRemove = [NSMutableArray array];

    for(NSString * filename in filenames) {
        // detect tiff filenames
        if ([[MCOAttachment mimeTypeForFilename:filename] isEqualToString:@"image/tiff"]) {
            [filenamesToRemove addObject:filename];
        }
    }

    [filenames removeObjectsInArray:filenamesToRemove];

    for(NSString * filename in filenamesToRemove) {
        // replaced tiff files by png
        NSString * newFilename = [self _pngFilenameFromFilename:filename];
        [tiffToPngFilenames addObject:newFilename];
        [filenames addObject:newFilename];
    }

    for(NSString * filename in filenames) {
        if ([self _filenameIsImage:filename]) {
            [imageFilenames addObject:filename];
            [contentIDs setObject:[[NSUUID UUID] UUIDString] forKey:filename];
        }
    }

    NSMutableString * markupString;

    markupString = nil;
    for(NSString * filename in filenames) {
        NSString * cid;

        cid = [contentIDs objectForKey:filename];
        if (cid == nil) {
            continue;
        }

        String * mimeType = Attachment::mimeTypeForFilename(MCO_FROM_OBJC(String, filename));

        NSData * data = [[NSData alloc] initWithContentsOfFile:filename];
        WebResource * resource = [[WebResource alloc] initWithData:data
                                                               URL:[NSURL URLWithString:[@"cid:" stringByAppendingString:cid]]
                                                          MIMEType:MCO_TO_OBJC(mimeType)
                                                  textEncodingName:nil
                                                         frameName:nil];
        [[[_webView mainFrame] dataSource] addSubresource:resource];

        if (markupString == nil) {
            markupString = [NSMutableString string];
        }

        NSSize size;
        size = [self _fitImageSizeWithFilename:filename];
        [markupString appendFormat:@"<img src=\"cid:%@\" width=\"%u\" height=\"%u\"/>\n", cid, (unsigned int) size.width, (unsigned int) size.height];
    }

    return markupString;
}

- (BOOL) _filenameIsImage:(NSString *)filename
{
    NSString * ext;
    static NSMutableArray * imageExts = nil;
    if (imageExts == nil) {
        imageExts = [[NSMutableArray alloc] init];
        [imageExts addObject:@"jpg"];
        [imageExts addObject:@"jpeg"];
        [imageExts addObject:@"png"];
        [imageExts addObject:@"gif"];
        [imageExts addObject:@"tiff"];
        [imageExts addObject:@"tif"];
    }

    ext = [[filename pathExtension] lowercaseString];
    for(NSString * currentExt in imageExts) {
        if ([ext isEqualToString:currentExt])
            return YES;
    }

    return NO;
}

- (BOOL) _draggingInfoIsImage:(id < NSDraggingInfo >)sender
{
    NSPasteboard * pasteboard;
    NSArray * files;
    BOOL isImage;

    pasteboard = [sender draggingPasteboard];
    files = [pasteboard propertyListForType:NSFilenamesPboardType];
    isImage = NO;
    if ([files count] > 0) {
        isImage = YES;
    }
    for(NSString * filename in files) {
        if (![self _filenameIsImage:filename]) {
            isImage = NO;
        }
    }
    if (isImage) {
        return YES;
    }

    return NO;
}

- (BOOL) DJLComposerWebView:(DJLComposerWebView *)webView prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    if ([self _draggingInfoIsImage:sender]) {
        NSMutableArray * filenames;
        NSPasteboard * pasteboard;
        NSString * markupString;

        pasteboard = [sender draggingPasteboard];
        filenames = [[pasteboard propertyListForType:NSFilenamesPboardType] mutableCopy];
        if ([filenames count] == 0) {
            return NO;
        }

        markupString = [self _markupStringForImages:filenames];

        if (markupString != nil) {
            [pasteboard declareTypes:[NSArray arrayWithObject:NSHTMLPboardType] owner:nil];
            [pasteboard setString:markupString forType:NSHTMLPboardType];
        }
    }
    return NO;
}

- (BOOL) _isWebViewFirstResponder
{
    if (![[[_webView window] firstResponder] isKindOfClass:[NSView class]]) {
        return NO;
    }

    NSView * view = (NSView *) [[_webView window] firstResponder];
    while (view != nil) {
        if (view == _webView) {
            return YES;
        }
        view = [view superview];
    }

    return NO;
}

#pragma mark menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(_accountSelected)) {
        return YES;
    }
    else if ([menuItem action] == @selector(createLink:)) {
        if ([self _isWebViewFirstResponder]) {
            return YES;
        }
        else {
            return NO;
        }
    }
    else {
        return NO;
    }
}

@end
