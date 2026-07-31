//
//  ImageSessionReplayViewController.m
//  Example
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ImageSessionReplayViewController.h"

static NSString * const FTImageCellIdentifier = @"SessionReplayImageCell";
static NSString * const FTImageColumnIdentifier = @"SessionReplayImageColumn";

@interface FTImageSessionReplayCellView : NSTableCellView

@property (nonatomic, strong) NSImageView *previewImageView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *urlLabel;
@property (nonatomic, strong) NSTextField *statusLabel;

- (void)configureWithImage:(nullable NSImage *)image
                     title:(NSString *)title
                       url:(NSString *)url
                    status:(NSString *)status
               statusColor:(NSColor *)statusColor;

@end

@implementation FTImageSessionReplayCellView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setupView {
    self.previewImageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.previewImageView.imageAlignment = NSImageAlignCenter;
    self.previewImageView.wantsLayer = YES;
    self.previewImageView.layer.backgroundColor =
        [NSColor colorWithWhite:0.94 alpha:1].CGColor;
    self.previewImageView.layer.cornerRadius = 8;
    self.previewImageView.layer.masksToBounds = YES;
    self.previewImageView.accessibilityLabel = @"Session Replay network image";
    self.imageView = self.previewImageView;

    self.titleLabel = [NSTextField labelWithString:@""];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [NSFont boldSystemFontOfSize:14];
    self.titleLabel.textColor = NSColor.labelColor;

    self.urlLabel = [NSTextField wrappingLabelWithString:@""];
    self.urlLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.urlLabel.font = [NSFont systemFontOfSize:11];
    self.urlLabel.textColor = NSColor.secondaryLabelColor;
    self.urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.urlLabel.maximumNumberOfLines = 2;

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];

    [self addSubview:self.previewImageView];
    [self addSubview:self.titleLabel];
    [self addSubview:self.urlLabel];
    [self addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.previewImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                                            constant:12],
        [self.previewImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.previewImageView.widthAnchor constraintEqualToConstant:120],
        [self.previewImageView.heightAnchor constraintEqualToConstant:90],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.previewImageView.trailingAnchor
                                                      constant:14],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.previewImageView.topAnchor constant:4],

        [self.urlLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.urlLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.urlLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.previewImageView.bottomAnchor
                                                       constant:-4],
    ]];
}

- (void)configureWithImage:(NSImage *)image
                     title:(NSString *)title
                       url:(NSString *)url
                    status:(NSString *)status
               statusColor:(NSColor *)statusColor {
    self.previewImageView.image = image;
    self.titleLabel.stringValue = title;
    self.urlLabel.stringValue = url;
    self.statusLabel.stringValue = status;
    self.statusLabel.textColor = statusColor;
    self.previewImageView.accessibilityLabel =
        [NSString stringWithFormat:@"%@, %@", title, status];
}

@end

@interface ImageSessionReplayViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *urlField;
@property (nonatomic, strong) NSTextField *summaryLabel;
@property (nonatomic, strong) NSMutableArray<NSString *> *imageURLs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSImage *> *imageCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *imageErrors;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadingURLs;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, assign) NSUInteger loadGeneration;

@end

@implementation ImageSessionReplayViewController

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 760)];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.imageURLs = [NSMutableArray array];
    self.imageCache = [NSMutableDictionary dictionary];
    self.imageErrors = [NSMutableDictionary dictionary];
    self.loadingURLs = [NSMutableSet set];
    [self createURLSession];
    [self setupView];
    [self loadNewBatch:nil];
}

- (void)dealloc {
    [self.urlSession invalidateAndCancel];
}

- (void)createURLSession {
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.timeoutIntervalForRequest = 30;
    self.urlSession = [NSURLSession sessionWithConfiguration:configuration];
}

