// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGiphyCollectionViewItem.h"

#import "DJLColoredView.h"

@class DJLGiphyItemView;

@protocol DJLGiphyItemViewDelegate

- (void) DJLGiphyItemView:(DJLGiphyItemView *)view clickedWithEvent:(NSEvent *)event;

@end

@interface DJLGiphyItemView : DJLColoredView

@property (nonatomic, assign) id <DJLGiphyItemViewDelegate> delegate;

@end

@implementation DJLGiphyItemView

- (void) mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];
    [[self delegate] DJLGiphyItemView:self clickedWithEvent:theEvent];
}

@end

@interface DJLGiphyImageView : NSView

@property (nonatomic, retain) NSImage * image;

@end

@implementation DJLGiphyImageView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    self.layer = [[CALayer alloc] init];
    self.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.wantsLayer = YES;
    return self;
}

- (void) setImage:(NSImage *)image
{
    _image = image;
    self.layer.contents = image;
}

@end

@interface DJLGiphyCollectionViewItem () <DJLGiphyItemViewDelegate>

@end

@implementation DJLGiphyCollectionViewItem {
    DJLColoredView * _selectionBackgroundView;
    DJLGiphyImageView * _imageView;
    NSImageView * _animatedImageView;
    BOOL _loading;
    BOOL _loaded;
    NSTrackingArea * _area;
    NSView * _view;
    BOOL _inside;
}

#define ATTACHMENT_HEIGHT 120
#define ATTACHMENT_WIDTH 120

- (void) dealloc
{
    [_view removeTrackingArea:_area];
}

- (void) loadView
{
    DJLGiphyItemView * view = [[DJLGiphyItemView alloc] initWithFrame:NSMakeRect(0, 0, ATTACHMENT_WIDTH, ATTACHMENT_WIDTH)];
    [view setDelegate:self];
    [view setBackgroundColor:[NSColor clearColor]];

    _selectionBackgroundView = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, ATTACHMENT_WIDTH, ATTACHMENT_HEIGHT)];
    [_selectionBackgroundView setBackgroundColor:[NSColor colorWithWhite:1.0 alpha:0.5]];
    [_selectionBackgroundView setHidden:YES];

    _imageView = [[DJLGiphyImageView alloc] initWithFrame:NSMakeRect(0, 0, ATTACHMENT_WIDTH, ATTACHMENT_WIDTH)];
    [view addSubview:_imageView];
    _animatedImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, ATTACHMENT_WIDTH, ATTACHMENT_WIDTH)];
    _animatedImageView.canDrawSubviewsIntoLayer = YES;
    [view addSubview:_animatedImageView];
    [_animatedImageView setHidden:YES];

    [view addSubview:_selectionBackgroundView];
    if ([self isSelected]) {
        [_selectionBackgroundView setHidden:NO];
    }

    [self setView:view];
    _view = view;

    _area = [[NSTrackingArea alloc] initWithRect:[[self view] bounds] options:NSTrackingActiveInKeyWindow | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    [[self view] addTrackingArea:_area];

    if ([self representedObject] != nil) {
        [self _reflectRepresentedObject];
    }
}

- (void) setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];
    [self _reflectRepresentedObject];
}

- (void) _reflectRepresentedObject
{
    [self _start];
}

- (void) _start
{
    NSDictionary * info = [self representedObject];
    NSString * urlString = info[@"images"][@"downsized_still"][@"url"];
    NSURL * url = [NSURL URLWithString:urlString];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDownloadTask * task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL * location, NSURLResponse * response, NSError * error) {
        [weakSelf _downloadFinishedWithLocation:location response:response error:error];
    }];
    [task resume];
}

- (void) _downloadFinishedWithLocation:(NSURL *)location response:(NSURLResponse *)response error:(NSError *)error
{
    BOOL failed = NO;

    if (error != nil) {
        failed = YES;
    }
    else {
        NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            failed = YES;
        }
    }

    if (failed) {
        return;
    }

    NSData * data = [NSData dataWithContentsOfURL:location];
    NSImage * image = [[NSImage alloc] initWithData:data];
    [image size];

    dispatch_async(dispatch_get_main_queue(), ^{
        [_imageView setImage:image];
    });
}

- (void) _loadAnimatedIfNeeded
{
    if (_loading || _loaded) {
        return;
    }

    _loading = YES;
    NSDictionary * info = [self representedObject];
    NSString * urlString = info[@"images"][@"downsized"][@"url"];
    NSURL * url = [NSURL URLWithString:urlString];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDownloadTask * task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL * location, NSURLResponse * response, NSError * error) {
        [weakSelf _downloadAnimatedFinishedWithLocation:location response:response error:error];
    }];
    [task resume];
}

- (void) _downloadAnimatedFinishedWithLocation:(NSURL *)location response:(NSURLResponse *)response error:(NSError *)error
{
    BOOL failed = NO;

    if (error != nil) {
        failed = YES;
    }
    else {
        NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            failed = YES;
        }
    }

    if (failed) {
        _loading = NO;
        return;
    }

    NSData * data = [NSData dataWithContentsOfURL:location];
    NSImage * image = [[NSImage alloc] initWithData:data];
    [image size];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSSize imageSize = [image size];
        CGFloat factor = imageSize.width / imageSize.height;
        if (factor > 1.0) {
            CGFloat deltaX = round(ATTACHMENT_WIDTH * (1.0 - factor) / 2.0);
            [_animatedImageView setFrame:NSMakeRect(deltaX, 0, round(ATTACHMENT_WIDTH * factor), ATTACHMENT_HEIGHT)];
        }
        else {
            CGFloat deltaY = round(ATTACHMENT_HEIGHT * (1.0 - 1.0 / factor) / 2.0);
            [_animatedImageView setFrame:NSMakeRect(0, deltaY, ATTACHMENT_WIDTH, round(ATTACHMENT_HEIGHT / factor))];
        }

        [_animatedImageView setImage:image];
        _loading = NO;
        _loaded = YES;

        [self _updateImage];
    });
}

- (void) _updateImage
{
    if (_inside && _loaded) {
        [_animatedImageView setHidden:NO];
        _animatedImageView.animates = YES;
    }
    else {
        [_animatedImageView setHidden:YES];
        _animatedImageView.animates = NO;
    }
}

- (void) layoutViews
{
}

- (void) setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [_selectionBackgroundView setHidden:!selected];
}

- (void) mouseEntered:(NSEvent *)theEvent
{
    [[NSCursor arrowCursor] push];
    _inside = YES;
    [self _loadAnimatedIfNeeded];
    [self _updateImage];
}

- (void) mouseExited:(NSEvent *)theEvent
{
    [NSCursor pop];
    _inside = NO;
    [self _updateImage];
}

- (void) DJLGiphyItemView:(DJLGiphyItemView *)view clickedWithEvent:(NSEvent *)event
{
    [[self delegate] DJLGiphyCollectionViewItem:self clickedWithEvent:event];
}

@end
