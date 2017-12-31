// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "DJLGiphyViewController.h"

#import "DJLGiphyCollectionView.h"
#import "DJLColoredView.h"
#import "DJLSearchField.h"
#include "DJLKeys.h"

#define IMAGE_HEIGHT 120
#define IMAGE_WIDTH 120

@interface DJLGiphyViewController () <NSCollectionViewDelegate>

@end

@implementation DJLGiphyViewController {
    NSScrollView * _scrollView;
    DJLGiphyCollectionView * _collectionView;
    DJLSearchField * _searchField;
    NSURLSessionDataTask * _dataTask;
    NSImageView * _poweredByGiphyImageView;
}

- (void) loadView
{
    DJLColoredView * view = [[DJLColoredView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [view setBackgroundColor:[NSColor clearColor]];
    [self setView:view];

    _searchField = [[DJLSearchField alloc] initWithFrame:NSZeroRect];
    [_searchField setDelegate:(id) self];
    [_searchField setFont:[NSFont systemFontOfSize:13]];
    [_searchField setFocusRingType:NSFocusRingTypeNone];
    [view addSubview:_searchField];

    _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
    [_scrollView setVerticalScrollElasticity:NSScrollElasticityAutomatic];
    [_scrollView setHasVerticalScroller:YES];
    [_scrollView setDrawsBackground:NO];
    [_scrollView setBackgroundColor:[NSColor clearColor]];
    //[_scrollView setContentInsets:NSEdgeInsetsMake(0, 0, 10, 0)];
    [_scrollView setAutomaticallyAdjustsContentInsets:NO];

    [view addSubview:_scrollView];
    _collectionView = [[DJLGiphyCollectionView alloc] initWithFrame:NSZeroRect];
    [_collectionView setDelegate:self];
    [_collectionView setSelectable:YES];
    [_collectionView setAllowsMultipleSelection:NO];
    [_collectionView setMinItemSize:NSMakeSize(IMAGE_WIDTH, IMAGE_HEIGHT)];
    [_collectionView setMaxItemSize:NSMakeSize(IMAGE_WIDTH, IMAGE_HEIGHT)];
    [_collectionView setMaxNumberOfRows:0];
    [_collectionView setMaxNumberOfColumns:4];
    [_collectionView setBackgroundColors:@[[NSColor clearColor]]];
    [_scrollView setDocumentView:_collectionView];

    _poweredByGiphyImageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    NSImage * image = [NSImage imageNamed:@"PoweredBy_200px-White_HorizText"];
    [_poweredByGiphyImageView setImage:image];
    [_poweredByGiphyImageView sizeToFit];
    [view addSubview:_poweredByGiphyImageView];

    [self _reallySearch];
}

- (void)viewDidLayout
{
    NSSize imageSize = [[_poweredByGiphyImageView image] size];
    imageSize.height += 10;
    imageSize.width += 20;
    NSRect bounds = [[self view] bounds];
    [_searchField sizeToFit];
    NSRect frame = [_searchField frame];
    frame.origin.x = 10;
    frame.origin.y = bounds.size.height - [_searchField frame].size.height - 10;
    frame.size.width = bounds.size.width -= 20;
    [_searchField setFrame:frame];
    frame = bounds;
    frame.origin.y = imageSize.height + 5;
    frame.origin.x = 10;
    frame.size.width = bounds.size.width;
    frame.size.height -= [_searchField frame].size.height + imageSize.height + 20;
    [_scrollView setFrame:frame];
    frame = [_poweredByGiphyImageView frame];
    frame.origin.x = 0;
    frame.size = imageSize;
    [_poweredByGiphyImageView setFrame:frame];
}

- (void) makeFirstResponder
{
    [[_searchField window] makeFirstResponder:_searchField];
}

- (void) prepareSize
{
    [[self delegate] DJLGiphyViewController:self hasHeight:[[_scrollView documentView] frame].size.height];
}

- (void) controlTextDidChange:(NSNotification *) notification
{
    [self _performSearch];
}

- (void) _performSearch
{
    if (_dataTask != nil) {
        [_dataTask cancel];
        _dataTask = nil;
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallySearch) object:nil];
    [self performSelector:@selector(_reallySearch) withObject:nil afterDelay:0.5];
}

- (void) _reallySearch
{
    if (_dataTask != nil) {
        [_dataTask cancel];
        _dataTask = nil;
    }

    NSCharacterSet * empty = [[NSCharacterSet alloc] init];
    NSString * key = [GIPHY_KEY stringByAddingPercentEncodingWithAllowedCharacters:empty];
    NSString * urlString;
    if ([[_searchField stringValue] length] != 0) {
        NSString * query = [[_searchField stringValue] stringByAddingPercentEncodingWithAllowedCharacters:empty];
        urlString = [NSString stringWithFormat:@"https://api.giphy.com/v1/gifs/search?q=%@&api_key=%@&limit=100", query, key];
    }
    else {
        urlString = [NSString stringWithFormat:@"https://api.giphy.com/v1/gifs/trending?api_key=%@&limit=100", key];
    }
    NSURL * url = [NSURL URLWithString:urlString];
    _dataTask = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        NSDictionary * result = nil;
        @try {
            result = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        }
        @catch (NSException * e) {
        }
        if (![result isKindOfClass:[NSDictionary class]]) {
            [_collectionView setContent:@[]];
            _dataTask = nil;
            return;
        }
        [_collectionView setContent:result[@"data"]];
        _dataTask = nil;
    }];
    [_dataTask resume];
}

- (void) DJLGiphyCollectionView:(DJLGiphyCollectionView *)view selectItem:(NSDictionary *)item
{
    [[self delegate] DJLGiphyViewController:self itemSelected:item];
}

- (void) djl_searchFieldOperationCancelled:(DJLSearchField *)searchField
{
    [[self delegate] DJLGiphyViewControllerClosed:self];
}

@end
