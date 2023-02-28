//
//  NetworkTraceVC.m
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "NetworkTraceVC.h"
#import "TableViewCellItem.h"
#import "HttpEngine.h"
#import <FTMobileAgent/FTMobileAgent.h>
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
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:@"Rum、Trace 开启 Resource 自动采集" handler:^{
        NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
            
        }];
    }];
    // 避免数据重复请关闭 enableTraceUserResource
    TableViewCellItem *item2 = [[TableViewCellItem alloc]initWithTitle:@"直接使用 FTURLSessionDelegate" handler:^{
        HttpEngine *engine = [[HttpEngine alloc]initWithSessionInstrumentationType:InstrumentationDirect];
        [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"继承 FTURLSessionDelegate" handler:^{
        HttpEngine *engine = [[HttpEngine alloc]initWithSessionInstrumentationType:InstrumentationInherit];
        [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"把 FTURLSessionDelegate 设置为属性" handler:^{
        HttpEngine *engine = [[HttpEngine alloc]initWithSessionInstrumentationType:InstrumentationProperty];
        [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
    }];
    
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"手动操作:使用 open api 操作" handler:^{
        NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
        NSString *key = [[NSUUID UUID] UUIDString];
        NSURL *url = [NSURL URLWithString:urlStr];
        // 获取 trace（链路追踪）需要添加的请求头
        NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        for (NSString *httpHeaderField in traceHeader.keyEnumerator) {
            [request addValue:traceHeader[httpHeaderField] forHTTPHeaderField:httpHeaderField];
        }
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
        RUMResource *handler = [[RUMResource alloc]initWithKey:key];
        self.taskHandler[task] = handler;
        [[FTExternalDataManager sharedManager] startResourceWithKey:key];

        [task resume];
    }];
    
    self.datas = @[@[item1],@[item2,item3,item4],@[item5]];
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
        return @"Trace-Autotrace, Rum-Session Auto Instrumentation";
    }else{
        return @"Use Manual";
    }
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    cell.textLabel.text = item.title;
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