- (void)setupView {
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;

    NSTextField *titleLabel =
        [NSTextField labelWithString:@"Session Replay Image Test"];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [NSFont boldSystemFontOfSize:24];
    titleLabel.textColor = NSColor.labelColor;

    NSTextField *descriptionLabel = [NSTextField wrappingLabelWithString:
        @"Remote images are rendered with NSImageView. Add or reload images, then "
         "inspect Session Replay image capture and resource upload."];
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descriptionLabel.font = [NSFont systemFontOfSize:13];
    descriptionLabel.textColor = NSColor.secondaryLabelColor;
    descriptionLabel.maximumNumberOfLines = 2;

    self.urlField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.urlField.translatesAutoresizingMaskIntoConstraints = NO;
    self.urlField.placeholderString = @"Image URL (https://...)";
    self.urlField.stringValue =
        @"https://picsum.photos/seed/macos-session-replay-custom/640/400";
    self.urlField.accessibilityLabel = @"Image URL";

    NSButton *loadURLButton =
        [NSButton buttonWithTitle:@"Load URL"
                           target:self
                           action:@selector(loadURLFromField:)];
    loadURLButton.translatesAutoresizingMaskIntoConstraints = NO;
    loadURLButton.bezelStyle = NSBezelStyleRounded;
    loadURLButton.keyEquivalent = @"\r";

    NSButton *addRandomButton =
        [NSButton buttonWithTitle:@"Add Random Image"
                           target:self
                           action:@selector(addRandomImage:)];
    addRandomButton.translatesAutoresizingMaskIntoConstraints = NO;
    addRandomButton.bezelStyle = NSBezelStyleRounded;

    NSButton *newBatchButton =
        [NSButton buttonWithTitle:@"Load New Batch"
                           target:self
                           action:@selector(loadNewBatch:)];
    newBatchButton.translatesAutoresizingMaskIntoConstraints = NO;
    newBatchButton.bezelStyle = NSBezelStyleRounded;

    NSStackView *buttonStack =
        [NSStackView stackViewWithViews:@[addRandomButton, newBatchButton]];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonStack.spacing = 10;
    buttonStack.alignment = NSLayoutAttributeCenterY;

    self.summaryLabel = [NSTextField labelWithString:@""];
    self.summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.summaryLabel.font = [NSFont systemFontOfSize:12];
    self.summaryLabel.textColor = NSColor.secondaryLabelColor;
    self.summaryLabel.alignment = NSTextAlignmentRight;

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;

    self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 112;
    self.tableView.intercellSpacing = NSMakeSize(0, 1);
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;

    NSTableColumn *column =
        [[NSTableColumn alloc] initWithIdentifier:FTImageColumnIdentifier];
    column.title = @"Network Images";
    column.resizingMask = NSTableColumnAutoresizingMask;
    column.width = 860;
    [self.tableView addTableColumn:column];
    scrollView.documentView = self.tableView;

    [self.view addSubview:titleLabel];
    [self.view addSubview:descriptionLabel];
    [self.view addSubview:self.urlField];
    [self.view addSubview:loadURLButton];
    [self.view addSubview:buttonStack];
    [self.view addSubview:self.summaryLabel];
    [self.view addSubview:scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor
                                                            constant:-24],

        [descriptionLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [descriptionLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                         constant:-24],

        [self.urlField.topAnchor constraintEqualToAnchor:descriptionLabel.bottomAnchor
                                                constant:16],
        [self.urlField.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [loadURLButton.leadingAnchor constraintEqualToAnchor:self.urlField.trailingAnchor
                                                    constant:10],
        [loadURLButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [loadURLButton.centerYAnchor constraintEqualToAnchor:self.urlField.centerYAnchor],
        [loadURLButton.widthAnchor constraintEqualToConstant:100],

        [buttonStack.topAnchor constraintEqualToAnchor:self.urlField.bottomAnchor constant:12],
        [buttonStack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.summaryLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:buttonStack.trailingAnchor
                                                                      constant:12],
        [self.summaryLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                          constant:-24],
        [self.summaryLabel.centerYAnchor constraintEqualToAnchor:buttonStack.centerYAnchor],

        [scrollView.topAnchor constraintEqualToAnchor:buttonStack.bottomAnchor constant:14],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-24],
    ]];
}

#pragma mark - Actions

- (void)loadURLFromField:(id)sender {
    NSString *urlString =
        [self.urlField.stringValue stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *scheme = url.scheme.lowercaseString;
    if (urlString.length == 0 ||
        (!([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]))) {
        [self showInvalidURLAlert];
        return;
    }
    [self appendImageURL:url.absoluteString];
}

- (void)addRandomImage:(id)sender {
    [self appendImageURL:[self randomImageURL]];
}

- (void)loadNewBatch:(id)sender {
    self.loadGeneration += 1;
    [self.urlSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> *tasks) {
        for (NSURLSessionTask *task in tasks) {
            [task cancel];
        }
    }];
    [self.imageURLs removeAllObjects];
    [self.imageCache removeAllObjects];
    [self.imageErrors removeAllObjects];
    [self.loadingURLs removeAllObjects];
    for (NSUInteger index = 0; index < 10; index++) {
        [self.imageURLs addObject:[self randomImageURL]];
    }
    [self.tableView reloadData];
    [self updateSummary];
}

