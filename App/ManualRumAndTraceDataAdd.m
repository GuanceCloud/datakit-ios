//
//  ManualRumAndTraceDataAdd.m
//  App
//
//  Created by 胡蕾蕾 on 2021/12/3.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "ManualRumAndTraceDataAdd.h"
#import "TableViewCellItem.h"
#import <FTExternalDataManager.h>
#import <FTRUMManager.h>
#import <FTResourceMetricsModel.h>
#import <FTResourceContentModel.h>
#import "FTURLSessionInterceptor.h"
#import "FTTraceManager.h"

@interface ManualRumAndTraceDataAdd ()<UITableViewDelegate,UITableViewDataSource,NSURLSessionDelegate,NSURLSessionTaskDelegate>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSMutableArray<TableViewCellItem*> *dataSource;
@property (nonatomic, copy) NSString *rumKey;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics API_AVAILABLE(ios(10.0));
@property (nonatomic, strong) NSData *data;

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
        // duration 以纳秒为单位 示例中为 1s
        [[FTExternalDataManager sharedManager] startViewWithName:@"TestVC"];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"RUM stopView" handler:^{
    
        [[FTExternalDataManager sharedManager] stopView];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"RUM addAction" handler:^{
        [[FTExternalDataManager sharedManager]  addClickActionWithName:@"UITableViewCell click"];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"RUM addError" handler:^{
        [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"crash_message" stack:@"crash_stack"];
    }];
    TableViewCellItem *item6 = [[TableViewCellItem alloc]initWithTitle:@"RUM addLongTask" handler:^{
        [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"long task" duration:@1000000000];
    }];
    TableViewCellItem *item7 = [[TableViewCellItem alloc]initWithTitle:@"RUM Resource" handler:^{
        [weakSelf manualRumResource];
    }];
    [self.dataSource addObjectsFromArray:@[item1,item2,item3,item4,item5,item6,item7]];
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    
}
- (void)manualTrace{
    NSString *key = [[NSUUID UUID]UUIDString];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
    NSDictionary *traceHeader = [[FTTraceManager sharedInstance] getTraceHeaderWithKey:key url:url];
    // 上面方法已废弃，使用下面方法进行替换
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
- (void)manualRumResource{
    self.rumKey = [[NSUUID UUID]UUIDString];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    [[FTExternalDataManager sharedManager] startResourceWithKey:self.rumKey];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    
    [task resume];
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)){
    self.metrics = metrics;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    self.data = data;

}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
    NSString * responseBody  =[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];

    [[FTExternalDataManager sharedManager] stopResourceWithKey:self.rumKey];
    
    FTResourceMetricsModel *metricsModel = [[FTResourceMetricsModel alloc]initWithTaskMetrics:self.metrics];


    FTResourceContentModel *content = [[FTResourceContentModel alloc]init];
    content.httpMethod = task.originalRequest.HTTPMethod;
    content.requestHeader = task.originalRequest.allHTTPHeaderFields;
    content.responseHeader = httpResponse.allHeaderFields;
    content.httpStatusCode = httpResponse.statusCode;
    content.responseBody = responseBody;
    //ios native
    content.error = error;
    [[FTExternalDataManager sharedManager] addResourceWithKey:self.rumKey metrics:metricsModel content:content];
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
