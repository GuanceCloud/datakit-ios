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
#import "FTExternalDataManager.h"
#import "FTResourceMetricsModel.h"
#import "FTResourceContentModel.h"
#import "FTTraceHandler.h"
@interface NetworkTraceVC ()<UITableViewDelegate,UITableViewDataSource,NSURLSessionDataDelegate>
@property (nonatomic, strong) UITableView *mTableView;
@property (nonatomic, strong) NSArray<NSArray*> *datas;
@property (nonatomic, strong) NSMutableDictionary *taskHandler;

@end

@implementation NetworkTraceVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"network trace";
    self.view.backgroundColor = [UIColor whiteColor];
    self.taskHandler = [NSMutableDictionary new];
    [self createUI];
}
- (void)createUI{
    // enableTraceUserResource = YES;
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:@"开启 Rum enableTraceUserResource 自动采集" handler:^{
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
       
        NSURL *url = [NSURL URLWithString:urlStr];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
        NSString *key = [[NSUUID UUID] UUIDString];
        FTTraceHandler *handler = [[FTTraceHandler alloc]initWithUrl:url identifier:key];
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
        return @"Use Auto Trace";
    }else if(section == 1){
        return @"Use Session Auto Instrumentation";
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
    FTTraceHandler *handler =  self.taskHandler[task];
    [handler taskReceivedMetrics:metrics];

}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    FTTraceHandler *handler =  self.taskHandler[dataTask];
    [handler taskReceivedData:data];

}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    FTTraceHandler *handler =  self.taskHandler[task];
    [handler taskCompleted:task error:error];

    [[FTExternalDataManager sharedManager] stopResourceWithKey:handler.identifier];
    
    [[FTExternalDataManager sharedManager] addResourceWithKey:handler.identifier metrics:handler.metricsModel content:handler.contentModel];
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
