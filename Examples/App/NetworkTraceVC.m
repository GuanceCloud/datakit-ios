//
//  NetworkTraceVC.m
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "NetworkTraceVC.h"
#import "TableViewCellItem.h"
#import <FTMobileSDK/FTMobileSDK.h>
//仅做示例，可以使用类保存单条 task 的数据
@interface RUMResource: NSObject
@property (nonatomic,copy) NSString *key;
@property (nonatomic,strong,nullable) NSData *data;
@property (nonatomic,strong,nullable) NSURLSessionTaskMetrics *metrics;
@end
@implementation RUMResource

-(instancetype)initWithKey:(NSString *)key{
    self = [super init];
    if(self){
        _key = key;
    }
    return self;
}

@end
@interface NetworkTraceVC ()<UITableViewDelegate,UITableViewDataSource,NSURLSessionDataDelegate>
@property (nonatomic, strong) UITableView *mTableView;
@property (nonatomic, strong) NSArray<NSArray*> *datas;
@property (nonatomic, strong) NSMutableDictionary <NSURLSessionTask  *,RUMResource*>*taskHandler;

@end

@implementation NetworkTraceVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"network data collection";
    self.view.backgroundColor = [UIColor whiteColor];
    self.taskHandler = [NSMutableDictionary new];
    [self createUI];
}
- (void)createUI{
    // enableTraceUserResource = YES;
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    __weak typeof(self) weakSelf = self;
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:@"Rum、Trace 开启 Resource 自动采集" handler:^{
        NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
        [task resume];
    }];
    // 避免数据重复请关闭 enableTraceUserResource
    TableViewCellItem *item2 = [[TableViewCellItem alloc]initWithTitle:@"注册 `FTURLSessionDelegate`" subTitle:@"委托替换为`FTURLSessionDelegate`，内部记录所有需要的事件并将方法转发给原始委托" handler:^{
    
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:[[FTURLSessionDelegate alloc]initWithRealDelegate:weakSelf] delegateQueue:nil];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
       
        [task resume];
        
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"启用自动注册`FTURLSessionDelegate`" subTitle:@"委托自动替换为`FTURLSessionDelegate`，内部记录所有需要的事件并将方法转发给原始委托"  handler:^{
        [FTURLSessionDelegate enableAutomaticRegistration];
        
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:weakSelf delegateQueue:[NSOperationQueue mainQueue]];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
       
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
       
        [task resume];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"拦截 Request 请求，自定义 Trace" handler:^{
        [FTURLSessionDelegate requestInterceptor:^NSURLRequest * _Nonnull(NSURLRequest * _Nonnull request) {
            NSMutableURLRequest *newRequest = [request mutableCopy];
            [newRequest setValue:@"interceptor" forHTTPHeaderField:@"test"];
            return request;
        }];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"添加 RUM Resource 额外资源" handler:^{
        [FTURLSessionDelegate rumResourcePropertyProvider:^NSDictionary * _Nullable(NSURLRequest * _Nullable request, NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error) {
            NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
            return @{@"request_body":body};
        }];
    }];
    
    TableViewCellItem *item6 = [[TableViewCellItem alloc]initWithTitle:@"手动操作:使用 open api 操作" handler:^{
        NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
        NSString *key = [[NSUUID UUID] UUIDString];
        NSURL *url = [NSURL URLWithString:urlStr];
        // 获取 trace（链路追踪）需要添加的请求头
        NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        for (NSString *httpHeaderField in traceHeader.keyEnumerator) {
            [request addValue:traceHeader[httpHeaderField] forHTTPHeaderField:httpHeaderField];
        }
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:weakSelf delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
        RUMResource *handler = [[RUMResource alloc]initWithKey:key];
        weakSelf.taskHandler[task] = handler;
        [[FTExternalDataManager sharedManager] startResourceWithKey:key];

        [task resume];
    }];
    
    self.datas = @[@[item1],@[item2,item3,item4,item5],@[item6]];
    self.mTableView.dataSource = self;
    self.mTableView.delegate = self;
    [self.mTableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"UITableViewCell"];
    [self.view addSubview:self.mTableView];
}
-(UITableView *)mTableView{
    if(!_mTableView){
        _mTableView = [[UITableView alloc]initWithFrame:self.view.frame style:UITableViewStylePlain];
    }
    return _mTableView;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 3;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.datas[section].count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section == 0){
        return @"Use Autotrace";
    }else if(section == 1){
        return @"URLSession Auto Instrumentation";
    }else{
        return @"Use Manual";
    }
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    if(item.subTitle.length>0){
        return 75;
    }
    return 45;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell =  [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"UITableViewCell"];
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = item.subTitle;
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    if (item.handler) {
        item.handler();
    }
}
#pragma mark --------- NSURLSessionDataDelegate ----------

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)){
    RUMResource *handler =  self.taskHandler[task];
    handler.metrics = metrics;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    RUMResource *handler =  self.taskHandler[dataTask];
    handler.data = data;

}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    RUMResource *handler =  self.taskHandler[task];
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    [[FTExternalDataManager sharedManager] stopResourceWithKey:handler.key];
    FTResourceMetricsModel *metricsModel;
    if(handler.metrics){
        metricsModel  = [[FTResourceMetricsModel alloc]initWithTaskMetrics:
                         handler.metrics];
    }
    FTResourceContentModel *contentModel = [[FTResourceContentModel alloc]initWithRequest:task.currentRequest response:response data:handler.data error:error];
    [[FTExternalDataManager sharedManager] addResourceWithKey:handler.key metrics:metricsModel content:contentModel];
    [session invalidateAndCancel];
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
