//
//  TestImageVC.m
//  ft-sdk-iosTest
//
//  Created by DemoViewController
//

#import "TestImageVC.h"

@interface TestImageVC () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSString *> *imageURLs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *imageCache;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIBarButtonItem *addCellButton;
@property (nonatomic, strong) NSURLSession *urlSession;

@end

@implementation TestImageVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Image Session Replay Test";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.imageURLs = [NSMutableArray array];
    self.imageCache = [NSMutableDictionary dictionary];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    self.urlSession = [NSURLSession sessionWithConfiguration:config];
    
    [self loadInitialImages];
    [self setupNavigationBar];
    [self setupTableView];
    [self setupRefreshButton];
}

- (void)dealloc {
    [self.urlSession invalidateAndCancel];
}

- (void)loadInitialImages {
    [self.imageURLs removeAllObjects];
    [self.imageCache removeAllObjects];
    
    for (int i = 0; i < 10; i++) {
        NSString *urlString = [NSString stringWithFormat:@"https://picsum.photos/seed/picsum%d/100/100", i];
        [self.imageURLs addObject:urlString];
    }
}

- (void)setupNavigationBar {
    UIImage *addImage;
    if (@available(iOS 13.0, *)) {
        addImage = [UIImage systemImageNamed:@"plus.circle.fill"];
    } else {
        addImage = [UIImage imageNamed:@"plus"];
    }
    
    if (@available(iOS 13.0, *)) {
        if (addImage.isSymbolImage) {
            NSLog(@"Add button uses symbol image");
        }
    }
    
    self.addCellButton = [[UIBarButtonItem alloc] initWithImage:addImage
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(addCellButtonTapped)];
    self.navigationItem.rightBarButtonItem = self.addCellButton;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 120;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ImageCell"];
    [self.view addSubview:self.tableView];
    
    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-60]
        ]];
    }
}

- (void)setupRefreshButton {
    self.refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshButton setTitle:@"Refresh Images" forState:UIControlStateNormal];
    [self.refreshButton addTarget:self action:@selector(refreshButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.refreshButton.backgroundColor = [UIColor systemBlueColor];
    [self.refreshButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.refreshButton.layer.cornerRadius = 8;
    [self.view addSubview:self.refreshButton];
    
    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.refreshButton.topAnchor constraintEqualToAnchor:self.tableView.bottomAnchor constant:8],
            [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
            [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
            [self.refreshButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
            [self.refreshButton.heightAnchor constraintEqualToConstant:44]
        ]];
    }
}

#pragma mark - Button Actions

- (void)addCellButtonTapped {
    int randomSeed = arc4random_uniform(10000);
    NSString *newURLString = [NSString stringWithFormat:@"https://picsum.photos/seed/%d/100/100", randomSeed];
    
    [self.imageURLs addObject:newURLString];
    
    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:self.imageURLs.count - 1 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self.tableView scrollToRowAtIndexPath:newIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)refreshButtonTapped {
    [self.imageCache removeAllObjects];
    
    [self loadInitialImages];
    [self.tableView reloadData];
}

#pragma mark - Image Loading

- (void)loadImageForURL:(NSString *)urlString atIndexPath:(NSIndexPath *)indexPath {
    if (self.imageCache[urlString]) {
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to load image: %@", error.localizedDescription);
            return;
        }
        
        UIImage *image = [UIImage imageWithData:data];
        if (image) {
            weakSelf.imageCache[urlString] = image;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UITableViewCell *cell = [weakSelf.tableView cellForRowAtIndexPath:indexPath];
                if (cell) {
                    cell.imageView.image = image;
                    [cell setNeedsLayout];
                }
            });
        }
    }];
    
    [task resume];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.imageURLs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ImageCell" forIndexPath:indexPath];
    

    cell.imageView.image = nil;
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    
    NSString *urlString = self.imageURLs[indexPath.row];
    
    cell.imageView.image = [self placeholderImage];
    cell.textLabel.text = [NSString stringWithFormat:@"Loading Image %ld", (long)indexPath.row];
    cell.detailTextLabel.text = urlString;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:10];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    
    UIImage *cachedImage = self.imageCache[urlString];
    if (cachedImage) {
        cell.imageView.image = cachedImage;
        cell.textLabel.text = [NSString stringWithFormat:@"Loaded Image %ld", (long)indexPath.row];
    } else {
        [self loadImageForURL:urlString atIndexPath:indexPath];
    }
    
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.imageView.clipsToBounds = YES;
    
    cell.isAccessibilityElement = YES;
    cell.accessibilityLabel = [NSString stringWithFormat:@"Network image cell %ld", (long)indexPath.row];
    
    return cell;
}

- (UIImage *)placeholderImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(100, 100), NO, 0.0);
    
    UIColor *backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    [backgroundColor setFill];
    UIRectFill(CGRectMake(0, 0, 100, 100));
    
    UIColor *foregroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    [foregroundColor setStroke];
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(20, 20)];
    [path addLineToPoint:CGPointMake(80, 80)];
    [path moveToPoint:CGPointMake(80, 20)];
    [path addLineToPoint:CGPointMake(20, 80)];
    [path stroke];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *urlString = self.imageURLs[indexPath.row];
    UIImage *image = self.imageCache[urlString];
    
    NSString *message;
    if (image) {
        message = [NSString stringWithFormat:@"Image loaded from:\n%@", urlString];
    } else {
        message = [NSString stringWithFormat:@"Loading image from:\n%@", urlString];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Image Info"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *urlString = self.imageURLs[indexPath.row];
    if (!self.imageCache[urlString]) {
        [self loadImageForURL:urlString atIndexPath:indexPath];
    }
}

@end
