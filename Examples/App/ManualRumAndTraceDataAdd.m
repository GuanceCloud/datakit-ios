//
//  ManualRumAndTraceDataAdd.m
//  App
//
//  Created by hulilei on 2021/12/3.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "ManualRumAndTraceDataAdd.h"
#import "TableViewCellItem.h"
#import <FTMobileSDK/FTMobileAgent.h>
#import <objc/runtime.h>

static const void * const kURLSessionTaskKey = &kURLSessionTaskKey;
static const void * const kURLSessionTaskData = &kURLSessionTaskData;
static const void * const kURLSessionTaskMetrics = &kURLSessionTaskMetrics;

@interface ManualRumAndTraceDataAdd ()<UITableViewDelegate,UITableViewDataSource,NSURLSessionDelegate,NSURLSessionDataDelegate>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSMutableArray<TableViewCellItem*> *dataSource;
@end

@implementation ManualRumAndTraceDataAdd

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    // Do any additional setup after loading the view.
    [self createUI];
}
-(NSMutableArray<TableViewCellItem *> *)dataSource{
    if (!_dataSource) {
        _dataSource = [[NSMutableArray alloc]init];
    }
    return _dataSource;
}
- (void)createUI{
    __weak typeof(self) weakSelf = self;
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:@"Trace" handler:^{
        [weakSelf manualTrace];
    }];
    TableViewCellItem *item2 = [[TableViewCellItem alloc]initWithTitle:@"RUM startView" handler:^{
        // duration in nanoseconds, example is 1s
        [[FTExternalDataManager sharedManager] startViewWithName:@"TestVC"];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"RUM stopView" handler:^{
    
        [[FTExternalDataManager sharedManager] stopView];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"RUM startAction" handler:^{
        [[FTExternalDataManager sharedManager] startAction:@"UITableViewCell click" actionType:@"click" property:@{@"start_action_key":@"start_action_value"}];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"RUM addAction" handler:^{
        [[FTExternalDataManager sharedManager] addAction:@"Add Action" actionType:@"click" property:@{@"add_action_key":@"add_action_value"}];
    }];
    TableViewCellItem *item6 = [[TableViewCellItem alloc]initWithTitle:@"RUM addError" handler:^{
        [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" state:FTAppStateUnknown message:@"crash_message" stack:@"crash_stack" property:nil];
    }];
    TableViewCellItem *item7 = [[TableViewCellItem alloc]initWithTitle:@"RUM addLongTask" handler:^{
        [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"long task" duration:@1000000000];
    }];
    TableViewCellItem *item8 = [[TableViewCellItem alloc]initWithTitle:@"RUM Resource" handler:^{
        [weakSelf manualRumResource:@"https://httpbin.org/status/200"];
    }];
    TableViewCellItem *item9 = [[TableViewCellItem alloc]initWithTitle:@"RUM Resource Error" handler:^{
        [weakSelf manualRumResource:@"https://httpbin.org/status/404"];
    }];
    [self.dataSource addObjectsFromArray:@[item1,item2,item3,item4,item5,item6,item7,item8,item9]];
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    
}
- (void)manualTrace{
    NSString *key = [[NSUUID UUID]UUIDString];
    NSString *urlStr = @"https://httpbin.org/status/200";

    NSURL *url = [NSURL URLWithString:urlStr];
    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
    // The above method is deprecated, use the method below instead
    //    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    if (traceHeader && traceHeader.allKeys.count>0) {
        [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [request setValue:value forHTTPHeaderField:field];
        }];
    }
    NSURLSession *session=[NSURLSession sharedSession];
    
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

    }];
    
    [task resume];
    
}
- (void)manualRumResource:(NSString *)urlStr{
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    NSString *resourceKey = [[NSUUID UUID]UUIDString];
    [self setAssociatedObject:task key:&kURLSessionTaskKey value:resourceKey];
    [[FTExternalDataManager sharedManager] startResourceWithKey:resourceKey];
    [task resume];
}

- (void)setAssociatedObject:(NSURLSessionTask *)task key:(const void *)key value:(id)value{
    objc_setAssociatedObject(task, &key, task, OBJC_ASSOCIATION_RETAIN);
}
- (id)getAssociatedObject:(NSURLSessionTask *)task key:(const void *)key{
    return objc_getAssociatedObject(task, key);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)){
    [self setAssociatedObject:task key:&kURLSessionTaskMetrics value:metrics];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    [self setAssociatedObject:dataTask key:&kURLSessionTaskData value:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;

    [[FTExternalDataManager sharedManager] stopResourceWithKey:[self getAssociatedObject:task key:&kURLSessionTaskKey]];
    
    FTResourceMetricsModel *metricsModel = [[FTResourceMetricsModel alloc]initWithTaskMetrics:[self getAssociatedObject:task key:&kURLSessionTaskMetrics]];


    FTResourceContentModel *content = [[FTResourceContentModel alloc]initWithRequest:task.currentRequest response:httpResponse data:[self getAssociatedObject:task key:&kURLSessionTaskData] error:error];
    [[FTExternalDataManager sharedManager] addResourceWithKey:[self getAssociatedObject:task key:&kURLSessionTaskKey] metrics:metricsModel content:content];
}
#pragma mark ========== UITableViewDataSource ==========
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = self.dataSource[indexPath.row].title;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.dataSource[indexPath.row];
    if (item.handler) {
        item.handler();
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