- (void)appendImageURL:(NSString *)urlString {
    [self.imageURLs addObject:urlString];
    NSInteger row = self.imageURLs.count - 1;
    [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row]
                          withAnimation:NSTableViewAnimationEffectGap];
    [self.tableView scrollRowToVisible:row];
    [self loadImageAtRow:row];
    [self updateSummary];
}

- (NSString *)randomImageURL {
    uint32_t seed = arc4random_uniform(1000000);
    return [NSString stringWithFormat:
        @"https://picsum.photos/seed/macos-%lu-%u/640/400",
        (unsigned long)self.loadGeneration,
        seed];
}

- (void)showInvalidURLAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Invalid image URL";
    alert.informativeText = @"Enter an http or https image URL.";
    [alert addButtonWithTitle:@"OK"];
    if (self.view.window) {
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

#pragma mark - Image loading

- (void)loadImageAtRow:(NSInteger)row {
    if (row < 0 || row >= self.imageURLs.count) {
        return;
    }
    NSString *urlString = self.imageURLs[row];
    if (self.imageCache[urlString] || [self.loadingURLs containsObject:urlString]) {
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        self.imageErrors[urlString] = @"Invalid URL";
        [self reloadRow:row];
        return;
    }

    [self.loadingURLs addObject:urlString];
    [self.imageErrors removeObjectForKey:urlString];
    [self updateSummary];

    NSUInteger generation = self.loadGeneration;
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task =
        [self.urlSession dataTaskWithURL:url
                      completionHandler:^(NSData *data,
                                          NSURLResponse *response,
                                          NSError *error) {
        NSImage *image = data.length > 0 ? [[NSImage alloc] initWithData:data] : nil;
        NSHTTPURLResponse *httpResponse =
            [response isKindOfClass:NSHTTPURLResponse.class]
                ? (NSHTTPURLResponse *)response
                : nil;
        NSString *failure = nil;
        if (error) {
            failure = error.localizedDescription;
        } else if (httpResponse &&
                   (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300)) {
            failure = [NSString stringWithFormat:@"HTTP %ld",
                                                  (long)httpResponse.statusCode];
        } else if (!image) {
            failure = @"Response is not a supported image";
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            ImageSessionReplayViewController *strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf.loadGeneration) {
                return;
            }
            [strongSelf.loadingURLs removeObject:urlString];
            if (image) {
                strongSelf.imageCache[urlString] = image;
                [strongSelf.imageErrors removeObjectForKey:urlString];
            } else {
                strongSelf.imageErrors[urlString] = failure ?: @"Image load failed";
            }
            NSUInteger currentRow = [strongSelf.imageURLs indexOfObject:urlString];
            if (currentRow != NSNotFound) {
                [strongSelf reloadRow:(NSInteger)currentRow];
            }
            [strongSelf updateSummary];
        });
    }];
    [task resume];
}

- (void)reloadRow:(NSInteger)row {
    if (row < 0 || row >= self.imageURLs.count) {
        return;
    }
    [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                              columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)updateSummary {
    self.summaryLabel.stringValue =
        [NSString stringWithFormat:@"%lu images · %lu loaded · %lu loading",
                                   (unsigned long)self.imageURLs.count,
                                   (unsigned long)self.imageCache.count,
                                   (unsigned long)self.loadingURLs.count];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.imageURLs.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
    FTImageSessionReplayCellView *cell =
        [tableView makeViewWithIdentifier:FTImageCellIdentifier owner:self];
    if (!cell) {
        cell = [[FTImageSessionReplayCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = FTImageCellIdentifier;
    }

    NSString *urlString = self.imageURLs[row];
    NSImage *image = self.imageCache[urlString];
    NSString *error = self.imageErrors[urlString];
    NSString *status = nil;
    NSColor *statusColor = nil;
    if (image) {
        status = @"Loaded — ready for Session Replay capture";
        statusColor = NSColor.systemGreenColor;
    } else if (error) {
        status = [@"Failed — " stringByAppendingString:error];
        statusColor = NSColor.systemRedColor;
    } else {
        status = @"Loading…";
        statusColor = NSColor.secondaryLabelColor;
    }
    [cell configureWithImage:image
                       title:[NSString stringWithFormat:@"Image %ld", (long)row + 1]
                         url:urlString
                      status:status
                 statusColor:statusColor];
    if (!image && !error) {
        [self loadImageAtRow:row];
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = self.tableView.selectedRow;
    if (row >= 0 && row < self.imageURLs.count) {
        self.urlField.stringValue = self.imageURLs[row];
    }
}

@end
